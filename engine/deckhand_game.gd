class_name DeckhandGame
extends RefCounted
## Deckhand rules engine (see GAME_RULES.md). No nodes, no rendering.
##
## The game advances on its own until some players must decide something.
## Those choices are exposed in `pending` (player index -> decision) and
## answered with `submit()`. Decisions asked of several players at once
## (draft picks, build choices...) resolve together once all are answered,
## which models simultaneous play. Bots, the local UI or a network peer all
## drive the game through the same two calls.

signal changed
signal logged(text: String)
## Game moments for presentation (sounds, animations): kind + details.
signal event(kind: String, info: Dictionary)

const ROUNDS := 5
const DRAFT_SIZE := 5
const BEGINNER_FIRST_DRAFT_SIZE := 7
const HAND_LIMIT := 8
const ROW_SIZE := 5
const WINDFALL_DECK := -1

const RANKS := [
	[85, "Sovereign of the High Seas"],
	[65, "Expert Navigator"],
	[50, "Feared and Respected"],
	[40, "Almost-Loyal Buccaneer"],
	[0, "Hull Scraper"],
]

enum Phase { SETUP, DRAFT, BUILD, ROUND_END, GAME_OVER }

var rng := RandomNumberGenerator.new()
## For bots' choices only, so working out a bot's move never changes the game's
## own random sequence (online, only one player's machine plays the bots).
var bot_rng := RandomNumberGenerator.new()
var options := {
	"beginner_draft": false, # 7 cards in the first draft
	"solo_variant": false,   # virtual opponents: random picks, free random builds, no hooks
}

var players: Array[Dictionary] = []
var supply: Array[int] = []
var discard_pile: Array[int] = []
var infamy_deck: Array[int] = []
var removed: Array[int] = [] # Infamy cards lost to ties
## Row slots: {cards: Array[int], revealed: bool}. Revealed cards stay until claimed.
var row: Array[Dictionary] = []
## Face-down Row cards put there by a player: card id -> {player, via:
## "windfall" (stacked) or "swap" (by a Telescope)}. Others came with the Row.
var row_origins := {}
var round_index := 0
var phase := Phase.SETUP
var build_step := 0
var log_lines: Array[String] = []
var final_scores: Array[Dictionary] = []

## player index -> decision dictionary ({type: String, ...}).
var pending: Dictionary = {}
var _answers: Dictionary = {}
var _queue: Array[Dictionary] = []
var _running := false

# --- Setup ------------------------------------------------------------------

## `seats`: Array of {name: String, bot: bool, virtual: bool}. Seat 0 is usually the human.
func setup(seats: Array, seed_value: int = -1, game_options: Dictionary = {}) -> void:
	CardDB.ensure_loaded()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	options.merge(game_options, true)

	players.clear()
	for seat: Dictionary in seats:
		players.append({
			"name": seat.get("name", "Pirate"),
			"bot": seat.get("bot", false),
			"virtual": seat.get("virtual", false),
			"hand": [] as Array[int],
			"windfall": -1,
			"crew": [] as Array[int],
			"passed": false,
			"draft_hand": [] as Array[int],
			"picks": [] as Array[int],
			"compasses_used": 0,
			"compass_draws": 0, # cards drawn by Compasses for the current pick
			"pending_battles": 0,
			"built_this_step": -1,
		})

	var infamy := CardDB.ids_of_kind("infamy")
	_shuffle(infamy)
	row.clear()
	row_origins.clear()
	for i in range(ROW_SIZE):
		row.append({"cards": [infamy.pop_back()] as Array[int], "revealed": false})
	for p in players:
		p.windfall = infamy.pop_back()
	infamy_deck = infamy
	supply = CardDB.ids_of_kind("supply")
	_shuffle(supply)
	discard_pile.clear()
	removed.clear()
	log_lines.clear()
	final_scores.clear()
	pending.clear()
	_answers.clear()
	_queue.clear()
	round_index = 0
	phase = Phase.SETUP

func start() -> void:
	_push_back({"type": "round_start"})
	_run()

# --- Queries ----------------------------------------------------------------

func player_count() -> int:
	return players.size()

func is_solo_variant() -> bool:
	return options.solo_variant

## Odd rounds pass clockwise (+1 seat), even rounds counter-clockwise.
func wind() -> int:
	return 1 if round_index % 2 == 1 else -1

func tentacles(p: int) -> int:
	var total := 0
	for id in players[p].crew:
		total += CardDB.get_card(id).tentacles
	return total

func symbol_count(p: int, key: String) -> int:
	var total := 0
	for id in players[p].crew:
		total += int(CardDB.get_card(id)[key])
	return total

## Raised banners by type (banners on flagpoles in the crew).
func raised_banners(p: int) -> Dictionary:
	var out := {}
	for b in CardDB.BANNERS:
		out[b] = 0
	for id in players[p].crew:
		for b: String in CardDB.get_card(id).banners:
			out[b] += 1
	return out

func crew_production_slots(p: int) -> Array:
	var slots: Array = []
	for id in players[p].crew:
		for slot: Array in CardDB.get_card(id).production:
			slots.append(slot)
	return slots

func can_claim(p: int, infamy_id: int) -> bool:
	var have := raised_banners(p)
	var need := {}
	for b: String in CardDB.get_card(infamy_id).cost:
		need[b] = need.get(b, 0) + 1
	for b in need:
		if have[b] < need[b]:
			return false
	return true

## Revealed, unclaimed Infamy cards in the row.
func claimable_cards() -> Array[int]:
	var out: Array[int] = []
	for slot in row:
		if slot.revealed:
			out.append_array(slot.cards)
	return out

func unrevealed_slots() -> Array[int]:
	var out: Array[int] = []
	for i in range(row.size()):
		if not row[i].revealed:
			out.append(i)
	return out

func supply_cards_in_hand(p: int) -> Array[int]:
	return players[p].hand.duplicate()

func hand_size(p: int) -> int:
	return players[p].hand.size() + (1 if players[p].windfall >= 0 else 0)

func card_score(p: int, id: int) -> int:
	var card := CardDB.get_card(id)
	var score: int = card.vp
	if card.multiplier != null:
		score += card.multiplier.vp * raised_banners(p)[card.multiplier.banner]
	return score

func score(p: int) -> int:
	var total := 0
	for id in players[p].crew:
		total += card_score(p, id)
	return total

## Where the score comes from: printed VP of supply (crew) and Infamy cards,
## and the banner multipliers.
func score_breakdown(p: int) -> Dictionary:
	var out := {"crew": 0, "infamy": 0, "multipliers": 0}
	var banners := raised_banners(p)
	for id in players[p].crew:
		var card := CardDB.get_card(id)
		out["infamy" if card.kind == "infamy" else "crew"] += card.vp
		if card.multiplier != null:
			out.multipliers += card.multiplier.vp * banners[card.multiplier.banner]
	return out

static func rank_for(points: int) -> String:
	for entry in RANKS:
		if points >= entry[0]:
			return entry[1]
	return RANKS[-1][1]

## Can player `p` afford `card_id` with these discards?
func check_payment(p: int, card_id: int, discards: Array, use_windfall: bool) -> Dictionary:
	return Payment.evaluate(CardDB.get_card(card_id).cost, crew_production_slots(p), discards, use_windfall)

## A fingerprint of the whole game state: equal on every machine that applied
## the same actions to the same seed (online play compares them).
func checksum() -> int:
	var state := [rng.state, round_index, phase, build_step, supply, discard_pile, infamy_deck, removed, row, row_origins, pending.keys(), _queue]
	for p in players:
		state.append([p.hand, p.windfall, p.crew, p.passed, p.draft_hand, p.picks, p.compasses_used, p.compass_draws, p.pending_battles])
	return hash(var_to_str(state))

## Players from `candidates` in priority order: most tentacles first
## (random among ties), then around the table in the wind direction.
func priority_order(candidates: Array) -> Array[int]:
	if candidates.is_empty():
		return []
	var best := -1
	var leaders: Array[int] = []
	for p: int in candidates:
		var t := tentacles(p)
		if t > best:
			best = t
			leaders = [p]
		elif t == best:
			leaders.append(p)
	var first: int = leaders[rng.randi_range(0, leaders.size() - 1)]
	var out: Array[int] = []
	var n := players.size()
	for k in range(n):
		var seat := posmod(first + k * wind(), n)
		if candidates.has(seat):
			out.append(seat)
	return out

# --- Decisions --------------------------------------------------------------

## Why `action` would be rejected for player `p`, or "" if it is valid.
## Changes nothing (online play checks a move before sending it).
func validate(p: int, action: Dictionary) -> String:
	if not pending.has(p):
		return "No decision pending for this player"
	var decision: Dictionary = pending[p]
	return call("_validate_" + decision.type, p, decision, action)

## Returns "" on success, otherwise why the action was rejected.
func submit(p: int, action: Dictionary) -> String:
	if not pending.has(p):
		return "No decision pending for this player"
	var decision: Dictionary = pending[p]
	var error: String = call("_validate_" + decision.type, p, decision, action)
	if not error.is_empty():
		return error
	pending.erase(p)
	if decision.type == "draft_pick" and action.get("redraw", false):
		# Nobody waits on a mulligan: it is played at once.
		_redraw_draft(p)
	elif decision.get("group", false):
		_answers[p] = action
	else:
		call("_answer_" + decision.type, p, decision, action)
	_run()
	return ""

func _ask(p: int, decision: Dictionary) -> void:
	pending[p] = decision

# --- Task queue -------------------------------------------------------------

func _push_back(task: Dictionary) -> void:
	_queue.append(task)

## Inserts tasks so they run next, in the given order.
func _push_front(tasks: Array) -> void:
	for i in range(tasks.size() - 1, -1, -1):
		_queue.push_front(tasks[i])

func _run() -> void:
	if _running:
		return
	_running = true
	while pending.is_empty() and not _queue.is_empty():
		var task: Dictionary = _queue.pop_front()
		call("_task_" + task.type, task)
	_running = false
	changed.emit()

func _log(text: String) -> void:
	log_lines.append(text)
	logged.emit(text)

func _shuffle(cards: Array) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp

func _draw_supply() -> int:
	if supply.is_empty():
		if discard_pile.is_empty():
			return -1
		supply = discard_pile.duplicate()
		discard_pile.clear()
		_shuffle(supply)
		_log("The discard pile is shuffled into a new Supply deck.")
		event.emit("shuffle", {"deck": "supply"})
	return supply.pop_back()

func _draw_into_hand(p: int, count: int) -> int:
	var drawn := 0
	for _i in range(count):
		var id := _draw_supply()
		if id < 0:
			break
		players[p].hand.append(id)
		drawn += 1
	return drawn

func _name(p: int) -> String:
	return players[p].name

# --- Rounds -----------------------------------------------------------------

func _task_round_start(_task: Dictionary) -> void:
	round_index += 1
	build_step = 0
	for p in players:
		p.passed = false
		p.compasses_used = 0
	_log("— Round %d — the wind blows %s." % [round_index, "clockwise" if wind() == 1 else "counter-clockwise"])
	event.emit("round_start", {})
	var slot: Dictionary = row[round_index - 1]
	slot.revealed = true
	for id in slot.cards:
		_log("Infamy revealed: %s." % CardDB.title(id))
		event.emit("reveal", {"card": id})
	_push_front([
		{"type": "claims"},
		{"type": "draft_begin"},
		{"type": "build_begin"},
		{"type": "round_end"},
	])

func _task_round_end(_task: Dictionary) -> void:
	phase = Phase.ROUND_END
	var asked := false
	for p in range(players.size()):
		var excess := hand_size(p) - HAND_LIMIT
		if excess > 0:
			_ask(p, {"type": "hand_limit", "group": true, "count": excess})
			asked = true
	if asked:
		_push_front([{"type": "hand_limit_resolve"}])
	_push_back({"type": "round_start"} if round_index < ROUNDS else {"type": "game_end"})

func _validate_hand_limit(p: int, decision: Dictionary, action: Dictionary) -> String:
	var cards: Array = action.get("discards", [])
	var count := cards.size() + (1 if action.get("windfall", false) else 0)
	if count != decision.count:
		return "Discard exactly %d card(s)" % decision.count
	for id in cards:
		if not players[p].hand.has(id) or cards.count(id) > 1:
			return "Invalid card"
	if action.get("windfall", false) and players[p].windfall < 0:
		return "No Windfall to discard"
	return ""

func _task_hand_limit_resolve(_task: Dictionary) -> void:
	for p in _answers:
		var action: Dictionary = _answers[p]
		for id: int in action.get("discards", []):
			players[p].hand.erase(id)
			discard_pile.append(id)
		if action.get("windfall", false):
			_discard_windfall(p, action.get("windfall_dest", WINDFALL_DECK))
		_log("%s discards down to %d cards." % [_name(p), HAND_LIMIT])
	_answers.clear()

func _task_game_end(_task: Dictionary) -> void:
	phase = Phase.GAME_OVER
	final_scores.clear()
	for p in range(players.size()):
		final_scores.append({"player": p, "score": score(p), "tentacles": tentacles(p)})
	final_scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.score != b.score:
			return a.score > b.score
		return a.tentacles > b.tentacles)
	var top: Dictionary = final_scores[0]
	var winners: Array[String] = []
	for entry in final_scores:
		if entry.score == top.score and entry.tentacles == top.tentacles:
			winners.append(_name(entry.player))
	_log("Game over! %s %s with %d VP." % [" & ".join(winners), "wins" if winners.size() == 1 else "share the victory", top.score])
	event.emit("game_end", {})

func winners() -> Array[int]:
	var out: Array[int] = []
	if final_scores.is_empty():
		return out
	var top: Dictionary = final_scores[0]
	for entry in final_scores:
		if entry.score == top.score and entry.tentacles == top.tentacles:
			out.append(entry.player)
	return out

# --- Draft ------------------------------------------------------------------

func _task_draft_begin(_task: Dictionary) -> void:
	phase = Phase.DRAFT
	var size := DRAFT_SIZE
	if round_index == 1 and options.beginner_draft:
		size = BEGINNER_FIRST_DRAFT_SIZE
	# Everyone must receive the same number of cards.
	size = mini(size, (supply.size() + discard_pile.size()) / players.size())
	for p in players:
		p.draft_hand.clear()
		p.picks.clear()
		for _i in range(size):
			p.draft_hand.append(_draw_supply())
	_log("Draft: each pirate draws %d cards." % size)
	event.emit("deal", {})
	_push_front([{"type": "draft_step"}])

## The round 1 mulligan, offered with the first pick: discard the whole
## draft hand, draw as many new cards, and pick from those.
func _redraw_draft(p: int) -> void:
	var size: int = players[p].draft_hand.size()
	discard_pile.append_array(players[p].draft_hand)
	players[p].draft_hand.clear()
	for _i in range(size):
		var id := _draw_supply()
		if id >= 0:
			players[p].draft_hand.append(id)
	_log("%s redraws their draft hand." % _name(p))
	event.emit("deal", {"player": p})
	_ask_draft_pick(p)

func compasses_available(p: int) -> int:
	return symbol_count(p, "compasses") - players[p].compasses_used

func _task_draft_step(_task: Dictionary) -> void:
	if players[0].draft_hand.is_empty():
		for p in players:
			p.hand.append_array(p.picks)
			p.picks.clear()
		_log("Draft complete.")
		return
	for p in range(players.size()):
		_ask_draft_pick(p, round_index == 1 and players[p].picks.is_empty())
	_push_front([{"type": "draft_resolve"}])

## Compasses may be used one after another on the same pick: each draws a
## card, and the pick then discards as many cards as they drew.
func _ask_draft_pick(p: int, can_redraw: bool = false) -> void:
	var cards_left := supply.size() + discard_pile.size()
	_ask(p, {
		"type": "draft_pick",
		"group": true,
		"discards": players[p].compass_draws,
		"can_redraw": can_redraw,
		"can_use_compass": compasses_available(p) > 0 and cards_left > 0,
	})

func _validate_draft_pick(p: int, decision: Dictionary, action: Dictionary) -> String:
	var hand: Array = players[p].draft_hand
	if action.get("redraw", false):
		return "" if decision.can_redraw else "You can only redraw before your first pick"
	if action.get("use_compass", false):
		return "" if decision.can_use_compass else "No Compass available"
	if not hand.has(action.get("pick", -1)):
		return "Pick a card from your draft hand"
	var discards: Array = action.get("discards", [])
	if discards.size() != decision.discards:
		return "Choose %d card%s to discard (Compass)" % [decision.discards, "" if decision.discards == 1 else "s"]
	for i in discards.size():
		var d: int = discards[i]
		if not hand.has(d) or d == action.pick or discards.find(d) != i:
			return "Choose other cards to discard (Compass)"
	return ""

func _task_draft_resolve(_task: Dictionary) -> void:
	# A Compass request draws a card and re-asks that player before passing.
	var compass_users: Array = []
	for p in _answers:
		if _answers[p].get("use_compass", false):
			compass_users.append(p)
	if not compass_users.is_empty():
		for p: int in compass_users:
			_answers.erase(p)
			players[p].compasses_used += 1
			var id := _draw_supply()
			if id >= 0:
				players[p].draft_hand.append(id)
				players[p].compass_draws += 1
				_log("%s uses a Compass." % _name(p))
			_ask_draft_pick(p)
		_push_front([{"type": "draft_resolve"}])
		return

	for p in _answers:
		var action: Dictionary = _answers[p]
		players[p].draft_hand.erase(action.pick)
		players[p].picks.append(action.pick)
		for d: int in action.get("discards", []):
			players[p].draft_hand.erase(d)
			discard_pile.append(d)
		players[p].compass_draws = 0
	_answers.clear()

	var n := players.size()
	var hands: Array = []
	for p in players:
		hands.append(p.draft_hand)
	for p in range(n):
		players[posmod(p + wind(), n)].draft_hand = hands[p]
	event.emit("draft_pass", {})
	_push_front([{"type": "draft_step"}])

# --- Build loop -------------------------------------------------------------

func _task_build_begin(_task: Dictionary) -> void:
	phase = Phase.BUILD
	build_step += 1
	var real_active := false
	for p in range(players.size()):
		var pl: Dictionary = players[p]
		pl.built_this_step = -1
		if pl.passed or pl.virtual:
			continue
		if pl.hand.is_empty():
			pl.passed = true
			_log("%s has nothing left to build and passes." % _name(p))
			continue
		_ask(p, {"type": "build", "group": true})
		real_active = true
	if not real_active:
		for pl in players:
			pl.passed = true
		return
	_push_front([{"type": "build_resolve"}])

func _validate_build(p: int, _decision: Dictionary, action: Dictionary) -> String:
	if action.get("pass", false):
		return ""
	var pl: Dictionary = players[p]
	var id: int = action.get("card", -1)
	if not pl.hand.has(id):
		return "Choose a Supply card from your hand"
	var discards: Array = action.get("discards", [])
	for d in discards:
		if d == id or not pl.hand.has(d) or discards.count(d) > 1:
			return "Invalid payment card"
	var use_windfall: bool = action.get("windfall", false)
	if use_windfall:
		if pl.windfall < 0:
			return "No Windfall to discard"
		var dest: int = action.get("windfall_dest", WINDFALL_DECK)
		if dest != WINDFALL_DECK and (dest < 0 or dest >= row.size() or row[dest].revealed):
			return "The Windfall can only go on an unrevealed Row slot"
	if not check_payment(p, id, discards, use_windfall).ok:
		return "Those discards don't cover the cost"
	return ""

func _task_build_resolve(_task: Dictionary) -> void:
	var builders: Array[int] = []
	for p in _answers:
		var action: Dictionary = _answers[p]
		var pl: Dictionary = players[p]
		if action.get("pass", false):
			pl.passed = true
			_log("%s passes." % _name(p))
			event.emit("pass", {"player": p})
			continue
		pl.hand.erase(action.card)
		for d: int in action.get("discards", []):
			pl.hand.erase(d)
			discard_pile.append(d)
		if action.get("windfall", false):
			_discard_windfall(p, action.get("windfall_dest", WINDFALL_DECK))
		pl.built_this_step = action.card
		builders.append(p)
		var paid: int = action.get("discards", []).size()
		_log("%s builds %s%s." % [_name(p), CardDB.title(action.card),
			"" if paid == 0 else " (discarding %d)" % paid])
		event.emit("build", {"player": p, "paid": paid})
	_answers.clear()

	# Solo variant: virtual opponents build a random card for free whenever someone builds.
	if not builders.is_empty():
		for p in range(players.size()):
			var pl: Dictionary = players[p]
			if pl.virtual and not pl.hand.is_empty():
				var id: int = pl.hand[rng.randi_range(0, pl.hand.size() - 1)]
				pl.hand.erase(id)
				pl.built_this_step = id
				builders.append(p)
				_log("%s builds %s." % [_name(p), CardDB.title(id)])
				event.emit("build", {"player": p, "paid": 0})

	if builders.is_empty():
		return

	# Battles announced earlier resolve on this build.
	var battles_due := {}
	for p in builders:
		if players[p].pending_battles > 0:
			battles_due[p] = players[p].pending_battles
			players[p].pending_battles = 0

	var tasks: Array = []
	for p in priority_order(builders):
		tasks.append({"type": "add_to_crew", "player": p, "card": players[p].built_this_step})
	for p in priority_order(battles_due.keys()):
		tasks.append({"type": "battle", "player": p, "count": battles_due[p], "participants": builders})
	tasks.append({"type": "claims"})
	tasks.append({"type": "build_begin"})
	_push_front(tasks)

func _discard_windfall(p: int, dest: int) -> void:
	var id: int = players[p].windfall
	players[p].windfall = -1
	if dest != WINDFALL_DECK and dest >= 0 and dest < row.size() and not row[dest].revealed:
		row[dest].cards.append(id)
		row_origins[id] = {"player": p, "via": "windfall"}
		_log("%s stacks their Windfall on Row slot %d." % [_name(p), dest + 1])
	else:
		infamy_deck.append(id)
		_shuffle(infamy_deck)
		event.emit("shuffle", {"deck": "infamy"})
		_log("%s shuffles their Windfall into the Infamy deck." % _name(p))

# --- Crew and effects -------------------------------------------------------

func _task_add_to_crew(task: Dictionary) -> void:
	var p: int = task.player
	var id: int = task.card
	var card := CardDB.get_card(id)
	players[p].crew.append(id)
	event.emit("crew", {"player": p, "card": id})

	var tasks: Array = []
	for effect: String in card.effects:
		tasks.append({"type": "effect", "player": p, "effect": effect, "source": id})
	# "Each time you add X to your crew" triggers on other crew cards.
	for other in players[p].crew:
		if other == id:
			continue
		var trigger: Variant = CardDB.get_card(other).trigger
		if trigger == null:
			continue
		var times := 0
		if trigger.on == "tentacle":
			times = card.tentacles
		else:
			times = card.banners.count(trigger.on)
		for _i in range(times):
			tasks.append({"type": "effect", "player": p, "effect": trigger.effect, "source": other})
	_push_front(tasks)

func _task_effect(task: Dictionary) -> void:
	var p: int = task.player
	match task.effect:
		"draw-1", "draw-2":
			var n := _draw_into_hand(p, 1 if task.effect == "draw-1" else 2)
			_log("%s draws %d card%s (%s)." % [_name(p), n, "" if n == 1 else "s", CardDB.title(task.source)])
			var hand: Array[int] = players[p].hand
			event.emit("draw", {"player": p, "source": task.source, "cards": hand.slice(hand.size() - n)})
		"3-choices":
			var drawn: Array[int] = []
			for _i in range(3):
				var id := _draw_supply()
				if id >= 0:
					drawn.append(id)
			if drawn.is_empty():
				return
			_ask(p, {"type": "choose_one", "cards": drawn, "source": task.source})
		"telescope":
			_start_telescope(p, task.source)
		"hook":
			_start_hook(p, task.source)
		"battle":
			players[p].pending_battles += 1
			_log("%s announces a Battle! It resolves on their next build." % _name(p))
			event.emit("battle_announce", {"player": p})
		"compass":
			pass # Passive: used during the draft.

func _validate_choose_one(_p: int, decision: Dictionary, action: Dictionary) -> String:
	return "" if decision.cards.has(action.get("card", -1)) else "Choose one of the drawn cards"

func _answer_choose_one(p: int, decision: Dictionary, action: Dictionary) -> void:
	for id: int in decision.cards:
		if id == action.card:
			players[p].hand.append(id)
		else:
			discard_pile.append(id)
	_log("%s draws 3 and keeps one (%s)." % [_name(p), CardDB.title(decision.source)])
	event.emit("draw", {"player": p})

func _start_telescope(p: int, source: int) -> void:
	if infamy_deck.is_empty():
		return
	var slots := unrevealed_slots()
	if slots.is_empty():
		_ask(p, {"type": "telescope_place", "card": infamy_deck[-1], "source": source})
	elif slots.size() == 1:
		_telescope_on_slot(p, slots[0], source)
	else:
		_ask(p, {"type": "telescope_slot", "slots": slots, "source": source})

## A slot is chosen: with Windfalls stacked on it, which of its cards to look at.
func _telescope_on_slot(p: int, slot: int, source: int) -> void:
	if row[slot].cards.size() > 1:
		_ask(p, {"type": "telescope_card", "slot": slot, "cards": row[slot].cards.duplicate(), "source": source})
	else:
		_ask_telescope_swap(p, slot, 0, source)

func _ask_telescope_swap(p: int, slot: int, index: int, source: int) -> void:
	_ask(p, {"type": "telescope_swap", "slot": slot, "index": index, "row_card": row[slot].cards[index], "deck_card": infamy_deck[-1], "source": source})

func _validate_telescope_slot(_p: int, decision: Dictionary, action: Dictionary) -> String:
	return "" if decision.slots.has(action.get("slot", -1)) else "Choose an unrevealed Row slot"

func _answer_telescope_slot(p: int, decision: Dictionary, action: Dictionary) -> void:
	_telescope_on_slot(p, action.slot, decision.source)

## Action: {"index"}, the card's place in the slot's stack (0: the Row's own).
func _validate_telescope_card(_p: int, decision: Dictionary, action: Dictionary) -> String:
	var index: int = action.get("index", -1)
	return "" if index >= 0 and index < decision.cards.size() else "Choose a card of the stack"

func _answer_telescope_card(p: int, decision: Dictionary, action: Dictionary) -> void:
	_ask_telescope_swap(p, decision.slot, action.index, decision.source)

func _validate_telescope_swap(_p: int, _decision: Dictionary, _action: Dictionary) -> String:
	return ""

func _answer_telescope_swap(p: int, decision: Dictionary, action: Dictionary) -> void:
	if action.get("swap", false):
		var slot_cards: Array[int] = row[decision.slot].cards
		slot_cards[decision.index] = infamy_deck.pop_back()
		infamy_deck.append(decision.row_card)
		row_origins.erase(decision.row_card)
		row_origins[slot_cards[decision.index]] = {"player": p, "via": "swap"}
		_log("%s peeks with a Telescope and swaps an Infamy card in slot %d." % [_name(p), decision.slot + 1])
		event.emit("telescope", {"player": p})
	else:
		_log("%s peeks with a Telescope." % _name(p))
		event.emit("telescope", {"player": p})
	_shuffle(infamy_deck)
	event.emit("shuffle", {"deck": "infamy"})

func _validate_telescope_place(_p: int, _decision: Dictionary, _action: Dictionary) -> String:
	return ""

func _answer_telescope_place(p: int, decision: Dictionary, action: Dictionary) -> void:
	if action.get("place", false):
		infamy_deck.pop_back()
		row[ROW_SIZE - 1].cards.append(decision.card)
		_log("%s places %s face up in the Row." % [_name(p), CardDB.title(decision.card)])
		event.emit("telescope", {"player": p})
		_push_front([{"type": "claims"}])
	else:
		_log("%s peeks with a Telescope." % _name(p))
		event.emit("telescope", {"player": p})
	_shuffle(infamy_deck)
	event.emit("shuffle", {"deck": "infamy"})

func _start_hook(p: int, source: int) -> void:
	if is_solo_variant():
		return
	var targets: Array[int] = []
	for q in range(players.size()):
		if q != p and not players[q].hand.is_empty():
			targets.append(q)
	if targets.is_empty():
		return
	if targets.size() == 1:
		_resolve_hook(p, targets[0], source)
	else:
		_ask(p, {"type": "hook_target", "targets": targets, "source": source})

func _validate_hook_target(_p: int, decision: Dictionary, action: Dictionary) -> String:
	return "" if decision.targets.has(action.get("target", -1)) else "Choose an opponent"

func _answer_hook_target(p: int, decision: Dictionary, action: Dictionary) -> void:
	_resolve_hook(p, action.target, decision.source)

func _resolve_hook(p: int, target: int, _source: int) -> void:
	var their: Array[int] = players[target].hand
	var stolen: int = their[rng.randi_range(0, their.size() - 1)]
	their.erase(stolen)
	players[p].hand.append(stolen)
	_log("%s hooks a card from %s." % [_name(p), _name(target)])
	event.emit("hook", {"player": p, "target": target, "card": stolen})
	if symbol_count(p, "hooks") < 3:
		_ask(p, {"type": "hook_give", "target": target, "stolen": stolen})

func _validate_hook_give(p: int, _decision: Dictionary, action: Dictionary) -> String:
	return "" if players[p].hand.has(action.get("card", -1)) else "Give back a Supply card from your hand"

func _answer_hook_give(p: int, decision: Dictionary, action: Dictionary) -> void:
	players[p].hand.erase(action.card)
	players[decision.target].hand.append(action.card)
	_log("%s gives a card back to %s." % [_name(p), _name(decision.target)])
	event.emit("hook_give", {"player": p, "target": decision.target, "card": action.card})

## Each participant scores the card they just built (with multipliers),
## plus 1 per Battle symbol in their crew. The best score draws.
func _task_battle(task: Dictionary) -> void:
	var p: int = task.player
	var best := -1
	var leaders: Array[int] = []
	var parts: Array[String] = []
	var scores := {}
	var details := {} # player -> {card, value, bonus}: how each score was made
	for q: int in task.participants:
		var built: int = players[q].built_this_step
		var value := card_score(q, built)
		var bonus := symbol_count(q, "battles")
		var s := value + bonus
		parts.append("%s %d" % [_name(q), s])
		scores[q] = s
		details[q] = {"card": built, "value": value, "bonus": bonus}
		if s > best:
			best = s
			leaders = [q]
		elif s == best:
			leaders.append(q)
	var winner := _break_tie(leaders)
	_log("Battle for %s: %s." % [_name(p), ", ".join(parts)])
	if winner < 0:
		_log("The Battle is a draw.")
		event.emit("battle", {"player": p, "winner": -1, "scores": scores, "details": details, "count": task.count})
		return
	var n := _draw_into_hand(winner, task.count)
	_log("%s wins the Battle and draws %d." % [_name(winner), n])
	event.emit("battle", {"player": p, "winner": winner, "scores": scores, "details": details, "count": n})

## Tentacles break ties; returns -1 if still tied.
func _break_tie(tied: Array[int]) -> int:
	if tied.size() == 1:
		return tied[0]
	var best := -1
	var leaders: Array[int] = []
	for q in tied:
		var t := tentacles(q)
		if t > best:
			best = t
			leaders = [q]
		elif t == best:
			leaders.append(q)
	return leaders[0] if leaders.size() == 1 else -1

# --- Infamy claims ----------------------------------------------------------

## Resolves one claim at a time (so new Tentacles can break later ties),
## then re-checks.
func _task_claims(_task: Dictionary) -> void:
	var winners_by_card := {}
	for id in claimable_cards():
		var qualified: Array[int] = []
		for p in range(players.size()):
			if can_claim(p, id):
				qualified.append(p)
		if qualified.is_empty():
			continue
		var winner := _break_tie(qualified)
		if winner < 0:
			_remove_from_row(id)
			removed.append(id)
			_log("%s is contested by several pirates and is lost." % CardDB.title(id))
			event.emit("lost", {"card": id, "rivals": qualified})
			_push_front([{"type": "claims"}])
			return
		winners_by_card[id] = winner
	if winners_by_card.is_empty():
		return
	var claimants: Array = []
	for id in winners_by_card:
		if not claimants.has(winners_by_card[id]):
			claimants.append(winners_by_card[id])
	var first: int = priority_order(claimants)[0]
	for id in winners_by_card:
		if winners_by_card[id] == first:
			_remove_from_row(id)
			_log("%s claims %s!" % [_name(first), CardDB.title(id)])
			event.emit("claim", {"player": first, "card": id})
			_push_front([{"type": "add_to_crew", "player": first, "card": id}, {"type": "claims"}])
			return

func _remove_from_row(id: int) -> void:
	for slot in row:
		slot.cards.erase(id)

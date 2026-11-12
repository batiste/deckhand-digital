class_name DeckhandBot
extends RefCounted
## Heuristic opponent. `decide()` answers any pending decision for a player.
## Virtual opponents (solo variant) play randomly, as the rules describe.

const EFFECT_VALUES := {
	"draw-1": 1.0, "draw-2": 2.0, "3-choices": 1.3, "telescope": 0.4,
	"hook": 0.8, "battle": 0.9, "compass": 0.0,
}
## Cards an effect brings into hand (a Hook steals one, gives one back below
## 3 Hooks: counted as a fraction).
const EFFECT_CARDS := {"draw-1": 1.0, "draw-2": 2.0, "3-choices": 1.25, "hook": 0.5}

## Weights of the engine-aware valuation. `legacy` plays the older bot (for
## comparison in tools/bot_arena.gd).
const DEFAULTS := {
	"legacy": false,
	"card_worth": 1.6,       # a card in hand, early (build or payment material)
	"card_worth_late": 0.6,  # ... in the last round
	"builds_per_round": 4.0, # expected own builds in a round, at least
	"production_use": 0.45,  # value of one production slot per future build
	"pass_threshold": -0.3,  # build when the net value beats this
	"burden": 1.5,           # draft: each resource the crew can't pay costs this many cards' worth
	"multiplier_reach": 1.0, # how many of the banners still to come a multiplier counts
	"discard_cost": 2.2,     # a card discarded to pay, in cards in hand (they are scarce)
	"vp_early": 0.4,         # weight of VP (and multipliers) in round 1, rising to 1 by the last
	"keep_buildable": 0.5,   # what a hand card is worth to keep: its value less its build cost, times this
	"spend_penalty": 2.0,    # build: extra cost per card discarded to pay, in round 1 (patience: production
	                         # built later pays for free), falling to nothing in the last round
	# Card-drawing triggers are valued at what they really draw: matching
	# cards in hand (if affordable) plus a share of the builds still to come,
	# at the rate bots really build (tools/trigger_stats.gd checks it).
	"trigger_builds_per_round": 3.3,
	"trigger_weight": 1.0,   # weight of what a trigger will draw
	"trigger_synergy": 0.25, # ... plus this per card-drawing trigger already in the crew
	"collector_chance": 0.35,# chance a bot plays a game as a collector of card-drawing triggers (it
	"collector_weight": 1.6, # then weights them this much: optimistic, so it goes for them)
	"collector_bailout": 3,  # from this round, a collector with no card-drawing trigger gives up
}
## Per-player weights overriding DEFAULTS (bot experiments).
static var tuning := {}

static func param(p: int, key: String) -> Variant:
	return tuning.get(p, {}).get(key, DEFAULTS[key])

static func decide(game: DeckhandGame, p: int) -> Dictionary:
	var decision: Dictionary = game.pending[p]
	if game.players[p].virtual:
		return _decide_random(game, p, decision)
	match decision.type:
		"draft_pick":
			return _draft_pick(game, p, decision)
		"build":
			return _build(game, p)
		"choose_one":
			return {"card": _best(game, p, decision.cards)}
		"telescope_slot":
			return {"slot": decision.slots[0]}
		"telescope_card":
			# Another pirate's Windfall is the one worth knowing about.
			return {"index": decision.cards.size() - 1}
		"telescope_swap":
			return {"swap": _claim_distance(game, p, decision.deck_card) < _claim_distance(game, p, decision.row_card)}
		"telescope_place":
			return {"place": _claim_distance(game, p, decision.card) <= 1}
		"hook_target":
			return {"target": _richest(game, decision.targets)}
		"hook_give":
			# Any card may go back, but handing back the one just taken
			# looks like nothing happened: only when there is no other.
			var others: Array = game.players[p].hand.filter(func(id: int) -> bool: return id != decision.stolen)
			return {"card": _worst(game, p, others if not others.is_empty() else game.players[p].hand)}
		"hand_limit":
			return _hand_limit(game, p, decision.count)
	push_error("Bot cannot answer %s" % decision.type)
	return {}

static func _decide_random(game: DeckhandGame, p: int, decision: Dictionary) -> Dictionary:
	var rng := game.bot_rng
	var pl: Dictionary = game.players[p]
	match decision.type:
		"draft_pick":
			var hand: Array = pl.draft_hand
			var pick: int = hand[rng.randi_range(0, hand.size() - 1)]
			return {"pick": pick, "discards": hand.filter(func(id: int) -> bool: return id != pick).slice(0, decision.discards)}
		"hand_limit":
			var cards: Array = pl.hand.duplicate()
			for i in range(cards.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var tmp: int = cards[i]
				cards[i] = cards[j]
				cards[j] = tmp
			var discards := cards.slice(0, decision.count)
			var out := {"discards": discards}
			if discards.size() < decision.count:
				out.windfall = true
			return out
		"choose_one":
			return {"card": decision.cards[rng.randi_range(0, decision.cards.size() - 1)]}
		"telescope_slot":
			return {"slot": decision.slots[rng.randi_range(0, decision.slots.size() - 1)]}
		"telescope_card":
			return {"index": rng.randi_range(0, decision.cards.size() - 1)}
	return {"redraw": false, "swap": false, "place": false}

# --- Valuation --------------------------------------------------------------

static func rounds_left(game: DeckhandGame) -> int:
	return DeckhandGame.ROUNDS - game.round_index

## How much a card is worth to player `p` if built now (approximate VP).
static func card_value(game: DeckhandGame, p: int, id: int) -> float:
	if param(p, "legacy"):
		return _legacy_value(game, p, id)
	var card := CardDB.get_card(id)
	var left := rounds_left(game)
	var progress := float(game.round_index - 1) / float(DeckhandGame.ROUNDS - 1)
	var banners := game.raised_banners(p)
	var worth := card_worth(game, p)
	var builds := expected_builds(game, p)
	# Points only count at the end: early on, an engine matters more.
	var vp_weight := lerpf(param(p, "vp_early"), 1.0, progress)
	var value := float(card.vp) * vp_weight

	if card.multiplier != null:
		# Banners raised later count too: more of them in a bigger crew.
		var share := _banner_share(card.multiplier.banner)
		var expected: float = float(banners[card.multiplier.banner] + card.banners.count(card.multiplier.banner)) + builds * share * param(p, "multiplier_reach")
		value += card.multiplier.vp * expected * vp_weight

	# Production pays (instead of discards) for every later build.
	value += card.production.size() * param(p, "production_use") * builds * (0.8 if card.production.size() == 1 and card.production[0].size() > 1 else 1.0)

	var wanted := _wanted_banners(game, p)
	for b: String in card.banners:
		value += 0.35 + wanted.get(b, 0.0)
		for other in game.players[p].crew:
			var mult: Variant = CardDB.get_card(other).multiplier
			if mult != null and mult.banner == b:
				value += mult.vp

	# Its own effects, and the triggers it sets off in the crew already.
	for e: String in card.effects:
		value += _effect_value(e, worth)
	for other in game.players[p].crew:
		var trigger: Variant = CardDB.get_card(other).trigger
		if trigger == null:
			continue
		var times: int = card.tentacles if trigger.on == "tentacle" else card.banners.count(trigger.on)
		value += times * _effect_value(trigger.effect, worth)
	# Its own trigger: on every matching card added later. Matching cards
	# already in hand are a sure thing (if the crew can afford them); future
	# builds are a bet that shrinks as the game runs out.
	if card.trigger != null:
		var synergy: float = param(p, "trigger_synergy") * _draw_triggers(game, p)
		var weight: float = param(p, "collector_weight" if _is_collector(game, p) else "trigger_weight") + synergy
		value += trigger_draws(game, p, id) * _effect_value(card.trigger.effect, worth) * weight
	value += card.compasses * 0.35 * left
	value += card.tentacles * 0.8
	# Late game, raw VP is all that matters.
	return lerpf(value, float(game.card_score(p, id)) + 0.5 * card.vp, progress * progress * 0.5)

## How many times card `id`'s trigger can be expected to fire for `p` if
## built now: matching cards in hand (as likely as they are affordable),
## then a share of the builds still to come at the rate bots really build.
## Its own symbols don't set it off.
static func trigger_draws(game: DeckhandGame, p: int, id: int) -> float:
	var trigger: Variant = CardDB.get_card(id).trigger
	if trigger == null:
		return 0.0
	var on: String = trigger.on
	var in_hand := 0.0
	var matching := 0
	for h: int in game.players[p].hand:
		if h == id:
			continue
		var hc := CardDB.get_card(h)
		var times: int = hc.tentacles if on == "tentacle" else hc.banners.count(on)
		if times > 0:
			in_hand += times * _buildable_odds(game, p, h)
			matching += 1
	var share := _tentacle_share() if on == "tentacle" else _banner_share(on)
	var per_round := maxf(param(p, "trigger_builds_per_round"), game.players[p].crew.size() / maxf(game.round_index - 1, 1.0))
	# The hand cards are among those builds: the rest come from new cards.
	var builds := maxf(per_round * (rounds_left(game) + 0.5) - matching, 0.0)
	return in_hand + builds * share

## What a card in hand is worth to `p`: more early, when it can still be built.
static func card_worth(game: DeckhandGame, p: int) -> float:
	var progress := float(game.round_index - 1) / float(DeckhandGame.ROUNDS - 1)
	return lerpf(param(p, "card_worth"), param(p, "card_worth_late"), progress)

## Builds `p` can still expect this game: at least `builds_per_round` a
## round, more if its crew already builds faster.
static func expected_builds(game: DeckhandGame, p: int) -> float:
	var per_round := maxf(param(p, "builds_per_round"), game.players[p].crew.size() / maxf(game.round_index - 1, 1.0))
	return per_round * (rounds_left(game) + 0.5)

## Whether `p` plays this game as a collector of card-drawing triggers
## (decided once per game, so bots vary from game to game). A collector
## still without one in crew or hand by the `collector_bailout` round
## gives the strategy up for the rest of the game.
static func _is_collector(game: DeckhandGame, p: int) -> bool:
	var pl: Dictionary = game.players[p]
	if not pl.has("collector"):
		pl.collector = game.bot_rng.randf() < param(p, "collector_chance")
	if pl.collector and game.round_index >= param(p, "collector_bailout") \
			and _draw_triggers(game, p) == 0 and _draw_triggers_in(pl.hand) == 0:
		pl.collector = false
	return pl.collector

## How likely `p` is to build card `id` from hand: what the crew can't pay
## costs discards, and a costly card more often ends up paying instead.
static func _buildable_odds(game: DeckhandGame, p: int, id: int) -> float:
	var burden := _cost_burden(game, p, id)
	if burden <= 1.0:
		return 1.0
	if burden <= 2.5:
		return 0.6
	return 0.25

## Card-drawing triggers in `p`'s crew.
static func _draw_triggers(game: DeckhandGame, p: int) -> int:
	return _draw_triggers_in(game.players[p].crew)

static func _draw_triggers_in(cards: Array) -> int:
	var n := 0
	for id: int in cards:
		var trigger: Variant = CardDB.get_card(id).trigger
		if trigger != null and EFFECT_CARDS.has(trigger.effect):
			n += 1
	return n

static func _effect_value(effect: String, worth: float) -> float:
	if EFFECT_CARDS.has(effect):
		return EFFECT_CARDS[effect] * worth
	return EFFECT_VALUES.get(effect, 0.0)

## Share of Supply cards with banner `b` (how often a built card raises it).
static func _banner_share(b: String) -> float:
	if not _shares.has(b):
		var n := 0
		var ids := CardDB.ids_of_kind("supply")
		for id in ids:
			n += CardDB.get_card(id).banners.count(b)
		_shares[b] = float(n) / ids.size()
	return _shares[b]

static func _tentacle_share() -> float:
	if not _shares.has("tentacle"):
		var n := 0
		var ids := CardDB.ids_of_kind("supply")
		for id in ids:
			n += CardDB.get_card(id).tentacles
		_shares["tentacle"] = float(n) / ids.size()
	return _shares["tentacle"]

static var _shares := {}

## The first bot's valuation.
static func _legacy_value(game: DeckhandGame, p: int, id: int) -> float:
	var card := CardDB.get_card(id)
	var left := rounds_left(game)
	var progress := float(game.round_index - 1) / float(DeckhandGame.ROUNDS - 1) # 0 early, 1 last round
	var banners := game.raised_banners(p)
	var value := float(card.vp)

	if card.multiplier != null:
		var expected := float(banners[card.multiplier.banner] + card.banners.count(card.multiplier.banner)) + left * 0.7
		value += card.multiplier.vp * expected

	# Production pays off over the remaining build steps.
	value += card.production.size() * (0.4 + 0.45 * left) * (0.8 if card.production.size() == 1 and card.production[0].size() > 1 else 1.0)

	var wanted := _wanted_banners(game, p)
	for b: String in card.banners:
		value += 0.35 + wanted.get(b, 0.0)
		for other in game.players[p].crew:
			var mult: Variant = CardDB.get_card(other).multiplier
			if mult != null and mult.banner == b:
				value += mult.vp

	for e: String in card.effects:
		value += EFFECT_VALUES.get(e, 0.0)
	value += card.compasses * 0.35 * left
	value += card.tentacles * 0.8
	if card.trigger != null:
		value += 0.6 * left
	# Late game, raw VP is all that matters.
	return lerpf(value, float(game.card_score(p, id)) + 0.5 * card.vp, progress * progress * 0.5)

## Value of keeping a card in hand (as future build or payment fodder).
static func keep_value(game: DeckhandGame, p: int, id: int) -> float:
	if not param(p, "legacy"):
		# A card likely to be built is worth keeping; one too costly for the
		# crew to build is payment material.
		var k: float = param(p, "keep_buildable")
		if k > 0.0:
			var buildable := card_value(game, p, id) - _cost_burden(game, p, id) * card_worth(game, p)
			return maxf(card_worth(game, p) * 0.5, card_worth(game, p) * 0.5 + buildable * k)
		# Worth its future build, or at least what it pays for.
		return maxf(card_worth(game, p) * param(p, "discard_cost"), card_value(game, p, id) * (0.15 if game.round_index == DeckhandGame.ROUNDS else 0.25) + 0.3)
	if game.round_index == DeckhandGame.ROUNDS:
		return 0.3 + card_value(game, p, id) * 0.15
	return 0.4 + card_value(game, p, id) * 0.25

## Banner types that move us towards claimable Infamy cards.
static func _wanted_banners(game: DeckhandGame, p: int) -> Dictionary:
	var wanted := {}
	var have := game.raised_banners(p)
	for slot in game.row:
		if not slot.revealed:
			continue # Face down: bots don't peek.
		for id: int in slot.cards:
			var card := CardDB.get_card(id)
			var need := {}
			for b: String in card.cost:
				need[b] = need.get(b, 0) + 1
			var missing := 0
			for b in need:
				missing += maxi(need[b] - have[b], 0)
			if missing == 0:
				continue
			var weight: float = (card.vp + 2.0) / float(missing + 1)
			for b in need:
				if have[b] < need[b]:
					wanted[b] = wanted.get(b, 0.0) + weight * 0.5
	return wanted

static func _claim_distance(game: DeckhandGame, p: int, infamy_id: int) -> int:
	var have := game.raised_banners(p)
	var need := {}
	for b: String in CardDB.get_card(infamy_id).cost:
		need[b] = need.get(b, 0) + 1
	var missing := 0
	for b in need:
		missing += maxi(need[b] - have[b], 0)
	return missing

## Rough cost of the payment still needed after crew production.
static func _cost_burden(game: DeckhandGame, p: int, id: int) -> float:
	var missing := Payment.missing_after_crew(CardDB.get_card(id).cost, game.crew_production_slots(p))
	var burden := 0.0
	for token in missing:
		if param(p, "legacy"):
			burden += 0.35 if token == "c" or token == "cs" else 0.8
		else:
			# Cards it takes: a coin is one discard (gold only comes that way);
			# a resource is one revealed card that makes it, or two any.
			burden += 1.0 if token == "c" or token == "cs" else 1.4
	return burden

# --- Decisions --------------------------------------------------------------

static func _draft_hand_quality(game: DeckhandGame, p: int) -> float:
	var values: Array = []
	for id: int in game.players[p].draft_hand:
		values.append(card_value(game, p, id) - _cost_burden(game, p, id))
	values.sort()
	values.reverse()
	return values.slice(0, 3).reduce(func(a: float, b: float) -> float: return a + b, 0.0)

static func _draft_pick(game: DeckhandGame, p: int, decision: Dictionary) -> Dictionary:
	if decision.can_redraw and _draft_hand_quality(game, p) < 4.5:
		return {"redraw": true}
	# One Compass per pick: the bots spread them over the draft.
	if decision.can_use_compass and decision.discards == 0 and game.players[p].draft_hand.size() > 1:
		return {"use_compass": true}
	var hand: Array = game.players[p].draft_hand
	var scored: Array = []
	for id: int in hand:
		var burden := _cost_burden(game, p, id) * 0.6
		if not param(p, "legacy"):
			# What building it will cost in cards discarded.
			burden = _cost_burden(game, p, id) * card_worth(game, p) * param(p, "burden")
		scored.append([card_value(game, p, id) - burden, id])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	# The weakest cards go, as many as the Compasses drew.
	var discards := scored.slice(scored.size() - decision.discards).map(func(entry: Array) -> int: return entry[1])
	return {"pick": scored[0][1], "discards": discards}

static func _build(game: DeckhandGame, p: int) -> Dictionary:
	var pl: Dictionary = game.players[p]
	var crew_slots := game.crew_production_slots(p)
	var keep := func(id: int) -> float: return keep_value(game, p, id)
	var windfall_value := INF if pl.windfall < 0 else (0.9 if game.round_index < DeckhandGame.ROUNDS else 0.1)
	var progress := float(game.round_index - 1) / float(DeckhandGame.ROUNDS - 1)
	var spend: float = 0.0 if param(p, "legacy") else param(p, "spend_penalty") * (1.0 - progress)
	# Cards beyond the hand limit are lost at the end of the round: no
	# patience then, they may as well pay.
	if game.hand_size(p) > DeckhandGame.HAND_LIMIT:
		spend = 0.0
	var best := {}
	var best_net := -INF
	for id: int in pl.hand:
		var others: Array = pl.hand.filter(func(o: int) -> bool: return o != id)
		var plan := Payment.plan(CardDB.get_card(id).cost, crew_slots, others, keep, windfall_value)
		if not plan.ok:
			continue
		var net := card_value(game, p, id)
		for d: int in plan.discards:
			net -= keep_value(game, p, d) + spend
		if plan.windfall:
			net -= windfall_value + spend * 2.0
		if net > best_net:
			best_net = net
			best = {"card": id, "discards": plan.discards, "windfall": plan.windfall, "windfall_dest": DeckhandGame.WINDFALL_DECK}
	# Now and then, a spent Windfall goes face down on a later Row slot
	# (rounds 3 to 5) rather than back into the Infamy deck.
	if best.get("windfall", false) and game.bot_rng.randf() < 0.45:
		var later := game.unrevealed_slots().filter(func(slot: int) -> bool: return slot >= 2)
		if not later.is_empty():
			best.windfall_dest = later[game.bot_rng.randi_range(0, later.size() - 1)]
	# Cards beyond the hand limit are lost anyway, so build more eagerly then.
	var threshold := 0.2 if game.hand_size(p) <= DeckhandGame.HAND_LIMIT else -0.8
	if game.round_index == DeckhandGame.ROUNDS:
		threshold = -0.5
	if not param(p, "legacy"):
		threshold = minf(threshold, param(p, "pass_threshold"))
	if best.is_empty() or best_net < threshold:
		return {"pass": true}
	return best

static func _hand_limit(game: DeckhandGame, p: int, count: int) -> Dictionary:
	var cards: Array = game.players[p].hand.duplicate()
	cards.sort_custom(func(a: int, b: int) -> bool: return keep_value(game, p, a) < keep_value(game, p, b))
	var discards := cards.slice(0, count)
	var out := {"discards": discards}
	if discards.size() < count:
		out.windfall = true
	return out

static func _best(game: DeckhandGame, p: int, cards: Array) -> int:
	var best: int = cards[0]
	for id: int in cards:
		if card_value(game, p, id) > card_value(game, p, best):
			best = id
	return best

static func _worst(game: DeckhandGame, p: int, cards: Array) -> int:
	var worst: int = cards[0]
	for id: int in cards:
		if keep_value(game, p, id) < keep_value(game, p, worst):
			worst = id
	return worst

static func _richest(game: DeckhandGame, targets: Array) -> int:
	var best: int = targets[0]
	for q: int in targets:
		if game.players[q].hand.size() > game.players[best].hand.size():
			best = q
	return best

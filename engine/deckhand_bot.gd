class_name DeckhandBot
extends RefCounted
## Heuristic opponent. `decide()` answers any pending decision for a player.
## Virtual opponents (solo variant) play randomly, as the rules describe.

const EFFECT_VALUES := {
	"draw-1": 1.0, "draw-2": 2.0, "3-choices": 1.3, "telescope": 0.4,
	"hook": 0.8, "battle": 0.9, "compass": 0.0,
}

static func decide(game: DeckhandGame, p: int) -> Dictionary:
	var decision: Dictionary = game.pending[p]
	if game.players[p].virtual:
		return _decide_random(game, p, decision)
	match decision.type:
		"mulligan":
			return {"redraw": _draft_hand_quality(game, p) < 4.5}
		"draft_pick":
			return _draft_pick(game, p, decision)
		"build":
			return _build(game, p)
		"choose_one":
			return {"card": _best(game, p, decision.cards)}
		"telescope_slot":
			return {"slot": decision.slots[0]}
		"telescope_swap":
			return {"swap": _claim_distance(game, p, decision.deck_card) < _claim_distance(game, p, decision.row_card)}
		"telescope_place":
			return {"place": _claim_distance(game, p, decision.card) <= 1}
		"hook_target":
			return {"target": _richest(game, decision.targets)}
		"hook_give":
			return {"card": _worst(game, p, game.players[p].hand)}
		"hand_limit":
			return _hand_limit(game, p, decision.count)
	push_error("Bot cannot answer %s" % decision.type)
	return {}

static func _decide_random(game: DeckhandGame, p: int, decision: Dictionary) -> Dictionary:
	var rng := game.rng
	var pl: Dictionary = game.players[p]
	match decision.type:
		"draft_pick":
			var hand: Array = pl.draft_hand
			var pick: int = hand[rng.randi_range(0, hand.size() - 1)]
			var out := {"pick": pick}
			if decision.must_discard:
				out.discard = hand.filter(func(id: int) -> bool: return id != pick)[0]
			return out
		"hand_limit":
			var cards: Array = pl.hand.duplicate()
			game._shuffle(cards)
			var discards := cards.slice(0, decision.count)
			var out := {"discards": discards}
			if discards.size() < decision.count:
				out.windfall = true
			return out
		"choose_one":
			return {"card": decision.cards[rng.randi_range(0, decision.cards.size() - 1)]}
		"telescope_slot":
			return {"slot": decision.slots[0]}
	return {"redraw": false, "swap": false, "place": false}

# --- Valuation --------------------------------------------------------------

static func rounds_left(game: DeckhandGame) -> int:
	return DeckhandGame.ROUNDS - game.round_index

## How much a card is worth to player `p` if built now (approximate VP).
static func card_value(game: DeckhandGame, p: int, id: int) -> float:
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
		burden += 0.35 if token == "c" or token == "cs" else 0.8
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
	if decision.can_use_compass and game.players[p].draft_hand.size() > 1:
		return {"use_compass": true}
	var hand: Array = game.players[p].draft_hand
	var scored: Array = []
	for id: int in hand:
		scored.append([card_value(game, p, id) - _cost_burden(game, p, id) * 0.6, id])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var out := {"pick": scored[0][1]}
	if decision.must_discard:
		out.discard = scored[-1][1]
	return out

static func _build(game: DeckhandGame, p: int) -> Dictionary:
	var pl: Dictionary = game.players[p]
	var crew_slots := game.crew_production_slots(p)
	var keep := func(id: int) -> float: return keep_value(game, p, id)
	var windfall_value := INF if pl.windfall < 0 else (0.9 if game.round_index < DeckhandGame.ROUNDS else 0.1)
	var best := {}
	var best_net := -INF
	for id: int in pl.hand:
		var others: Array = pl.hand.filter(func(o: int) -> bool: return o != id)
		var plan := Payment.plan(CardDB.get_card(id).cost, crew_slots, others, keep, windfall_value)
		if not plan.ok:
			continue
		var net := card_value(game, p, id)
		for d: int in plan.discards:
			net -= keep_value(game, p, d)
		if plan.windfall:
			net -= windfall_value
		if net > best_net:
			best_net = net
			best = {"card": id, "discards": plan.discards, "windfall": plan.windfall, "windfall_dest": DeckhandGame.WINDFALL_DECK}
	# Cards beyond the hand limit are lost anyway, so build more eagerly then.
	var threshold := 0.2 if game.hand_size(p) <= DeckhandGame.HAND_LIMIT else -0.8
	if game.round_index == DeckhandGame.ROUNDS:
		threshold = -0.5
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

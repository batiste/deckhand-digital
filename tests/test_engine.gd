extends SceneTree
## Headless engine tests. Run with:
##   godot --headless --path . --script res://tests/test_engine.gd

var failures := 0

func _init() -> void:
	CardDB.ensure_loaded()
	test_card_data()
	test_payment()
	test_full_games()
	print("\n%s" % ("ALL TESTS PASSED" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(1 if failures > 0 else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func test_card_data() -> void:
	check(CardDB.ids_of_kind("supply").size() == 96, "96 supply cards")
	check(CardDB.ids_of_kind("infamy").size() == 12, "12 infamy cards")
	check(CardDB.get_card(39).production == [["g", "p"]], "Bazaar produces gun | parrot")
	check(CardDB.get_card(11).multiplier.banner == "coin", "Inking Oath multiplies coin banners")

func test_payment() -> void:
	# Tavern Keeper costs 3 silver coins; any 3 discarded cards pay it.
	var cost: Array = ["cs", "cs", "cs"]
	check(not Payment.evaluate(cost, [], [13, 14], false).ok, "2 cards can't pay 3 coins")
	check(Payment.evaluate(cost, [], [13, 14, 15], false).ok, "3 cards pay 3 coins")
	check(Payment.evaluate(cost, [["cs"]], [13, 14], false).ok, "crew silver + 2 cards")
	check(Payment.evaluate(cost, [], [13], true).ok, "windfall (2 coins) + 1 card")
	# Bitter Vintage: a revealed parrot, then the windfall and 3 cards as two pairs.
	var vintage := ["g", "p", "s"]
	check(not Payment.evaluate(vintage, [], [19, 13, 14, 15], false).ok, "4 cards can't pay gun, parrot and skull")
	check(Payment.evaluate(vintage, [], [19, 13, 14, 15], true).ok, "the windfall pairs with a card for any resource")
	var with_windfall := Payment.plan(vintage, [], [19, 13, 14, 15], func(_id: int) -> float: return 1.0, 1.0)
	check(with_windfall.ok and with_windfall.windfall, "plan pairs the windfall")
	# Hypnotic Frogs: 4 parrots. Tropical Messenger (19) produces parrot when revealed.
	var frogs: Array = ["p", "p", "p", "p"]
	check(Payment.evaluate(frogs, [["p"], ["p"]], [19, 99], false).ok, "2 crew parrots + 2 revealed parrot cards")
	check(not Payment.evaluate(frogs, [["p"], ["p"]], [19, 20], false).ok, "Arms Dealer can't be revealed for a parrot")
	check(Payment.evaluate(frogs, [["p"], ["p"]], [19, 20, 21], false).ok, "two cards pair into any resource")
	# Choice slots can only be used once.
	check(not Payment.evaluate(["g", "p"], [["g", "p"]], [], false).ok, "a g|p slot pays only one")
	check(Payment.missing_after_crew(["g", "p"], [["g", "p"]]).size() == 1, "one token missing")
	var plan := Payment.plan(frogs, [["p"]], [19, 20, 21, 22, 23], func(_id: int) -> float: return 1.0)
	check(plan.ok and Payment.evaluate(frogs, [["p"]], plan.discards, plan.windfall).ok, "plan finds a valid payment")

func test_full_games() -> void:
	var stats := {"games": 0, "claims": 0, "total_score": 0, "max_score": 0}
	for seed_value in range(40):
		var n := 2 + seed_value % 4
		var solo := seed_value % 10 == 9
		var seats: Array = []
		for i in range(n if not solo else 2):
			seats.append({"name": "Bot %d" % i, "bot": true, "virtual": solo and i == 1})
		var game := DeckhandGame.new()
		game.setup(seats, seed_value, {"solo_variant": solo, "beginner_draft": seed_value % 3 == 0})
		game.start()
		var guard := 0
		while game.phase != DeckhandGame.Phase.GAME_OVER and guard < 5000:
			guard += 1
			check_conservation(game, seed_value)
			var p: int = game.pending.keys()[0]
			var action := DeckhandBot.decide(game, p)
			var error := game.submit(p, action)
			if not error.is_empty():
				check(false, "seed %d: bot action rejected (%s): %s -> %s" % [seed_value, game.pending[p].type, action, error])
				break
		check(game.phase == DeckhandGame.Phase.GAME_OVER, "seed %d: game finished (guard %d)" % [seed_value, guard])
		check_conservation(game, seed_value)
		stats.games += 1
		for p in range(game.player_count()):
			var s := game.score(p)
			stats.total_score += s
			stats.max_score = maxi(stats.max_score, s)
			for id in game.players[p].crew:
				if CardDB.is_infamy(id):
					stats.claims += 1
		if seed_value < 3:
			print("seed %d scores: %s" % [seed_value, game.final_scores])
	print("simulated %d games, avg score %.1f, best %d, %d infamy claims" % [
		stats.games, float(stats.total_score) / (stats.games * 3.0), stats.max_score, stats.claims])

func check_conservation(game: DeckhandGame, seed_value: int) -> void:
	var seen := {}
	var all: Array = []
	all.append_array(game.supply)
	all.append_array(game.discard_pile)
	all.append_array(game.infamy_deck)
	all.append_array(game.removed)
	for slot in game.row:
		all.append_array(slot.cards)
	for pl in game.players:
		all.append_array(pl.hand)
		all.append_array(pl.crew)
		all.append_array(pl.draft_hand)
		all.append_array(pl.picks)
		if pl.windfall >= 0:
			all.append(pl.windfall)
	for d in game.pending.values():
		if d.type == "choose_one":
			all.append_array(d.cards)
	# Built or claimed cards waiting for their turn to join a crew.
	for task in game._queue:
		if task.type == "add_to_crew" and not CardDB.is_infamy(task.card):
			all.append(task.card)
	for id in all:
		if seen.has(id):
			check(false, "seed %d: card %d duplicated" % [seed_value, id])
		seen[id] = true
	if all.size() != 108:
		check(false, "seed %d: %d cards accounted for (expected 108) in phase %d" % [seed_value, all.size(), game.phase])

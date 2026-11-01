extends SceneTree
## Online play end to end: two tables (two players) in one process, through a
## relay running locally (cd server && npm run dev):
##   godot --headless --path . -s res://tests/test_online.gd -- --relay=http://localhost:8787
## Anna creates a table, Ben joins it, Anna starts with a bot; each plays their
## own seat (Anna's machine also plays the bot). Midway, Ben's connection is
## cut; he reconnects and catches up. Both games must end identical.

var failures := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures += 1

func _init() -> void:
	var anna: Control = await _table()
	var ben: Control = await _table()

	var got := {} # (a lambda cannot assign to a local)
	anna._net.create_table(func(c: String) -> void: got.code = c)
	if not await _until(func() -> bool: return got.get("code", "") != "", 10.0):
		check(false, "the relay hands out a table code (is it running?)")
		quit(1)
		return
	var code: String = got.code
	anna._net.join(code, "Anna")
	await _until(func() -> bool: return anna._net.player_id == 0, 10.0)
	ben._net.join(code, "Ben")
	await _until(func() -> bool: return anna._net.players.size() == 2, 10.0)
	check(anna._net.is_host() and not ben._net.is_host(), "Anna hosts the table %s, Ben joined" % code)

	anna._net.start_game(1, {})
	await _until(func() -> bool: return anna._online and ben._online and anna.game != null and ben.game != null, 10.0)
	check(anna._seat == 0 and ben._seat == 1 and anna.game.player_count() == 3, "both see 3 seats; Anna is seat 0, Ben seat 1")

	var cut := false
	var deadline := Time.get_ticks_msec() + 600 * 1000
	while Time.get_ticks_msec() < deadline and not (_over(anna) and _over(ben)):
		for t: Control in [anna, ben]:
			if t.game != null and t.game.pending.has(t._seat):
				t._submit(DeckhandBot.decide(t.game, t._seat))
		if not cut and anna._applied >= 60:
			cut = true
			ben._net._socket.close() # dropped: it reconnects on its own
			var caught_up := await _until(func() -> bool: return ben._applied >= 60 and ben._applied == anna._applied, 20.0)
			check(caught_up and ben.game.checksum() == anna.game.checksum(), "Ben reconnects and catches up to the same game")
		await process_frame
	check(_over(anna) and _over(ben), "the game is played to the end online (%d actions)" % anna._applied)
	check(anna._applied == ben._applied and anna.game.checksum() == ben.game.checksum(), "both copies end identical")
	check(anna.game.final_scores == ben.game.final_scores, "same final scores: %s" % [anna.game.final_scores])
	print("\nALL ONLINE TESTS PASSED" if failures == 0 else "\n%d FAILURE(S)" % failures)
	quit(1 if failures else 0)

func _over(t: Control) -> bool:
	return t.game != null and t.game.phase == DeckhandGame.Phase.GAME_OVER

func _table() -> Control:
	var t: Control = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(t)
	await process_frame
	t._menu.visible = false
	return t

## Waits until `test` is true (or `seconds` pass); returns whether it is.
func _until(test: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not test.call() and Time.get_ticks_msec() < end:
		await process_frame
	return test.call()

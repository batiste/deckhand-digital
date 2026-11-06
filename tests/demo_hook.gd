extends SceneTree
## Stages the Hook ceremonies and saves screenshots (temporary demo driver).
##   godot --path . -s res://tests/demo_hook.gd -- --out=/some/dir

var out := "/tmp"
var table: Control

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	table = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(table)
	await process_frame
	table.settings.solo = false
	table.settings.opponents = 2
	table._new_game()
	# Fast-forward to a build turn of the human seat, with a few cards in hand.
	var guard := 0
	while guard < 5000:
		guard += 1
		var g: DeckhandGame = table.game
		if g.phase == DeckhandGame.Phase.BUILD and g.pending.has(0) and g.round_index >= 2 \
				and g.players[0].hand.size() >= 3 and g.players[1].hand.size() >= 2:
			break
		if g.pending.has(0):
			g.submit(0, DeckhandBot.decide(g, 0))
		table._process(1.0)
		await process_frame
	await create_timer(5.0).timeout
	await shot("0_before")

	var g: DeckhandGame = table.game
	if "--mess" in OS.get_cmdline_user_args():
		# A Battle and two Hooks at once.
		g.event.emit("battle", {"player": 1, "winner": 2, "scores": {0: 3, 1: 4, 2: 6}, "count": 1})
		g._resolve_hook(1, 0, -1)
		g._resolve_hook(2, 0, -1)
		g._run()
		g.changed.emit()
		for i in range(16):
			await create_timer(0.6).timeout
			await shot("m%02d" % i)
		quit(0)
		return
	# A: a rival hooks a card from you (and gives one back).
	g._resolve_hook(1, 0, -1)
	g._run()
	g.changed.emit()
	for t in [["a0_tug1", 0.15], ["a0_tug2", 0.45], ["a1_rising", 0.9], ["a2_spotlight", 1.4], ["a3_leaving", 1.6], ["a4_gift", 0.55], ["a5_after", 2.0]]:
		await create_timer(t[1]).timeout
		await shot(t[0])

	# B: you hook a card from a rival.
	g._resolve_hook(0, 1, -1)
	g._run()
	g.changed.emit()
	for t in [["b1_arriving", 1.0], ["b2_spotlight", 1.2], ["b3_prompt", 3.0]]:
		await create_timer(t[1]).timeout
		await shot(t[0])
	# Pick a card to give back (not the stolen one): the confirmation.
	var stolen: int = g.pending[0].stolen
	for view in table._hand_views:
		if view.card_id != stolen and not view.get_meta("windfall", false):
			table._on_hand_clicked(view)
			break
	await create_timer(0.8).timeout
	await shot("b4_confirm")
	table._submit({"card": table._give_card})
	for t in [["b5_giving", 0.35], ["b6_given", 0.35]]:
		await create_timer(t[1]).timeout
		await shot(t[0])
	quit(0)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)

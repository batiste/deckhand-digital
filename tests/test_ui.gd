extends SceneTree
## Headless UI smoke test: plays full games through the table scene,
## answering the human seat with the bot logic.
##   godot --headless --path . --script res://tests/test_ui.gd

func _init() -> void:
	var table: Control = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(table)
	await process_frame
	for solo in [false, true]:
		table.settings.solo = solo
		table.settings.opponents = 3
		table._new_game()
		var guard := 0
		while table.game.phase != DeckhandGame.Phase.GAME_OVER and guard < 20000:
			guard += 1
			if table.game.pending.has(0):
				var decision: Dictionary = table.game.pending[0]
				# Exercise the build UI path for the human seat.
				if decision.type == "build" and not table.game.players[0].hand.is_empty():
					table._build_card = table.game.players[0].hand[0]
					table._auto_pay()
				var error: String = table.game.submit(0, DeckhandBot.decide(table.game, 0))
				if not error.is_empty():
					printerr("human action rejected: ", error)
					quit(1)
					return
			table._process(1.0)
			await process_frame
		print("solo=%s finished=%s scores=%s" % [solo, table.game.phase == DeckhandGame.Phase.GAME_OVER, table.game.final_scores])
	quit(0)

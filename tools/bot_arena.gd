extends SceneTree
## Bot against bot: seats alternate between two settings ("new" = the
## defaults with ARENA_NEW overrides, "old" = legacy or ARENA_OLD), seats and
## seeds rotated so neither side is favoured. Prints wins and average scores.
##   godot --headless --path . -s res://tools/bot_arena.gd -- games=80 new='{"pass_threshold": -0.5}'

func _init() -> void:
	var games := 80
	var new_params := {}
	var old_params := {"legacy": true}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("games="):
			games = int(arg.trim_prefix("games="))
		elif arg.begins_with("new="):
			new_params = JSON.parse_string(arg.trim_prefix("new="))
		elif arg.begins_with("old="):
			old_params = JSON.parse_string(arg.trim_prefix("old="))
	var stats := {"new": {"wins": 0.0, "score": 0.0, "crew": 0.0, "n": 0, "paid": 0.0, "builds": 0.0}, "old": {"wins": 0.0, "score": 0.0, "crew": 0.0, "n": 0, "paid": 0.0, "builds": 0.0}}
	for k in games:
		var n := 2 + k % 3
		var side := []
		for i in n:
			side.append("new" if (i + k) % 2 == 0 else "old")
		var seats: Array = []
		DeckhandBot.tuning.clear()
		for i in n:
			seats.append({"name": "P%d" % i, "bot": true})
			DeckhandBot.tuning[i] = new_params if side[i] == "new" else old_params
		var g := DeckhandGame.new()
		g.setup(seats, 20000 + k, {})
		g.start()
		var guard := 0
		while g.phase != DeckhandGame.Phase.GAME_OVER and guard < 30000:
			guard += 1
			var p: int = g.pending.keys()[0]
			var move := DeckhandBot.decide(g, p)
			if g.pending[p].type == "build" and move.has("card"):
				stats[side[p]].builds += 1
				stats[side[p]].paid += move.get("discards", []).size()
			var error := g.submit(p, move)
			if not error.is_empty():
				g.submit(p, {"pass": true})
		var winners := g.winners()
		for i in n:
			var st: Dictionary = stats[side[i]]
			st.score += g.score(i)
			st.crew += g.players[i].crew.size()
			st.n += 1
			if winners.has(i):
				st.wins += 1.0 / winners.size()
	for key in ["new", "old"]:
		var st: Dictionary = stats[key]
		print("%s: win share %.0f%%  avg score %.1f  avg crew %.1f  cards paid per build %.2f" % [key, 100.0 * st.wins / games, st.score / st.n, st.crew / st.n, st.paid / maxf(st.builds, 1)])
	quit(0)

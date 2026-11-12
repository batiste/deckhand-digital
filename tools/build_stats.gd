extends SceneTree
## Bot games: builds, cards paid per build, cards lost to the hand limit and
## hand size when passing, per round (how economical the bots are).
##   godot --headless --path . -s res://tools/build_stats.gd
func _init() -> void:
	var games := 200
	var per_round := {} # round -> [builds, paid, limit_lost, hand_end, players]
	var end_hand := 0.0; var np := 0
	for k in games:
		var n := 2 + k % 3
		var seats := []
		for i in n: seats.append({"name": "P%d" % i, "bot": true})
		var g := DeckhandGame.new()
		g.setup(seats, 70000 + k, {})
		g.start()
		var guard := 0
		var last_round := 1
		while g.phase != DeckhandGame.Phase.GAME_OVER and guard < 30000:
			guard += 1
			var p: int = g.pending.keys()[0]
			var d: Dictionary = g.pending[p]
			var move := DeckhandBot.decide(g, p)
			var r := g.round_index
			var row: Array = per_round.get(r, [0.0, 0.0, 0.0, 0.0, 0])
			if d.type == "build" and move.has("card"):
				row[0] += 1; row[1] += move.get("discards", []).size() + (2 if move.get("windfall", false) else 0)
			elif d.type == "hand_limit":
				row[2] += d.count
			elif d.type == "build" and move.get("pass", false):
				row[3] += g.hand_size(p); row[4] += 1
			per_round[r] = row
			g.submit(p, move)
		for q in n:
			end_hand += g.hand_size(q); np += 1
	print("round  builds/player  paid/build  lost-to-limit/player  hand-when-passing")
	var ppg := 0.0
	for k in games: ppg += 2 + k % 3
	for r in range(1, 6):
		var row: Array = per_round[r]
		print("%d  %.2f  %.2f  %.2f  %.1f" % [r, row[0] / ppg, row[1] / maxf(row[0], 1), row[2] / ppg, row[3] / maxf(row[4], 1)])
	print("cards left in hand at game end: %.1f" % (end_hand / np))
	quit()

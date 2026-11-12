extends SceneTree
## Bot games: how many cards the card-drawing triggers actually draw, by how
## many a crew ended with and by the round each was built.
##   godot --headless --path . -s res://tools/trigger_stats.gd
func _init() -> void:
	var games := 300
	var by_count := {} # triggers in final crew -> [n, drawn, score, crew]
	var per_trigger := [] # [round built, cards it drew]
	for k in games:
		var n := 2 + k % 3
		var seats := []
		for i in n:
			seats.append({"name": "P%d" % i, "bot": true})
		DeckhandBot.tuning.clear()
		var g := DeckhandGame.new()
		g.setup(seats, 50000 + k, {})
		var drawn := {}   # trigger card id -> cards drawn
		var built_round := {}
		var collector := {}
		var predicted := {} # trigger card id -> times the bot expected it to fire
		g.event.connect(func(kind: String, data: Dictionary) -> void:
			if data.get("cause", -1) < 0:
				return
			if kind == "draw":
				drawn[data.source] = drawn.get(data.source, 0) + data.cards.size()
			elif kind == "effect" and data.effect == "3-choices":
				drawn[data.source] = drawn.get(data.source, 0) + 1)
		g.start()
		var guard := 0
		var crew_before := {}
		while g.phase != DeckhandGame.Phase.GAME_OVER and guard < 30000:
			guard += 1
			var p: int = g.pending.keys()[0]
			var move := DeckhandBot.decide(g, p)
			if g.pending[p].type == "build" and move.has("card") and CardDB.get_card(move.card).trigger != null:
				predicted[move.card] = DeckhandBot.trigger_draws(g, p, move.card)
			if g.players[p].has("collector") and not collector.has(p):
				collector[p] = g.players[p].collector
			g.submit(p, move)
			for q in n:
				for id: int in g.players[q].crew:
					if CardDB.get_card(id).trigger != null and not built_round.has(id):
						built_round[id] = g.round_index
		for q in n:
			var t := DeckhandBot._draw_triggers(g, q)
			var got := 0
			for id: int in g.players[q].crew:
				if CardDB.get_card(id).trigger != null:
					got += drawn.get(id, 0)
					per_trigger.append([built_round[id], drawn.get(id, 0), predicted.get(id, 0.0)])
			var row: Array = by_count.get(t, [0, 0, 0, 0, 0])
			row[0] += 1; row[1] += got; row[2] += g.score(q); row[3] += g.players[q].crew.size()
			row[4] += 1 if collector.get(q, false) else 0
			by_count[t] = row
	var keys := by_count.keys(); keys.sort()
	print("triggers-in-crew  players  cards-drawn  score  crew  started-as-collector")
	for t in keys:
		var r: Array = by_count[t]
		print("%d  %4d  %.1f  %.1f  %.1f  %d%%" % [t, r[0], float(r[1]) / r[0], float(r[2]) / r[0], float(r[3]) / r[0], 100 * r[4] / r[0]])
	print("per trigger by round built: round, count, avg cards drawn, bot's prediction")
	for r in range(1, 6):
		var rows := per_trigger.filter(func(e): return e[0] == r)
		if rows.size():
			print(r, "  ", rows.size(), "  %.2f  %.2f" % [rows.reduce(func(a, e): return a + e[1], 0) / float(rows.size()), rows.reduce(func(a, e): return a + e[2], 0.0) / float(rows.size())])
	quit()

extends SceneTree
## Screenshots of the table with staged stats (banners, production, symbols,
## VP) for every pirate, to check the layout quickly: no game is played and
## no animation is waited for.
##   godot --path . -s res://tools/ui_showcase.gd -- --out=/some/dir [--preset=full] [--size=1600x900]
## Presets: full (default), ones, high, empty, all (each of them in turn).

const PRESETS := ["full", "ones", "high", "empty"]

## A game whose stats queries return the staged values (per player) instead
## of counting the crew. Players without a stage count as usual.
class StagedGame extends DeckhandGame:
	var stage := {} # player -> {banners, slots, tentacles, battles, hooks, compasses, compass_left, score}

	func raised_banners(p: int) -> Dictionary:
		if not stage.has(p):
			return super(p)
		var out := {}
		for b in CardDB.BANNERS:
			out[b] = stage[p].banners.get(b, 0)
		return out

	func crew_production_slots(p: int) -> Array:
		return stage[p].slots if stage.has(p) else super(p)

	func tentacles(p: int) -> int:
		return stage[p].tentacles if stage.has(p) else super(p)

	func symbol_count(p: int, key: String) -> int:
		return stage[p].get(key, 0) if stage.has(p) else super(p, key)

	func compasses_available(p: int) -> int:
		return stage[p].compass_left if stage.has(p) else super(p)

	func score(p: int) -> int:
		return stage[p].score if stage.has(p) else super(p)

var out := "/tmp"
var size := Vector2i(1600, 900)
var table: Control

func _init() -> void:
	var preset := "full"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--preset="):
			preset = arg.substr(9)
		elif arg.begins_with("--size="):
			var wh := arg.substr(7).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	table = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(table)
	await process_frame
	for name: String in (PRESETS if preset == "all" else [preset]):
		await _show(name)
	quit(0)

func _show(preset: String) -> void:
	table.settings.solo = false
	table.settings.opponents = 2
	table._new_game()
	var real: DeckhandGame = table.game
	var g := StagedGame.new()
	g.setup(_seats(real), 1, {})
	# Everyone gets a crew of real cards, so the crew areas are laid out.
	for p in g.player_count():
		for i in 10 if preset != "empty" else 0:
			g.players[p].crew.append(g.supply.pop_back())
		g.stage[p] = _stage(preset, p)
	table.game = g
	# The real game's deal may still refresh: let it, then render ours.
	for i in 3:
		await process_frame
	for pass_index in 2: # the second pass sees the laid-out sizes
		_hide_extras()
		table._render_top()
		table._render_row()
		table._render_piles()
		table._render_opponents()
		table._render_crew()
		table._render_hand()
		await process_frame
		await process_frame
	# Cards fly in from the deal: let them land.
	await create_timer(1.5).timeout
	_hide_extras()
	await RenderingServer.frame_post_draw
	var path := "%s/showcase_%s.png" % [out, preset]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  (your symbols at size ", table._ledger_symbols.get_meta("icon_size", "?"), ", banners at ", table._ledger_body.get_meta("icon_size", "?"), ")")

static func _seats(game: DeckhandGame) -> Array:
	var seats: Array = []
	for pl: Dictionary in game.players:
		seats.append({"name": pl.name, "bot": pl.get("bot", false)})
	return seats

## Round titles, the draft dialog and the like: out of the picture.
func _hide_extras() -> void:
	table._overlay.visible = false
	table._menu.visible = false
	table._curtain.visible = false
	for layer in [table._title_layer, table._finale]:
		if is_instance_valid(layer):
			layer.visible = false

## The staged stats for `preset`, a little different per player.
static func _stage(preset: String, p: int) -> Dictionary:
	var stage := {"banners": {}, "slots": [], "tentacles": 0, "battles": 0, "hooks": 0, "compasses": 0, "compass_left": 0, "score": 0}
	match preset:
		"full":
			# Every banner (1 to 3), every resource twice, two "A or B"
			# slots, every symbol (1 to 3).
			for i in CardDB.BANNERS.size():
				stage.banners[CardDB.BANNERS[i]] = 1 + (i + p) % 3
			for token: String in CardDB.RESOURCE_NAMES:
				stage.slots.append_array([[token], [token]])
			stage.slots.append_array([["g", "p"], ["h", "s"]])
			stage.tentacles = 1 + p % 3
			stage.battles = 1 + (p + 1) % 3
			stage.hooks = 1 + (p + 2) % 3
			stage.compasses = 3
			stage.compass_left = 1
			stage.score = [117, 88, 42][p % 3]
		"ones":
			for b: String in CardDB.BANNERS:
				stage.banners[b] = 1
			for token: String in CardDB.RESOURCE_NAMES:
				stage.slots.append([token])
			for key in ["tentacles", "battles", "hooks", "compasses", "compass_left"]:
				stage[key] = 1
			stage.score = 9
		"high":
			# A strong late-game crew: the widest realistic case.
			var counts := [10, 8, 7, 6, 5, 4, 3, 2]
			for i in CardDB.BANNERS.size():
				stage.banners[CardDB.BANNERS[i]] = counts[(i + p) % counts.size()]
			var made := [7, 5, 4, 3, 3, 2, 2, 1]
			var tokens := CardDB.RESOURCE_NAMES.keys()
			for i in tokens.size():
				for k in made[(i + p) % made.size()]:
					stage.slots.append([tokens[i]])
			stage.slots.append_array([["g", "p"], ["h", "s"], ["r", "e"]])
			stage.tentacles = 5
			stage.battles = 3
			stage.hooks = 3
			stage.compasses = 2
			stage.compass_left = 1
			stage.score = [117, 96, 104][p % 3]
		"empty":
			pass
	return stage

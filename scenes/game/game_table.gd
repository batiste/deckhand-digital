extends Control
## The single-player table: renders a DeckhandGame and turns clicks into
## decisions for seat 0. Every other seat is played by DeckhandBot.

const BOT_DELAY := 0.45
## Online: how long a player may be away before the host's bots play for them.
const ABSENT_GRACE := 15.0
const ICONS := "res://assets/icons/"
const FONT_REGULAR := "res://scenes/shared/fonts/signika/Signika-Regular.ttf"
const FONT_BOLD := "res://scenes/shared/fonts/signika/Signika-SemiBold.ttf"

const HAND_CARD := Vector2(172, 235)
const ROW_CARD := Vector2(126, 171)
const PILE_CARD := Vector2(78, 106)
## Offset of each card edge drawn under a deck, for its thickness.
const PILE_STEP := Vector2(1.0, 2.0)
const CREW_CARD := Vector2(128, 174)
## Height of a crew card left showing (banners, VP, title) when stacked.
const CREW_PEEK := 49.0
## Crew groups, in order, with their headings.
const CREW_GROUPS := {"basic": "Basic", "advanced": "Advanced", "support": "Support", "infamy": "Infamy"}
const CREW_MAX_COLUMNS := 6
const RESOURCE_ORDER: Array[String] = ["g", "p", "r", "h", "s", "e", "cs", "c"]
const OPP_CARD := Vector2(50, 68)
const OPP_COLUMN_WIDTH := 340.0
const OVERLAY_CARD := Vector2(180, 245)
const OVERLAY_CARD_SMALL := Vector2(135, 184)
const LEDGER_WIDTH := 196.0
## How much of the hand shows above the bottom edge; hovered cards rise fully.
const HAND_VISIBLE := 170.0
const HAND_FOCUS_SCALE := 1.4
const HAND_NEIGHBOUR_SCALE := 1.12
const ZOOM_CARD := Vector2(340, 462)
## Global size multipliers for text and inline icons.
const TEXT_SCALE := 1.15
const ICON_SCALE := 1.25

const WOOD := "res://assets/ui/wood.jpg"
const ROUNDED_SHADER := preload("res://scenes/game/rounded_panel.gdshader")
const PARCHMENT := "res://assets/ui/parchment.jpg"
const LOGO := "res://assets/new-logo.png"
const PUBLISHER_LOGO := "res://assets/tidale-logo.png"
const PUBLISHER_URL := "https://tidale.org/deckhand-race-for-infamy/"
## Title screen paintings, shown in turn.
const MENU_ART: Array[String] = [
	"res://assets/art/kraken.jpg",
	"res://assets/art/walk-plank.jpg",
	"res://assets/art/whale.jpg",
	"res://assets/art/drowned-keeper.jpg",
]
const SLIDE_TIME := 12.0
const SLIDE_FADE := 1.8

const TABLE_TINT := Color(0.26, 0.18, 0.12)
const PANEL_BG := Color(0.06, 0.045, 0.035, 0.84)
const INK := Color(0.22, 0.13, 0.06)
const GOLD := Color(1.0, 0.82, 0.42)
const MUTED := Color(0.62, 0.68, 0.76)
const PLAYER_COLORS := [Color(1.0, 0.82, 0.42), Color(0.55, 0.8, 1.0), Color(1.0, 0.55, 0.5), Color(0.6, 0.9, 0.55), Color(0.85, 0.65, 1.0)]

const BOT_NAMES := ["Calico Mae", "One-Eyed Bart", "Silver Ines", "Doc Barnacle"]
const EFFECT_TEXT := {
	"draw-1": "Draw 1 card.",
	"draw-2": "Draw 2 cards.",
	"3-choices": "Draw 3 cards, keep 1, discard 2.",
	"telescope": "Telescope: look at a face-down Row card and the top Infamy card; you may swap them.",
	"compass": "Compass: once per draft, draw an extra draft card, then discard one before passing.",
	"hook": "Hook: steal a random card from an opponent (give one back unless you have 3 Hooks).",
	"battle": "Battle! Resolves on your next build: best built card (+1 per Battle) draws 1.",
}
const EFFECT_ICONS := {
	"draw-1": "fx-draw-1", "draw-2": "fx-draw-2", "3-choices": "fx-3-choices", "telescope": "fx-telescope",
	"compass": "fx-compass", "hook": "fx-hook", "battle": "fx-battle", "tentacle": "fx-tentacle",
}

var game: DeckhandGame
## Your seat at the table: 0 offline; online, the seat the relay gave you.
var _seat := 0

# Online play (see NetClient): every machine runs the game in lockstep.
var _net: NetClient
var _online := false
var _seats: Array = [] # the relay's seats: {name, bot, owner}
var _applied := 0 # actions from the relay applied so far
var _sent := {} # seat -> the decision a move was already sent for
var _absent_since := {} # player id -> when they dropped out (msec)
var _replaying := false # catching up on a game: no sounds or titles
var settings := {"opponents": 2, "solo": false, "beginner": false}

var _bot_wait := 0.0
var _hand_views: Array[CardView] = []
var _hovered_hand: CardView = null
var _decision: Variant = null # the human decision the input state belongs to

# Input state for the current human decision.
var _build_card := -1
var _pay: Array[int] = []
var _pay_windfall := false
var _windfall_dest := DeckhandGame.WINDFALL_DECK
var _selected: Array[int] = []
var _selected_windfall := false
var _overlay_hidden := false # the player put the current choice aside to look at the table
var _kb_hand := false # the focused hand card was chosen with the keyboard
var _kb_card := -1 # card focused with the keyboard in a choice overlay
var _badges_queued := false
var _using_keys := false # the player is moving between cards with the keyboard
var _kb_index := 0 # position of the card last focused with the keyboard

var _round_label: Label
var _phase_label: Label
var _row_box: HBoxContainer
var _piles_box: HBoxContainer
var _opponents_box: VBoxContainer
var _crew_columns: HBoxContainer
var _crew_panel: PanelContainer
var _pay_panel: PanelContainer # paying for a build: floats over the crew
var _pay_body: VBoxContainer
var _ledger_vp: RichTextLabel
var _ledger_body: RichTextLabel
var _hand_area: Control
var _action_text: RichTextLabel
var _buttons: HBoxContainer
var _log: RichTextLabel
var _overlay: Control
var _overlay_body: VBoxContainer
var _menu: Control
var _credits: Control
var _settings: Control
var _online_panel: Control
var _online_ui := {} # the online panel's controls, by name
var _zoom_layer: CanvasLayer
var _zoom_panel: PanelContainer
var _zoom_card: CardView
var _zoom_info: VBoxContainer # the card's rules, under its picture
var _sfx: Sfx
var _music: Music
var _curtain: ColorRect # black, for fading into a new game
var _slides: Array[TextureRect] = [] # two layers for crossfading the title art

# Card motion: views are rebuilt on every refresh, so poses are captured before
# and replayed by CardMotion after layout.
var _motion: CardMotion
var _motion_gen := 0
var _card_views: Array[CardView] = []
var _hand_pose := {} # card id -> {position, rotation, scale} of the last hand layout
var _pile_views := {} # "supply" / "infamy" / "discard" -> CardView
var _opp_panels := {} # player -> PanelContainer
var _refresh_queued := false
var _unplayed := {} # snapshot whose animation has not started yet
var _title_layer: CanvasLayer # the round title on show, if any
var _hold_choices := false # the round title is up: choices wait for it
var _lost := {} # contested Infamy card id -> the tied players, until it is shown
var _spotlights := 0 # Infamy cards (claimed or contested) still to show; choices wait
var _in_spotlight := {} # card id -> true while shown mid-table (its table copy stays hidden)
var _claimed := {} # Infamy card id -> claiming player, until its flight starts
var _shown := {} # player -> {vp, banners} last displayed, to animate gains

func _ready() -> void:
	CardDB.ensure_loaded()
	_sfx = Sfx.new()
	add_child(_sfx)
	_net = NetClient.new()
	add_child(_net)
	_net.welcomed.connect(func(_id: int, _code: String) -> void: _render_online())
	_net.lobby_changed.connect(_on_lobby_changed)
	_net.started.connect(_on_net_started)
	_net.acted.connect(_on_net_acted)
	_net.desynced.connect(func(_n: int) -> void:
		_flash("Out of step with the table: catching up.")
		_net.join(_net.code, _player_name()))
	_net.failed.connect(func(message: String) -> void:
		_online_status(message)
		_flash(message))
	_net.disconnected.connect(func() -> void:
		if _online:
			_flash("Connection lost: reconnecting…"))
	_music = Music.new()
	add_child(_music)
	_build_ui()
	_motion = CardMotion.new()
	_motion.layer = 5
	add_child(_motion)
	var curtain_layer := CanvasLayer.new()
	curtain_layer.layer = 30
	add_child(curtain_layer)
	_curtain = ColorRect.new()
	_curtain.color = Color.BLACK
	_curtain.set_anchors_preset(PRESET_FULL_RECT)
	_curtain.visible = false
	curtain_layer.add_child(_curtain)
	_open_menu()
	_intro()

# --- Game lifecycle ---------------------------------------------------------

## From the menu: fade to black, set the table up (`begin`), and fade it in.
func _start_game(begin: Callable = _new_game) -> void:
	if _curtain.visible:
		return
	_curtain.visible = true
	_curtain.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_curtain, "modulate:a", 1.0, 0.45)
	tween.tween_callback(begin)
	# Let the deal settle behind the curtain first.
	tween.tween_interval(0.5)
	tween.tween_property(_curtain, "modulate:a", 0.0, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: _curtain.visible = false)

## A game against bots on this machine.
func _new_game() -> void:
	_leave_online()
	var seats: Array = [{"name": "Captain", "bot": false}]
	if settings.solo:
		seats.append({"name": "The Phantom Crew", "bot": true, "virtual": true})
	else:
		var names := BOT_NAMES.duplicate()
		names.shuffle()
		for i in range(settings.opponents):
			seats.append({"name": names[i], "bot": true})
	_begin(seats, -1, {"solo_variant": settings.solo, "beginner_draft": settings.beginner})

func _begin(seats: Array, seed_value: int, options: Dictionary) -> void:
	_menu.visible = false
	_music.play(Music.GAME, 2.0)
	# The first deal, reveal and bot moves happen at once: keep them quiet.
	_sfx.hush(2.5)
	game = DeckhandGame.new()
	game.setup(seats, seed_value, options)
	game.changed.connect(_queue_refresh)
	game.logged.connect(_append_log)
	game.event.connect(_on_game_event)
	_log.clear()
	_decision = null
	_motion.settle()
	_card_views.clear()
	_hand_pose.clear()
	_unplayed = {}
	_shown.clear()
	_claimed.clear()
	_lost.clear()
	_spotlights = 0
	_in_spotlight.clear()
	_hold_choices = false
	game.start()

func _process(delta: float) -> void:
	if game == null or game.phase == DeckhandGame.Phase.GAME_OVER:
		return
	var drive := _bot_seats()
	var bots: Array = game.pending.keys().filter(func(p: int) -> bool:
		return drive.has(p) and not (_sent.has(p) and is_same(_sent[p], game.pending[p])))
	if bots.is_empty():
		return
	var p: int = bots[0]
	var decision: Dictionary = game.pending[p]
	# Simultaneous decisions are answered at once; effect choices are paced so
	# the log can be followed.
	if not decision.get("group", false):
		_bot_wait -= delta
		if _bot_wait > 0.0:
			return
	_bot_wait = BOT_DELAY
	if _online:
		var move := DeckhandBot.decide(game, p)
		if not game.validate(p, move).is_empty() and decision.type == "build":
			move = {"pass": true}
		_sent[p] = decision
		_net.send_action(p, move)
		return
	var error := game.submit(p, DeckhandBot.decide(game, p))
	if not error.is_empty():
		push_error("Bot %d %s rejected: %s" % [p, decision.type, error])
		if decision.type == "build":
			game.submit(p, {"pass": true})

func _submit(action: Dictionary) -> void:
	if not _online:
		var error := game.submit(_seat, action)
		if not error.is_empty():
			_flash(error)
		return
	# Online: checked here, played when the relay sends it back to everyone.
	var problem := game.validate(_seat, action)
	if not problem.is_empty():
		_flash(problem)
		return
	var decision: Dictionary = game.pending[_seat]
	if _sent.has(_seat) and is_same(_sent[_seat], decision):
		return
	_sent[_seat] = decision
	_net.send_action(_seat, action)

## The seats this machine plays for the bots: all but yours offline; online,
## on the host's machine, the bots and players who have been away a while.
func _bot_seats() -> Array:
	var out := []
	for p in range(game.player_count()):
		if p == _seat:
			continue
		if not _online:
			out.append(p)
		elif _net.is_host() and _seat_absent(p):
			out.append(p)
	return out

func _seat_absent(p: int) -> bool:
	var seat: Dictionary = _seats[p]
	if seat.bot:
		return true
	var since: int = _absent_since.get(seat.owner, -1)
	return since >= 0 and (Time.get_ticks_msec() - since) / 1000.0 > ABSENT_GRACE

# --- Online ------------------------------------------------------------------

func _on_net_started(seed_value: int, seats: Array, options: Dictionary, actions: Array) -> void:
	var begin := func() -> void:
		_online = true
		_seats = seats
		_seat = 0
		for i in seats.size():
			if seats[i].owner == _net.player_id:
				_seat = i
		_applied = 0
		_sent.clear()
		_online_panel.visible = false
		var engine_seats := seats.map(func(seat: Dictionary) -> Dictionary: return {"name": seat.name, "bot": seat.bot})
		# Catching up (rejoining): replay the game so far, quietly.
		_replaying = not actions.is_empty()
		_begin(engine_seats, seed_value, options)
		for entry: Dictionary in actions:
			game.submit(entry.seat, entry.action)
		_applied = actions.size()
		_replaying = false
	if _online and game != null and game.phase != DeckhandGame.Phase.GAME_OVER:
		begin.call() # reconnected mid-game: no curtain
	else:
		_start_game(begin)

func _on_net_acted(n: int, seat: int, action: Dictionary) -> void:
	if not _online or game == null or n < _applied:
		return
	if n > _applied:
		# Missed one: rejoining sends the whole game again.
		_net.join(_net.code, _player_name())
		return
	game.submit(seat, action)
	_applied += 1
	_sent.erase(seat)
	if _applied % 5 == 0:
		_net.send_checksum(_applied, game.checksum())

func _on_lobby_changed(players: Array, _host: int, _started: bool) -> void:
	var now := Time.get_ticks_msec()
	for player: Dictionary in players:
		if player.online:
			_absent_since.erase(player.id)
		elif not _absent_since.has(player.id):
			_absent_since[player.id] = now
	_render_online()
	if _online and game != null:
		_queue_refresh()

func _leave_online() -> void:
	_net.leave()
	_online = false
	_seat = 0
	_seats = []
	_sent.clear()
	_absent_since.clear()

# --- UI construction --------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	theme = _make_theme()

	# The table: dark stained planks with a vignette.
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	var planks := _cover(WOOD)
	planks.modulate = TABLE_TINT
	add_child(planks)
	# Lamplight: a warm, flickering pool, the edges in shadow.
	var candle := ColorRect.new()
	candle.set_anchors_preset(PRESET_FULL_RECT)
	candle.mouse_filter = MOUSE_FILTER_IGNORE
	var light := ShaderMaterial.new()
	light.shader = preload("res://scenes/game/candlelight.gdshader")
	candle.material = light
	add_child(candle)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	margin.add_child(columns)

	var main := VBoxContainer.new()
	main.size_flags_horizontal = SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10)
	columns.add_child(main)

	var side := VBoxContainer.new()
	side.custom_minimum_size.x = OPP_COLUMN_WIDTH
	side.add_theme_constant_override("separation", 10)
	columns.add_child(side)

	# Top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	main.add_child(top)
	_round_label = _label("", 24, GOLD, true)
	top.add_child(_round_label)
	_phase_label = _label("", 17, MUTED)
	_phase_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_phase_label)
	top.add_child(_button("Menu", _open_menu))

	# Infamy row and piles
	var board := HBoxContainer.new()
	board.add_theme_constant_override("separation", 12)
	main.add_child(board)
	var row_panel := _panel()
	row_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	board.add_child(row_panel)
	var row_v := VBoxContainer.new()
	row_panel.add_child(row_v)
	row_v.add_child(_label("Infamy Row — claim a card when your raised banners match its requirement", 14, MUTED))
	_row_box = HBoxContainer.new()
	_row_box.add_theme_constant_override("separation", 16)
	row_v.add_child(_row_box)
	var piles_panel := _panel()
	board.add_child(piles_panel)
	var piles_v := VBoxContainer.new()
	piles_panel.add_child(piles_v)
	piles_v.add_child(_label("Decks", 14, MUTED))
	_piles_box = HBoxContainer.new()
	_piles_box.add_theme_constant_override("separation", 10)
	piles_v.add_child(_piles_box)

	# Your score and resources beside your crew; overlays sit right of it.
	var home := HBoxContainer.new()
	home.size_flags_vertical = SIZE_EXPAND_FILL
	home.add_theme_constant_override("separation", 12)
	main.add_child(home)
	var ledger := _panel()
	ledger.custom_minimum_size.x = LEDGER_WIDTH
	home.add_child(ledger)
	var ledger_scroll := ScrollContainer.new()
	ledger_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ledger_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	ledger.add_child(ledger_scroll)
	var ledger_v := VBoxContainer.new()
	ledger_v.size_flags_horizontal = SIZE_EXPAND_FILL
	ledger_v.add_theme_constant_override("separation", 0)
	ledger_scroll.add_child(ledger_v)
	_ledger_vp = _rich(16)
	_ledger_vp.fit_content = true
	ledger_v.add_child(_ledger_vp)
	_ledger_body = _with_tips(_rich(15))
	_ledger_body.fit_content = true
	ledger_v.add_child(_ledger_body)

	# Your crew
	var crew_panel := _panel()
	crew_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	home.add_child(crew_panel)
	_crew_panel = crew_panel
	# "Your crew" as a large, faint title in the background of the panel.
	var crew_title := _label("Your crew", 40, Color(1, 1, 1, 0.05), true)
	crew_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	crew_title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	crew_title.size_flags_horizontal = SIZE_FILL
	crew_title.size_flags_vertical = SIZE_FILL
	crew_panel.add_child(crew_title)
	var crew_v := VBoxContainer.new()
	crew_panel.add_child(crew_v)
	var crew_scroll := ScrollContainer.new()
	crew_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	# The layout always fits the panel; never show scroll bars.
	crew_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	crew_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	crew_v.add_child(crew_scroll)
	_crew_columns = HBoxContainer.new()
	_crew_columns.add_theme_constant_override("separation", 18)
	crew_scroll.add_child(_crew_columns)
	# How many columns fit depends on the width.
	crew_scroll.resized.connect(func() -> void:
		if game != null:
			_queue_refresh())

	# Action bar
	var action_panel := _wood_panel(Color(0.42, 0.3, 0.2))
	# Slimmer than the other wood panels: the table above needs the height.
	var action_style := action_panel.get_theme_stylebox("panel") as StyleBoxTexture
	action_style.content_margin_top = 10
	action_style.content_margin_bottom = 10
	main.add_child(action_panel)
	var action_h := HBoxContainer.new()
	action_h.add_theme_constant_override("separation", 12)
	action_panel.add_child(action_h)
	_action_text = _rich(17)
	_action_text.fit_content = true
	_action_text.size_flags_horizontal = SIZE_EXPAND_FILL
	_action_text.custom_minimum_size.y = 42
	action_h.add_child(_action_text)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	action_h.add_child(_buttons)

	# Hand
	_hand_area = Control.new()
	# The cards hang past the bottom of the window.
	_hand_area.custom_minimum_size.y = HAND_VISIBLE
	_hand_area.resized.connect(_layout_hand)
	main.add_child(_hand_area)

	# Side column: opponents and log
	var opp_scroll := ScrollContainer.new()
	opp_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	opp_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(opp_scroll)
	_opponents_box = VBoxContainer.new()
	_opponents_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_opponents_box.add_theme_constant_override("separation", 10)
	opp_scroll.add_child(_opponents_box)
	var log_panel := _panel()
	log_panel.custom_minimum_size.y = 210
	side.add_child(log_panel)
	_log = _rich(14)
	_log.scroll_following = true
	log_panel.add_child(_log)

	_build_pay_panel()
	_build_overlay()
	_build_menu()
	_build_zoom()

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	# Leave the hand and action bar visible below the overlay.
	center.offset_bottom = -(HAND_VISIBLE + 84)
	# Centred on the window, with the ledger's width kept clear on both sides.
	center.offset_left = LEDGER_WIDTH + 24
	center.offset_right = -(LEDGER_WIDTH + 24)
	_overlay.add_child(center)
	# Lighter wood and a bright rim, so the choice stands out from the table.
	var panel := _wood_panel(Color(0.68, 0.5, 0.32), true)
	(panel.material as ShaderMaterial).set_shader_parameter("rim_color", Color(1.0, 0.82, 0.45, 0.95))
	(panel.material as ShaderMaterial).set_shader_parameter("rim_width", 3.0)
	panel.mouse_filter = MOUSE_FILTER_STOP
	center.add_child(panel)
	_overlay_body = VBoxContainer.new()
	_overlay_body.add_theme_constant_override("separation", 12)
	panel.add_child(_overlay_body)

func _build_menu() -> void:
	# Its own layer, above the cards (which use z_index), the flying cards
	# and the zoom.
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_menu = Control.new()
	_menu.set_anchors_preset(PRESET_FULL_RECT)
	_menu.theme = _make_theme()
	layer.add_child(_menu)
	# Black under the paintings, so the table never shows through a fade.
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(PRESET_FULL_RECT)
	_menu.add_child(black)
	# The title screen: paintings scrolling slowly behind the logo, each
	# crossfading into the next.
	for i in range(2):
		var art := TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.mouse_filter = MOUSE_FILTER_IGNORE
		_menu.add_child(art)
		_slides.append(art)
	_slides[1].modulate.a = 0.0
	_show_slide(0)
	_menu.add_child(_vignette())
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	_menu.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -10)
	center.add_child(column)
	var logo := TextureRect.new()
	logo.texture = load(LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(640, 302)
	logo.resized.connect(func() -> void: logo.pivot_offset = logo.size / 2.0)
	var gleam := ShaderMaterial.new()
	gleam.shader = preload("res://scenes/game/logo.gdshader")
	logo.material = gleam
	column.add_child(logo)
	var panel := _wood_panel()
	(panel.material as ShaderMaterial).set_shader_parameter("lantern", 1.0)
	(panel.material as ShaderMaterial).set_shader_parameter("rim_width", 2.5)
	panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	column.add_child(panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 460
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var intro := _label("Recruit a crew of rogues over five rounds. Raise your banners, claim Infamy, and score the most Victory Points.", 15, Color(1, 0.92, 0.8, 0.85))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(intro)

	# Back to the game in progress.
	var resume := _big(_primary(_button("Resume", func() -> void: _menu.visible = false)))
	resume.name = "Resume"
	v.add_child(resume)

	# A new game against bots, with its setup.
	v.add_child(_menu_heading("A new voyage"))
	var opp_row := HBoxContainer.new()
	opp_row.add_theme_constant_override("separation", 12)
	opp_row.add_child(_label("Opponents", 17))
	var opp := OptionButton.new()
	opp.name = "Opponents"
	for n in range(1, 5):
		opp.add_item("%d bot%s" % [n, "" if n == 1 else "s"], n)
	opp.size_flags_horizontal = SIZE_EXPAND_FILL
	opp.item_selected.connect(func(i: int) -> void: settings.opponents = i + 1)
	opp_row.add_child(opp)
	v.add_child(opp_row)
	var solo := CheckBox.new()
	solo.text = "Solo variant: one random virtual opponent, chase a rank"
	solo.toggled.connect(func(on: bool) -> void:
		settings.solo = on
		opp.disabled = on)
	v.add_child(solo)
	var beginner := CheckBox.new()
	beginner.text = "Beginner draft: 7 cards in the first draft"
	beginner.toggled.connect(func(on: bool) -> void: settings.beginner = on)
	v.add_child(beginner)
	var new_game := _big(_button("New game", _start_game))
	v.add_child(new_game)

	# With other people.
	v.add_child(_menu_heading("With friends"))
	v.add_child(_big(_tint(_button("Play online", _show_online), Color(0.12, 0.27, 0.38), Color(0.5, 0.75, 0.9))))

	# Everything else, quietly.
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 6)
	v.add_child(footer)
	footer.add_child(_quiet(_button("Settings", _show_settings)))
	footer.add_child(_label("·", 15, MUTED))
	footer.add_child(_quiet(_button("Credits", _show_credits)))
	footer.add_child(_label("·", 15, MUTED))
	footer.add_child(_quiet(_button("Quit", func() -> void: get_tree().quit())))
	_menu.set_meta("new_game", new_game)
	_menu.set_meta("opponents", opp)
	_menu.set_meta("resume", resume)
	_build_credits()
	_build_online()
	_build_settings()
	_menu.set_meta("logo", logo)
	_menu.set_meta("panel", panel)

## Who made the game, from the rulebook's credits page.
const CREDITS := [
	["Game design", ["Batiste Bieler"]],
	["Illustrations", ["Vitor Henrique", "Ricardo Zopello", "Batiste Bieler", "Mauri", "Toloma", "Daniel Cunha", "Marvin Blattert", "Matias Gonzalez"]],
	["Iconography", ["Louise Fayt", "Batiste Bieler"]],
	["Playtesting", ["Jessica Gibbons", "Gaël Nardin", "Jonathan Bieler", "Eduard Schäli", "Riccardo Zoppello", "Lucas Clark", "the Break My Game community", "and many others"]],
	["Music", ["Composed with Suno"]],
	["Sound effects", ["Synthesised for this game"]],
	["Typeface", ["Signika, by Anna Giedryś (SIL Open Font License)"]],
	["Engine", ["Made with the Godot Engine"]],
]

## A panel over the dimmed menu, closed by `close` (also on a click outside
## it). Returns [the sheet, its content box].
func _menu_sheet(title_text: String, close: Callable) -> Array:
	var sheet := Control.new()
	sheet.set_anchors_preset(PRESET_FULL_RECT)
	sheet.visible = false
	_menu.add_child(sheet)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close.call())
	sheet.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.add_child(center)
	var panel := _wood_panel(Color(0.5, 0.36, 0.24), true)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var title := _label(title_text, 30, GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	return [sheet, v]

## A small gold heading between the menu's zones, with rules either side.
func _menu_heading(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in 3:
		if i == 1:
			row.add_child(_label(text.to_upper(), 14, Color(0.98, 0.8, 0.48), true))
			continue
		var line := HSeparator.new()
		var style := StyleBoxLine.new()
		style.color = Color(0.95, 0.75, 0.42, 0.7)
		style.thickness = 2
		line.add_theme_stylebox_override("separator", style)
		line.add_theme_constant_override("separation", 2)
		line.size_flags_horizontal = SIZE_EXPAND_FILL
		line.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(line)
	return row

## Settings: the sound mixer, saved as it changes.
func _build_settings() -> void:
	var sheet := _menu_sheet("Settings", func() -> void: _settings.visible = false)
	_settings = sheet[0]
	var v: VBoxContainer = sheet[1]
	v.custom_minimum_size.x = 420
	var mixer := GridContainer.new()
	mixer.columns = 2
	mixer.add_theme_constant_override("h_separation", 16)
	mixer.add_theme_constant_override("v_separation", 10)
	v.add_child(mixer)
	for spec in [["Master", "Volume"], ["Music", "Music"], ["Effects", "Sound effects"]]:
		var bus: String = spec[0]
		mixer.add_child(_label(spec[1], 17))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = _sfx.volumes[bus]
		slider.size_flags_horizontal = SIZE_EXPAND_FILL
		slider.size_flags_vertical = SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(level: float) -> void: _sfx.set_volume(bus, level))
		slider.drag_ended.connect(func(_changed: bool) -> void:
			_sfx.save_volumes()
			if bus != "Music":
				_sfx.play("coin"))
		mixer.add_child(slider)
	var close := _button("Close", func() -> void: _settings.visible = false)
	close.size_flags_horizontal = SIZE_SHRINK_CENTER
	v.add_child(close)

func _show_settings() -> void:
	_settings.visible = true
	_settings.modulate.a = 0.0
	_settings.create_tween().tween_property(_settings, "modulate:a", 1.0, 0.2)

func _build_credits() -> void:
	var sheet := _menu_sheet("Credits", func() -> void: _credits.visible = false)
	_credits = sheet[0]
	var v: VBoxContainer = sheet[1]
	var text := "[center]"
	for section: Array in CREDITS:
		text += "[color=#c9a76a][font_size=%d]%s[/font_size][/color]\n" % [_fs(14), section[0].to_upper()]
		# Non-breaking spaces keep each name on one line.
		var names: Array[String] = []
		for name: String in section[1]:
			names.append(name.replace(" ", "\u00a0"))
		text += "%s\n\n" % "  ·  ".join(names)
	var body := _rich(17)
	body.fit_content = true
	body.custom_minimum_size.x = 560
	body.add_theme_color_override("default_color", Color(1, 0.93, 0.8))
	body.text = text.strip_edges() + "[/center]"
	v.add_child(body)
	# The publisher: its logo on a light plate (it is blue on white) and a
	# link to the game's page.
	var publisher := HBoxContainer.new()
	publisher.alignment = BoxContainer.ALIGNMENT_CENTER
	publisher.add_theme_constant_override("separation", 16)
	v.add_child(publisher)
	var plate := PanelContainer.new()
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.97, 0.94, 0.86)
	plate_style.set_corner_radius_all(10)
	plate_style.set_content_margin_all(8)
	plate.add_theme_stylebox_override("panel", plate_style)
	plate.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	plate.tooltip_text = PUBLISHER_URL
	plate.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			OS.shell_open(PUBLISHER_URL))
	publisher.add_child(plate)
	var logo := TextureRect.new()
	logo.texture = load(PUBLISHER_LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(76, 72)
	logo.mouse_filter = MOUSE_FILTER_IGNORE
	plate.add_child(logo)
	var about := VBoxContainer.new()
	about.alignment = BoxContainer.ALIGNMENT_CENTER
	publisher.add_child(about)
	about.add_child(_label("Published by Tidale", 17, Color(1, 0.93, 0.8), true))
	var link := LinkButton.new()
	link.text = PUBLISHER_URL.trim_prefix("https://")
	link.uri = PUBLISHER_URL
	link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	link.add_theme_font_size_override("font_size", _fs(16))
	link.add_theme_color_override("font_color", GOLD)
	link.add_theme_color_override("font_hover_color", Color(1, 0.93, 0.7))
	link.add_theme_color_override("font_pressed_color", GOLD)
	about.add_child(link)
	var close := _button("Close", func() -> void: _credits.visible = false)
	close.size_flags_horizontal = SIZE_SHRINK_CENTER
	v.add_child(close)

## Play online: create or join a table, then wait in its lobby for the host
## to start. See _render_online() for what shows when.
func _build_online() -> void:
	var sheet := _menu_sheet("Play online", _close_online)
	_online_panel = sheet[0]
	var v: VBoxContainer = sheet[1]
	v.custom_minimum_size.x = 520
	var ui := _online_ui

	# Before joining: your name, then create or join.
	var join := VBoxContainer.new()
	join.add_theme_constant_override("separation", 12)
	v.add_child(join)
	ui.join = join
	var name_row := HBoxContainer.new()
	name_row.add_child(_label("Your name", 17))
	var name_edit := LineEdit.new()
	name_edit.max_length = 24
	name_edit.text = _player_name()
	name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(text: String) -> void: _save_setting("online", "name", text))
	name_row.add_child(name_edit)
	join.add_child(name_row)
	ui.name = name_edit
	var create := _button("Create a table", func() -> void:
		_online_status("Creating a table…")
		_net.create_table(func(code: String) -> void:
			if code.is_empty():
				_online_status("Could not reach the server.")
			else:
				_net.join(code, _player_name())))
	_primary(create)
	join.add_child(create)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	join_row.add_child(_label("or join with a code", 16, MUTED))
	var code_edit := LineEdit.new()
	code_edit.max_length = 5
	code_edit.placeholder_text = "ABCDE"
	code_edit.custom_minimum_size.x = 110
	code_edit.text_changed.connect(func(text: String) -> void:
		var caret := code_edit.caret_column
		code_edit.text = text.to_upper()
		code_edit.caret_column = caret)
	join_row.add_child(code_edit)
	var join_button := _button("Join", func() -> void:
		if code_edit.text.strip_edges().length() < 5:
			_online_status("Codes have 5 letters.")
			return
		_online_status("Joining…")
		_net.join(code_edit.text, _player_name()))
	join_row.add_child(join_button)
	code_edit.text_submitted.connect(func(_t: String) -> void: join_button.pressed.emit())
	join.add_child(join_row)

	# At a table: its code, who is there, and (for the host) the start.
	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 12)
	v.add_child(table)
	ui.table = table
	var code_row := HBoxContainer.new()
	code_row.alignment = BoxContainer.ALIGNMENT_CENTER
	code_row.add_theme_constant_override("separation", 12)
	code_row.add_child(_label("Table", 18, MUTED))
	var code_label := _label("", 34, GOLD, true)
	code_row.add_child(code_label)
	ui.code = code_label
	code_row.add_child(_button("Copy", func() -> void:
		DisplayServer.clipboard_set(_net.code)
		_online_status("Code copied: send it to your crew.")))
	table.add_child(code_row)
	var players := _rich(17)
	players.fit_content = true
	players.add_theme_color_override("default_color", Color(1, 0.93, 0.8))
	table.add_child(players)
	ui.players = players
	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 12)
	host_row.add_child(_label("Bots", 17))
	var bots := OptionButton.new()
	host_row.add_child(bots)
	ui.bots = bots
	var beginner := CheckBox.new()
	beginner.text = "Beginner draft"
	host_row.add_child(beginner)
	ui.beginner = beginner
	table.add_child(host_row)
	ui.host_row = host_row
	var start := _button("Start the game", func() -> void:
		_net.start_game(bots.get_selected_id(), {"beginner_draft": beginner.button_pressed}))
	_primary(start)
	start.size_flags_horizontal = SIZE_SHRINK_CENTER
	table.add_child(start)
	ui.start = start

	var status := _label("", 15, MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(status)
	ui.status = status
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 10)
	var leave := _button("Leave the table", func() -> void:
		_leave_online()
		_online_status("")
		_render_online())
	bottom.add_child(leave)
	ui.leave = leave
	bottom.add_child(_button("Close", _close_online))
	v.add_child(bottom)

## Shows the online panel in the state of the connection.
func _render_online() -> void:
	if _online_panel == null:
		return
	var ui := _online_ui
	var at_table := _net.player_id >= 0
	ui.join.visible = not at_table
	ui.table.visible = at_table
	ui.leave.visible = at_table
	if not at_table:
		return
	ui.code.text = _net.code
	var lines: Array[String] = []
	var humans := 0
	for player: Dictionary in _net.players:
		humans += 1
		var mark := "[color=#8fe388]●[/color]" if player.online else "[color=#8a96a6]○[/color]"
		var tags := ""
		if player.id == _net.host:
			tags += "  [color=#c9a76a](host)[/color]"
		if player.id == _net.player_id:
			tags += "  [color=#c9a76a](you)[/color]"
		lines.append("%s  %s%s" % [mark, player.name, tags])
	ui.players.text = "\n".join(lines)
	var hosting := _net.is_host()
	ui.host_row.visible = hosting
	ui.start.visible = hosting
	var bots: OptionButton = ui.bots
	var keep := bots.get_selected_id() if bots.item_count > 0 else (1 if humans < 2 else 0)
	bots.clear()
	for n in range(0, 5 - humans + 1):
		bots.add_item("%d" % n, n)
	bots.select(clampi(keep, 0, bots.item_count - 1))
	ui.start.disabled = humans + bots.get_selected_id() < 2
	if not bots.item_selected.is_connected(_on_bots_selected):
		bots.item_selected.connect(_on_bots_selected)
	if not hosting:
		_online_status("Waiting for the host to start the game…")
	elif humans < 2:
		_online_status("Share the code, or add bots and start.")
	else:
		_online_status("")

func _on_bots_selected(_index: int) -> void:
	_render_online()

func _show_online() -> void:
	_render_online()
	_online_panel.visible = true
	_online_panel.modulate.a = 0.0
	_online_panel.create_tween().tween_property(_online_panel, "modulate:a", 1.0, 0.2)

## Closing the panel before the game starts leaves the table.
func _close_online() -> void:
	_online_panel.visible = false
	if not _online:
		_leave_online()
		_online_status("")

func _online_status(text: String) -> void:
	if _online_ui.has("status"):
		_online_ui.status.text = text

func _player_name() -> String:
	var config := ConfigFile.new()
	config.load(NetClient.SETTINGS)
	return config.get_value("online", "name", "")

func _save_setting(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(NetClient.SETTINGS)
	config.set_value(section, key, value)
	config.save(NetClient.SETTINGS)

func _show_credits() -> void:
	_credits.visible = true
	_credits.modulate.a = 0.0
	_credits.create_tween().tween_property(_credits, "modulate:a", 1.0, 0.2)

func _open_menu() -> void:
	(_menu.get_meta("opponents") as OptionButton).select(settings.opponents - 1)
	var in_game := game != null and game.phase != DeckhandGame.Phase.GAME_OVER
	(_menu.get_meta("resume") as Button).visible = in_game
	# The green button is what you most likely want: back to the game, or a new one.
	var new_game: Button = _menu.get_meta("new_game")
	for state in ["normal", "hover", "pressed"]:
		new_game.remove_theme_stylebox_override(state)
	if not in_game:
		_primary(new_game)
	_hide_zoom(true)
	_menu.visible = true

## First appearance of the title menu: fades in from the boot screen's dark
## with the intro music, the logo drops in, then the options.
func _intro() -> void:
	var logo: Control = _menu.get_meta("logo")
	var panel: Control = _menu.get_meta("panel")
	_menu.modulate = Color(0, 0, 0)
	logo.modulate.a = 0.0
	panel.modulate.a = 0.0
	var tween := create_tween()
	_music.play(Music.INTRO, 1.5)
	tween.tween_property(_menu, "modulate", Color.WHITE, 1.0)
	tween.parallel().tween_property(logo, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(logo, "scale", Vector2.ONE, 0.8).from(Vector2(1.5, 1.5)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)

## Brings title painting `index` in over the current one and schedules the
## next. The painting covers the screen and scrolls along its longer side, so
## all of a tall one is seen.
func _show_slide(index: int) -> void:
	# _slides[0] is the painting on show, _slides[1] the spare layer.
	var art := _slides[1]
	var shown := _slides[0]
	art.texture = load(MENU_ART[index])
	art.modulate = Color(0.85, 0.85, 0.88, 0.0)
	_menu.move_child(art, maxi(art.get_index(), shown.get_index()))
	_slides.assign([art, shown])
	var tween := art.create_tween()
	tween.tween_property(art, "modulate:a", 1.0, SLIDE_FADE)
	var screen: Vector2 = get_viewport_rect().size
	var image: Vector2 = art.texture.get_size()
	art.size = image * maxf(screen.x / image.x, screen.y / image.y)
	var overflow := art.size - screen
	var from := -overflow / 2.0
	var to := from
	if overflow.y > overflow.x:
		from.y = 0.0
		to.y = -overflow.y
	else:
		from.x = 0.0
		to.x = -overflow.x
	tween.parallel().tween_property(art, "position", to, SLIDE_TIME + SLIDE_FADE).from(from).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_callback(_show_slide.bind((index + 1) % MENU_ART.size())).set_delay(SLIDE_TIME)

## A dark radial vignette over the table and the menu.
static func _vignette(strength: float = 0.85) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0, 0, 0, strength))
	gradient.add_point(0.55, Color(0, 0, 0, 0.15))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(1.15, 1.1)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(PRESET_FULL_RECT)
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	return rect

func _build_zoom() -> void:
	_zoom_layer = CanvasLayer.new()
	_zoom_layer.layer = 10
	add_child(_zoom_layer)
	_zoom_panel = PanelContainer.new()
	var parchment := StyleBoxTexture.new()
	parchment.texture = load(PARCHMENT)
	_zoom_panel.add_theme_stylebox_override("panel", parchment)
	# Rounded like the card on top of it, with a thin dark-ink rim.
	var rounded := ShaderMaterial.new()
	rounded.shader = ROUNDED_SHADER
	rounded.set_shader_parameter("radius", ZOOM_CARD.x * 0.055)
	rounded.set_shader_parameter("rim_color", Color(0.32, 0.2, 0.1, 0.55))
	_zoom_panel.material = rounded
	_zoom_panel.resized.connect(func() -> void: rounded.set_shader_parameter("size", _zoom_panel.size))
	_zoom_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_zoom_panel.visible = false
	_zoom_layer.add_child(_zoom_panel)
	# The card edge to edge on top, its rules on the parchment below.
	var v := VBoxContainer.new()
	v.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	_zoom_panel.add_child(v)
	_zoom_card = CardView.make(1, ZOOM_CARD)
	_zoom_card.interactive = false
	_zoom_card.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(_zoom_card)
	var text_margin := MarginContainer.new()
	text_margin.mouse_filter = MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		text_margin.add_theme_constant_override("margin_" + side, 14)
	v.add_child(text_margin)
	_zoom_info = VBoxContainer.new()
	_zoom_info.custom_minimum_size.x = ZOOM_CARD.x - 28
	_zoom_info.mouse_filter = MOUSE_FILTER_IGNORE
	_zoom_info.add_theme_constant_override("separation", 6)
	text_margin.add_child(_zoom_info)

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load(FONT_REGULAR)
	t.default_font_size = _fs(16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.17, 0.1)
	normal.border_color = Color(0.75, 0.58, 0.3)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	var hover := normal.duplicate()
	hover.bg_color = Color(0.32, 0.24, 0.13)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.15, 0.11, 0.06)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.15, 0.15, 0.15)
	disabled.border_color = Color(0.3, 0.3, 0.3)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1.0, 0.85, 0.45)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(10)
	focus.set_expand_margin_all(3)
	t.set_stylebox("focus", "Button", focus)
	# Check boxes: no button frame, a gold box with room before the label.
	var plain := StyleBoxEmpty.new()
	plain.content_margin_left = 2
	plain.content_margin_top = 4
	plain.content_margin_bottom = 4
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "CheckBox", plain)
	t.set_constant("h_separation", "CheckBox", 12)
	t.set_icon("unchecked", "CheckBox", _check_icon(false))
	t.set_icon("checked", "CheckBox", _check_icon(true))
	t.set_color("font_color", "CheckBox", Color(1, 0.93, 0.8))
	t.set_color("font_hover_color", "CheckBox", Color(1, 0.97, 0.9))
	t.set_color("font_pressed_color", "CheckBox", Color(1, 0.93, 0.8))
	t.set_color("font_hover_pressed_color", "CheckBox", Color(1, 0.97, 0.9))
	t.set_color("font_color", "Button", Color(1, 0.93, 0.8))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5))
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.09, 0.05)
	track.border_color = Color(0.75, 0.58, 0.3, 0.8)
	track.set_border_width_all(1)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var filled := StyleBoxFlat.new()
	filled.bg_color = Color(0.85, 0.64, 0.3)
	filled.set_corner_radius_all(4)
	filled.content_margin_top = 4
	filled.content_margin_bottom = 4
	var filled_hover := filled.duplicate()
	filled_hover.bg_color = Color(1.0, 0.8, 0.42)
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(0.93, 0.86, 0.7)
	tip.border_color = Color(0.45, 0.3, 0.15)
	tip.set_border_width_all(1)
	tip.set_corner_radius_all(8)
	tip.set_content_margin_all(10)
	tip.shadow_color = Color(0, 0, 0, 0.4)
	tip.shadow_size = 8
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", _fs(15))
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled_hover)
	return t

## A check box drawn in the menu's colours: a rounded gold-rimmed square,
## filled gold with a dark tick when checked.
static func _check_icon(checked: bool) -> ImageTexture:
	var size := roundi(22 * TEXT_SCALE)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size / 2.0
	var gold := Color(0.92, 0.72, 0.36)
	for y in size:
		for x in size:
			# Signed distance to a rounded square, for smooth edges.
			var q := Vector2(absf(x + 0.5 - half), absf(y + 0.5 - half)) - Vector2(half - 4.5, half - 4.5)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 3.0
			var inside := clampf(0.5 - d, 0.0, 1.0)
			var rim := clampf(0.5 - absf(d + 1.0), 0.0, 1.0)
			var fill := gold if checked else Color(0.12, 0.08, 0.04)
			var c := fill.lerp(gold, rim)
			c.a = inside
			img.set_pixel(x, y, c)
	if checked:
		# The tick: two thick strokes.
		var ink := Color(0.16, 0.1, 0.04)
		var a := Vector2(size * 0.27, size * 0.52)
		var b := Vector2(size * 0.43, size * 0.68)
		var c2 := Vector2(size * 0.74, size * 0.33)
		for y in size:
			for x in size:
				var p := Vector2(x + 0.5, y + 0.5)
				var dist := minf(_segment_distance(p, a, b), _segment_distance(p, b, c2))
				var cover := clampf(size * 0.075 + 0.5 - dist, 0.0, 1.0)
				if cover > 0.0:
					var base := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(base.lerp(ink, cover), base.a))
	return ImageTexture.create_from_image(img)

static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return p.distance_to(a + ab * t)

# --- Small builders ---------------------------------------------------------

func _panel(color: Color = PANEL_BG) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	return panel

## Dark-stained wood with rounded corners, for dialogs and the action bar.
func _wood_panel(tint: Color = Color(0.5, 0.36, 0.24), shadow: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxTexture.new()
	style.texture = load(WOOD)
	style.modulate_color = tint
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	if shadow:
		# Drawn behind the panel, grown back over the content margins.
		var drop := StyleBoxFlat.new()
		drop.bg_color = Color(0, 0, 0, 0.5)
		drop.set_corner_radius_all(16)
		drop.set_expand_margin_all(18)
		drop.shadow_color = Color(0, 0, 0, 0.6)
		drop.shadow_size = 40
		drop.shadow_offset = Vector2(0, 16)
		var behind := Panel.new()
		behind.add_theme_stylebox_override("panel", drop)
		behind.show_behind_parent = true
		behind.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(behind)
	var rounded := ShaderMaterial.new()
	rounded.shader = ROUNDED_SHADER
	panel.material = rounded
	panel.resized.connect(func() -> void: rounded.set_shader_parameter("size", panel.size))
	return panel

## Full-rect image that covers its area (cropping as needed).
func _cover(path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.set_anchors_preset(PRESET_FULL_RECT)
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	return rect

func _label(text: String, font_size: int = 16, color: Color = Color(0.92, 0.94, 0.97), bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _fs(font_size))
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", load(FONT_BOLD))
	return label

func _rich(font_size: int) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.add_theme_font_size_override("normal_font_size", _fs(font_size))
	rich.add_theme_font_size_override("bold_font_size", _fs(font_size))
	rich.add_theme_font_override("bold_font", load(FONT_BOLD))
	rich.size_flags_horizontal = SIZE_EXPAND_FILL
	rich.size_flags_vertical = SIZE_EXPAND_FILL
	return rich

func _button(text: String, callback: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.pressed.connect(func() -> void: _sfx.play("click"))
	button.pressed.connect(callback)
	return button

## Green, for the choice that moves things along.
func _primary(button: Button) -> Button:
	_tint(button, Color(0.14, 0.36, 0.17), Color(0.5, 0.85, 0.45))
	button.set_meta("primary", true)
	return button

## `button` in its own colours: `fill` (lighter on hover) inside a `rim`.
func _tint(button: Button, fill: Color, rim: Color) -> Button:
	var states := {"normal": fill, "hover": fill.lightened(0.15), "pressed": fill.darkened(0.25)}
	for state: String in states:
		var style: StyleBoxFlat = theme.get_stylebox(state, "Button").duplicate()
		style.bg_color = states[state]
		style.border_color = rim
		button.add_theme_stylebox_override(state, style)
	return button

## A big menu button.
func _big(button: Button) -> Button:
	button.add_theme_font_size_override("font_size", _fs(20))
	button.custom_minimum_size.y = 50
	return button

## A quiet text button, for the menu's footer.
func _quiet(button: Button) -> Button:
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(0, 0, 0, 0)
	plain.set_corner_radius_all(6)
	plain.content_margin_left = 10
	plain.content_margin_right = 10
	plain.content_margin_top = 4
	plain.content_margin_bottom = 4
	var hover := plain.duplicate()
	hover.bg_color = Color(1, 0.9, 0.7, 0.12)
	button.add_theme_stylebox_override("normal", plain)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color(0.93, 0.83, 0.65))
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_font_size_override("font_size", _fs(15))
	return button

func _card(id: int, card_size: Vector2, face_up: bool = true) -> CardView:
	var view := CardView.make(id, card_size, face_up)
	view.hovered.connect(_on_card_hovered)
	_card_views.append(view)
	view.unhovered.connect(_on_card_unhovered)
	return view

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func _fs(size: int) -> int:
	return roundi(size * TEXT_SCALE)

static func _img(name: String, size: int = 20) -> String:
	return "[img=%d]%s%s.png[/img]" % [roundi(size * ICON_SCALE), ICONS, name]

static func _res(token: String, size: int = 20) -> String:
	return _img("res-" + token, size)

static func _banner(banner: String, size: int = 22) -> String:
	return _img("banner-" + banner, size)

func _who(p: int) -> String:
	return "[color=#%s]%s[/color]" % [PLAYER_COLORS[p % PLAYER_COLORS.size()].to_html(false), game.players[p].name]

# --- Rendering --------------------------------------------------------------

## The game can change several times in one action; render once per frame.
func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()

func _refresh() -> void:
	_refresh_queued = false
	if game == null:
		return
	var decision: Variant = game.pending.get(_seat)
	if not is_same(decision, _decision):
		_decision = decision
		_reset_input()
	# Hovered cards may be rebuilt below without an exit event. (If the same
	# card is hovered again this frame, the zoom simply stays.)
	_hide_zoom()
	var snapshot := _capture_cards()
	_render_top()
	_render_row()
	_render_piles()
	_render_opponents()
	_render_crew()
	_render_hand()
	_render_action()
	_render_overlay()
	_animate_cards(snapshot)
	_keep_keyboard_focus()

func _reset_input() -> void:
	_build_card = -1
	_pay.clear()
	_pay_windfall = false
	_windfall_dest = DeckhandGame.WINDFALL_DECK
	_selected.clear()
	_selected_windfall = false
	_overlay_hidden = false

func _render_top() -> void:
	if game.phase == DeckhandGame.Phase.GAME_OVER:
		_round_label.text = "Game over"
	else:
		_round_label.text = "Round %d / %d" % [game.round_index, DeckhandGame.ROUNDS]
	var phase_names := {
		DeckhandGame.Phase.SETUP: "Setup",
		DeckhandGame.Phase.DRAFT: "Draft",
		DeckhandGame.Phase.BUILD: "Build — step %d" % game.build_step,
		DeckhandGame.Phase.ROUND_END: "End of round",
		DeckhandGame.Phase.GAME_OVER: "Final scores",
	}
	var wind := "clockwise ↻" if game.wind() == 1 else "counter-clockwise ↺"
	_phase_label.text = "%s    ·    wind %s" % [phase_names[game.phase], wind]

func _render_row() -> void:
	_clear(_row_box)
	for i in range(game.row.size()):
		var slot: Dictionary = game.row[i]
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.size_flags_horizontal = SIZE_EXPAND_FILL
		_row_box.add_child(v)
		var title := _label("Round %d" % (i + 1), 13, GOLD if i + 1 == game.round_index else MUTED)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		if slot.cards.is_empty():
			var empty := Panel.new()
			empty.custom_minimum_size = ROW_CARD
			empty.modulate = Color(1, 1, 1, 0.15)
			empty.size_flags_horizontal = SIZE_SHRINK_CENTER
			v.add_child(empty)
			continue
		if not slot.revealed:
			var back := _card(slot.cards[-1], ROW_CARD, false)
			if slot.cards.size() > 1:
				back.set_caption("×%d" % slot.cards.size())
			back.size_flags_horizontal = SIZE_SHRINK_CENTER
			v.add_child(back)
			continue
		# Cards revealed together: a cascade in the slot's usual height. The
		# last revealed is in front; each one behind shows its banner strip
		# (with a check on those you have) below the one before it.
		var n: int = slot.cards.size()
		var strip := 0.18 # of a card's height: its banner strip
		var card_size := ROW_CARD / (1.0 + strip * (n - 1))
		var stack := Control.new()
		stack.custom_minimum_size = ROW_CARD
		stack.size_flags_horizontal = SIZE_SHRINK_CENTER
		v.add_child(stack)
		for k in range(n):
			var id: int = slot.cards[k]
			var depth := n - 1 - k # 0 = in front
			var view := _card(id, card_size.round())
			view.position = Vector2((ROW_CARD.x - card_size.x) / 2.0 + (depth % 2) * 4.0 - 2.0 * signf(depth), depth * card_size.y * strip)
			if game.can_claim(_seat, id):
				view.mark = CardView.Mark.CLAIMABLE
			view.set_requirement(_banners_met(_seat, id))
			stack.add_child(view)

## For each banner printed on Infamy card `infamy_id`, whether player `p`
## has it raised (a second Skull needs two Skulls, and so on).
func _banners_met(p: int, infamy_id: int) -> Array:
	var have := game.raised_banners(p)
	var seen := {}
	var met := []
	for b: String in CardDB.printed_banners(infamy_id):
		seen[b] = seen.get(b, 0) + 1
		met.append(have[b] >= seen[b])
	return met

func _render_piles() -> void:
	_clear(_piles_box)
	var specs := [
		["Supply", game.supply.size(), CardView.SUPPLY_BACK, false],
		["Infamy", game.infamy_deck.size(), CardView.INFAMY_BACK, true],
		["Discard", game.discard_pile.size(), CardView.SUPPLY_BACK, false],
	]
	for spec in specs:
		var v := VBoxContainer.new()
		_piles_box.add_child(v)
		var id: int = 1 if spec[3] else 13
		# The pile's thickness: card edges under the top card, one per ~10 cards.
		var layers := clampi(ceili(spec[1] / 10.0) - 1, 0, 6)
		var pile := Control.new()
		pile.custom_minimum_size = PILE_CARD + Vector2(PILE_STEP.x, PILE_STEP.y) * 6
		v.add_child(pile)
		for i in range(layers, 0, -1):
			var edge := Panel.new()
			var paper := StyleBoxFlat.new()
			paper.bg_color = Color(0.8, 0.74, 0.62).darkened(0.06 * i)
			paper.border_color = Color(0.3, 0.2, 0.1, 0.7)
			paper.set_border_width_all(1)
			paper.set_corner_radius_all(int(PILE_CARD.x * 0.06))
			edge.add_theme_stylebox_override("panel", paper)
			edge.size = PILE_CARD - Vector2(4, 4)
			edge.position = Vector2(2, 2) + PILE_STEP * i
			edge.mouse_filter = MOUSE_FILTER_IGNORE
			pile.add_child(edge)
		var view := CardView.make(id, PILE_CARD, false)
		view.interactive = false
		_pile_views[spec[0].to_lower()] = view
		view.set_caption(str(spec[1]))
		if spec[1] == 0:
			view.modulate.a = 0.25
		pile.add_child(view)
		var caption := _label(spec[0], 13, MUTED)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(caption)

## `fresh` banners (just raised) have their count in gold.
func _player_summary(p: int, icon_size: int, fresh: Array = []) -> String:
	var banners := game.raised_banners(p)
	var parts: Array[String] = []
	for b in CardDB.BANNERS:
		if banners[b] > 0:
			var count := "[color=#ffd36b][b]%d[/b][/color]" % banners[b] if fresh.has(b) else str(banners[b])
			parts.append(_tip(_banner_tip(b), "%s%s" % [_banner(b, icon_size + 2), count]))
	var banner_text := " ".join(parts) if not parts.is_empty() else "[color=#8a96a6]no banners[/color]"
	var prod: Array[String] = []
	for group: Array in _production_groups(p):
		prod.append(_tip(_slot_tip(group[0], group[1]).replace("Your crew", "Their crew"), "%s%d" % [_slot_icons(group[0], icon_size), group[1]]))
	var prod_text := " ".join(prod) if not prod.is_empty() else "[color=#8a96a6]none[/color]"
	var extras := _tip(SYMBOL_TIPS["fx-tentacle"], "%s%d" % [_img("fx-tentacle", icon_size), game.tentacles(p)])
	for key in ["battles", "hooks", "compasses"]:
		var n := game.symbol_count(p, key)
		if n > 0:
			var icon: String = {"battles": "fx-battle", "hooks": "fx-hook", "compasses": "fx-compass"}[key]
			extras += "  " + _tip(SYMBOL_TIPS[icon], "%s%d" % [_img(icon, icon_size), n])
	if game.players[p].pending_battles > 0:
		extras += "  " + _tip(BATTLE_TIP, "[color=#ffb070]Battle pending ×%d[/color]" % game.players[p].pending_battles)
	return "Banners %s     Produces %s     %s" % [banner_text, prod_text, extras]

## `bbcode` with a tooltip `text` on hover (in a label set up by _with_tips()).
static func _tip(text: String, bbcode: String) -> String:
	return '[hint="%s"]%s[/hint]' % [text.replace('"', "'"), bbcode]

## A label whose _tip() tooltips show without Godot's dashed underline.
static func _with_tips(label: RichTextLabel) -> RichTextLabel:
	label.hint_underlined = false
	return label

static func _banner_tip(banner: String) -> String:
	return "%s banner. Raised banners let you claim Infamy cards, and some cards score per banner." % CardDB.BANNER_NAMES[banner]

static func _slot_tip(slot: Array, count: int) -> String:
	var names: Array[String] = []
	for token: String in slot:
		names.append(CardDB.RESOURCE_NAMES[token])
	return "Your crew produces %s, %d %s. Each use pays for one card you build." % [" or ".join(names), count, "time" if count == 1 else "times"]

const BATTLE_TIP := "A Battle announced by this pirate. It is fought on their next build: everyone who builds in that same step scores the card they built (+1 per Battle symbol in their crew), and the best draws a card. Players who don't build that step don't take part."

const SYMBOL_TIPS := {
	"fx-tentacle": "Tentacles: the most wins ties, for priority and at the end of the game.",
	"fx-battle": "Battles in your crew add +1 to your built card in each Battle.",
	"fx-hook": "Hooks: with 3, you keep the card you steal.",
	"fx-compass": "Compass: once per draft each, draw an extra draft card, then discard one before passing.",
}

## Identical production slots together: [[slot, count], ...] in crew order.
func _production_groups(p: int) -> Array:
	var groups: Array = []
	var index := {}
	for slot: Array in game.crew_production_slots(p):
		var key := "|".join(slot)
		if index.has(key):
			groups[index[key]][1] += 1
		else:
			index[key] = groups.size()
			groups.append([slot, 1])
	return groups

## A production slot: one icon, or its alternatives separated by "/".
func _slot_icons(slot: Array, icon_size: int) -> String:
	var alt: Array[String] = []
	for token: String in slot:
		alt.append(_res(token, icon_size))
	return "/".join(alt)

func _render_opponents() -> void:
	_clear(_opponents_box)
	for p in range(game.player_count()):
		if p == _seat:
			continue
		var pl: Dictionary = game.players[p]
		var panel := _panel()
		_opponents_box.add_child(panel)
		_opp_panels[p] = panel
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		panel.add_child(v)
		var head := _rich(16)
		head.fit_content = true
		var status := ""
		if game.phase == DeckhandGame.Phase.BUILD and pl.passed:
			status = "  [color=#8a96a6](passed)[/color]"
		elif _online and not _seats[p].bot and not _net.is_online(_seats[p].owner):
			status = "  [color=#e8a0a0](away)[/color]"
		elif game.pending.has(p):
			status = "  [color=#8a96a6](thinking…)[/color]"
		var template := "[b]%s[/b]%s\n[color=#ffd36b]{vp} VP[/color]   ·   hand %d   ·   %s" % [
			_who(p), status, game.hand_size(p),
			"windfall ✓" if pl.windfall >= 0 else "no windfall"]
		v.add_child(head)
		var fresh := _show_gains(p, head, template, Vector2(0.0, head.get_theme_font("normal_font").get_height(_fs(16))), 0.75)
		var summary := _with_tips(_rich(13))
		summary.fit_content = true
		summary.text = _player_summary(p, 15, fresh).replace("     ", "\n")
		v.add_child(summary)
		# One row; the cards overlap once they no longer fit side by side.
		var row := HBoxContainer.new()
		var room := OPP_COLUMN_WIDTH - 24.0
		var n: int = pl.crew.size()
		row.add_theme_constant_override("separation", int(minf(3.0, (room - OPP_CARD.x * n) / maxf(n - 1, 1))))
		v.add_child(row)
		for id in pl.crew:
			row.add_child(_card(id, OPP_CARD))

func _render_crew() -> void:
	var pl: Dictionary = game.players[_seat]
	_render_ledger()
	_clear(_crew_columns)
	if pl.crew.is_empty():
		_crew_columns.add_child(_label("Built cards join your crew here. Their production pays for later builds.", 15, MUTED))
		return
	# Grouped by what the cards produce, each group under a small heading.
	# A deep group continues in a column beside its first.
	var groups := {}
	for id: int in pl.crew:
		var group := _crew_group(id)
		if not groups.has(group):
			groups[group] = []
		groups[group].append(id)
	var stacks: Array = []
	var titles: Array[String] = []
	for group: String in CREW_GROUPS:
		if groups.has(group):
			var ids: Array = groups[group]
			# Identical producers side by side (stable: build order otherwise).
			var order := func(id: int) -> int:
				var tokens := CardDB.production_tokens(id)
				return RESOURCE_ORDER.find(tokens[0]) if not tokens.is_empty() else RESOURCE_ORDER.size()
			var keyed: Array = []
			for i in ids.size():
				keyed.append([order.call(ids[i]), i, ids[i]])
			keyed.sort()
			stacks.append(keyed.map(func(k: Array) -> int: return k[2]))
			titles.append(CREW_GROUPS[group])
	var area: Vector2 = (_crew_columns.get_parent() as Control).size
	var probe := _label("Basic", 13)
	var heading_height := probe.get_combined_minimum_size().y
	probe.free()
	area.y -= heading_height + 2.0
	var layout := _crew_layout(stacks, area)
	var card_size: Vector2 = layout.card
	for i in stacks.size():
		var stack: Array = stacks[i]
		var group_box := VBoxContainer.new()
		group_box.add_theme_constant_override("separation", 2)
		_crew_columns.add_child(group_box)
		group_box.add_child(_label(titles[i], 13, MUTED))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		group_box.add_child(row)
		for start in range(0, stack.size(), layout.depth):
			var column := VBoxContainer.new()
			# Rounded down, so a column never comes out taller than planned.
			column.add_theme_constant_override("separation", floori(layout.peek - card_size.y))
			row.add_child(column)
			var parts := stack.slice(start, start + layout.depth)
			for k in parts.size():
				var id: int = parts[k]
				# Laid by hand: every other card a touch left, then right,
				# slightly turned (the same each time for a given card).
				var holder := Control.new()
				holder.custom_minimum_size = card_size
				holder.mouse_filter = MOUSE_FILTER_IGNORE
				column.add_child(holder)
				var view := _card(id, card_size)
				view.interactive = false
				var wobble := (hash(id) % 1000) / 1000.0
				view.position.x = (-1.0 if k % 2 == 0 else 1.0) * (2.0 + 2.5 * wobble)
				view.rotation_degrees = (wobble - 0.5) * 1.6
				holder.add_child(view)

## Which crew group a card goes in (see CREW_GROUPS).
static func _crew_group(id: int) -> String:
	if CardDB.is_infamy(id):
		return "infamy"
	var tokens := CardDB.production_tokens(id)
	for token in ["h", "s", "e"]:
		if tokens.has(token):
			return "advanced"
	for token in ["g", "p", "r"]:
		if tokens.has(token):
			return "basic"
	return "support"

## The largest crew card size (down to 65%) at which `stacks` fit in `area`
## in at most CREW_MAX_COLUMNS columns: {card: size, peek: height of each
## card showing, depth: cards per column}.
func _crew_layout(stacks: Array, area: Vector2) -> Dictionary:
	var scale := 1.0
	while true:
		var card := (CREW_CARD * scale).round()
		var room := area.y - card.y
		# As deep as the full peek allows; deeper (overlapping more) only to
		# stay within the column limit.
		var depth := maxi(1, int(room / (CREW_PEEK * scale)) + 1)
		var most := maxi(1, int(room / (maxf(24.0, CREW_PEEK * 0.6) * scale)) + 1)
		while depth < most and _crew_columns_needed(stacks, depth) > CREW_MAX_COLUMNS:
			depth += 1
		var columns := _crew_columns_needed(stacks, depth)
		var width := columns * (card.x + 10.0) + (stacks.size() - 1) * 8.0
		if (columns <= CREW_MAX_COLUMNS and width <= area.x) or scale <= 0.65:
			var peek := CREW_PEEK * scale
			if depth > 1:
				peek = minf(peek, room / (depth - 1))
			return {"card": card, "peek": peek, "depth": depth}
		scale -= 0.05
	return {}

static func _crew_columns_needed(stacks: Array, depth: int) -> int:
	var columns := 0
	for stack: Array in stacks:
		columns += ceili(float(stack.size()) / depth)
	return columns

## The left column: your VP, then banners, production and symbols, each
## kind of icon once with its count.
func _render_ledger() -> void:
	var offset := Vector2(_ledger_vp.size.x / 2.0 - 40.0, _ledger_vp.size.y * 0.45)
	var fresh := _show_gains(_seat, _ledger_vp, "[center][color=#ffd36b][font_size=%d][b]{vp}[/b][/font_size] VP[/color][/center]" % _fs(32), offset)
	var banners := game.raised_banners(_seat)
	var cells: Array[String] = []
	for b in CardDB.BANNERS:
		if banners[b] > 0:
			var count := "[color=#ffd36b][b]%d[/b][/color]" % banners[b] if fresh.has(b) else str(banners[b])
			cells.append(_tip(_banner_tip(b), "%s %s" % [_banner(b, 21), count]))
	var text := _ledger_section("Banners", cells, "none raised")
	cells = []
	for group: Array in _production_groups(_seat):
		cells.append(_tip(_slot_tip(group[0], group[1]), "%s %d" % [_slot_icons(group[0], 20), group[1]]))
	text += _ledger_section("Produces", cells, "nothing yet")
	cells = [_tip(SYMBOL_TIPS["fx-tentacle"], "%s %d" % [_img("fx-tentacle", 20), game.tentacles(_seat)])]
	var compasses := game.symbol_count(_seat, "compasses")
	for spec in [["battles", "fx-battle"], ["hooks", "fx-hook"]]:
		var n := game.symbol_count(_seat, spec[0])
		if n > 0:
			cells.append(_tip(SYMBOL_TIPS[spec[1]], "%s %d" % [_img(spec[1], 20), n]))
	if compasses > 0:
		cells.append(_tip(SYMBOL_TIPS["fx-compass"] + " %d left this draft." % game.compasses_available(_seat), "%s %d/%d" % [_img("fx-compass", 20), game.compasses_available(_seat), compasses]))
	text += _ledger_section("Symbols", cells, "")
	if game.players[_seat].pending_battles > 0:
		text += _tip(BATTLE_TIP, "[color=#ffb070]Battle pending ×%d[/color]" % game.players[_seat].pending_battles)
	_ledger_body.text = text

func _ledger_section(title: String, cells: Array[String], empty: String) -> String:
	# A short gap after each section, not a full line.
	var gap := "[font_size=%d] [/font_size]\n" % _fs(4)
	var text := "[color=#8a96a6][font_size=%d]%s[/font_size][/color]\n" % [_fs(13), title]
	if cells.is_empty():
		return text + "[color=#8a96a6]%s[/color]\n" % empty + gap
	text += "[table=3]"
	for cell in cells:
		# Equal columns, so a wide entry does not push the others apart.
		text += "[cell expand=1 padding=0,0,6,0]%s[/cell]" % cell
	return text + "[/table]\n" + gap

## Hand order: windfall first, then hand, then draft picks.
func _hand_entries() -> Array:
	var pl: Dictionary = game.players[_seat]
	var entries: Array = []
	if pl.windfall >= 0:
		entries.append({"id": pl.windfall, "windfall": true})
	for id in pl.hand:
		entries.append({"id": id})
	for id in pl.picks:
		entries.append({"id": id, "picked": true})
	return entries

func _render_hand() -> void:
	# Keep the focused card focused across rebuilds while the mouse is on it.
	var focus_id := -1
	if is_instance_valid(_hovered_hand) and (_kb_hand or _hovered_hand.get_global_rect().has_point(get_viewport().get_mouse_position())):
		focus_id = _hovered_hand.card_id
	_clear(_hand_area)
	_hand_views.clear()
	_hovered_hand = null
	var decision: Variant = game.pending.get(_seat)
	var type: String = decision.type if decision != null else ""
	for entry: Dictionary in _hand_entries():
		var id: int = entry.id
		var view := _card(id, HAND_CARD)
		view.set_meta("windfall", entry.get("windfall", false))
		if entry.get("windfall", false):
			view.set_caption("Windfall (2 coins)")
		elif entry.get("picked", false):
			view.set_caption("Drafted")
			view.mark = CardView.Mark.HIGHLIGHT
		view.clicked.connect(_on_hand_clicked)
		view.hovered.connect(func(v: CardView) -> void:
			_hovered_hand = v
			_kb_hand = false
			_sfx.play("card_flip", -20.0, 0.12)
			_layout_hand())
		view.unhovered.connect(func(v: CardView) -> void:
			if _hovered_hand == v:
				_hovered_hand = null
			_layout_hand())
		if type == "build":
			if entry.get("windfall", false):
				view.mark = CardView.Mark.PAYMENT if _pay_windfall else CardView.Mark.NONE
			elif id == _build_card:
				view.mark = CardView.Mark.SELECTED
			elif _pay.has(id):
				view.mark = CardView.Mark.PAYMENT
		elif type == "hand_limit":
			var chosen: bool = _selected_windfall if entry.get("windfall", false) else _selected.has(id)
			view.mark = CardView.Mark.PAYMENT if chosen else CardView.Mark.NONE
		elif type == "hook_give":
			if entry.get("windfall", false):
				view.mark = CardView.Mark.DISABLED
			elif id == decision.stolen:
				view.mark = CardView.Mark.HIGHLIGHT
				view.set_caption("Stolen")
		# Crew production alone pays for it.
		if view.mark == CardView.Mark.NONE and not entry.get("windfall", false) and _is_free(id):
			view.mark = CardView.Mark.FREE
		_hand_area.add_child(view)
		_hand_views.append(view)
		if id == focus_id:
			_hovered_hand = view
	_layout_hand()
	if _hovered_hand != null:
		_on_card_hovered(_hovered_hand)
	else:
		_kb_hand = false

func _is_free(id: int) -> bool:
	return Payment.missing_after_crew(CardDB.get_card(id).cost, game.crew_production_slots(_seat)).is_empty()

## A fan hanging off the bottom of the window. The hovered card stands up
## whole, enlarged, and its neighbours make room.
func _layout_hand() -> void:
	var n := _hand_views.size()
	if n == 0:
		return
	var width := _hand_area.size.x
	var step := minf(HAND_CARD.x * 0.74, (width - HAND_CARD.x * 2.0) / maxf(n - 1, 1))
	var total := step * (n - 1) + HAND_CARD.x
	var x0 := (width - total) / 2.0
	var focus := _hand_views.find(_hovered_hand)
	# The window's bottom edge, in hand area coordinates.
	var bottom := get_viewport_rect().size.y - _hand_area.get_global_rect().position.y
	for i in range(n):
		var view := _hand_views[i]
		var t := 0.0 if n == 1 else float(i) / float(n - 1) * 2.0 - 1.0
		var lift := 0.0
		match view.mark:
			CardView.Mark.SELECTED:
				lift = 56.0
			CardView.Mark.PAYMENT:
				lift = 36.0
		var hovered := i == focus
		view.z_index = i + (100 if hovered else 0)
		view.focused = hovered and _kb_hand
		view.lifted = hovered
		var x := x0 + i * step
		var neighbour := focus >= 0 and absi(i - focus) == 1
		if focus >= 0 and not hovered:
			x += signf(i - focus) * HAND_CARD.x * (0.36 if neighbour else 0.3)
		if neighbour:
			lift += 18.0
		var target := Vector2(x, 14.0 + t * t * 18.0 - lift)
		var angle := 0.0 if hovered else t * minf(n, 9) * 1.1
		if hovered:
			# Scaled about its centre, the card's bottom rests on the edge.
			target.y = bottom + 4.0 - HAND_CARD.y * (1.0 + HAND_FOCUS_SCALE) / 2.0
		var scale_to := Vector2.ONE * (HAND_FOCUS_SCALE if hovered else HAND_NEIGHBOUR_SCALE if neighbour else 1.0)
		var shadow := 0.9 if hovered else 0.35
		if not view.has_meta("placed"):
			# Fresh views (the hand is rebuilt on every refresh) continue from
			# where the same card was, or snap into place.
			view.set_meta("placed", true)
			var pose: Dictionary = _hand_pose.get(view.card_id, {})
			if pose.is_empty():
				view.position = target
				view.rotation_degrees = angle
				view.shadow = shadow
				continue
			view.position = pose.position
			view.rotation_degrees = pose.rotation
			view.scale = pose.scale
			view.shadow = pose.shadow
		var tween := view.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(view, "position", target, 0.22)
		tween.tween_property(view, "rotation_degrees", angle, 0.22)
		tween.tween_property(view, "scale", scale_to, 0.22)
		tween.tween_property(view, "shadow", shadow, 0.22)

func _set_buttons(specs: Array) -> void:
	_clear(_buttons)
	for spec in specs:
		_buttons.add_child(_button(spec[0], spec[1], spec[2] if spec.size() > 2 else true))
	_queue_key_badges()

func _render_action() -> void:
	var decision: Variant = game.pending.get(_seat)
	var paying: bool = decision != null and decision.type == "build" and _build_card >= 0 and game.phase != DeckhandGame.Phase.GAME_OVER
	if not paying:
		_show_pay_panel(false)
	if game.phase == DeckhandGame.Phase.GAME_OVER:
		_action_text.text = "[b]The voyage is over.[/b]"
		_set_buttons([["Scores", _render_overlay], ["New game", _open_menu]])
		return
	if decision == null:
		_action_text.text = "[color=#8a96a6]The other pirates are deciding…[/color]"
		_set_buttons([])
		return
	match decision.type:
		"build":
			_render_build_action()
		"hand_limit":
			var count := _selected.size() + (1 if _selected_windfall else 0)
			_action_text.text = "[b]End of round[/b] — hand limit is %d. Click cards to discard: %d / %d selected." % [
				DeckhandGame.HAND_LIMIT, count, decision.count]
			_set_buttons([["Discard", _confirm_hand_limit, count == decision.count]])
		"hook_give":
			_action_text.text = "[b]Hook[/b] — you stole [b]%s[/b]. With fewer than 3 Hooks you must give a card back: click a card in your hand to give it to %s." % [
				CardDB.title(decision.stolen), _who(decision.target)]
			_set_buttons([])
		_:
			if _hold_choices:
				_action_text.text = ""
				_set_buttons([])
			elif _overlay_hidden:
				_action_text.text = "[color=#8a96a6]Your choice is put aside — look around the table, then bring it back.[/color]"
				_set_buttons([["Show the choice", _toggle_overlay]])
			else:
				_action_text.text = "[b]Make your choice above.[/b]"
				_set_buttons([["Hide to see the table", _toggle_overlay]])

func _render_build_action() -> void:
	if _build_card < 0:
		_action_text.text = "[b]Build:[/b] click a card in your hand to build it, or pass for the rest of the round."
		_set_buttons([["Pass", func() -> void: _submit({"pass": true})]])
		return
	var card := CardDB.get_card(_build_card)
	var crew_missing := Payment.missing_after_crew(card.cost, game.crew_production_slots(_seat))
	var result := game.check_payment(_seat, _build_card, _pay, _pay_windfall)
	# One line here; the payment itself is in the panel over the crew.
	var state := "[color=#8fe388]✓ paid — ready to build[/color]" if result.ok else "[color=#e8c890]pick hand cards to discard[/color]"
	_action_text.text = "[b]Build %s[/b]   %s" % [card.title, state]
	var specs: Array = [
		["Cancel", func() -> void:
			_reset_input()
			_refresh()],
	]
	if not crew_missing.is_empty():
		specs.append(["Auto-pay", _auto_pay])
	_set_buttons(specs)
	var build := _button("Build", _confirm_build, result.ok)
	if result.ok:
		_primary(build)
	_buttons.add_child(build)
	_buttons.add_child(_button("Pass", func() -> void: _submit({"pass": true})))
	_render_pay_panel(card, crew_missing, result)
	_show_pay_panel(true)

## The payment panel: a wooden plate that rises over the bottom of the crew
## while a card is being paid for, so nothing else on the table moves.
func _build_pay_panel() -> void:
	_pay_panel = _wood_panel(Color(0.58, 0.42, 0.27), true)
	_pay_panel.mouse_filter = MOUSE_FILTER_STOP
	_pay_panel.visible = false
	add_child(_pay_panel)
	_pay_body = VBoxContainer.new()
	_pay_body.add_theme_constant_override("separation", 10)
	_pay_panel.add_child(_pay_body)
	_crew_panel.resized.connect(_place_pay_panel)

func _render_pay_panel(card: Dictionary, crew_missing: Array, result: Dictionary) -> void:
	_clear(_pay_body)
	_pay_body.add_child(_label("Paying for %s" % card.title, 18, GOLD, true))
	# The cost as a checklist: what the crew pays, what discards pay, what is missing.
	var unpaid := {}
	for token: String in result.missing:
		unpaid[token] = unpaid.get(token, 0) + 1
	var from_discards := {}
	for token: String in crew_missing:
		from_discards[token] = from_discards.get(token, 0) + 1
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_pay_body.add_child(row)
	for token: String in card.cost:
		var mark: String
		if from_discards.get(token, 0) == 0:
			mark = "crew"
		elif unpaid.get(token, 0) >= from_discards[token]:
			mark = "missing"
		else:
			mark = "discard"
		if mark != "crew":
			from_discards[token] -= 1
		if mark == "missing":
			unpaid[token] -= 1
		row.add_child(_cost_chip(token, mark))
	if crew_missing.is_empty():
		_pay_body.add_child(_label("Your crew pays it all.", 15, Color(0.75, 0.95, 0.7)))
	else:
		# What discarding gives (the sentence that used to sit in the action bar).
		var rates := _rich(15)
		rates.fit_content = true
		rates.autowrap_mode = TextServer.AUTOWRAP_OFF
		rates.add_theme_color_override("default_color", Color(1, 0.92, 0.8))
		rates.text = "[color=#c9a76a]Discard:[/color]  1 card → %s or %s or its resource   ·   2 cards → any   ·   Windfall → %s%s" % [
			_res("cs", 14), _res("c", 14), _res("cs", 14), _res("cs", 14)]
		_pay_body.add_child(rates)
	if _pay_windfall:
		var dest := OptionButton.new()
		dest.add_item("Windfall goes to the Infamy deck", DeckhandGame.WINDFALL_DECK)
		for slot in game.unrevealed_slots():
			dest.add_item("Windfall goes on Row slot %d" % (slot + 1), slot)
		dest.select(maxi(dest.get_item_index(_windfall_dest), 0))
		dest.item_selected.connect(func(i: int) -> void: _windfall_dest = dest.get_item_id(i))
		dest.size_flags_horizontal = SIZE_SHRINK_BEGIN
		_pay_body.add_child(dest)

## One cost icon with what pays it underneath.
func _cost_chip(token: String, mark: String) -> Control:
	var chip := VBoxContainer.new()
	chip.add_theme_constant_override("separation", 2)
	var icon := TextureRect.new()
	icon.texture = load("%sres-%s.png" % [ICONS, token])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(40, 40)
	icon.tooltip_text = CardDB.RESOURCE_NAMES[token]
	if mark == "missing":
		icon.modulate = Color(1, 1, 1, 0.35)
	chip.add_child(icon)
	var spec: Array = {"crew": ["✓ crew", Color(0.6, 0.92, 0.55)], "discard": ["✓ discard", GOLD], "missing": ["needed", Color(0.95, 0.6, 0.55)]}[mark]
	var caption := _label(spec[0], 12, spec[1], true)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(caption)
	return chip

func _show_pay_panel(on: bool) -> void:
	if on == _pay_panel.visible and not _pay_panel.has_meta("hiding"):
		if on:
			_place_pay_panel.call_deferred()
		return
	if _pay_panel.has_meta("fade"):
		(_pay_panel.get_meta("fade") as Tween).kill()
	var fade := _pay_panel.create_tween().set_parallel()
	_pay_panel.set_meta("fade", fade)
	if on:
		_pay_panel.remove_meta("hiding")
		_pay_panel.visible = true
		_place_pay_panel.call_deferred()
		fade.tween_property(_pay_panel, "modulate:a", 1.0, 0.18).from(0.0)
	else:
		_pay_panel.set_meta("hiding", true)
		fade.tween_property(_pay_panel, "modulate:a", 0.0, 0.15)
		fade.chain().tween_callback(func() -> void:
			_pay_panel.visible = false
			_pay_panel.remove_meta("hiding"))

## Bottom-left of the crew area, just above the action bar.
func _place_pay_panel() -> void:
	if not _pay_panel.visible:
		return
	_pay_panel.reset_size()
	var crew := _crew_panel.get_global_rect()
	_pay_panel.position = Vector2(crew.position.x + 14.0, crew.end.y - _pay_panel.size.y - 10.0)

# --- Overlays for choices ---------------------------------------------------

func _show_overlay(title: String, subtitle: String) -> HBoxContainer:
	_clear(_overlay_body)
	_overlay.visible = true
	_overlay_body.add_child(_label(title, 24, GOLD, true))
	if not subtitle.is_empty():
		var sub := _rich(16)
		sub.fit_content = true
		sub.custom_minimum_size.x = 640
		sub.text = subtitle
		_overlay_body.add_child(sub)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 12)
	_overlay_body.add_child(cards)
	return cards

func _overlay_buttons(specs: Array) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for spec in specs:
		var button := _button(spec[0], spec[1], spec[2] if spec.size() > 2 else true)
		if spec.size() > 3 and spec[3]:
			_primary(button)
		# Bigger than the action bar's: these are the choice being made.
		button.add_theme_font_size_override("font_size", _fs(19))
		button.custom_minimum_size = Vector2(130, 48)
		row.add_child(button)
	_overlay_body.add_child(row)
	_queue_key_badges()

func _overlay_card(parent: Control, id: int, on_click: Callable, face_up: bool = true, card_size: Vector2 = OVERLAY_CARD) -> CardView:
	var view := _card(id, card_size, face_up)
	view.clicked.connect(func(_v: CardView) -> void:
		_sfx.play("card_flip", -4.0)
		on_click.call())
	# Pointing at a choice focuses it, like the arrow keys.
	view.hovered.connect(func(v: CardView) -> void:
		_kb_card = v.card_id
		_show_overlay_focus())
	parent.add_child(view)
	return view

func _render_overlay() -> void:
	_overlay.visible = false
	if game.phase == DeckhandGame.Phase.GAME_OVER:
		_render_game_over()
		return
	var decision: Variant = game.pending.get(_seat)
	if decision == null or _hold_choices:
		return
	match decision.type:
		"mulligan":
			var cards := _show_overlay("First draft", "You may keep this draft hand, or discard it all and draw a new one (once, round 1 only).")
			var draft: Array = game.players[_seat].draft_hand
			for id: int in draft:
				_card_into(cards, id, _overlay_size(draft.size()))
			_overlay_buttons([["Keep", func() -> void: _submit({"redraw": false}), true, true], ["Redraw all", func() -> void: _submit({"redraw": true})]])
		"draft_pick":
			_render_draft_overlay(decision)
		"choose_one":
			var cards := _show_overlay("Draw 3, keep 1", "From %s: keep one card, the other two are discarded." % CardDB.title(decision.source))
			for id: int in decision.cards:
				_overlay_card(cards, id, func() -> void: _submit({"card": id}))
		"telescope_slot":
			var cards := _show_overlay("Telescope", "Choose a face-down Row card to look at.")
			for slot: int in decision.slots:
				var view := _overlay_card(cards, game.row[slot].cards[-1], func() -> void: _submit({"slot": slot}), false)
				view.set_caption("Round %d" % (slot + 1))
		"telescope_swap":
			var cards := _show_overlay("Telescope", "Left: the face-down card for round %d. Right: the top of the Infamy deck. Swap them?" % (decision.slot + 1))
			_card_into(cards, decision.row_card).set_caption("In the Row")
			_card_into(cards, decision.deck_card).set_caption("Infamy deck")
			_overlay_buttons([["Keep the Row", func() -> void: _submit({"swap": false})], ["Swap", func() -> void: _submit({"swap": true})]])
		"telescope_place":
			var cards := _show_overlay("Telescope", "Last round: you may place the top Infamy card face up in the Row.")
			_card_into(cards, decision.card)
			_overlay_buttons([["Leave it", func() -> void: _submit({"place": false})], ["Place it", func() -> void: _submit({"place": true})]])
		"hook_target":
			_show_overlay("Hook", "Steal a random card from which pirate?")
			var specs: Array = []
			for q: int in decision.targets:
				specs.append(["%s (%d cards)" % [game.players[q].name, game.players[q].hand.size()], func() -> void: _submit({"target": q})])
			_overlay_buttons(specs)
	if _overlay_hidden:
		_overlay.visible = false
	_show_overlay_focus()

## Puts the pending choice aside (or brings it back) without changing it.
func _toggle_overlay() -> void:
	_overlay_hidden = not _overlay_hidden
	_overlay.visible = true
	_overlay.modulate.a = 1.0 if _overlay_hidden else 0.0
	var tween := _overlay.create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0 if _overlay_hidden else 1.0, 0.18)
	if _overlay_hidden:
		tween.tween_callback(func() -> void: _overlay.visible = not _overlay_hidden)
	_render_action()

## Smaller cards when a big draft hand would not fit beside the ledger.
func _overlay_size(count: int) -> Vector2:
	return OVERLAY_CARD if count <= 5 else OVERLAY_CARD_SMALL

func _card_into(parent: Control, id: int, card_size: Vector2 = OVERLAY_CARD) -> CardView:
	var view := _card(id, card_size)
	view.interactive = false
	parent.add_child(view)
	return view

func _render_draft_overlay(decision: Dictionary) -> void:
	var pl: Dictionary = game.players[_seat]
	var direction := "to your left ↻" if game.wind() == 1 else "to your right ↺"
	var sub := "Pick one card to keep; the rest pass %s. Picked so far: %d." % [direction, pl.picks.size()]
	if decision.must_discard:
		sub = "[color=#ffd36b]Compass:[/color] click the card to keep, then a card to discard."
	var cards := _show_overlay("Draft — round %d" % game.round_index, sub)
	var pick: int = _selected[0] if _selected.size() > 0 else -1
	var drop: int = _selected[1] if _selected.size() > 1 else -1
	for id: int in pl.draft_hand:
		var view := _overlay_card(cards, id, func() -> void: _on_draft_card(id, decision), true, _overlay_size(pl.draft_hand.size()))
		if id == pick:
			view.mark = CardView.Mark.SELECTED
			view.set_caption("Keep")
		elif id == drop:
			view.mark = CardView.Mark.PAYMENT
			view.set_caption("Discard")
	var specs: Array = []
	if decision.can_use_compass:
		specs.append(["Use Compass (%d left)" % game.compasses_available(_seat), func() -> void: _submit({"use_compass": true})])
	if decision.must_discard:
		specs.append(["Confirm", func() -> void: _submit({"pick": pick, "discard": drop}), pick >= 0 and drop >= 0, true])
	_overlay_buttons(specs)

func _on_draft_card(id: int, decision: Dictionary) -> void:
	if not decision.must_discard:
		_submit({"pick": id})
		return
	if _selected.is_empty():
		_selected.append(id)
	elif _selected[0] == id:
		_selected.clear()
	elif _selected.size() > 1 and _selected[1] == id:
		_selected.resize(1)
	elif _selected.size() == 1:
		_selected.append(id)
	else:
		_selected[1] = id
	_render_overlay()

func _render_game_over() -> void:
	var winners := game.winners()
	var headline := "Victory!" if winners.has(_seat) else "Defeat"
	if winners.size() > 1 and winners.has(_seat):
		headline = "Shared victory"
	_show_overlay(headline, "[center]Your rank: [b][color=#ffd36b]%s[/color][/b][/center]" % DeckhandGame.rank_for(game.score(_seat)))
	# Score sheet: where each pirate's points come from.
	var sheet := GridContainer.new()
	sheet.columns = 6
	sheet.add_theme_constant_override("h_separation", 28)
	sheet.add_theme_constant_override("v_separation", 8)
	_overlay_body.add_child(sheet)
	_overlay_body.move_child(sheet, 2)
	for title in ["", "Crew cards", "Infamy", "Multipliers", "Total", "%s" % _img("fx-tentacle", 18)]:
		sheet.add_child(_sheet_cell("[color=#8a96a6]%s[/color]" % title, 14))
	var row := 0
	for entry: Dictionary in game.final_scores:
		var p: int = entry.player
		var parts := game.score_breakdown(p)
		var star := "[color=#ffd36b]★[/color] " if winners.has(p) else ""
		var cells := [
			_sheet_cell("%s[b]%s[/b]" % [star, _who(p)], 18, false),
			_sheet_cell(str(parts.crew), 18),
			_sheet_cell(str(parts.infamy), 18),
			_sheet_cell(str(parts.multipliers), 18),
			_sheet_cell("[b][color=#ffd36b]%d VP[/color][/b]" % entry.score, 20),
			_sheet_cell(str(entry.tentacles), 16),
		]
		# Pirates appear one after another, from the bottom of the table up.
		var delay := 0.35 + 0.3 * (game.final_scores.size() - 1 - row)
		for cell: Control in cells:
			sheet.add_child(cell)
			cell.modulate.a = 0.0
			cell.create_tween().tween_property(cell, "modulate:a", 1.0, 0.4).set_delay(delay)
		row += 1
	_overlay_buttons([["View the table", func() -> void: _overlay.visible = false], ["New game", _open_menu]])

func _sheet_cell(text: String, font_size: int, centered: bool = true) -> RichTextLabel:
	var cell := _rich(font_size)
	cell.fit_content = true
	cell.autowrap_mode = TextServer.AUTOWRAP_OFF
	cell.text = "[center]%s[/center]" % text if centered else text
	return cell

# --- Score feedback ---------------------------------------------------------

## Writes `template` ({vp} = score) into `label`, counting up from the score
## shown last time and floating the gains ("+2 VP", new banners) above the
## score at `offset` from the label. Returns the banners just raised.
func _show_gains(p: int, label: RichTextLabel, template: String, offset: Vector2, size: float = 1.0) -> Array:
	var vp := game.score(p)
	var banners := game.raised_banners(p)
	var before: Dictionary = _shown.get(p, {"vp": vp, "banners": banners})
	_shown[p] = {"vp": vp, "banners": banners}
	var fresh: Array = []
	for b: String in banners:
		if banners[b] > before.banners.get(b, 0):
			fresh.append(b)
	if label.has_meta("vp_tween"):
		(label.get_meta("vp_tween") as Tween).kill()
		label.remove_meta("vp_tween")
	label.text = template.replace("{vp}", str(vp))
	if vp != before.vp:
		var tween := label.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		label.set_meta("vp_tween", tween)
		tween.tween_method(func(value: float) -> void:
			label.text = template.replace("{vp}", str(roundi(value))),
			float(before.vp), float(vp), 0.7)
	var gain := ""
	if vp > before.vp:
		gain = "+%d VP" % (vp - before.vp)
	for b: String in fresh:
		gain += "   +%s" % _banner(b, 20)
	if not gain.is_empty():
		_float_text(label, offset, gain, size)
	return fresh

## A gold note that rises from `node` (+ `offset`) and fades away.
func _float_text(node: Control, offset: Vector2, text: String, size: float) -> void:
	var note := _rich(roundi(18 * size))
	note.fit_content = true
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.mouse_filter = MOUSE_FILTER_IGNORE
	note.add_theme_color_override("default_color", GOLD)
	note.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	note.add_theme_constant_override("outline_size", 6)
	note.text = "[b]%s[/b]" % text
	note.modulate.a = 0.0
	_motion.add_child(note)
	# Wait for the (possibly new) label to be laid out.
	await get_tree().process_frame
	if not is_instance_valid(node) or not node.is_inside_tree():
		note.queue_free()
		return
	note.size = note.get_combined_minimum_size()
	var start := node.get_global_rect().position + offset - Vector2(0.0, note.size.y * 0.6)
	note.position = start
	note.pivot_offset = Vector2(0.0, note.size.y / 2.0)
	var tween := note.create_tween()
	tween.tween_property(note, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(note, "scale", Vector2.ONE, 0.35).from(Vector2(0.7, 0.7)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(note, "position:y", start.y - 34.0, 1.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(note, "modulate:a", 0.0, 0.6).set_delay(1.0)
	tween.tween_callback(note.queue_free)

# --- Card motion ------------------------------------------------------------

## Records where every visible card is before the table is rebuilt.
func _capture_cards() -> Dictionary:
	if not _unplayed.is_empty():
		# Rebuilt again before the last changes were laid out: animate from
		# the earlier state instead.
		_card_views.clear()
		return _unplayed
	var flying := _motion.in_flight()
	var poses := {}
	for id: int in flying:
		poses[id] = flying[id].pose
	for view in _card_views:
		if is_instance_valid(view) and view.is_inside_tree() and view.is_visible_in_tree() and not poses.has(view.card_id) and not _in_spotlight.has(view.card_id):
			var pose := CardMotion.pose_of(view, view.face_up)
			pose.zone = _zone_of(view)
			poses[view.card_id] = pose
	_card_views.clear()
	_hand_pose.clear()
	for view in _hand_views:
		if is_instance_valid(view) and view.has_meta("placed"):
			_hand_pose[view.card_id] = {"position": view.position, "rotation": view.rotation_degrees, "scale": view.scale, "shadow": view.shadow}
	var anchors := {}
	for key: String in _pile_views:
		if is_instance_valid(_pile_views[key]) and _pile_views[key].is_inside_tree():
			anchors[key] = CardMotion.pose_of(_pile_views[key], false)
	for p: int in _opp_panels:
		if is_instance_valid(_opp_panels[p]) and _opp_panels[p].is_inside_tree():
			var rect: Rect2 = _opp_panels[p].get_global_rect()
			anchors[p] = {"center": rect.get_center(), "size": OPP_CARD, "rotation": 0.0, "face_up": false}
	return {"poses": poses, "anchors": anchors, "flying": flying}

func _zone_of(view: CardView) -> String:
	if view.get_parent() == _hand_area:
		return "hand"
	if _overlay.is_ancestor_of(view):
		return "overlay"
	if _row_box.is_ancestor_of(view):
		return "row"
	if _crew_columns.is_ancestor_of(view):
		return "crew"
	return "opponents"

## Screen direction draft cards travel in: left with the wind clockwise.
func _pass_direction() -> float:
	return -1.0 if game.wind() == 1 else 1.0

## Flies cards that moved, appeared or vanished since `snapshot`.
func _animate_cards(snapshot: Dictionary) -> void:
	_motion_gen += 1
	var generation := _motion_gen
	var poses: Dictionary = snapshot.poses
	var anchors: Dictionary = snapshot.anchors
	var flying: Dictionary = snapshot.flying
	var present := {}
	var moving: Array[CardView] = []
	var continuing: Array[CardView] = []
	for view in _card_views:
		if not view.is_visible_in_tree():
			continue
		present[view.card_id] = true
		if _in_spotlight.has(view.card_id):
			view.modulate.a = 0.0 # shown mid-table for now
			continue
		var old: Dictionary = poses.get(view.card_id, {})
		var zone := _zone_of(view)
		var flight: Dictionary = flying.get(view.card_id, {})
		if not flight.is_empty() and flight.zone == zone and flight.face_up == view.face_up:
			# Still heading to the same place: keep that flight going.
			continuing.append(view)
			view.modulate.a = 0.0
			continue
		if not old.is_empty() and old.get("zone") == zone and old.face_up == view.face_up:
			continue # Stayed put (the hand animates itself from _hand_pose).
		moving.append(view)
		view.modulate.a = 0.0 # Until the ghost lands; avoids a one-frame pop.
	var draft_passed := false
	var burned := 0
	for id: int in poses:
		if not present.has(id):
			draft_passed = draft_passed or (poses[id].get("zone") == "overlay" and game.phase == DeckhandGame.Phase.DRAFT)
			if game.discard_pile.has(id) and not _motion.is_flying(id):
				# Discards burn away where they were, one after the other.
				_motion.burn(id, poses[id], burned * 0.08)
				burned += 1
			else:
				_animate_vanished(id, poses[id], anchors)
	if burned > 0:
		_sfx.play("burn", -8.0)
	# Containers lay out new cards on the next frame.
	_unplayed = snapshot
	await get_tree().process_frame
	if generation != _motion_gen:
		return
	_unplayed = {}
	# On the first refresh the decks were not on the table yet.
	for key: String in _pile_views:
		if not anchors.has(key) and is_instance_valid(_pile_views[key]):
			anchors[key] = CardMotion.pose_of(_pile_views[key], false)
	for view in continuing:
		if not is_instance_valid(view) or not view.is_inside_tree():
			continue
		if _motion.is_flying(view.card_id):
			_motion.retarget(view.card_id, view, CardMotion.pose_of(view, view.face_up))
		else:
			view.modulate.a = 1.0
	var queued := {}
	for view in moving:
		if not is_instance_valid(view) or not view.is_inside_tree():
			continue
		var to := CardMotion.pose_of(view, view.face_up)
		var old: Dictionary = poses.get(view.card_id, {})
		var zone := _zone_of(view)
		if not old.is_empty():
			if _claimed.has(view.card_id):
				var claimer: int = _claimed[view.card_id]
				_claimed.erase(view.card_id)
				view.modulate.a = 0.0
				_spotlight_claim(view.card_id, old, claimer)
				continue
			_motion.fly(view.card_id, old, to, {"target": view, "zone": zone})
			continue
		if zone == "overlay" and draft_passed:
			# The next draft hand slides in from the neighbour passing it.
			var from := to.duplicate()
			from.center -= Vector2(_pass_direction() * 320.0, 0.0)
			_motion.fly(view.card_id, from, to, {"target": view, "zone": zone, "fade_in": true})
		elif zone in ["hand", "overlay", "row"]:
			# Dealt from its deck, face down, turning over on the way.
			var deck := "infamy" if CardDB.is_infamy(view.card_id) else "supply"
			var count: int = queued.get(deck, 0)
			queued[deck] = count + 1
			if anchors.has(deck):
				_motion.fly(view.card_id, anchors[deck], to, {"target": view, "zone": zone, "delay": count * 0.07})
			else:
				view.modulate.a = 1.0
		else:
			var from := to.duplicate()
			from.size *= 0.8
			_motion.fly(view.card_id, from, to, {"target": view, "zone": zone, "fade_in": true, "duration": 0.3})

## A band across the table announcing the round and the wind: it opens,
## holds a moment and fades, without blocking the mouse.
func _round_title(round_number: int, wind: int, delay: float) -> void:
	var title := "Round %d" % round_number if round_number < DeckhandGame.ROUNDS else "Final round"
	var wind_text := "The wind blows %s" % ("clockwise  ↻" if wind == 1 else "counter-clockwise  ↺")
	# The round's first choice (the draft) is dealt once the title has gone.
	_band(title, GOLD, wind_text, delay, true)

## A band across the middle of the table: `title`, and a `subtitle` (BBCode)
## under it. It opens, holds a moment and fades, letting clicks through.
## Bands queue up behind one another; with `hold`, choices wait for it.
func _band(title_text: String, color: Color, subtitle: String, delay: float, hold: bool) -> void:
	if hold:
		_hold_choices = true
	while is_instance_valid(_title_layer):
		await _title_layer.tree_exited
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_title_layer = layer
	layer.tree_exited.connect(func() -> void:
		if hold:
			_hold_choices = _spotlights > 0
			_queue_refresh())
	var band := PanelContainer.new()
	band.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.035, 0.02, 0.86)
	style.border_color = Color(color, 0.8)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 30
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	band.add_theme_stylebox_override("panel", style)
	band.set_anchors_preset(PRESET_CENTER)
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.grow_vertical = GROW_DIRECTION_BOTH
	layer.add_child(band)
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.mouse_filter = MOUSE_FILTER_IGNORE
	band.add_child(lines)
	var title := _label(title_text, 46, color, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	title.add_theme_constant_override("outline_size", 8)
	lines.add_child(title)
	var sub := _rich(19)
	sub.fit_content = true
	sub.mouse_filter = MOUSE_FILTER_IGNORE
	sub.add_theme_color_override("default_color", Color(0.95, 0.88, 0.72))
	sub.text = "[center]%s[/center]" % subtitle
	lines.add_child(sub)
	band.pivot_offset = Vector2(get_viewport_rect().size.x / 2.0, band.get_combined_minimum_size().y / 2.0)
	band.modulate.a = 0.0
	var tween := band.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(band, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(band, "scale:y", 1.0, 0.3).from(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(title, "position:x", 0.0, 0.5).from(-60.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.1 if hold else 1.8)
	tween.tween_property(band, "modulate:a", 0.0, 0.45)
	tween.tween_callback(layer.queue_free)

## A Battle is announced: when and how it will be fought.
func _battle_announced(p: int) -> void:
	var text := "It is fought on [b]your next build[/b]." if p == _seat else "It is fought on %s's next build." % _who(p)
	text += "\nEveryone who builds then compares the card they built (+1 per Battle symbol); the best draws a card."
	_band("You announce a Battle!" if p == _seat else "A Battle is announced!", Color(1.0, 0.55, 0.4), text, 0.0, false)

## A Battle is fought: each builder's score, and who wins.
func _battle_fought(p: int, winner: int, scores: Dictionary, count: int) -> void:
	var parts: Array[String] = []
	for q: int in scores:
		var name := "You" if q == _seat else _who(q)
		var score := "[b]%d[/b]" % scores[q]
		if q == winner:
			score = "[color=#ffd36b]%s[/color]" % score
		parts.append("%s %s" % [name, score])
	var outcome: String
	if winner < 0:
		outcome = "A draw: nobody draws."
	elif winner == _seat:
		outcome = "[color=#ffd36b]You win and draw %d.[/color]" % count
	else:
		outcome = "%s wins and draws %d." % [_who(winner), count]
	var whose := "Your Battle" if p == _seat else "%s's Battle" % _who(p)
	_band("Battle!", Color(1.0, 0.55, 0.4), "%s:   %s\n%s" % [whose, "   ·   ".join(parts), outcome], 0.0, false)

## A claimed Infamy card: shown mid-table ("Silver Ines claims it!"), then
## off to its new owner's crew, glowing, landing in a puff of gold.
func _spotlight_claim(id: int, from: Dictionary, claimer: int) -> void:
	_in_spotlight[id] = true
	var who := "You claim it!" if claimer == _seat else "%s claims it!" % _who(claimer)
	var caption := "[center][font_size=%d][b][color=#ffd36b]%s[/color][/b][/font_size][/center]" % [_fs(30), who]
	_spotlight(id, from, caption, func(pose: Dictionary) -> void:
		_in_spotlight.erase(id)
		# The card's place in its new crew, as laid out now.
		var target: CardView = null
		for view in _card_views:
			if is_instance_valid(view) and view.is_inside_tree() and view.card_id == id:
				target = view
		if target == null:
			_motion.burst(pose.center, pose.size)
			return
		var options := _claim_flight()
		options.target = target
		options.zone = _zone_of(target)
		# From its big mid-table size: less swell, a lower arc.
		options.lift = 0.08
		options.arc = 40.0
		options.duration = 0.8
		_motion.fly(id, pose, CardMotion.pose_of(target, true), options))

## A contested Infamy card (a tie: nobody gets it): shown mid-table with who
## tied for it, then it burns away.
func _contested(id: int, from: Dictionary, rivals: Array) -> void:
	var names: Array[String] = []
	for p: int in rivals:
		names.append(_who(p))
	var tied := " and ".join(names) if names.size() < 3 else ", ".join(names.slice(0, -1)) + " and " + names[-1]
	var caption := "[center][font_size=%d][b][color=#ff8a70]Contested![/color][/b][/font_size]\n%s tie for it: nobody claims it.[/center]" % [_fs(32), tied]
	_spotlight(id, from, caption, func(pose: Dictionary) -> void:
		_sfx.play("burn")
		_motion.burn(id, pose))

## Shows Infamy card `id` in the middle of the dimmed table: it flies there
## from pose `from`, turning face up, with `caption` under it; after a moment
## `finish` is called with its pose (to send it on) and the table clears.
func _spotlight(id: int, from: Dictionary, caption_text: String, finish: Callable) -> void:
	if is_instance_valid(_title_layer):
		await _title_layer.tree_exited
	var screen := get_viewport_rect().size
	var dim_layer := CanvasLayer.new()
	dim_layer.layer = 4 # under the flying card (layer 5)
	add_child(dim_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	dim.modulate.a = 0.0
	dim_layer.add_child(dim)
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var card_size := Vector2(240, 326)
	var center := Vector2(screen.x / 2.0, screen.y / 2.0 - 50.0)
	var view := CardView.make(id, card_size)
	view.interactive = false
	view.mouse_filter = MOUSE_FILTER_IGNORE
	view.position = center - card_size / 2.0
	layer.add_child(view)
	view.set_requirement(_banners_met(_seat, id))
	var caption := _rich(18)
	caption.fit_content = true
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	caption.custom_minimum_size.x = 640
	caption.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
	caption.add_theme_constant_override("outline_size", 6)
	caption.text = caption_text
	caption.position = Vector2(center.x - 320.0, center.y + card_size.y / 2.0 + 18.0)
	caption.modulate.a = 0.0
	layer.add_child(caption)

	_sfx.play("reveal", -4.0)
	var to := {"center": center, "size": card_size, "rotation": 0.0, "face_up": true}
	_motion.fly(id, from, to, {"target": view, "duration": 0.85, "lift": 0.25, "arc": 70.0})
	var tween := create_tween()
	tween.tween_property(dim, "modulate:a", 1.0, 0.4)
	tween.tween_interval(0.5)
	tween.tween_property(caption, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.7)
	tween.tween_callback(func() -> void:
		var pose := CardMotion.pose_of(view, true)
		view.visible = false
		finish.call(pose))
	tween.tween_property(caption, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(dim, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void:
		layer.queue_free()
		dim_layer.queue_free()
		_spotlights -= 1
		if _spotlights == 0 and not is_instance_valid(_title_layer):
			_hold_choices = false
			_queue_refresh())

## A claimed Infamy card lifts high, glowing, and lands in a puff of gold.
func _claim_flight() -> Dictionary:
	return {
		"duration": 1.0, "lift": 0.45, "arc": 90.0, "glow": true,
		"on_land": func(pose: Dictionary) -> void: _motion.burst(pose.center, pose.size),
	}

func _animate_vanished(id: int, from: Dictionary, anchors: Dictionary) -> void:
	if _lost.has(id):
		_contested(id, from, _lost[id])
		_lost.erase(id)
		return
	var to := from.duplicate()
	var holder := -1
	for p in range(game.player_count()):
		if p != _seat and (game.players[p].hand.has(id) or game.players[p].draft_hand.has(id)):
			holder = p
	if game.discard_pile.has(id) and anchors.has("discard"):
		to = anchors.discard.duplicate()
		to.face_up = from.face_up
	elif from.get("zone") == "overlay" and game.phase == DeckhandGame.Phase.DRAFT:
		to.center += Vector2(_pass_direction() * 320.0, 0.0)
	elif game.supply.has(id) and anchors.has("supply"):
		to = anchors.supply
	elif game.infamy_deck.has(id) and anchors.has("infamy"):
		to = anchors.infamy
	elif holder >= 0 and anchors.has(holder):
		to = anchors[holder]
	else:
		to.size *= 0.8
	if _claimed.has(id):
		var claimer: int = _claimed[id]
		_claimed.erase(id)
		_spotlight_claim(id, from, claimer)
		return
	_motion.fly(id, from, to, {"fade_out": true})

# --- Input ------------------------------------------------------------------

## Game moments -> sounds. Opponents' actions play a little quieter.
func _on_game_event(kind: String, info: Dictionary) -> void:
	if _replaying:
		return
	var p: int = info.get("player", _seat)
	var volume := 0.0 if p == _seat else -6.0
	match kind:
		"round_start":
			_sfx.play("bell", -3.0)
			# The first round's card waits for the table to fade in.
			_round_title(game.round_index, game.wind(), 1.3 if _curtain.visible else 0.0)
		"reveal":
			_sfx.play("reveal")
		"deal":
			_sfx.play("card_deal", -2.0)
		"draft_pass":
			_sfx.play("card_deal", -9.0)
		"pass":
			_sfx.play("pass", volume)
		"build":
			if info.paid > 0:
				_sfx.play("coin", volume - 2.0)
		"crew":
			if not CardDB.is_infamy(info.card):
				_sfx.play("card_place", volume)
		"draw":
			_sfx.play("card_deal", volume - 4.0)
		"telescope":
			_sfx.play("telescope", volume)
		"hook":
			_sfx.play("hook", 0.0 if _seat in [p, info.target] else -6.0)
		"battle_announce":
			_sfx.play("battle", volume - 10.0)
			_battle_announced(p)
		"battle":
			_sfx.play("battle")
			_battle_fought(p, info.winner, info.get("scores", {}), info.get("count", 1))
		"claim":
			_sfx.play("claim", volume)
			_claimed[info.card] = p
			_spotlights += 1
			_hold_choices = true
			# If the card was not on the table to animate from, show it anyway.
			var claimed_card: int = info.card
			get_tree().create_timer(0.5).timeout.connect(func() -> void:
				if _claimed.has(claimed_card):
					var claimer: int = _claimed[claimed_card]
					_claimed.erase(claimed_card)
					var middle := get_viewport_rect().size / 2.0
					_spotlight_claim(claimed_card, {"center": middle, "size": ROW_CARD, "rotation": 0.0, "face_up": false}, claimer))
		"lost":
			# Shown (and its sound played) when the table animates it away.
			_lost[info.card] = info.rivals
			_spotlights += 1
			_hold_choices = true
			# If the card was not on the table to animate from, show it anyway.
			var card: int = info.card
			get_tree().create_timer(0.5).timeout.connect(func() -> void:
				if _lost.has(card):
					var rivals: Array = _lost[card]
					_lost.erase(card)
					var center := get_viewport_rect().size / 2.0
					_contested(card, {"center": center, "size": ROW_CARD, "rotation": 0.0, "face_up": false}, rivals))
		"game_end":
			_sfx.play("victory" if game.winners().has(_seat) else "defeat")

func _on_hand_clicked(view: CardView) -> void:
	var decision: Variant = game.pending.get(_seat)
	if decision == null:
		return
	_sfx.play("card_flip", -6.0)
	var is_windfall: bool = view.get_meta("windfall", false)
	var id := view.card_id
	match decision.type:
		"build":
			if is_windfall:
				if _build_card >= 0:
					_pay_windfall = not _pay_windfall
			elif _build_card < 0:
				if game.players[_seat].hand.has(id):
					_build_card = id
			elif id == _build_card:
				_reset_input()
			elif _pay.has(id):
				_pay.erase(id)
			else:
				_pay.append(id)
		"hand_limit":
			if is_windfall:
				_selected_windfall = not _selected_windfall
			elif _selected.has(id):
				_selected.erase(id)
			elif game.players[_seat].hand.has(id):
				_selected.append(id)
		"hook_give":
			if not is_windfall and game.players[_seat].hand.has(id):
				_submit({"card": id})
			return
		_:
			return
	_render_hand()
	_render_action()

func _auto_pay() -> void:
	var others: Array = game.players[_seat].hand.filter(func(id: int) -> bool: return id != _build_card)
	var keep := func(id: int) -> float: return DeckhandBot.keep_value(game, _seat, id)
	var windfall_value := INF if game.players[_seat].windfall < 0 else 1.0
	var plan := Payment.plan(CardDB.get_card(_build_card).cost, game.crew_production_slots(_seat), others, keep, windfall_value)
	if not plan.ok:
		_flash("Not enough cards to pay for this one.")
		return
	_pay.assign(plan.discards)
	_pay_windfall = plan.windfall
	_render_hand()
	_render_action()

func _confirm_build() -> void:
	_submit({
		"card": _build_card,
		"discards": _pay.duplicate(),
		"windfall": _pay_windfall,
		"windfall_dest": _windfall_dest,
	})

func _confirm_hand_limit() -> void:
	_submit({"discards": _selected.duplicate(), "windfall": _selected_windfall, "windfall_dest": DeckhandGame.WINDFALL_DECK})

func _flash(text: String) -> void:
	_action_text.text = "[color=#ff9080]%s[/color]" % text

# --- Keyboard ---------------------------------------------------------------
# Esc: menu.  Left / Right: move between cards (the choice, else the hand).
# Enter / Space: play the focused card, or else press the green button.
# H: hide or show the choice.  Each button has its own key, shown on it
# (the first free letter of its label, else a digit).  Tab still works.

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 3.0:
		_using_keys = false
	if not event is InputEventKey or not event.pressed:
		return
	var key: Key = (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		if _credits.visible:
			_credits.visible = false
		elif _online_panel.visible:
			_close_online()
		elif _settings.visible:
			_settings.visible = false
		elif _menu.visible and game != null:
			_menu.visible = false
		elif not _menu.visible:
			_open_menu()
		get_viewport().set_input_as_handled()
		return
	if _menu.visible or game == null:
		return
	match key:
		KEY_LEFT, KEY_RIGHT:
			_move_focus(-1 if key == KEY_LEFT else 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if get_viewport().gui_get_focus_owner() is BaseButton:
				return # The focused button takes it.
			_activate_focus()
		KEY_H:
			if (_overlay.visible or _overlay_hidden) and game.phase != DeckhandGame.Phase.GAME_OVER:
				_toggle_overlay()
		_:
			var button := _button_for_key(key)
			if button == null:
				return
			button.pressed.emit()
	get_viewport().set_input_as_handled()

## The cards arrows move between: the open choice's cards, else the hand.
func _nav_cards() -> Array[CardView]:
	var cards: Array[CardView] = []
	if not _overlay.visible or _overlay_hidden:
		cards.assign(_hand_views)
		return cards
	for view in _card_views:
		if is_instance_valid(view) and view.interactive and view.is_visible_in_tree() and _overlay.is_ancestor_of(view):
			cards.append(view)
	cards.sort_custom(func(a: CardView, b: CardView) -> bool: return a.global_position.x < b.global_position.x)
	return cards

func _focused_card() -> CardView:
	for view in _nav_cards():
		if view == _hovered_hand or view.card_id == _kb_card:
			return view
	return null

func _move_focus(direction: int) -> void:
	var cards := _nav_cards()
	if cards.is_empty():
		return
	get_viewport().gui_release_focus()
	var index := cards.find(_focused_card())
	index = (0 if direction > 0 else cards.size() - 1) if index < 0 else clampi(index + direction, 0, cards.size() - 1)
	var view := cards[index]
	_using_keys = true
	_kb_index = index
	_sfx.play("card_flip", -20.0, 0.12)
	if _hand_views.has(view):
		_hovered_hand = view
		_kb_hand = true
		_layout_hand()
	else:
		_kb_card = view.card_id
		_show_overlay_focus()
	_on_card_hovered(view, true)

## After a refresh, while playing with the keyboard: if the focused card is
## gone (it was picked or built), focus the card now in its place.
func _keep_keyboard_focus() -> void:
	if not _using_keys:
		return
	# The new cards are laid out on the next frame.
	await get_tree().process_frame
	if not _using_keys or _focused_card() != null:
		return
	var cards := _nav_cards()
	if cards.is_empty():
		return
	var view := cards[clampi(_kb_index, 0, cards.size() - 1)]
	if _hand_views.has(view):
		_hovered_hand = view
		_kb_hand = true
		_layout_hand()
	else:
		_kb_card = view.card_id
		_show_overlay_focus()
	_on_card_hovered(view, true)

func _activate_focus() -> void:
	var view := _focused_card()
	if view != null and view.interactive:
		view.clicked.emit(view)
		return
	for button in _visible_buttons():
		if button.has_meta("primary") and not button.disabled:
			button.pressed.emit()
			return

## The buttons on screen: the open choice's first, then the action bar's.
func _visible_buttons() -> Array[Button]:
	var out: Array[Button] = []
	var roots: Array[Node] = []
	if _overlay.visible and not _overlay_hidden:
		roots.append(_overlay_body)
	roots.append(_buttons)
	for node in roots:
		for button in node.find_children("*", "Button", true, false):
			if button.is_visible_in_tree() and not button is OptionButton and not button.is_queued_for_deletion():
				out.append(button)
	return out

func _button_for_key(key: Key) -> Button:
	for button in _visible_buttons():
		if button.get_meta("key", KEY_NONE) == key and not button.disabled:
			return button
	return null

## Gives the buttons on screen their keys once this frame's rendering is done.
func _queue_key_badges() -> void:
	if not _badges_queued:
		_badges_queued = true
		_assign_keys.call_deferred()

func _assign_keys() -> void:
	_badges_queued = false
	# Keys with another meaning are never handed out.
	var taken := {KEY_H: true, KEY_SPACE: true}
	for button in _visible_buttons():
		var key := KEY_NONE
		var label := button.text.to_upper()
		if label.begins_with("HIDE") or label.begins_with("SHOW THE"):
			key = KEY_H
		else:
			for c in label:
				var k := OS.find_keycode_from_string(c)
				if c >= "A" and c <= "Z" and not taken.has(k):
					key = k
					break
			if key == KEY_NONE:
				for d in range(1, 10):
					if not taken.has(KEY_0 + d):
						key = KEY_0 + d
						break
		taken[key] = true
		button.set_meta("key", key)
		_badge(button, OS.get_keycode_string(key))

## A small key cap in the button's corner.
func _badge(button: Button, text: String) -> void:
	var badge: Label = button.get_node_or_null("KeyBadge")
	if badge == null:
		badge = Label.new()
		badge.name = "KeyBadge"
		badge.mouse_filter = MOUSE_FILTER_IGNORE
		badge.add_theme_font_size_override("font_size", _fs(11))
		badge.add_theme_color_override("font_color", Color(0.12, 0.08, 0.03))
		var cap := StyleBoxFlat.new()
		cap.bg_color = Color(1.0, 0.84, 0.5, 0.92)
		cap.set_corner_radius_all(4)
		cap.content_margin_left = 4
		cap.content_margin_right = 4
		badge.add_theme_stylebox_override("normal", cap)
		button.add_child(badge)
	badge.text = text
	# Pinned to the top-right corner, overhanging it a little.
	var cap_size := badge.get_combined_minimum_size()
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -cap_size.x * 0.6
	badge.offset_right = cap_size.x * 0.4
	badge.offset_top = -cap_size.y * 0.45
	badge.offset_bottom = cap_size.y * 0.55

## Lifts the overlay card chosen with the keyboard.
func _show_overlay_focus() -> void:
	for view in _card_views:
		if not is_instance_valid(view) or not _overlay.is_ancestor_of(view):
			continue
		var focused := view.card_id == _kb_card and view.interactive
		view.z_index = 1 if focused else 0
		view.shadow = 0.9 if focused else 0.0
		view.focused = focused
		view.lifted = focused
		view.create_tween().tween_property(view, "scale", Vector2.ONE * (1.07 if focused else 1.0), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# --- Zoom and log -----------------------------------------------------------

func _on_card_hovered(view: CardView, from_keyboard: bool = false) -> void:
	if not view.face_up or view.card_id <= 0:
		return
	# A hand card is already shown enlarged, and a big copy of a choice card
	# would hide the others: show only the rules.
	var in_hand := _hand_views.has(view)
	var in_choice := from_keyboard and _overlay.is_ancestor_of(view)
	_zoom_card.visible = not in_hand and not in_choice
	_zoom_card.set_card(view.card_id)
	_zoom_card.set_requirement(_banners_met(_seat, view.card_id) if CardDB.is_infamy(view.card_id) and view.face_up and game != null else [])
	_describe(view.card_id)
	_show_zoom()
	_zoom_panel.reset_size()
	# Shrink-wrap again once the text has been laid out.
	_zoom_panel.reset_size.call_deferred()
	var screen := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()
	if from_keyboard:
		# Beside the card, as if the pointer were on its edge.
		var rect := view.get_global_rect()
		mouse = Vector2(rect.end.x if rect.get_center().x < get_viewport_rect().size.x / 2.0 else rect.position.x, rect.get_center().y)
	var panel_size := _zoom_panel.get_combined_minimum_size()
	var x := mouse.x + 40.0 if mouse.x < screen.x / 2.0 else mouse.x - 40.0 - panel_size.x
	var y := clampf(mouse.y - panel_size.y / 2.0, 8.0, screen.y - panel_size.y - 8.0)
	if in_hand:
		var center := (view.get_global_transform() * (view.size / 2.0)).x
		var half := HAND_CARD.x * HAND_FOCUS_SCALE / 2.0 + 20.0
		x = center + half if center < screen.x / 2.0 else center - half - panel_size.x
		# Above the fan, so the neighbouring cards stay visible.
		y = screen.y - panel_size.y - HAND_VISIBLE - 40.0
	if in_choice:
		# Under the card, over the crew.
		var rect := view.get_global_rect()
		x = clampf(rect.get_center().x - panel_size.x / 2.0, 8.0, screen.x - panel_size.x - 8.0)
		y = minf(rect.end.y + 40.0, screen.y - panel_size.y - 8.0)
	_zoom_panel.position = Vector2(x, y)

## Fades the card zoom in, carrying on from wherever a fade-out had got to.
func _show_zoom() -> void:
	if _zoom_panel.has_meta("fade"):
		(_zoom_panel.get_meta("fade") as Tween).kill()
	if not _zoom_panel.visible:
		_zoom_panel.modulate.a = 0.0
		_zoom_panel.visible = true
	var fade := _zoom_panel.create_tween()
	fade.tween_property(_zoom_panel, "modulate:a", 1.0, 0.1)
	_zoom_panel.set_meta("fade", fade)

func _hide_zoom(at_once: bool = false) -> void:
	if _zoom_panel.has_meta("fade"):
		(_zoom_panel.get_meta("fade") as Tween).kill()
	if at_once or not _zoom_panel.visible:
		_zoom_panel.visible = false
		return
	var fade := _zoom_panel.create_tween()
	fade.tween_property(_zoom_panel, "modulate:a", 0.0, 0.1)
	fade.tween_callback(func() -> void: _zoom_panel.visible = false)
	_zoom_panel.set_meta("fade", fade)

func _on_card_unhovered(view: CardView) -> void:
	if _zoom_card.card_id == view.card_id:
		_hide_zoom()

## Short wording of the effects, for the card tooltip.
const EFFECT_SHORT := {
	"draw-1": "Draw 1 card.",
	"draw-2": "Draw 2 cards.",
	"3-choices": "Draw 3, keep 1.",
	"telescope": "Look at a face-down Row card and the top Infamy card; you may swap them.",
	"compass": "Once per draft: draw 1 extra draft card, then discard 1.",
	"hook": "Steal a random card from a rival; give one back unless you have 3 Hooks.",
	"battle": "On your next build, the best built card (+1 per Battle) draws 1.",
}

## Fills the card tooltip with `id`'s rules: a title line, then sections
## of label / icons rows, separated by thin lines.
func _describe(id: int) -> void:
	_clear(_zoom_info)
	var card := CardDB.get_card(id)
	var head := "[b]%s[/b]" % card.title
	if card.vp > 0:
		head += "   [color=#8a3b12][b]%d VP[/b][/color]" % card.vp
	_info_text(head, 17)

	var rows: Array = []
	if card.kind == "infamy":
		var need := []
		for b: String in card.cost:
			need.append(_banner(b, 20))
		rows.append(["Claim with", _icons(need)])
	else:
		var cost := []
		for token: String in card.cost:
			cost.append(_res(token, 18))
		rows.append(["Cost", _icons(cost)])
		if not card.production.is_empty():
			var prod := []
			for slot: Array in card.production:
				prod.append(_slot_icons(slot, 18))
			rows.append(["Produces", _icons(prod)])
		if not card.banners.is_empty():
			var banners := []
			for b: String in card.banners:
				banners.append(_banner(b, 18))
			rows.append(["Banners", _icons(banners)])
	_info_rows(rows)

	# Effects: an icon column, then the text (wrapping under itself).
	var effects: Array = []
	if card.multiplier != null:
		effects.append([_banner(card.multiplier.banner, 18), "[color=#8a3b12][b]+%d VP[/b][/color] per raised banner at the end" % card.multiplier.vp])
	if card.tentacles > 0:
		effects.append([_img("fx-tentacle", 16), "Wins ties."])
	for effect: String in card.effects:
		effects.append([_img(EFFECT_ICONS[effect], 16), EFFECT_SHORT[effect]])
	if card.trigger != null:
		var on: String = _img("fx-tentacle", 16) if card.trigger.on == "tentacle" else _banner(card.trigger.on, 18)
		effects.append([on, "Each time you add one: %s" % EFFECT_SHORT[card.trigger.effect]])
	if not effects.is_empty():
		_info_line()
		for row: Array in effects:
			_info_effect(row[0], row[1])

	if game != null and card.kind == "supply" and not game.players[_seat].crew.has(id):
		# What discarding it pays: a coin, or (revealed) one of its resources.
		var options := [_res("cs", 16), _res("c", 16)]
		for token in CardDB.production_tokens(id):
			if not token in ["cs", "c"]:
				options.append(_res(token, 16))
		_info_line()
		_info_rows([["Discard", "[color=#7a6248]/[/color]".join(options)]], 0.75)

## Icons with even spacing between them.
static func _icons(parts: Array) -> String:
	return " ".join(parts)

func _info_text(bbcode: String, font_size: int) -> RichTextLabel:
	var label := _rich(font_size)
	label.fit_content = true
	# Its width up front, so its height is measured with the right wrapping.
	label.custom_minimum_size.x = _zoom_info.custom_minimum_size.x
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_color_override("default_color", INK)
	label.text = bbcode
	_zoom_info.add_child(label)
	return label

## Rows of [label, icons]: labels small and muted in a column of their own.
func _info_rows(rows: Array, alpha: float = 1.0) -> void:
	if rows.is_empty():
		return
	var text := "[table=2]"
	for row: Array in rows:
		text += "[cell padding=0,2,12,2][color=#7a6248][font_size=%d]%s[/font_size][/color][/cell][cell padding=0,2,0,2]%s[/cell]" % [_fs(13), row[0], row[1]]
	_info_text(text + "[/table]", 15).modulate.a = alpha

## One effect: its icon, then its text wrapping in a block of its own.
func _info_effect(icon: String, text: String) -> void:
	const ICON_WIDTH := 30.0
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	_zoom_info.add_child(row)
	var icon_label := _info_text(icon, 15)
	icon_label.custom_minimum_size.x = ICON_WIDTH
	icon_label.size_flags_horizontal = SIZE_SHRINK_BEGIN
	icon_label.reparent(row)
	var body := _info_text(text, 15)
	body.custom_minimum_size.x = _zoom_info.custom_minimum_size.x - ICON_WIDTH - 6
	body.reparent(row)

func _info_line() -> void:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color(0.45, 0.3, 0.15, 0.3)
	style.thickness = 1
	line.add_theme_stylebox_override("separator", style)
	line.add_theme_constant_override("separation", 4)
	line.mouse_filter = MOUSE_FILTER_IGNORE
	_zoom_info.add_child(line)

func _append_log(text: String) -> void:
	var colored := text
	for p in range(game.player_count()):
		colored = colored.replace(game.players[p].name, _who(p))
	if text.begins_with("—"):
		colored = "\n[b][color=#ffd36b]%s[/color][/b]" % text
	_log.append_text(colored + "\n")

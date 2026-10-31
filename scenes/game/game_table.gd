extends Control
## The single-player table: renders a DeckhandGame and turns clicks into
## decisions for seat 0. Every other seat is played by DeckhandBot.

const HUMAN := 0
const BOT_DELAY := 0.45
const ICONS := "res://assets/icons/"
const FONT_REGULAR := "res://scenes/shared/fonts/signika/Signika-Regular.ttf"
const FONT_BOLD := "res://scenes/shared/fonts/signika/Signika-SemiBold.ttf"

const HAND_CARD := Vector2(150, 204)
const ROW_CARD := Vector2(108, 147)
const PILE_CARD := Vector2(78, 106)
const CREW_CARD := Vector2(88, 120)
const OPP_CARD := Vector2(50, 68)
const OVERLAY_CARD := Vector2(180, 245)
const ZOOM_CARD := Vector2(340, 462)
## Global size multipliers for text and inline icons.
const TEXT_SCALE := 1.15
const ICON_SCALE := 1.25

const WOOD := "res://assets/ui/wood.jpg"
const ROUNDED_SHADER := preload("res://scenes/game/rounded_panel.gdshader")
const PARCHMENT := "res://assets/ui/parchment.jpg"
const LOGO := "res://assets/new-logo.png"
const MENU_ART := "res://assets/art/kraken.jpg"
const VICTORY_ART := "res://assets/art/armada.jpg"
const DEFEAT_ART := "res://assets/art/plank.jpg"

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

var _round_label: Label
var _phase_label: Label
var _row_box: HBoxContainer
var _piles_box: HBoxContainer
var _opponents_box: VBoxContainer
var _crew_flow: HFlowContainer
var _crew_stats: RichTextLabel
var _hand_area: Control
var _action_text: RichTextLabel
var _buttons: HBoxContainer
var _log: RichTextLabel
var _overlay: Control
var _overlay_body: VBoxContainer
var _menu: Control
var _zoom_layer: CanvasLayer
var _zoom_panel: PanelContainer
var _zoom_card: CardView
var _zoom_text: RichTextLabel
var _sfx: Sfx

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
var _shown := {} # player -> {vp, banners} last displayed, to animate gains

func _ready() -> void:
	CardDB.ensure_loaded()
	_sfx = Sfx.new()
	add_child(_sfx)
	_build_ui()
	_motion = CardMotion.new()
	_motion.layer = 5
	add_child(_motion)
	_open_menu()
	var splash := SplashScreen.new()
	splash.finished.connect(func() -> void: _sfx.play("bell", -6.0))
	add_child(splash)

# --- Game lifecycle ---------------------------------------------------------

func _new_game() -> void:
	_menu.visible = false
	var seats: Array = [{"name": "Captain", "bot": false}]
	if settings.solo:
		seats.append({"name": "The Phantom Crew", "bot": true, "virtual": true})
	else:
		var names := BOT_NAMES.duplicate()
		names.shuffle()
		for i in range(settings.opponents):
			seats.append({"name": names[i], "bot": true})
	game = DeckhandGame.new()
	game.setup(seats, -1, {"solo_variant": settings.solo, "beginner_draft": settings.beginner})
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
	game.start()

func _process(delta: float) -> void:
	if game == null or game.phase == DeckhandGame.Phase.GAME_OVER:
		return
	var bots: Array = game.pending.keys().filter(func(p: int) -> bool: return p != HUMAN)
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
	var error := game.submit(p, DeckhandBot.decide(game, p))
	if not error.is_empty():
		push_error("Bot %d %s rejected: %s" % [p, decision.type, error])
		if decision.type == "build":
			game.submit(p, {"pass": true})

func _submit(action: Dictionary) -> void:
	var error := game.submit(HUMAN, action)
	if not error.is_empty():
		_flash(error)

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
	add_child(SplashScreen.make_vignette(0.7))

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
	side.custom_minimum_size.x = 340
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
	board.add_child(row_panel)
	var row_v := VBoxContainer.new()
	row_panel.add_child(row_v)
	row_v.add_child(_label("Infamy Row — claim a card when your raised banners match its requirement", 14, MUTED))
	_row_box = HBoxContainer.new()
	_row_box.add_theme_constant_override("separation", 8)
	row_v.add_child(_row_box)
	var piles_panel := _panel()
	piles_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	board.add_child(piles_panel)
	var piles_v := VBoxContainer.new()
	piles_panel.add_child(piles_v)
	piles_v.add_child(_label("Decks", 14, MUTED))
	_piles_box = HBoxContainer.new()
	_piles_box.add_theme_constant_override("separation", 10)
	piles_v.add_child(_piles_box)

	# Your crew
	var crew_panel := _panel()
	crew_panel.size_flags_vertical = SIZE_EXPAND_FILL
	main.add_child(crew_panel)
	var crew_v := VBoxContainer.new()
	crew_panel.add_child(crew_v)
	_crew_stats = _rich(16)
	_crew_stats.fit_content = true
	_crew_stats.size_flags_vertical = SIZE_SHRINK_BEGIN
	crew_v.add_child(_crew_stats)
	var crew_scroll := ScrollContainer.new()
	crew_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	crew_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	crew_v.add_child(crew_scroll)
	_crew_flow = HFlowContainer.new()
	_crew_flow.size_flags_horizontal = SIZE_EXPAND_FILL
	_crew_flow.add_theme_constant_override("h_separation", 6)
	_crew_flow.add_theme_constant_override("v_separation", 6)
	crew_scroll.add_child(_crew_flow)

	# Action bar
	var action_panel := _wood_panel(Color(0.42, 0.3, 0.2))
	main.add_child(action_panel)
	var action_h := HBoxContainer.new()
	action_h.add_theme_constant_override("separation", 12)
	action_panel.add_child(action_h)
	_action_text = _rich(17)
	_action_text.fit_content = true
	_action_text.size_flags_horizontal = SIZE_EXPAND_FILL
	_action_text.custom_minimum_size.y = 52
	action_h.add_child(_action_text)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	action_h.add_child(_buttons)

	# Hand
	_hand_area = Control.new()
	_hand_area.custom_minimum_size.y = HAND_CARD.y + 40
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
	log_panel.custom_minimum_size.y = 260
	side.add_child(log_panel)
	_log = _rich(14)
	_log.scroll_following = true
	log_panel.add_child(_log)

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
	center.offset_bottom = -(HAND_CARD.y + 120)
	_overlay.add_child(center)
	var panel := _wood_panel()
	panel.mouse_filter = MOUSE_FILTER_STOP
	center.add_child(panel)
	_overlay_body = VBoxContainer.new()
	_overlay_body.add_theme_constant_override("separation", 12)
	panel.add_child(_overlay_body)

func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_menu)
	var art := _cover(MENU_ART)
	art.modulate = Color(0.55, 0.55, 0.6)
	_menu.add_child(art)
	_menu.add_child(SplashScreen.make_vignette())
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
	column.add_child(logo)
	var panel := _wood_panel()
	panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	column.add_child(panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 480
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var intro := _label("Recruit a crew of rogues over five rounds. Raise your banners, claim Infamy, and score the most Victory Points.", 16, Color(1, 0.92, 0.8))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(intro)

	var opp_row := HBoxContainer.new()
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
	var sound := CheckBox.new()
	sound.text = "Sound effects"
	sound.button_pressed = true
	sound.toggled.connect(func(on: bool) -> void: _sfx.enabled = on)
	v.add_child(sound)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.add_child(_button("Exit", func() -> void: get_tree().quit()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var resume := _button("Resume", func() -> void: _menu.visible = false)
	resume.name = "Resume"
	buttons.add_child(resume)
	buttons.add_child(_button("New game", _new_game))
	v.add_child(buttons)
	_menu.set_meta("opponents", opp)
	_menu.set_meta("resume", resume)

func _open_menu() -> void:
	(_menu.get_meta("opponents") as OptionButton).select(settings.opponents - 1)
	(_menu.get_meta("resume") as Button).visible = game != null
	_menu.visible = true

func _build_zoom() -> void:
	_zoom_layer = CanvasLayer.new()
	_zoom_layer.layer = 10
	add_child(_zoom_layer)
	_zoom_panel = PanelContainer.new()
	var parchment := StyleBoxTexture.new()
	parchment.texture = load(PARCHMENT)
	parchment.set_content_margin_all(16)
	_zoom_panel.add_theme_stylebox_override("panel", parchment)
	_zoom_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_zoom_panel.visible = false
	_zoom_layer.add_child(_zoom_panel)
	var v := VBoxContainer.new()
	v.mouse_filter = MOUSE_FILTER_IGNORE
	_zoom_panel.add_child(v)
	_zoom_card = CardView.make(1, ZOOM_CARD)
	_zoom_card.interactive = false
	_zoom_card.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(_zoom_card)
	_zoom_text = _rich(15)
	_zoom_text.fit_content = true
	_zoom_text.custom_minimum_size.x = ZOOM_CARD.x
	_zoom_text.mouse_filter = MOUSE_FILTER_IGNORE
	_zoom_text.add_theme_color_override("default_color", INK)
	v.add_child(_zoom_text)

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
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(1, 0.93, 0.8))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5))
	return t

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
func _wood_panel(tint: Color = Color(0.5, 0.36, 0.24)) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxTexture.new()
	style.texture = load(WOOD)
	style.modulate_color = tint
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
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
	var decision: Variant = game.pending.get(HUMAN)
	if not is_same(decision, _decision):
		_decision = decision
		_reset_input()
	# Hovered cards may be rebuilt below without an exit event.
	_zoom_panel.visible = false
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

func _reset_input() -> void:
	_build_card = -1
	_pay.clear()
	_pay_windfall = false
	_windfall_dest = DeckhandGame.WINDFALL_DECK
	_selected.clear()
	_selected_windfall = false

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
		_row_box.add_child(v)
		var title := _label("Round %d" % (i + 1), 13, GOLD if i + 1 == game.round_index else MUTED)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		if slot.cards.is_empty():
			var empty := Panel.new()
			empty.custom_minimum_size = ROW_CARD
			empty.modulate = Color(1, 1, 1, 0.15)
			v.add_child(empty)
			continue
		if not slot.revealed:
			var back := _card(slot.cards[-1], ROW_CARD, false)
			if slot.cards.size() > 1:
				back.set_caption("×%d" % slot.cards.size())
			v.add_child(back)
			continue
		var stack := HBoxContainer.new()
		stack.add_theme_constant_override("separation", int(-ROW_CARD.x * 0.55) if slot.cards.size() > 1 else 0)
		v.add_child(stack)
		for id: int in slot.cards:
			var view := _card(id, ROW_CARD)
			if game.can_claim(HUMAN, id):
				view.mark = CardView.Mark.HIGHLIGHT
			stack.add_child(view)
		var need := ""
		for id: int in slot.cards:
			need += _requirement_progress(HUMAN, id) + " "
		var req := _rich(13)
		req.fit_content = true
		req.custom_minimum_size.x = ROW_CARD.x
		req.text = "[center]%s[/center]" % need
		v.add_child(req)

func _requirement_progress(p: int, infamy_id: int) -> String:
	var have := game.raised_banners(p)
	var need := {}
	for b: String in CardDB.get_card(infamy_id).cost:
		need[b] = need.get(b, 0) + 1
	var parts: Array[String] = []
	for b in need:
		var color := "#8fe388" if have[b] >= need[b] else "#e8a0a0"
		parts.append("%s[color=%s]%d/%d[/color]" % [_banner(b, 16), color, mini(have[b], need[b]), need[b]])
	return " ".join(parts)

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
		var view := CardView.make(id, PILE_CARD, false)
		view.interactive = false
		_pile_views[spec[0].to_lower()] = view
		view.set_caption(str(spec[1]))
		if spec[1] == 0:
			view.modulate.a = 0.25
		v.add_child(view)
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
			parts.append("%s%s" % [_banner(b, icon_size + 2), count])
	var banner_text := " ".join(parts) if not parts.is_empty() else "[color=#8a96a6]no banners[/color]"
	var prod: Array[String] = []
	for slot: Array in game.crew_production_slots(p):
		var alt: Array[String] = []
		for token: String in slot:
			alt.append(_res(token, icon_size))
		prod.append("|".join(alt))
	var prod_text := " ".join(prod) if not prod.is_empty() else "[color=#8a96a6]none[/color]"
	var extras := "%s%d" % [_img("fx-tentacle", icon_size), game.tentacles(p)]
	for key in ["battles", "hooks", "compasses"]:
		var n := game.symbol_count(p, key)
		if n > 0:
			extras += "  %s%d" % [_img({"battles": "fx-battle", "hooks": "fx-hook", "compasses": "fx-compass"}[key], icon_size), n]
	if game.players[p].pending_battles > 0:
		extras += "  [color=#ffb070]Battle pending ×%d[/color]" % game.players[p].pending_battles
	return "Banners %s     Produces %s     %s" % [banner_text, prod_text, extras]

func _render_opponents() -> void:
	_clear(_opponents_box)
	for p in range(1, game.player_count()):
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
		elif game.pending.has(p):
			status = "  [color=#8a96a6](thinking…)[/color]"
		var template := "[b]%s[/b]%s\n[color=#ffd36b]{vp} VP[/color]   ·   hand %d   ·   %s" % [
			_who(p), status, game.hand_size(p),
			"windfall ✓" if pl.windfall >= 0 else "no windfall"]
		v.add_child(head)
		var fresh := _show_gains(p, head, template, Vector2(0.0, head.get_theme_font("normal_font").get_height(_fs(16))), 0.75)
		var summary := _rich(13)
		summary.fit_content = true
		summary.text = _player_summary(p, 15, fresh).replace("     ", "\n")
		v.add_child(summary)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 3)
		flow.add_theme_constant_override("v_separation", 3)
		v.add_child(flow)
		for id in pl.crew:
			flow.add_child(_card(id, OPP_CARD))

func _render_crew() -> void:
	var pl: Dictionary = game.players[HUMAN]
	var prefix := "Your crew   "
	var offset := Vector2(load(FONT_BOLD).get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(16)).x, 0.0)
	var fresh := _show_gains(HUMAN, _crew_stats, "[b]%s[/b][color=#ffd36b]{vp} VP[/color]     {summary}" % prefix, offset)
	_crew_stats.text = _crew_stats.text.replace("{summary}", _player_summary(HUMAN, 18, fresh))
	_clear(_crew_flow)
	for id in pl.crew:
		var view := _card(id, CREW_CARD)
		view.interactive = false
		_crew_flow.add_child(view)
	if pl.crew.is_empty():
		_crew_flow.add_child(_label("Built cards join your crew here. Their production pays for later builds.", 15, MUTED))

## Hand order: windfall first, then hand, then draft picks.
func _hand_entries() -> Array:
	var pl: Dictionary = game.players[HUMAN]
	var entries: Array = []
	if pl.windfall >= 0:
		entries.append({"id": pl.windfall, "windfall": true})
	for id in pl.hand:
		entries.append({"id": id})
	for id in pl.picks:
		entries.append({"id": id, "picked": true})
	return entries

func _render_hand() -> void:
	_clear(_hand_area)
	_hand_views.clear()
	_hovered_hand = null
	var decision: Variant = game.pending.get(HUMAN)
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
		_hand_area.add_child(view)
		_hand_views.append(view)
	_layout_hand()

func _layout_hand() -> void:
	var n := _hand_views.size()
	if n == 0:
		return
	var width := _hand_area.size.x
	var step := minf(HAND_CARD.x + 8.0, (width - HAND_CARD.x) / maxf(n - 1, 1))
	var total := step * (n - 1) + HAND_CARD.x
	var x0 := (width - total) / 2.0
	for i in range(n):
		var view := _hand_views[i]
		var t := 0.0 if n == 1 else float(i) / float(n - 1) * 2.0 - 1.0
		var lift := 0.0
		match view.mark:
			CardView.Mark.SELECTED:
				lift = 34.0
			CardView.Mark.PAYMENT:
				lift = 20.0
		var hovered := view == _hovered_hand
		if hovered:
			lift = maxf(lift, 26.0)
		view.z_index = i + (100 if hovered else 0)
		var target := Vector2(x0 + i * step, 26.0 + absf(t) * 12.0 - lift)
		var angle := 0.0 if hovered else t * minf(n, 9) * 0.9
		var scale_to := Vector2.ONE * (1.06 if hovered else 1.0)
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

func _render_action() -> void:
	var decision: Variant = game.pending.get(HUMAN)
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
			_action_text.text = "[b]Make your choice above.[/b]"
			_set_buttons([])

func _render_build_action() -> void:
	if _build_card < 0:
		_action_text.text = "[b]Build:[/b] click a card in your hand to build it, or pass for the rest of the round."
		_set_buttons([["Pass", func() -> void: _submit({"pass": true})]])
		return
	var card := CardDB.get_card(_build_card)
	var cost: Array = card.cost
	var crew_missing := Payment.missing_after_crew(cost, game.crew_production_slots(HUMAN))
	var result := game.check_payment(HUMAN, _build_card, _pay, _pay_windfall)
	var cost_icons := ""
	for token: String in cost:
		cost_icons += _res(token, 22)
	var text := "[b]%s[/b]   cost %s" % [card.title, cost_icons]
	if crew_missing.is_empty():
		text += "   [color=#8fe388]fully paid by your crew[/color]"
	else:
		var need := ""
		for token in crew_missing:
			need += _res(token, 20)
		text += "   after crew: %s" % need
		if result.ok:
			text += "   [color=#8fe388]✓ payment covered[/color]"
		else:
			var missing := ""
			for token: String in result.missing:
				missing += _res(token, 20)
			text += "   [color=#e8a0a0]still missing %s[/color]" % missing
		text += "\n[color=#8a96a6]Click hand cards to discard them: 1 card = a coin or one resource it produces, 2 cards = any resource, Windfall = 2 coins.[/color]"
	_action_text.text = text
	var specs: Array = [
		["Cancel", func() -> void:
			_reset_input()
			_refresh()],
	]
	if not crew_missing.is_empty():
		specs.append(["Auto-pay", _auto_pay])
	if _pay_windfall:
		var dest := OptionButton.new()
		dest.add_item("Windfall → Infamy deck", DeckhandGame.WINDFALL_DECK)
		for slot in game.unrevealed_slots():
			dest.add_item("Windfall → Row slot %d" % (slot + 1), slot)
		dest.select(maxi(dest.get_item_index(_windfall_dest), 0))
		dest.item_selected.connect(func(i: int) -> void: _windfall_dest = dest.get_item_id(i))
		_set_buttons(specs)
		_buttons.add_child(dest)
		_buttons.move_child(dest, 0)
	else:
		_set_buttons(specs)
	_buttons.add_child(_button("Build", _confirm_build, result.ok))
	_buttons.add_child(_button("Pass", func() -> void: _submit({"pass": true})))

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
	row.add_theme_constant_override("separation", 10)
	for spec in specs:
		row.add_child(_button(spec[0], spec[1], spec[2] if spec.size() > 2 else true))
	_overlay_body.add_child(row)

func _overlay_card(parent: Control, id: int, on_click: Callable, face_up: bool = true) -> CardView:
	var view := _card(id, OVERLAY_CARD, face_up)
	view.clicked.connect(func(_v: CardView) -> void:
		_sfx.play("card_flip", -4.0)
		on_click.call())
	parent.add_child(view)
	return view

func _render_overlay() -> void:
	_overlay.visible = false
	if game.phase == DeckhandGame.Phase.GAME_OVER:
		_render_game_over()
		return
	var decision: Variant = game.pending.get(HUMAN)
	if decision == null:
		return
	match decision.type:
		"mulligan":
			var cards := _show_overlay("First draft", "You may keep this draft hand, or discard it all and draw a new one (once, round 1 only).")
			for id: int in game.players[HUMAN].draft_hand:
				_card_into(cards, id)
			_overlay_buttons([["Keep", func() -> void: _submit({"redraw": false})], ["Redraw all", func() -> void: _submit({"redraw": true})]])
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

func _card_into(parent: Control, id: int) -> CardView:
	var view := _card(id, OVERLAY_CARD)
	view.interactive = false
	parent.add_child(view)
	return view

func _render_draft_overlay(decision: Dictionary) -> void:
	var pl: Dictionary = game.players[HUMAN]
	var direction := "to your left ↻" if game.wind() == 1 else "to your right ↺"
	var sub := "Pick one card to keep; the rest pass %s. Picked so far: %d." % [direction, pl.picks.size()]
	if decision.must_discard:
		sub = "[color=#ffd36b]Compass:[/color] click the card to keep, then a card to discard."
	var cards := _show_overlay("Draft — round %d" % game.round_index, sub)
	var pick: int = _selected[0] if _selected.size() > 0 else -1
	var drop: int = _selected[1] if _selected.size() > 1 else -1
	for id: int in pl.draft_hand:
		var view := _overlay_card(cards, id, func() -> void: _on_draft_card(id, decision))
		if id == pick:
			view.mark = CardView.Mark.SELECTED
			view.set_caption("Keep")
		elif id == drop:
			view.mark = CardView.Mark.PAYMENT
			view.set_caption("Discard")
	var specs: Array = []
	if decision.can_use_compass:
		specs.append(["Use Compass (%d left)" % game.compasses_available(HUMAN), func() -> void: _submit({"use_compass": true})])
	if decision.must_discard:
		specs.append(["Confirm", func() -> void: _submit({"pick": pick, "discard": drop}), pick >= 0 and drop >= 0])
	_overlay_buttons(specs)

func _on_draft_card(id: int, decision: Dictionary) -> void:
	if not decision.must_discard:
		_submit({"pick": id})
		return
	if _selected.is_empty() or _selected[0] == id:
		_selected = [id] if _selected.is_empty() else []
	elif _selected.size() == 1:
		_selected.append(id)
	else:
		_selected[1] = id
	_render_overlay()

func _render_game_over() -> void:
	var lines := ""
	var winners := game.winners()
	for entry: Dictionary in game.final_scores:
		var p: int = entry.player
		var crown := "   [color=#ffd36b]★ winner[/color]" if winners.has(p) else ""
		lines += "%s   [color=#ffd36b]%d VP[/color]   %s%d%s\n" % [_who(p), entry.score, _img("fx-tentacle", 16), entry.tentacles, crown]
	var mine := game.score(HUMAN)
	lines += "\nYour rank: [b]%s[/b]" % DeckhandGame.rank_for(mine)
	var headline := "Victory!" if winners.has(HUMAN) else "Defeat"
	if winners.size() > 1 and winners.has(HUMAN):
		headline = "Shared victory"
	_show_overlay(headline, lines)
	var art := _cover(VICTORY_ART if winners.has(HUMAN) else DEFEAT_ART)
	art.set_anchors_preset(PRESET_TOP_LEFT)
	art.custom_minimum_size = Vector2(640, 260)
	_overlay_body.add_child(art)
	_overlay_body.move_child(art, 0)
	_overlay_buttons([["View the table", func() -> void: _overlay.visible = false], ["New game", _open_menu]])

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
			label.text = label.text.replace(label.get_meta("vp_text", ""), "%d VP" % roundi(value))
			label.set_meta("vp_text", "%d VP" % roundi(value)),
			float(before.vp), float(vp), 0.7)
		label.text = template.replace("{vp}", str(before.vp))
		label.set_meta("vp_text", "%d VP" % before.vp)
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
		if is_instance_valid(view) and view.is_inside_tree() and view.is_visible_in_tree() and not poses.has(view.card_id):
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
	if _crew_flow.is_ancestor_of(view):
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
	for id: int in poses:
		if not present.has(id):
			draft_passed = draft_passed or (poses[id].get("zone") == "overlay" and game.phase == DeckhandGame.Phase.DRAFT)
			_animate_vanished(id, poses[id], anchors)
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

func _animate_vanished(id: int, from: Dictionary, anchors: Dictionary) -> void:
	var to := from.duplicate()
	var holder := -1
	for p in range(1, game.player_count()):
		if game.players[p].hand.has(id) or game.players[p].draft_hand.has(id):
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
	_motion.fly(id, from, to, {"fade_out": true})

# --- Input ------------------------------------------------------------------

## Game moments -> sounds. Opponents' actions play a little quieter.
func _on_game_event(kind: String, info: Dictionary) -> void:
	var p: int = info.get("player", HUMAN)
	var volume := 0.0 if p == HUMAN else -6.0
	match kind:
		"round_start":
			_sfx.play("bell", -3.0)
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
			_sfx.play("hook", 0.0 if HUMAN in [p, info.target] else -6.0)
		"battle_announce":
			_sfx.play("battle", volume - 10.0)
		"battle":
			_sfx.play("battle")
		"claim":
			_sfx.play("claim", volume)
		"lost":
			_sfx.play("reveal", -8.0)
		"game_end":
			_sfx.play("victory" if game.winners().has(HUMAN) else "defeat")

func _on_hand_clicked(view: CardView) -> void:
	var decision: Variant = game.pending.get(HUMAN)
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
				if game.players[HUMAN].hand.has(id):
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
			elif game.players[HUMAN].hand.has(id):
				_selected.append(id)
		"hook_give":
			if not is_windfall and game.players[HUMAN].hand.has(id):
				_submit({"card": id})
			return
		_:
			return
	_render_hand()
	_render_action()

func _auto_pay() -> void:
	var others: Array = game.players[HUMAN].hand.filter(func(id: int) -> bool: return id != _build_card)
	var keep := func(id: int) -> float: return DeckhandBot.keep_value(game, HUMAN, id)
	var windfall_value := INF if game.players[HUMAN].windfall < 0 else 1.0
	var plan := Payment.plan(CardDB.get_card(_build_card).cost, game.crew_production_slots(HUMAN), others, keep, windfall_value)
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

# --- Zoom and log -----------------------------------------------------------

func _on_card_hovered(view: CardView) -> void:
	if not view.face_up or view.card_id <= 0:
		return
	_zoom_card.set_card(view.card_id)
	_zoom_text.text = _describe(view.card_id)
	_zoom_panel.visible = true
	_zoom_panel.reset_size()
	var screen := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()
	var panel_size := _zoom_panel.get_combined_minimum_size()
	var x := mouse.x + 40.0 if mouse.x < screen.x / 2.0 else mouse.x - 40.0 - panel_size.x
	var y := clampf(mouse.y - panel_size.y / 2.0, 8.0, screen.y - panel_size.y - 8.0)
	_zoom_panel.position = Vector2(x, y)

func _on_card_unhovered(view: CardView) -> void:
	if _zoom_card.card_id == view.card_id:
		_zoom_panel.visible = false

func _describe(id: int) -> String:
	var card := CardDB.get_card(id)
	var lines: Array[String] = ["[b]%s[/b]" % card.title]
	if card.kind == "infamy":
		var req := ""
		for b: String in card.cost:
			req += _banner(b, 20)
		lines.append("Infamy — claim with raised banners: %s" % req)
	else:
		var cost := ""
		for token: String in card.cost:
			cost += _res(token)
		lines.append("Cost: %s" % cost)
		if not card.production.is_empty():
			var prod: Array[String] = []
			for slot: Array in card.production:
				var alt: Array[String] = []
				for token: String in slot:
					alt.append(_res(token))
				prod.append(" | ".join(alt))
			lines.append("Produces: %s" % "  ".join(prod))
		if not card.banners.is_empty():
			var banners := ""
			for b: String in card.banners:
				banners += _banner(b)
			lines.append("Raised banners: %s" % banners)
	if card.vp > 0:
		lines.append("[color=#8a3b12]%d VP[/color]" % card.vp)
	if card.multiplier != null:
		lines.append("[color=#8a3b12]%d VP per raised %s[/color] banner (end of game)" % [card.multiplier.vp, _banner(card.multiplier.banner)])
	if card.tentacles > 0:
		lines.append("%s Tentacle: wins ties." % _img("fx-tentacle"))
	for effect: String in card.effects:
		lines.append("%s %s" % [_img(EFFECT_ICONS[effect]), EFFECT_TEXT[effect]])
	if card.trigger != null:
		var on: String = _img("fx-tentacle") if card.trigger.on == "tentacle" else _banner(card.trigger.on)
		lines.append("Each time you add %s to your crew: %s" % [on, EFFECT_TEXT[card.trigger.effect]])
	if game != null and card.kind == "supply" and game.players[HUMAN].crew.has(id) == false:
		lines.append("[color=#7a6248]Discard value: a coin%s[/color]" % (", or reveal for one of its resources" if not card.production.is_empty() else ""))
	return "\n".join(lines)

func _append_log(text: String) -> void:
	var colored := text
	for p in range(game.player_count()):
		colored = colored.replace(game.players[p].name, _who(p))
	if text.begins_with("—"):
		colored = "\n[b][color=#ffd36b]%s[/color][/b]" % text
	_log.append_text(colored + "\n")

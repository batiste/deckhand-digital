extends Control
## The single-player table: renders a DeckhandGame and turns clicks into
## decisions for seat 0. Every other seat is played by DeckhandBot.

const BOT_DELAY := 0.45
## Online: how long a player may be away before the host's bots play for them.
const ABSENT_GRACE := 15.0
const ICONS := "res://assets/icons/"
const FONT_REGULAR := "res://scenes/shared/fonts/signika/Signika-Regular.ttf"
const FONT_BOLD := "res://scenes/shared/fonts/signika/Signika-SemiBold.ttf"
## Big moments only (bands, what is shown mid-table): as the printed rules' titles.
const FONT_TITLE := "res://scenes/shared/fonts/imfell/IMFellEnglish-Regular.ttf"
# The text font lacks symbols like ✓ ★ ● ↻; desktop falls back to system fonts, the web export has none.
const FONT_SYMBOLS := "res://scenes/shared/fonts/dejavu/DejaVuSans-Symbols.ttf"

const HAND_CARD := Vector2(172, 235)
const ROW_CARD := Vector2(126, 171)
const PILE_CARD := Vector2(90, 122)
## Offset of each card edge drawn under a deck, for its thickness.
const PILE_STEP := Vector2(1.0, 2.0)
const CREW_CARD := Vector2(128, 174)
## Height of a crew card left showing (banners, VP, title) when stacked.
const CREW_PEEK := 49.0
## Crew groups, in order, with their headings.
const CREW_GROUPS := {"basic": "Basic", "advanced": "Advanced", "support": "Support", "infamy": "Infamy"}
const CREW_MAX_COLUMNS := 6
const OPP_CARD := Vector2(50, 68)
const OPP_COLUMN_WIDTH := 340.0
const OVERLAY_CARD := Vector2(181, 247) # leaves even gaps around the choice
const OVERLAY_CARD_SMALL := Vector2(135, 184)
const LEDGER_WIDTH := 216.0
## How much of the hand shows above the bottom edge; hovered cards rise fully.
const HAND_VISIBLE := 170.0
const HAND_FOCUS_SCALE := 1.4
const HAND_NEIGHBOUR_SCALE := 1.12
const ZOOM_CARD := Vector2(340, 462)
## Global size multipliers for text and inline icons.
const TEXT_SCALE := 1.15
const LARGE_TEXT := 1.15 # "Larger text", on top of TEXT_SCALE
const ICON_SCALE := 1.25

const WOOD := "res://assets/ui/wood.jpg"
const ROUNDED_SHADER := preload("res://scenes/game/rounded_panel.gdshader")
const SHINE_SHADER := preload("res://scenes/game/shine.gdshader")
const RAYS_SHADER := preload("res://scenes/game/rays.gdshader")
const VP_SEAL := preload("res://assets/vp.png")
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

const TABLE_TINT := Color(0.234, 0.162, 0.108)
const TABLE_PLANKS := 3
const PANEL_BG := Color(0, 0, 0, 0) # board zones: no box, the table shows through
const TABLE_SHADE := Color(0.06, 0.045, 0.035, 0.45) # dims the whole table under the play
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
var _give_card := -1 # Hook: the card picked to give back, until confirmed
# Your build, once sent, while the others choose: {card, pay, windfall}.
# Keeps its marks in the hand (the decision, and its input state, are gone).
var _sent_build := {}
var _pay: Array[int] = []
var _pay_windfall := false
var _windfall_dest := DeckhandGame.WINDFALL_DECK
var _windfall_step := false # building with your Windfall: choosing where it goes
var _confirming := "" # a move asked to be confirmed: "pass" (over the hand limit)
var _selected: Array[int] = []
var _selected_windfall := false
var _overlay_hidden := false # the player put the current choice aside to look at the table
var _kb_hand := false # the focused hand card was chosen with the keyboard
var _kb_card := -1 # card focused with the keyboard in a choice overlay
var _badges_queued := false
var _was_fullscreen := true # the window's mode when last looked at
var _key_hints := true # the key caps on buttons (Settings)
static var text_scale := TEXT_SCALE # TEXT_SCALE, larger with "Larger text"
static var _reopen_settings := false # the scene was reloaded from Settings
var _using_keys := false # the player is moving between cards with the keyboard
var _kb_index := 0 # position of the card last focused with the keyboard

var _round_label: Label
var _phase_label: Label
var _row_box: HBoxContainer
var _piles_box: HBoxContainer
var _opponents_box: VBoxContainer
var _crew_columns: HBoxContainer
var _crew_panel: PanelContainer
var _crew_hint: Label
var _board: Control # the Infamy Row and the decks
var _action_bar: Control
var _pay_panel: PanelContainer # paying for a build: floats over the crew
var _pay_body: VBoxContainer
var _vp_text: RichTextLabel
var _ledger_body: RichTextLabel
var _hand_area: Control
var _action_text: RichTextLabel
var _buttons: HBoxContainer
var _log: RichTextLabel
var _overlay: Control
var _overlay_body: VBoxContainer
var _menu: Control
var _credits: Control
var _rules: Control
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
var _slide_tween: Tween # paused while the menu is hidden

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
var _hands_passed := false # the next draft hand slides in from a neighbour
var _title_layer: CanvasLayer # the round title on show, if any
var _finale: CanvasLayer # the end-of-game screen, built once per game
var _finale_cued := false # the end piece has started; the screen follows
var _hold_choices := false # the round title is up: choices wait for it
var _lost := {} # contested Infamy card id -> the tied players, until it is shown
var _spotlights := 0 # Infamy cards (claimed or contested) still to show; choices wait
var _in_spotlight := {} # card id -> true while shown mid-table (its table copy stays hidden)
var _fresh := {} # card id -> true: hidden till now, to be dealt in as if new on the next refresh
# Infamy cards entering the spotlight together, by the same pirate, are
# shown side by side: {key, frame, ids, after, done}. Each group waits for
# the one before it (`after`) to clear the table.
var _spot_groups: Array = []
# The stage: table moments (bands, spotlights, a Hook's card coming back)
# play one at a time, in the order their events came. Each takes a ticket
# when its event fires, waits for its turn, and leaves when done.
var _stage_next := 0 # the next ticket to hand out
var _stage_now := 0 # the ticket on stage
signal _stage_moved
var _claimed := {} # Infamy card id -> claiming player, until its flight starts
var _gifts := {} # card id -> true: given back after a Hook, flies off glowing
var _band_ok: Button = null # the OK of the band on screen, if it has one
var _band_dismiss := Callable() # closes that band
var _band_since := 0 # when it showed (msec): a click on the hand closes it, after a grace
var _landing: Array = [] # your cards on their way to the crew: [{id, draws: [{source, cards}]}]
var _auto_passed: Variant = null # the build choice passed for you (nothing to build)
var _auto_pick := {} # the last draft card, taken for you: {decision, at (msec)}
var _retract_restore := {} # a build taken back: its selection, to restore
var _retract_sent := false # online: a take-back on its way to the relay
var _glow_free_at := {} # pirate -> when their last draw glow ends (msec)
var _active := {} # crew card id -> reasons it glows (its effect is resolving)
var _placing := {} # card id -> Row slot: placed by a Telescope, not yet shown there
var _battle_glow := {} # card id -> {player, fought, lit}: announced a Battle not yet over
var _pending_sources := {} # cards whose effect waits on a pirate's choice -> lit yet
var _hooks_waiting := 0 # Hook ceremonies yet to take their stage ticket
var _band_holds := 0 # bands (shown or queued) that hold the choices
var _bands_queued := 0 # bands called and not yet gone (holding or not)
var _hooked_keep := {} # card id -> true: hooked from you, still shown in hand until its tug
var _row_held := {} # Row slot -> true: revealed, still face down until its round's band shows
# Battle bands still waiting to show, that later Battles join.
var _announce_batch: Variant = null # {counts: {player: n}}
var _result_batch: Variant = null # {winner, scores, details, count, battles, drawn}
var _shown := {} # player -> {vp, banners} last displayed, to animate gains
var _fonts: Array[Font] = [] # keeps the fallback-patched fonts loaded

func _ready() -> void:
	CardDB.ensure_loaded()
	# Held in _fonts: an unreferenced font drops out of the resource cache, and
	# the next load() would return a fresh copy without the fallback.
	for path in [FONT_REGULAR, FONT_BOLD, FONT_TITLE]:
		var font: FontFile = load(path)
		if font.fallbacks.is_empty():
			font.fallbacks = [load(FONT_SYMBOLS)]
		_fonts.append(font)
	_load_display()
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
	add_child(PerfOverlay.new()) # F3
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
	if _reopen_settings:
		_reopen_settings = false
		_show_settings()

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
	if is_instance_valid(_finale):
		_finale.queue_free()
	_finale_cued = false
	_lost.clear()
	_spotlights = 0
	_in_spotlight.clear()
	_spot_groups = []
	_sent_build = {}
	_landing.clear()
	_active.clear()
	_battle_glow.clear()
	_placing.clear()
	_glow_free_at.clear()
	_retract_restore = {}
	_retract_sent = false
	_pending_sources.clear()
	_hooks_waiting = 0
	_hooked_keep.clear()
	_row_held.clear()
	_announce_batch = null
	_result_batch = null
	_stage_now = _stage_next # whatever was queued is dropped
	_stage_moved.emit()
	_hold_choices = false
	_band_holds = 0
	_bands_queued = 0
	game.start()

func _process(delta: float) -> void:
	if Effects.tick(delta):
		queue_redraw() # the screen is redrawn whole: any request will do
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
	var current: Variant = game.pending.get(_seat)
	if current != null and current.type == "build" and not action.get("pass", false):
		_sent_build = {"card": action.card, "pay": action.get("discards", []).duplicate(), "windfall": action.get("windfall", false),
			"dest": action.get("windfall_dest", DeckhandGame.WINDFALL_DECK), "decision": current}
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
	# Dim the choice at once while the relay answers.
	_queue_refresh()

## Takes back the build you chose while the others still choose theirs.
func _take_back() -> void:
	if not game.can_retract(_seat):
		_flash("Too late: every pirate has chosen.")
		return
	_retract_restore = _sent_build.duplicate()
	if not _online:
		game.submit(_seat, {"retract": true})
		return
	if _retract_sent:
		return
	_retract_sent = true
	_net.send_action(_seat, {"retract": true})
	_queue_refresh()

## Whether this machine has sent the pending choice and awaits the relay.
func _choice_sent() -> bool:
	return _online and _sent.has(_seat) and is_same(_sent[_seat], game.pending.get(_seat))

## The other pirates still making a simultaneous choice (a draft pick)
## after yours is made, or [] when there is nothing to wait for in a dialog.
## Offline the bots answer within a frame, so there is no dialog to show.
func _waiting_on() -> Array:
	if not _online or game.pending.has(_seat):
		return []
	var out := []
	for p: int in game.pending:
		if game.pending[p].type == "draft_pick":
			out.append(p)
	return out

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
	if seat == _seat and action.get("retract", false):
		_retract_sent = false
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
	# The wood texture is one plank: lay a few across the table, mirrored
	# in turn so their grain does not repeat.
	var planks := VBoxContainer.new()
	planks.set_anchors_preset(PRESET_FULL_RECT)
	planks.add_theme_constant_override("separation", 0)
	planks.mouse_filter = MOUSE_FILTER_IGNORE
	planks.modulate = TABLE_TINT
	add_child(planks)
	for i in TABLE_PLANKS:
		var plank := TextureRect.new()
		plank.texture = load(WOOD)
		plank.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plank.stretch_mode = TextureRect.STRETCH_SCALE
		plank.size_flags_vertical = SIZE_EXPAND_FILL
		plank.flip_h = i % 2 == 1
		plank.flip_v = i == 1
		plank.mouse_filter = MOUSE_FILTER_IGNORE
		planks.add_child(plank)
	# Lamplight: a warm, flickering pool, the edges in shadow.
	var candle := ColorRect.new()
	candle.set_anchors_preset(PRESET_FULL_RECT)
	candle.mouse_filter = MOUSE_FILTER_IGNORE
	var light := ShaderMaterial.new()
	Effects.use(light, preload("res://scenes/game/candlelight.gdshader"))
	candle.material = light
	add_child(candle)
	var shade := ColorRect.new()
	shade.color = TABLE_SHADE
	shade.set_anchors_preset(PRESET_FULL_RECT)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)

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
	top.add_child(_button("How to play", _show_rules))
	top.add_child(_button("Menu", _open_menu))

	# Infamy row and piles
	var board := HBoxContainer.new()
	board.add_theme_constant_override("separation", 12)
	main.add_child(board)
	_board = board
	var row_panel := _panel()
	row_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	board.add_child(row_panel)
	var row_v := VBoxContainer.new()
	row_panel.add_child(row_v)
	_row_box = HBoxContainer.new()
	_row_box.add_theme_constant_override("separation", 16)
	row_v.add_child(_row_box)
	board.add_child(_gold_line(true))
	var piles_panel := _panel()
	board.add_child(piles_panel)
	var piles_v := VBoxContainer.new()
	piles_panel.add_child(piles_v)
	_piles_box = HBoxContainer.new()
	_piles_box.add_theme_constant_override("separation", 10)
	piles_v.add_child(_piles_box)

	main.add_child(_gold_line(false))

	# Your score and resources beside your crew; overlays sit right of it.
	var home := HBoxContainer.new()
	home.size_flags_vertical = SIZE_EXPAND_FILL
	home.add_theme_constant_override("separation", 12)
	main.add_child(home)
	var ledger := _panel()
	_pad(ledger, 16)
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
	_ledger_body = _with_tips(_rich(15))
	_ledger_body.fit_content = true
	ledger_v.add_child(_ledger_body)

	home.add_child(_gold_line(true))

	# Your crew
	var crew_panel := _panel()
	_pad(crew_panel, 16)
	crew_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	home.add_child(crew_panel)
	_crew_panel = crew_panel
	# Until the first card is built: what the panel is for.
	_crew_hint = _label("Built cards join your crew here.\nTheir production pays for later builds.", 22, Color(1, 0.93, 0.8, 0.28))
	_crew_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crew_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crew_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crew_panel.add_child(_crew_hint)
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
	# Your score, on the wax seal in the crew's top-right corner.
	var corner := Control.new()
	corner.mouse_filter = MOUSE_FILTER_IGNORE
	crew_panel.add_child(corner)
	var vp_seal := _wax_seal(Vector2(77, 93))
	vp_seal.anchor_left = 1.0
	vp_seal.anchor_right = 1.0
	vp_seal.offset_left = -77.0 - 10.0
	vp_seal.offset_right = -10.0
	vp_seal.offset_top = 8.0
	vp_seal.offset_bottom = 8.0 + 93.0
	corner.add_child(vp_seal)
	_vp_text = _seal_text(vp_seal)
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
	_action_bar = action_panel
	var action_h := HBoxContainer.new()
	action_h.add_theme_constant_override("separation", 12)
	action_h.custom_minimum_size.y = 42
	action_panel.add_child(action_h)
	_action_text = _rich(17)
	_action_text.fit_content = true
	_action_text.size_flags_horizontal = SIZE_EXPAND_FILL
	_action_text.size_flags_vertical = SIZE_SHRINK_CENTER # centred in the bar
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
	# Lighter wood and a bright rim, so the choice stands out from the table.
	var panel := _wood_panel(Color(0.68, 0.5, 0.32), true)
	(panel.material as ShaderMaterial).set_shader_parameter("rim_color", Color(1.0, 0.82, 0.45, 0.95))
	(panel.material as ShaderMaterial).set_shader_parameter("rim_width", 3.0)
	panel.mouse_filter = MOUSE_FILTER_STOP
	_overlay.add_child(panel)
	_overlay_body = VBoxContainer.new()
	_overlay_body.add_theme_constant_override("separation", 12)
	panel.add_child(_overlay_body)
	_overlay.set_meta("panel", panel)
	panel.resized.connect(_place_overlay)
	# Outside a container nothing shrinks it back when its content shrinks.
	panel.minimum_size_changed.connect(_place_overlay, CONNECT_DEFERRED)
	_crew_panel.resized.connect(_place_overlay)
	_action_bar.resized.connect(_place_overlay)

## Over your crew, leaving the Infamy Row clear: centred across the crew
## panel, and with even gaps between the Row and the action bar. Taller than
## that space, it stands just above the action bar.
func _place_overlay() -> void:
	var panel: Control = _overlay.get_meta("panel")
	panel.reset_size()
	var crew := _crew_panel.get_global_rect()
	var screen := get_viewport_rect().size
	var x := clampf(crew.get_center().x - panel.size.x / 2.0, 12.0, screen.x - panel.size.x - 12.0)
	var top := _board.get_global_rect().end.y
	var bottom := _action_bar.get_global_rect().position.y
	var y := minf((top + bottom - panel.size.y) / 2.0, bottom - 6.0 - panel.size.y)
	panel.global_position = Vector2(x, maxf(y, 12.0))

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
	# The title paintings pan forever: hold them while the menu is hidden,
	# or the game would keep redrawing for nothing.
	_menu.visibility_changed.connect(func() -> void:
		if _slide_tween != null and _slide_tween.is_valid():
			if _menu.visible:
				_slide_tween.play()
			else:
				_slide_tween.pause())
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
	Effects.use(gleam, preload("res://scenes/game/logo.gdshader"), true)
	logo.material = gleam
	column.add_child(logo)
	var panel := _wood_panel()
	Effects.use(panel.material, ROUNDED_SHADER)
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
	var online := _big(_tint(_button("Play online", _show_online), Color(0.12, 0.27, 0.38), Color(0.5, 0.75, 0.9)))
	v.add_child(online)

	# Everything else, quietly.
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 6)
	v.add_child(footer)
	var down: Array[Control] = [online]
	down.append(_quiet(_button("How to play", _show_rules)))
	footer.add_child(down[-1])
	footer.add_child(_label("·", 15, MUTED))
	down.append(_quiet(_button("Settings", _show_settings)))
	footer.add_child(down[-1])
	footer.add_child(_label("·", 15, MUTED))
	down.append(_quiet(_button("Credits", _show_credits)))
	footer.add_child(down[-1])
	# A browser tab has nothing to quit to: quitting just freezes the page.
	if not OS.has_feature("web"):
		footer.add_child(_label("·", 15, MUTED))
		down.append(_quiet(_button("Quit", func() -> void: get_tree().quit())))
		footer.add_child(down[-1])
	# Down from the last big button walks the footer, one by one.
	for i in range(1, down.size()):
		down[i - 1].focus_neighbor_bottom = down[i - 1].get_path_to(down[i])
		down[i].focus_neighbor_top = down[i].get_path_to(down[i - 1])
	_menu.set_meta("new_game", new_game)
	_menu.set_meta("opponents", opp)
	_menu.set_meta("resume", resume)
	_build_credits()
	_build_rules()
	_build_online()
	_build_settings()
	_menu.set_meta("logo", logo)
	_menu.set_meta("panel", panel)
	# The menu and the table take turns at the button keys.
	_menu.visibility_changed.connect(_queue_key_badges)

## Who made the game, from the rulebook's credits page.
const CREDITS := [
	["Game design", ["Batiste Bieler"]],
	["Illustrations", ["Vitor Henrique", "Ricardo Zopello", "Batiste Bieler", "Mauri", "Toloma", "Daniel Cunha", "Marvin Blattert", "Matias Gonzalez"]],
	["Iconography", ["Louise Fayt", "Batiste Bieler"]],
	["Playtesting", ["Jessica Gibbons", "Gaël Nardin", "Jonathan Bieler", "Eduard Schäli", "Riccardo Zoppello", "Lucas Clark", "the Break My Game community", "and many others"]],
	["Music", ["Composed with Suno"]],
	["Sound effects", ["Synthesised for this game"]],
	["Typefaces", ["Signika by Anna Giedryś", "IM FELL English by Igino Marini", "DejaVu Sans"]],
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
	v.add_child(_menu_heading("Sound"))
	var mixer := GridContainer.new()
	mixer.columns = 2
	mixer.add_theme_constant_override("h_separation", 16)
	mixer.add_theme_constant_override("v_separation", 10)
	v.add_child(mixer)
	var ring: Array[Control] = []
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
		var settled := func() -> void:
			_sfx.save_volumes()
			if bus != "Music":
				_sfx.play("coin")
		var dragging := [false]
		slider.drag_started.connect(func() -> void: dragging[0] = true)
		slider.value_changed.connect(func(level: float) -> void:
			_sfx.set_volume(bus, level)
			if not dragging[0]:
				settled.call()) # a step with the arrow keys
		slider.drag_ended.connect(func(_changed: bool) -> void:
			dragging[0] = false
			settled.call())
		mixer.add_child(slider)
		ring.append(slider)
	v.add_child(_menu_heading("Display"))
	var config := ConfigFile.new()
	config.load(NetClient.SETTINGS)
	# A browser tab has its own full screen (and no window to resize).
	if not OS.has_feature("web"):
		var full := CheckBox.new()
		full.text = "Fullscreen"
		full.button_pressed = config.get_value("display", "fullscreen", true)
		full.toggled.connect(func(on: bool) -> void:
			_save_setting("display", "fullscreen", on)
			_apply_fullscreen(on))
		v.add_child(full)
		ring.append(full)
	var larger := CheckBox.new()
	larger.text = "Larger text"
	larger.button_pressed = config.get_value("display", "large_text", false)
	larger.toggled.connect(func(on: bool) -> void:
		_save_setting("display", "large_text", on)
		# Every label is sized as it is built: rebuild the scene, if no game
		# would be lost; otherwise from the next start.
		if game == null:
			_reopen_settings = true
			get_tree().reload_current_scene.call_deferred()
		else:
			_flash("Larger text applies from the next start."))
	v.add_child(larger)
	ring.append(larger)
	var reduced := CheckBox.new()
	reduced.text = "Reduced effects (smoother on older computers)"
	reduced.button_pressed = Effects.reduced
	reduced.toggled.connect(func(on: bool) -> void:
		_save_setting("display", "reduced_effects", on)
		Effects.set_reduced(on)
		# Shaders on screen switch at once; the menu is rebuilt for its
		# panning paintings (a game in progress hides them anyway).
		if game == null:
			_reopen_settings = true
			get_tree().reload_current_scene.call_deferred())
	v.add_child(reduced)
	ring.append(reduced)
	var hints := CheckBox.new()
	hints.text = "Show key hints on buttons"
	hints.button_pressed = _key_hints
	hints.toggled.connect(func(on: bool) -> void:
		_save_setting("display", "key_hints", on)
		_key_hints = on
		for badge in find_children("KeyBadge", "Label", true, false):
			badge.visible = on)
	v.add_child(hints)
	ring.append(hints)
	var close := _button("Close", func() -> void: _settings.visible = false)
	close.size_flags_horizontal = SIZE_SHRINK_CENTER
	v.add_child(close)
	ring.append(close)
	_focus_ring(ring)
	_settings.set_meta("first", ring[0])
	# Closed, focus goes back to where it was (the Settings button).
	_settings.visibility_changed.connect(func() -> void:
		var back: Variant = _settings.get_meta("back", null)
		if not _settings.visible and back is Control and is_instance_valid(back) and back.is_visible_in_tree():
			back.grab_focus())

## The saved display settings, applied before the table is built.
func _load_display() -> void:
	var config := ConfigFile.new()
	config.load(NetClient.SETTINGS)
	text_scale = TEXT_SCALE * (LARGE_TEXT if config.get_value("display", "large_text", false) else 1.0)
	_key_hints = config.get_value("display", "key_hints", true)
	Effects.reduced = config.get_value("display", "reduced_effects", false)
	if OS.has_feature("web"):
		return
	# The window opens as user://window.cfg says (see _remember_window), so
	# it is already right; settings saved before that file existed are put
	# right once, after macOS has finished opening the window full screen.
	var wanted: bool = config.get_value("display", "fullscreen", true)
	_was_fullscreen = wanted
	if _is_fullscreen() != wanted:
		_remember_window(wanted)
		if not wanted:
			await get_tree().create_timer(1.2).timeout
		_apply_fullscreen(wanted)
	# Full screen entered or left from the window itself (the green button,
	# a shortcut) is remembered too. The window has no signal for it.
	var watch := Timer.new()
	watch.wait_time = 0.5
	watch.autostart = true
	watch.timeout.connect(_remember_fullscreen)
	add_child(watch)

func _is_fullscreen() -> bool:
	return get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]

func _remember_fullscreen() -> void:
	var on := _is_fullscreen()
	if on == _was_fullscreen:
		return
	_was_fullscreen = on
	_save_setting("display", "fullscreen", on)
	_remember_window(on)

## The window mode for the next launch, read by Godot before it opens the
## window (project setting application/config/project_settings_override).
static func _remember_window(fullscreen: bool) -> void:
	var override := ConfigFile.new()
	override.set_value("display", "window/size/mode", Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED)
	override.save("user://window.cfg")

func _apply_fullscreen(on: bool) -> void:
	_was_fullscreen = on
	_remember_window(on)
	var window := get_window()
	window.mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED
	if not on:
		window.size = Vector2i(ProjectSettings.get_setting("display/window/size/window_width_override"),
			ProjectSettings.get_setting("display/window/size/window_height_override"))
		window.move_to_center()

## Keeps the keyboard focus among `controls` (a sheet's), so it never slips
## to the menu behind: Up / Down and Tab go round them, Left / Right stay.
func _focus_ring(controls: Array[Control]) -> void:
	var n := controls.size()
	for i in n:
		var control := controls[i]
		var prev := control.get_path_to(controls[(i - 1 + n) % n])
		var next := control.get_path_to(controls[(i + 1) % n])
		control.focus_neighbor_top = prev
		control.focus_previous = prev
		control.focus_neighbor_bottom = next
		control.focus_next = next
		control.focus_neighbor_left = NodePath(".")
		control.focus_neighbor_right = NodePath(".")

func _show_settings() -> void:
	_settings.set_meta("back", get_viewport().gui_get_focus_owner())
	_settings.visible = true
	# Arrows: Up / Down between the sliders and Close, Left / Right to set.
	(_settings.get_meta("first") as Control).grab_focus()
	_settings.modulate.a = 0.0
	_settings.create_tween().tween_property(_settings, "modulate:a", 1.0, 0.2)

func _build_credits() -> void:
	var sheet := _menu_sheet("Credits", func() -> void: _credits.visible = false)
	_credits = sheet[0]
	var v: VBoxContainer = sheet[1]
	var intro := _rich(17)
	intro.fit_content = true
	intro.add_theme_color_override("default_color", Color(1, 0.93, 0.8))
	intro.text = "[center][color=#e8c27a]Deckhand: Race for Infamy[/color] began as a physical card game.\nThis is its digital edition.[/center]"
	v.add_child(intro)
	# Two columns of sections, so the sheet fits the screen even with
	# larger text.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 14)
	v.add_child(grid)
	for section: Array in CREDITS:
		# Non-breaking spaces keep each name on one line (not a long credit
		# like the typeface's, which may wrap).
		var names: Array[String] = []
		for name: String in section[1]:
			names.append(name.replace(" ", "\u00a0") if name.length() <= 32 else name)
		var body := _rich(17)
		body.fit_content = true
		body.custom_minimum_size.x = 440
		body.add_theme_color_override("default_color", Color(1, 0.93, 0.8))
		body.text = "[center][color=#c9a76a][font_size=%d]%s[/font_size][/color]\n%s[/center]" % [_fs(14), section[0].to_upper(), "  ·  ".join(names)]
		grid.add_child(body)
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
	# Whose the art is, and what may be reused.
	var rights := _rich(14)
	rights.fit_content = true
	rights.add_theme_color_override("default_color", Color(0.85, 0.78, 0.65))
	rights.text = "[center]Art, icons, logos and music © Batiste Bieler / Tidale, all rights reserved. Code: MIT License.[/center]"
	v.add_child(rights)
	var close := _button("Close", func() -> void: _credits.visible = false)
	close.size_flags_horizontal = SIZE_SHRINK_CENTER
	v.add_child(close)

## How to play, in a nutshell: enough to start; the cards' details show on
## hover, and the rest is learnt at the table.
func _build_rules() -> void:
	var sheet := _menu_sheet("How to play", func() -> void: _rules.visible = false)
	_rules = sheet[0]
	var v: VBoxContainer = sheet[1]
	var gold := "[color=#ffd36b][b]%s[/b][/color]"
	var sections := [
		["Goal", "Recruit the best pirate crew. After [b]5 rounds[/b], the most %s wins." % (gold % "Victory Points")],
		["1 · Draft", "Keep one card from your draft hand and pass the rest, the way the wind blows. Repeat until the hands are empty."],
		["2 · Build", "Choose a card from your hand to build, all at once; or pass for the rest of the round. Built cards join your [b]crew[/b]."],
		["Paying", "Your crew's production pays first. For the rest, discard cards from your hand:\n1 card = 1 coin %s %s  ·  1 card shown = a resource it produces  ·  2 cards = any resource  ·  Windfall = 2 coins" % [_res("cs", 20), _res("c", 20)]],
		["Infamy", "Banners raised in your crew %s claim the Infamy cards in the Row: meet a card's banners and it is yours." % _banner("gun", 20)],
		["Scoring", "Add the VP on your crew and the multipliers (VP per banner). Ties go to the most Tentacles %s." % _img("fx-tentacle", 20)],
	]
	var text := ""
	for section: Array in sections:
		text += "[color=#e8c27a][font_size=%d]%s[/font_size][/color]\n%s\n\n" % [_fs(13), section[0].to_upper(), section[1]]
	text += "[color=#c9a76a][i]Hover any card to read what it does.[/i][/color]"
	var body := _rich(16)
	body.fit_content = true
	body.custom_minimum_size.x = 600
	body.add_theme_color_override("default_color", Color(1, 0.93, 0.8))
	body.add_theme_font_override("italics_font", load(FONT_REGULAR))
	body.text = text
	v.add_child(body)
	var close := _button("Close", func() -> void: _rules.visible = false)
	close.size_flags_horizontal = SIZE_SHRINK_CENTER
	v.add_child(close)
	_rules.set_meta("close", close)
	# Its own layer, above the menu's: it also opens from the table.
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	var holder := Control.new()
	holder.set_anchors_preset(PRESET_FULL_RECT)
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	holder.theme = _menu.theme
	layer.add_child(holder)
	_rules.reparent(holder, false)

func _show_rules() -> void:
	_rules.visible = true
	_rules.modulate.a = 0.0
	_rules.create_tween().tween_property(_rules, "modulate:a", 1.0, 0.2)
	(_rules.get_meta("close") as Control).grab_focus()

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
	# Leaving a finished game: back to the title music.
	if game != null and not in_game:
		_music.play(Music.INTRO, 1.5)
	(_menu.get_meta("resume") as Button).visible = in_game
	# The green button is what you most likely want: back to the game, or a new one.
	var new_game: Button = _menu.get_meta("new_game")
	for state in ["normal", "hover", "pressed"]:
		new_game.remove_theme_stylebox_override(state)
	new_game.remove_meta("primary")
	if not in_game:
		_primary(new_game)
	_hide_zoom(true)
	_menu.visible = true
	_queue_key_badges()

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
	# The logo fades in, settling from a third larger.
	tween.parallel().tween_property(logo, "modulate:a", 1.0, 0.8).set_delay(0.2)
	tween.parallel().tween_property(logo, "scale", Vector2.ONE, 1.0).from(Vector2(1.3, 1.3)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(0.2)
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
	_slide_tween = tween
	if not _menu.visible:
		tween.pause()
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
	if Effects.reduced:
		# Still paintings: only the crossfade moves, so the menu can idle.
		art.position = (from + to) / 2.0
	else:
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
	rounded.shader = Effects.frozen(ROUNDED_SHADER) # no lantern: never animates
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
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(state, "CheckBox", plain)
	t.set_stylebox("focus", "CheckBox", focus)
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
	t.set_stylebox("focus", "HSlider", focus)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled_hover)
	return t

## A check box drawn in the menu's colours: a rounded gold-rimmed square,
## filled gold with a dark tick when checked.
static func _check_icon(checked: bool) -> ImageTexture:
	var size := roundi(22 * text_scale)
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
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	return panel

## A thin, discreet gold line between board zones, fading out at both ends.
func _gold_line(vertical: bool) -> TextureRect:
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(GOLD, 0.0), Color(GOLD, 0.4), Color(GOLD, 0.4), Color(GOLD, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.width = 1 if vertical else 256
	texture.height = 256 if vertical else 1
	if vertical:
		texture.fill_to = Vector2(0, 1)
	var line := TextureRect.new()
	line.texture = texture
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.custom_minimum_size = Vector2(1, 0) if vertical else Vector2(0, 1)
	line.mouse_filter = MOUSE_FILTER_IGNORE
	return line

## Gives a panel from _panel() roomier content margins.
func _pad(panel: PanelContainer, margin: float) -> void:
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(margin)

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
	rounded.shader = Effects.frozen(ROUNDED_SHADER) # no lantern: never animates
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
	# Its key is its first letter, in bold (no key cap): the text is drawn by
	# two labels over the button's own, now invisible, text.
	button.add_theme_font_size_override("font_size", _fs(15))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color(0, 0, 0, 0))
	button.set_meta("key", OS.find_keycode_from_string(button.text.left(1).to_upper()))
	button.set_meta("plain_key", true)
	var row := HBoxContainer.new()
	row.set_anchors_preset(PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	button.add_child(row)
	row.add_child(_label(button.text.left(1), 15, Color.WHITE, true))
	row.add_child(_label(button.text.substr(1), 15, Color.WHITE))
	var tint := func(lit: bool) -> void: row.modulate = GOLD if lit else Color(0.93, 0.83, 0.65)
	tint.call(false)
	button.mouse_entered.connect(tint.bind(true))
	button.mouse_exited.connect(func() -> void: tint.call(button.has_focus()))
	button.focus_entered.connect(tint.bind(true))
	button.focus_exited.connect(func() -> void: tint.call(button.is_hovered()))
	return button

func _card(id: int, card_size: Vector2, face_up: bool = true) -> CardView:
	var view := CardView.make(id, card_size, face_up)
	view.active = _active.has(id)
	view.primed = _primed().has(id)
	view.hovered.connect(_on_card_hovered)
	_card_views.append(view)
	view.unhovered.connect(_on_card_unhovered)
	return view

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func _fs(size: int) -> int:
	return roundi(size * text_scale)

static func _img(name: String, size: int = 20) -> String:
	return "[img=%d]%s%s.png[/img]" % [roundi(size * ICON_SCALE), ICONS, name]

## A resource icon fitted in a `size` square: a tall one (the skull) as tall
## as the others, so the counts beside them line up.
static func _res(token: String, size: int = 20) -> String:
	var path := "%sres-%s.png" % [ICONS, token]
	if not _icon_aspect.has(path):
		var texture := load(path) as Texture2D
		_icon_aspect[path] = texture.get_width() / float(texture.get_height()) if texture != null else 1.0
	var aspect: float = _icon_aspect[path]
	var box := size * ICON_SCALE
	if aspect >= 1.0:
		return "[img=%d]%s[/img]" % [roundi(box), path]
	return "[img=%dx%d]%s[/img]" % [roundi(box * aspect), roundi(box), path]

static var _icon_aspect := {} # icon path -> width / height

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
		if decision != null:
			_sent_build = {} # a new choice: the last build is over
		_decision = decision
		_reset_input()
		if decision != null and is_same(_retract_restore.get("decision"), decision):
			# A build taken back: chosen again as it was, to change.
			_build_card = _retract_restore.card
			_pay.assign(_retract_restore.pay)
			_pay_windfall = _retract_restore.windfall
			_windfall_dest = _retract_restore.dest
		_retract_restore = {}
	_track_pending_sources()
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
	_give_card = -1
	_pay.clear()
	_pay_windfall = false
	_windfall_dest = DeckhandGame.WINDFALL_DECK
	_windfall_step = false
	_confirming = ""
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
	var wind := "clockwise" if game.wind() == 1 else "counter-clockwise"
	_phase_label.text = "%s    ·    wind %s" % [phase_names[game.phase], wind]

func _render_row() -> void:
	_clear(_row_box)
	for i in range(game.row.size()):
		var slot: Dictionary = game.row[i]
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.size_flags_horizontal = SIZE_EXPAND_FILL
		_row_box.add_child(v)
		if slot.cards.is_empty():
			var empty := Panel.new()
			empty.custom_minimum_size = ROW_CARD
			empty.modulate = Color(1, 1, 1, 0.15)
			empty.size_flags_horizontal = SIZE_SHRINK_CENTER
			v.add_child(empty)
			continue
		if not slot.revealed or _row_held.has(i):
			# Face down: stacked cards show, each a little up and to the right.
			var count: int = slot.cards.size()
			var step := Vector2(5, -5)
			var back_size := (ROW_CARD * (1.0 - step.x * (count - 1) / ROW_CARD.y)).round()
			var pile := Control.new()
			pile.custom_minimum_size = ROW_CARD
			pile.size_flags_horizontal = SIZE_SHRINK_CENTER
			v.add_child(pile)
			var picking := _picking_windfall()
			var story := _slot_story(i)
			for k in count:
				var back := _card(slot.cards[k], back_size, false)
				back.tooltip_text = story
				if picking:
					# Where your Windfall may go: click the slot to stack it.
					back.clicked.connect(func(_v: CardView) -> void: _pick_windfall(i))
					back.pickable = k == count - 1
				back.position = Vector2((ROW_CARD.x - back_size.x) / 2.0, ROW_CARD.y - back_size.y) + step * k - Vector2(step.x * (count - 1) / 2.0, 0)
				if count > 1:
					if k == count - 1:
						back.set_caption("×%d" % count)
					back.add_child(_card_rim(back_size))
				pile.add_child(back)
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

## A faint gold rim around a face-down card, so each card of a stack shows.
func _card_rim(card_size: Vector2) -> Panel:
	var rim := Panel.new()
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Color(GOLD, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(card_size.x * 0.06))
	rim.add_theme_stylebox_override("panel", style)
	rim.set_anchors_preset(PRESET_FULL_RECT)
	rim.mouse_filter = MOUSE_FILTER_IGNORE
	return rim

## A deck is shuffled: its top half is cut off and riffled back in a few
## times. A new Supply first gathers the discard pile into it.
func _shuffle_pile(deck: String) -> void:
	# After the cards that caused it have moved.
	await get_tree().create_timer(0.35).timeout
	var pile: CardView = _pile_views.get(deck)
	if not is_instance_valid(pile) or not pile.is_inside_tree():
		return
	var at := CardMotion.pose_of(pile, false)
	var layer := Control.new()
	layer.mouse_filter = MOUSE_FILTER_IGNORE
	_motion.add_child(layer)
	var id := 1 if deck == "infamy" else 13
	var start := 0.0
	var discard: CardView = _pile_views.get("discard")
	if deck == "supply" and is_instance_valid(discard) and discard.is_inside_tree():
		# The discards slide over to the empty Supply.
		var from := CardMotion.pose_of(discard, false)
		for k in 4:
			var ghost := CardView.make(id, at.size, false)
			ghost.interactive = false
			ghost.mouse_filter = MOUSE_FILTER_IGNORE
			ghost.position = from.center - at.size / 2.0
			layer.add_child(ghost)
			var slide := ghost.create_tween()
			slide.tween_interval(k * 0.06)
			slide.tween_property(ghost, "position", at.center - at.size / 2.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			slide.tween_callback(ghost.queue_free)
		start = 0.5
	var halves: Array[CardView] = []
	for side in [-1.0, 1.0]:
		var half := CardView.make(id, at.size, false)
		half.interactive = false
		half.mouse_filter = MOUSE_FILTER_IGNORE
		half.position = at.center - at.size / 2.0
		half.pivot_offset = at.size / 2.0
		half.modulate.a = 0.0
		layer.add_child(half)
		halves.append(half)
	var tween := layer.create_tween()
	tween.tween_interval(start)
	tween.tween_callback(func() -> void:
		_sfx.play("card_deal", -10.0)
		for half in halves:
			half.modulate.a = 1.0)
	# Riffles: the halves part left and right, then slide back together,
	# the one in front changing each time.
	for k in 3:
		for i in 2:
			var side := -1.0 if i == 0 else 1.0
			tween.parallel().tween_property(halves[i], "position:x", at.center.x - at.size.x / 2.0 + side * at.size.x * 0.42, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(halves[i], "rotation_degrees", side * 7.0, 0.11)
		tween.tween_callback(func() -> void: layer.move_child(halves[k % 2], -1))
		for i in 2:
			tween.parallel().tween_property(halves[i], "position:x", at.center.x - at.size.x / 2.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(halves[i], "rotation_degrees", 0.0, 0.12)
	tween.tween_callback(layer.queue_free)

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
		if spec[3] and _picking_windfall():
			# Or into the Infamy deck.
			view.interactive = true
			view.pickable = true
			view.clicked.connect(func(_v: CardView) -> void: _pick_windfall(DeckhandGame.WINDFALL_DECK))
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
	var banner_widths: Array[float] = []
	for b in CardDB.BANNERS:
		if banners[b] > 0:
			banner_widths.append(_item_width(icon_size + 2, 1, banners[b]))
	var prod: Array[String] = []
	var prod_widths: Array[float] = []
	for group: Array in _production_groups(p):
		prod.append(_tip(_slot_tip(group[0], group[1]).replace("Your crew", "Their crew"), "%s%d" % [_slot_icons(group[0], icon_size), group[1]]))
		prod_widths.append(_item_width(icon_size, group[0].size(), group[1]))
	# Labels on the left, their icons on the right: on two even lines when
	# they do not fit on one (rather than a lone icon on a line of its own).
	var font := get_theme_default_font()
	var label_width := font.get_string_size("Produces", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(13)).x + 10.0
	var room := OPP_COLUMN_WIDTH - 32.0 - label_width
	var banner_text := _even_lines(parts, banner_widths, room) if not parts.is_empty() else "[color=#8a96a6]no banners[/color]"
	var prod_text := _even_lines(prod, prod_widths, room) if not prod.is_empty() else "[color=#8a96a6]none[/color]"
	var extras := _tip(SYMBOL_TIPS["fx-tentacle"], "%s%d" % [_img("fx-tentacle", icon_size), game.tentacles(p)])
	for key in ["battles", "hooks", "compasses"]:
		var n := game.symbol_count(p, key)
		if n > 0:
			var icon: String = {"battles": "fx-battle", "hooks": "fx-hook", "compasses": "fx-compass"}[key]
			extras += "  " + _tip(SYMBOL_TIPS[icon], "%s%d" % [_img(icon, icon_size), n])
	if game.players[p].pending_battles > 0:
		extras += "  " + _tip(BATTLE_TIP, "[color=#ffb070]Battle pending ×%d[/color]" % game.players[p].pending_battles)
	return "[table=2][cell padding=0,0,10,2]Banners[/cell][cell padding=0,0,0,2]%s[/cell][cell padding=0,0,10,2]Produces[/cell][cell padding=0,0,0,2]%s[/cell][/table]\n%s" % [banner_text, prod_text, extras]

## About how wide an icon item is in the summary: `icons` icons (with a
## slash between) and its count.
func _item_width(icon_size: int, icons: int, count: int) -> float:
	var digit := _fs(13) * 0.6
	return icon_size * icons + (icons - 1) * digit + str(count).length() * digit + digit * 0.6

## `items` joined by spaces, broken into as few lines as fit `room`, each
## about as long as the others.
static func _even_lines(items: Array[String], widths: Array[float], room: float) -> String:
	var total := 0.0
	for w in widths:
		total += w
	var lines := maxi(1, ceili(total / room))
	if lines == 1:
		return " ".join(items)
	var target := total / lines
	var out := ""
	var line_width := 0.0
	for i in range(items.size()):
		if line_width > 0.0 and line_width + widths[i] / 2.0 > target and out.count("\n") < lines - 1:
			out += "\n"
			line_width = 0.0
		elif line_width > 0.0:
			out += " "
		out += items[i]
		line_width += widths[i]
	return out

## `text` (BBCode allowed) in the title font.
static func _fancy(text: String) -> String:
	return "[font=%s]%s[/font]" % [FONT_TITLE, text]

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
	# Word joiners: the alternatives never part across lines.
	return "\u2060/\u2060".join(alt)

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
		elif game.has_answered(p) and not game.pending.is_empty():
			status = "  [color=#8fe388]✓ ready[/color]"
		var template := "[b]%s[/b]%s\n[color=#ffd36b]{vp} VP[/color]   ·   hand %d   ·   %s" % [
			_who(p), status, game.hand_size(p),
			"windfall ✓" if pl.windfall >= 0 else "no windfall"]
		v.add_child(head)
		var fresh := _show_gains(p, head, template, Vector2(0.0, head.get_theme_font("normal_font").get_height(_fs(16))), 0.75)
		var summary := _with_tips(_rich(13))
		summary.fit_content = true
		summary.text = _player_summary(p, 15, fresh)
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
	_crew_hint.visible = pl.crew.is_empty()
	if pl.crew.is_empty():
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
			# In build order: the newest card lies on top, at the bottom,
			# fully visible.
			stacks.append(groups[group])
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
	var offset := Vector2(_vp_text.size.x / 2.0 - 40.0, _vp_text.size.y * 0.45)
	var fresh := _show_gains(_seat, _vp_text, "[center][font_size=%d][b]{vp}[/b][/font_size]\n[font_size=%d]VP[/font_size][/center]" % [_fs(24), _fs(10)], offset)
	var banners := game.raised_banners(_seat)
	var cells: Array[String] = []
	for b in CardDB.BANNERS:
		if banners[b] > 0:
			var count := "[color=#ffd36b][b]%d[/b][/color]" % banners[b] if fresh.has(b) else str(banners[b])
			cells.append(_tip(_banner_tip(b), "%s %s" % [_banner(b, 21), count]))
	var text := _ledger_section("Banners", cells, "none raised")
	cells = []
	var choices: Array[String] = [] # "A or B" slots: too wide for a third, two per row
	for group: Array in _production_groups(_seat):
		if (group[0] as Array).size() > 1:
			# No count: each "A or B" pair is on one card only, so it is 1.
			choices.append(_tip(_slot_tip(group[0], group[1]), _slot_icons(group[0], 26)))
		else:
			cells.append(_tip(_slot_tip(group[0], group[1]), "%s %d" % [_slot_icons(group[0], 26), group[1]]))
	text += _ledger_section("Produces", cells, "nothing yet" if choices.is_empty() else "", 3, not choices.is_empty())
	if not choices.is_empty():
		text += _ledger_section("", choices, "", 2)
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

## A titled grid of `cells` in `columns` (no title: it continues the section
## above; `more`: the next one does, so no gap yet).
func _ledger_section(title: String, cells: Array[String], empty: String, columns: int = 3, more: bool = false) -> String:
	# A short gap after each section, not a full line.
	var gap := "" if more else "[font_size=%d] [/font_size]\n" % _fs(4)
	var text := "" if title.is_empty() else "[color=#8a96a6][font_size=%d]%s[/font_size][/color]\n" % [_fs(13), title]
	if cells.is_empty():
		return text + ("" if empty.is_empty() else "[color=#8a96a6]%s[/color]\n" % empty) + gap
	text += "[table=%d]" % columns
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
	# Built, but not in the crew yet (players before you in priority order
	# are still adding theirs): it stays in hand until its turn comes, then
	# flies over (else it would vanish, then appear in the crew from nowhere).
	var built: int = pl.built_this_step
	if built >= 0 and not pl.crew.has(built) and not pl.hand.has(built):
		entries.append({"id": built, "building": true})
	# Hooked from you, but its turn on the table has not come yet.
	for id: int in _hooked_keep:
		if not pl.hand.has(id):
			entries.append({"id": id, "hooked": true})
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
	var surplus := _surplus() if type == "build" else {}
	for entry: Dictionary in _hand_entries():
		var id: int = entry.id
		var view := _card(id, HAND_CARD)
		view.set_meta("windfall", entry.get("windfall", false))
		view.set_meta("building", entry.get("building", false) or entry.get("hooked", false))
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
		if entry.get("building", false):
			view.mark = CardView.Mark.SELECTED
			view.set_caption("Building")
		elif type == "" and not _sent_build.is_empty():
			# Sent, waiting for the others: the build keeps its marks.
			if entry.get("windfall", false):
				view.mark = CardView.Mark.PAYMENT if _sent_build.windfall else CardView.Mark.NONE
			elif id == _sent_build.card:
				view.mark = CardView.Mark.SELECTED
				view.set_caption("Building")
			elif _sent_build.pay.has(id):
				view.mark = CardView.Mark.PAYMENT
		elif type == "build":
			if entry.get("windfall", false):
				view.mark = CardView.Mark.PAYMENT if _pay_windfall else CardView.Mark.NONE
				if _pay_windfall and surplus.windfall:
					view.set_note("Not needed", SURPLUS_RED)
			elif id == _build_card:
				view.mark = CardView.Mark.SELECTED
			elif _pay.has(id):
				view.mark = CardView.Mark.PAYMENT
				if surplus.cards.has(id):
					view.set_note("Not needed", SURPLUS_RED)
		elif type == "hand_limit":
			var chosen: bool = _selected_windfall if entry.get("windfall", false) else _selected.has(id)
			view.mark = CardView.Mark.PAYMENT if chosen else CardView.Mark.NONE
		elif type == "hook_give":
			if entry.get("windfall", false):
				view.mark = CardView.Mark.DISABLED
			elif id == _give_card:
				view.mark = CardView.Mark.SELECTED
				view.set_caption("Give back")
			elif id == decision.stolen:
				view.mark = CardView.Mark.HIGHLIGHT
				view.set_caption("Stolen")
		# Crew production alone pays for it.
		if view.mark == CardView.Mark.NONE and not entry.get("windfall", false) and _is_free(id):
			view.mark = CardView.Mark.FREE
		# Choosing what to build: the cards you cannot pay for are dimmed
		# (they can still pay for another).
		if type == "build" and _build_card < 0 and not entry.get("windfall", false) \
				and not entry.get("building", false) and not _can_afford(id):
			view.dim = true
		_hand_area.add_child(view)
		_hand_views.append(view)
		if id == focus_id:
			_hovered_hand = view
	_layout_hand()
	if _hovered_hand != null:
		_on_card_hovered(_hovered_hand)
	else:
		_kb_hand = false

const AUTO_PASS_DELAY := 2.0

## Passes for you (nothing to build) once `decision` has been on show a moment;
## once per decision (a pass taken back is not passed again).
func _auto_pass(decision: Dictionary) -> void:
	if is_same(_auto_passed, decision):
		return
	_auto_passed = decision
	await get_tree().create_timer(AUTO_PASS_DELAY).timeout
	while is_inside_tree() and _hold_choices: # a moment on show first
		await get_tree().process_frame
	if not is_inside_tree() or not is_same(game.pending.get(_seat), decision) or _any_affordable():
		return
	if _choice_sent():
		return
	_submit({"pass": true})

## Whether your hand (and Windfall) can pay for card `id` with your crew.
func _can_afford(id: int) -> bool:
	if not game.players[_seat].hand.has(id):
		return false
	if _is_free(id):
		return true
	var others: Array = game.players[_seat].hand.filter(func(other: int) -> bool: return other != id)
	var windfall_value := INF if game.players[_seat].windfall < 0 else 1.0
	var keep := func(_card: int) -> float: return 0.0
	return Payment.plan(CardDB.get_card(id).cost, game.crew_production_slots(_seat), others, keep, windfall_value).ok

func _any_affordable() -> bool:
	for id: int in game.players[_seat].hand:
		if _can_afford(id):
			return true
	return false

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

## Your crew cards that the card chosen to build would set off ("each time
## you add X to your crew"), with how many times.
func _primed() -> Dictionary:
	var decision: Variant = game.pending.get(_seat)
	if _build_card < 0 or decision == null or decision.type != "build":
		return {}
	return game.triggers_of(_seat, _build_card)

## Lights the crew cards the chosen card would set off.
func _show_primed() -> void:
	var primed := _primed()
	for view in _card_views:
		if is_instance_valid(view) and game.players[_seat].crew.has(view.card_id):
			view.primed = primed.has(view.card_id)

func _render_action() -> void:
	_show_primed()
	var decision: Variant = game.pending.get(_seat)
	var paying: bool = decision != null and decision.type == "build" and _build_card >= 0 and game.phase != DeckhandGame.Phase.GAME_OVER
	if not paying:
		_show_pay_panel(false)
	if game.phase == DeckhandGame.Phase.GAME_OVER:
		_action_text.text = "[b]The voyage is over.[/b]"
		_set_buttons([["Scores", _show_finale], ["New game", _open_menu]])
		return
	if decision == null or _choice_sent():
		if decision == null and game.can_retract(_seat) and not _retract_sent:
			# Your build waits for the others': it can still be changed.
			_action_text.text = "[color=#8a96a6]Your build is chosen. The other pirates are deciding…[/color]"
			_set_buttons([["Take back", _take_back]])
			return
		_action_text.text = "[color=#8a96a6]The other pirates are deciding…[/color]"
		_set_buttons([])
		return
	if _spotlights > 0:
		# A card is shown mid-table: its caption has the floor.
		_action_text.text = ""
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
			if _hold_choices:
				_action_text.text = ""
				_set_buttons([])
			elif _give_card < 0:
				_action_text.text = "[b]Hook[/b] — you stole [b]%s[/b] from %s. With fewer than 3 Hooks you must give one card back: pick it in your hand." % [
					CardDB.title(decision.stolen), _who(decision.target)]
				_set_buttons([])
			else:
				_action_text.text = "[b]Hook[/b] — give [b]%s[/b] back to %s?  [color=#8a96a6](click another card to change)[/color]" % [
					CardDB.title(_give_card), _who(decision.target)]
				_set_buttons([["Give to %s »" % game.players[decision.target].name, func() -> void: _submit({"card": _give_card})]])
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
	if _windfall_step:
		_action_text.text = "[b]Build %s[/b]   [color=#e8c890]choose where your Windfall goes[/color]" % CardDB.title(_build_card)
		_set_buttons([])
		return
	if _build_card < 0 and not _any_affordable():
		# Passing is all there is: it is done for you, after a moment.
		_action_text.text = "[b]Build:[/b] you can't pay for any card in your hand, so you pass for the rest of the round."
		_set_buttons([["Pass »", func() -> void: _submit({"pass": true})]])
		_auto_pass(game.pending[_seat])
		return
	if _confirming == "pass":
		var extra := game.hand_size(_seat) - DeckhandGame.HAND_LIMIT
		_action_text.text = "[color=#ffb070]⚠ You hold %d cards: at the end of the round you discard %d, down to %d.[/color] Pass anyway?" % [
			game.hand_size(_seat), extra, DeckhandGame.HAND_LIMIT]
		_set_buttons([["« Back", _unconfirm], ["Pass anyway", func() -> void: _submit({"pass": true})]])
		# Bright red: it costs cards.
		_tint(_buttons.get_child(_buttons.get_child_count() - 1), Color(0.82, 0.1, 0.06), Color(1.0, 0.5, 0.42))
		return
	if _build_card < 0:
		_action_text.text = "[b]Build:[/b] click a card in your hand to build it, or pass for the rest of the round."
		_set_buttons([["Pass »", _try_pass]])
		return
	var card := CardDB.get_card(_build_card)
	var crew_missing := Payment.missing_after_crew(card.cost, game.crew_production_slots(_seat))
	var result := game.check_payment(_seat, _build_card, _pay, _pay_windfall)
	# Just the card here: the payment, and whether it is paid, is in the
	# panel over the crew.
	_action_text.text = "[b]Build %s[/b]" % card.title
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
	_buttons.add_child(_button("Pass »", _try_pass))
	_render_pay_panel(card, crew_missing, result)
	_show_pay_panel(true)

## Pass, after a word if you hold more than the hand limit (you will
## discard the rest at the end of the round).
func _try_pass() -> void:
	if game.hand_size(_seat) > DeckhandGame.HAND_LIMIT and _confirming != "pass":
		_confirming = "pass"
		_render_action()
		return
	_submit({"pass": true})

func _unconfirm() -> void:
	_confirming = ""
	_render_action()

## How many of the cards chosen to pay (the Windfall included) are not
## needed: dropped one by one while the payment still holds.
func _overpaid() -> int:
	var surplus := _surplus()
	return surplus.cards.size() + (1 if surplus.windfall else 0)

const SURPLUS_RED := Color(1.0, 0.29, 0.23) # as the overpaid status line

## The discards the payment does without: {cards, windfall: bool}. The
## Windfall first, then the latest picked (likeliest a slip).
func _surplus() -> Dictionary:
	var out := {"cards": [], "windfall": false}
	if _build_card < 0 or not game.check_payment(_seat, _build_card, _pay, _pay_windfall).ok:
		return out
	var pay := _pay.duplicate()
	var windfall := _pay_windfall
	if windfall and game.check_payment(_seat, _build_card, pay, false).ok:
		windfall = false
		out.windfall = true
	var latest := _pay.duplicate()
	latest.reverse()
	for id: int in latest:
		var without := pay.duplicate()
		without.erase(id)
		if game.check_payment(_seat, _build_card, without, windfall).ok:
			pay = without
			out.cards.append(id)
	return out

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
	var title := _label("Paying for %s" % card.title, 20, GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pay_body.add_child(title)
	# Wide rather than tall (it covers less of the crew): the cost on the
	# left, how to pay it on the right.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	_pay_body.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_vertical = SIZE_SHRINK_CENTER
	columns.add_child(left)
	# The cost as a checklist: each token paid (and by what) or not yet.
	var payers: Array = result.get("payers", [])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	left.add_child(row)
	for i in range(card.cost.size()):
		var token: String = card.cost[i]
		var payer: Dictionary = payers[i] if i < payers.size() else {}
		var chip := _cost_chip(token, "missing" if payer.is_empty() else "paid")
		var what: String = CardDB.RESOURCE_NAMES[token]
		_chip_icon(chip).tooltip_text = "%s: still to pay." % what if payer.is_empty() else "%s, paid by %s." % [what, _payer_text(payer)]
		row.add_child(chip)
	var status := _rich(16)
	status.fit_content = true
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	var extra := _overpaid() if result.ok else 0
	if extra > 0:
		status.text = "[center][color=#ff4a3a]Paid, with %d card%s more than needed[/color][/center]" % [extra, "" if extra == 1 else "s"]
	elif result.ok:
		status.text = "[center][color=#8fe388]✓ Paid: ready to build[/color][/center]"
	elif not _can_afford(_build_card):
		# Selectable all the same: to see what it lacks.
		status.text = "[center][color=#ff4a3a]Your hand and crew can't pay for it[/color][/center]"
	else:
		# What is left to pay has a red border above.
		status.text = "[center][color=#ffe0a0]Pick hand cards to discard[/color][/center]"
	left.add_child(status)
	if crew_missing.is_empty():
		var all_crew := _label("Your crew pays it all.", 15, Color(0.75, 0.95, 0.7))
		all_crew.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left.add_child(all_crew)
		return
	columns.add_child(_gold_line(true))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_vertical = SIZE_SHRINK_CENTER
	columns.add_child(right)
	# What discarding gives, each way with how often this payment uses it:
	# lit with a count when used, dimmed when not.
	var used: Dictionary = result.get("used", {})
	# The cards used each way, for the rows' tooltips.
	var by_way := {"single": [], "pair": [], "windfall": []}
	for payer: Dictionary in result.get("payers", []):
		var kind: String = payer.get("kind", "crew")
		if kind == "single":
			by_way.single.append(_pay_card_name(payer.discard))
		elif kind == "pair":
			by_way.pair.append("%s + %s" % [_pay_card_name(payer.discards[0]), _pay_card_name(payer.discards[1])])
		elif kind == "windfall" and by_way.windfall.is_empty():
			by_way.windfall.append("your Windfall")
	var rates := _with_tips(_rich(16))
	rates.fit_content = true
	rates.autowrap_mode = TextServer.AUTOWRAP_OFF
	var rules := [
		[used.get("single", 0), "Discard 1 card →", "%s or %s or its resource" % [_res("cs", 15), _res("c", 15)], "single"],
		[used.get("pair", 0), "Discard 2 cards →", "any resource", "pair"],
		[used.get("windfall", 0), "Windfall →", "%s%s or %s%s" % [_res("cs", 15), _res("cs", 15), _res("c", 15), _res("cs", 15)], "windfall"],
	]
	var table := "[table=2]"
	for rule: Array in rules:
		var count: int = rule[0]
		if result.ok and count == 0:
			continue # paid: only the ways it is paid
		var mark := "[color=#8fe388][b]×%d[/b][/color]" % count if count > 0 else ""
		var label_color := "#ffe0a0" if count > 0 else "#a08a68"
		var text_color := "#fff2dc" if count > 0 else "#b8a88c"
		var line := "[color=%s][b]%s[/b][/color] [color=%s]%s[/color]" % [label_color, rule[1], text_color, rule[2]]
		var cards: Array = by_way[rule[3]]
		if not cards.is_empty():
			line = _tip("Used for this payment: %s." % ", ".join(cards), line)
		table += "[cell padding=0,0,8,0]%s[/cell][cell]%s[/cell]" % [mark, line]
	rates.text = table + "[/table]"
	right.add_child(rates)
	if _pay_windfall and not game.unrevealed_slots().is_empty():
		right.add_child(_label("After Build, you choose where your Windfall goes.", 14, Color(0.85, 0.78, 0.65)))

## One cost icon; still to pay, it has a red border.
## What pays a cost token, in words (see Payment.evaluate's payers; the
## discards are the current payment's).
func _payer_text(payer: Dictionary) -> String:
	match payer.get("kind", ""):
		"crew":
			return "your crew's %s" % CardDB.title(_crew_slot_card(payer.slot))
		"single":
			return "discarding %s" % _pay_card_name(payer.discard)
		"pair":
			return "discarding %s and %s (2 cards: any resource)" % [_pay_card_name(payer.discards[0]), _pay_card_name(payer.discards[1])]
		"windfall":
			return "discarding your Windfall"
	return "?"

## A discard of the current payment by index (the one past the cards: the Windfall).
func _pay_card_name(index: int) -> String:
	return CardDB.title(_pay[index]) if index < _pay.size() else "your Windfall"

## The crew card whose production is slot `slot` (crew_production_slots order).
func _crew_slot_card(slot: int) -> int:
	var k := 0
	for id: int in game.players[_seat].crew:
		for _s in CardDB.get_card(id).production:
			if k == slot:
				return id
			k += 1
	return -1

func _chip_icon(chip: Control) -> TextureRect:
	return chip.find_children("*", "TextureRect", true, false)[0]

func _cost_chip(token: String, mark: String) -> Control:
	var chip := VBoxContainer.new()
	chip.add_theme_constant_override("separation", 2)
	var icon := TextureRect.new()
	icon.texture = load("%sres-%s.png" % [ICONS, token])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(50, 50)
	icon.tooltip_text = CardDB.RESOURCE_NAMES[token]
	# A border following its shape: red still to pay, green paid (by the
	# crew or discards). Drawn inset in a bigger rect (room for the border),
	# at the same size as without.
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_GLOW
	material.set_shader_parameter("inset", MISSING_INSET)
	material.set_shader_parameter("glow_color", MISSING_GLOW if mark == "missing" else PAID_GLOW)
	icon.material = material
	icon.custom_minimum_size = Vector2(50, 50) / (1.0 - 2.0 * MISSING_INSET)
	# Keep the row's spacing: the extra room overlaps the neighbours.
	var spot := Control.new()
	spot.custom_minimum_size = Vector2(50, 50)
	spot.mouse_filter = MOUSE_FILTER_IGNORE
	icon.position = (spot.custom_minimum_size - icon.custom_minimum_size) / 2.0
	icon.size = icon.custom_minimum_size
	spot.add_child(icon)
	chip.add_child(spot)
	return chip

const OUTLINE_GLOW := preload("res://scenes/game/outline_glow.gdshader")
const MISSING_INSET := 0.14 # of the icon's rect, each side: room for its border
const MISSING_GLOW := Color(1.0, 0.1, 0.05, 1.0)
const PAID_GLOW := Color(0.3, 0.95, 0.35, 0.85)

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

const PAY_PANEL_GAP := 40.0 # above the action bar: room for the panel's shadow

## Centred over the crew area, just above the action bar.
func _place_pay_panel() -> void:
	if not _pay_panel.visible:
		return
	_pay_panel.reset_size()
	var crew := _crew_panel.get_global_rect()
	var x := clampf(crew.get_center().x - _pay_panel.size.x / 2.0, crew.position.x + 8.0, crew.end.x - _pay_panel.size.x - 8.0)
	# Clear of the action bar, its shadow included.
	var bottom := minf(crew.end.y, _action_bar.get_global_rect().position.y)
	_pay_panel.position = Vector2(x, bottom - _pay_panel.size.y - PAY_PANEL_GAP)

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

## Puts `button` at the top right of the choice, level with its title.
## More than one go side by side.
func _overlay_corner(button: Button) -> void:
	var header: Control = _overlay_body.get_child(0)
	if not header.has_meta("corner"):
		var title := header
		header = HBoxContainer.new()
		header.set_meta("corner", true)
		header.add_theme_constant_override("separation", 10)
		_overlay_body.add_child(header)
		_overlay_body.move_child(header, 0)
		title.reparent(header)
		title.size_flags_horizontal = SIZE_EXPAND_FILL
	button.size_flags_vertical = SIZE_SHRINK_CENTER
	header.add_child(button)
	_queue_key_badges()

func _overlay_buttons(specs: Array) -> void:
	if specs.is_empty():
		return # no empty row: it would pad the bottom
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
	# Clear of the cards above: a selected card's glow and the key badges
	# would otherwise touch the buttons.
	var gap := MarginContainer.new()
	gap.add_theme_constant_override("margin_top", 14)
	gap.add_child(row)
	_overlay_body.add_child(gap)
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
	if _hold_choices:
		return
	var waiting := _waiting_on()
	if not waiting.is_empty():
		_render_waiting_overlay(waiting)
	elif decision == null:
		return
	else:
		_render_choice_overlay(decision)
	# Sent, until the relay plays it back: the choice stays, dimmed, so its
	# cards can then animate (a redraw burns them).
	_overlay_body.modulate.a = 0.55 if _choice_sent() else 1.0
	if _overlay_hidden:
		_overlay.visible = false
	_show_overlay_focus()

func _render_waiting_overlay(waiting: Array) -> void:
	var names := waiting.map(func(p: int) -> String: return "[b]%s[/b]" % game.players[p].name)
	_show_overlay("Waiting for the other pirates…", "Your choice is made. Still choosing: %s." % ", ".join(names))

## Building with your Windfall: it goes into the Infamy deck, or face down
## on a Row slot (revealed with that round's card). Both glow on the table,
## to be clicked; this says so.
func _render_windfall_overlay() -> void:
	var windfall: int = game.players[_seat].windfall
	var spot := _show_overlay("Where does your Windfall go?",
		"You discard [b]%s[/b] to pay. Click the [b]Infamy deck[/b] to shuffle it in, or a face-down [b]Row slot[/b] to stack it there: it is revealed with that slot's card, at the start of that round." % CardDB.title(windfall))
	spot.queue_free() # no cards here: the choices are on the table
	_overlay_buttons([["« Back to payment", func() -> void:
		_windfall_step = false
		_queue_refresh()]])

## Whether the Row slots and the Infamy deck are offered for your Windfall.
func _picking_windfall() -> bool:
	var decision: Variant = game.pending.get(_seat)
	return _windfall_step and decision != null and decision.type == "build" and not _hold_choices and not _choice_sent()

func _pick_windfall(dest: int) -> void:
	if not _picking_windfall():
		return
	_sfx.play("card_flip", -4.0)
	_windfall_dest = dest
	_confirm_build()

func _render_choice_overlay(decision: Dictionary) -> void:
	if decision.type == "build" and _windfall_step:
		_render_windfall_overlay()
		return
	match decision.type:
		"draft_pick":
			_render_draft_overlay(decision)
		"choose_one":
			var cards := _show_overlay("Draw 3, keep 1", "From %s: keep one card, the other two are discarded." % CardDB.title(decision.source))
			for id: int in decision.cards:
				_overlay_card(cards, id, func() -> void: _submit({"card": id}))
		"telescope_slot":
			var cards := _show_overlay("Telescope", "Choose a face-down Row slot to look at.")
			for slot: int in decision.slots:
				var stack: Array = game.row[slot].cards
				var view := _overlay_card(cards, stack[-1], func() -> void: _submit({"slot": slot}), false)
				view.set_caption("Round %d" % (slot + 1) if stack.size() == 1 else "Round %d · %d cards" % [slot + 1, stack.size()])
		"telescope_card":
			var cards := _show_overlay("Telescope", "Round %d's slot holds %d cards: choose the one to look at." % [decision.slot + 1, decision.cards.size()])
			_telescope_fan(cards, decision.cards)
		"telescope_swap":
			var cards := _show_overlay("Telescope", "Left: the face-down card for round %d. Right: the top of the Infamy deck. Swap them?" % (decision.slot + 1))
			_card_into(cards, decision.row_card).set_caption("In the Row")
			_card_into(cards, decision.deck_card).set_caption("Infamy deck")
			_overlay_buttons([["Keep the Row", func() -> void: _submit({"swap": false})], ["Swap", func() -> void: _submit({"swap": true})]])
		"telescope_place":
			var cards := _show_overlay("Telescope", "Last round: you may place the top Infamy card face up in the Row, in slot %d." % (game.place_slot() + 1))
			_card_into(cards, decision.card)
			_overlay_buttons([["Leave it", func() -> void: _submit({"place": false})], ["Place it", func() -> void: _submit({"place": true})]])
		"hook_target":
			_show_overlay("Hook", "Steal a random card from which pirate?")
			var specs: Array = []
			for q: int in decision.targets:
				specs.append(["%s (%d cards)" % [game.players[q].name, game.players[q].hand.size()], func() -> void: _submit({"target": q})])
			_overlay_buttons(specs)

## The cards of a stacked Row slot, fanned out (the Row's own card on the
## left), each with who put it there underneath.
func _telescope_fan(parent: HBoxContainer, ids: Array) -> void:
	var n := ids.size()
	var step := OVERLAY_CARD.x * 0.72
	var fan := Control.new()
	fan.custom_minimum_size = Vector2(OVERLAY_CARD.x + step * (n - 1) + 40.0, OVERLAY_CARD.y + 46.0)
	parent.add_child(fan)
	for k in n:
		var id: int = ids[k]
		var spread := k - (n - 1) / 2.0
		var view := _overlay_card(fan, id, func() -> void: _submit({"index": k}), false)
		view.position = Vector2(20.0 + step * k, 6.0 + absf(spread) * 8.0)
		view.pivot_offset = Vector2(OVERLAY_CARD.x / 2.0, OVERLAY_CARD.y)
		view.rotation_degrees = spread * 6.0
		var who := _rich(14)
		who.fit_content = true
		who.mouse_filter = MOUSE_FILTER_IGNORE
		who.custom_minimum_size.x = step + 8.0
		who.position = Vector2(20.0 + step * k + (OVERLAY_CARD.x - who.custom_minimum_size.x) / 2.0, OVERLAY_CARD.y + 18.0)
		who.text = "[center]%s[/center]" % _row_origin(id)
		fan.add_child(who)

## Row slot `slot` face down: who put each of its cards there (bottom first),
## for its tooltip. Public: stacking and swapping are done in the open.
func _slot_story(slot: int) -> String:
	var cards: Array = game.row[slot].cards
	var lines: Array[String] = ["Round %d · face down%s" % [slot + 1, "" if cards.size() == 1 else ", %d cards" % cards.size()]]
	for id: int in cards:
		var origin: Dictionary = game.row_origins.get(id, {})
		if origin.is_empty():
			lines.append("• Dealt with the Row")
			continue
		var p: int = origin.player
		var who: String = "you" if p == _seat else game.players[p].name
		if origin.via == "swap":
			lines.append("• Swapped in by %s (Telescope)" % who)
		else:
			lines.append("• %s Windfall, stacked" % ("Your" if p == _seat else who + "'s"))
	if cards.size() > 1:
		lines.append("All are revealed together at the start of round %d." % (slot + 1))
	return "\n".join(lines)

## Who put a face-down Row card there, as shown under the Telescope's fan.
func _row_origin(id: int) -> String:
	var origin: Dictionary = game.row_origins.get(id, {})
	if origin.is_empty():
		return "Row card"
	var p: int = origin.player
	if origin.via == "swap":
		return "Swapped in by you" if p == _seat else "Swapped in by %s" % _who(p)
	return "Your Windfall" if p == _seat else "%s's Windfall" % _who(p)

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
	var discards: int = decision.discards
	if discards > 0:
		sub = "[color=#ffd36b]Compass:[/color] click the card to keep, then %s to discard." % ("a card" if discards == 1 else "%d cards" % discards)
		if decision.can_use_compass:
			sub += " Or use another Compass first."
	# The last card, and nothing else to do: shown a moment, then taken.
	var last: bool = pl.draft_hand.size() == 1 and discards == 0 \
			and not decision.can_use_compass and not decision.can_redraw
	if last:
		sub = "The last card of the draft is yours."
	var cards := _show_overlay("Draft — round %d" % game.round_index, sub)
	if last:
		var id: int = pl.draft_hand[0]
		_overlay_card(cards, id, func() -> void: _submit({"pick": id}), true, OVERLAY_CARD)
		var take := _primary(_button("Take it", func() -> void: _submit({"pick": id})))
		take.add_theme_font_size_override("font_size", _fs(17))
		_overlay_corner(take)
		_auto_take_last(decision, id, take)
		return
	if decision.can_redraw:
		var redraw := _button("Redraw all", func() -> void: _submit({"redraw": true}))
		redraw.tooltip_text = "Not happy with this hand? Discard it and draw a new one, once."
		_overlay_corner(redraw)
	var pick: int = _selected[0] if _selected.size() > 0 else -1
	var drops := _selected.slice(1)
	for id: int in pl.draft_hand:
		var view := _overlay_card(cards, id, func() -> void: _on_draft_card(id, decision), true, _overlay_size(pl.draft_hand.size()))
		if id == pick:
			view.mark = CardView.Mark.SELECTED
			view.set_caption("Keep")
		elif drops.has(id):
			view.mark = CardView.Mark.PAYMENT
			view.set_caption("Discard")
	# The Compass's buttons together at the top right, Confirm last.
	if decision.can_use_compass:
		_overlay_corner(_compass_button())
	if discards > 0:
		var confirm := _primary(_button("Confirm", func() -> void: _submit({"pick": pick, "discards": drops}), pick >= 0 and drops.size() == discards))
		confirm.add_theme_font_size_override("font_size", _fs(17))
		_overlay_corner(confirm)

## Green like "New game", with the Compass icon, at the top right.
func _compass_button() -> Button:
	var button := _button("Use Compass (%d left)" % game.compasses_available(_seat), func() -> void: _submit({"use_compass": true}))
	button.tooltip_text = SYMBOL_TIPS["fx-compass"]
	_primary(button)
	# Only its look: Enter should not spend a Compass (it confirms the pick).
	button.remove_meta("primary")
	button.icon = load(ICONS + "fx-compass.png") as Texture2D
	button.add_theme_constant_override("icon_max_width", roundi(24 * ICON_SCALE))
	button.add_theme_constant_override("h_separation", 8)
	button.add_theme_font_size_override("font_size", _fs(17))
	return button

const AUTO_PICK_TIME := 2.5

## Takes the last draft card for you once its bar on `button` has run down
## (from when it was first shown; a re-render keeps the time left). While
## the choice is put aside, it waits.
func _auto_take_last(decision: Dictionary, id: int, button: Button) -> void:
	var first := not is_same(_auto_pick.get("decision"), decision)
	if first:
		_auto_pick = {"decision": decision, "at": Time.get_ticks_msec() + int(AUTO_PICK_TIME * 1000.0)}
	var left := maxf(0.0, (_auto_pick.at - Time.get_ticks_msec()) / 1000.0)
	_countdown_bar(button, left, AUTO_PICK_TIME)
	if not first:
		return # its timer is already running
	await get_tree().create_timer(AUTO_PICK_TIME).timeout
	while is_inside_tree() and (_overlay_hidden or _hold_choices):
		await get_tree().process_frame
	if not is_inside_tree() or not is_same(game.pending.get(_seat), decision) or _choice_sent():
		return
	_submit({"pick": id})

## Without a Compass drawn, a click picks. With one or more: the first card
## clicked is kept, the next ones (one per Compass) discarded; click again to
## unmark.
func _on_draft_card(id: int, decision: Dictionary) -> void:
	if decision.discards == 0:
		_submit({"pick": id})
		return
	if _selected.is_empty():
		_selected.append(id)
	elif _selected[0] == id:
		_selected.clear()
	elif _selected.has(id):
		_selected.erase(id)
	elif _selected.size() <= decision.discards:
		_selected.append(id)
	else:
		_selected[-1] = id # all chosen: swap the last discard
	_render_overlay()

func _render_game_over() -> void:
	if is_instance_valid(_finale):
		return
	# After everything queued (a Battle, a claim, a Hook...) has played out.
	if _hold_choices or _stage_busy():
		get_tree().create_timer(0.3).timeout.connect(_render_game_over)
		return
	if _finale_cued:
		return
	# The end piece starts a moment before the result comes up (it fades in
	# itself); then silence, until the menu brings the title music back.
	_finale_cued = true
	_music.cut_to(Music.END, 0.8)
	await get_tree().create_timer(1.0).timeout
	if game != null and game.phase == DeckhandGame.Phase.GAME_OVER and not is_instance_valid(_finale):
		_build_finale()

func _show_finale() -> void:
	if is_instance_valid(_finale):
		_finale.visible = true

## The end of the game: the table dims, the result pops in, your rank is
## stamped in wax, and the score sheet counts up, last place first.
func _build_finale() -> void:
	var winners := game.winners()
	var won := winners.has(_seat)
	_sfx.play("victory" if won else "defeat")
	_finale = CanvasLayer.new()
	_finale.layer = 7
	add_child(_finale)
	var root := Control.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.theme = theme
	_finale.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.0, 0.78)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.modulate.a = 0.0
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.6)
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	root.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	# The result.
	var headline := "Victory!" if won else "Defeat"
	if won and winners.size() > 1:
		headline = "Shared victory!"
	var title := _label(headline, 72, GOLD if won else Color(0.9, 0.45, 0.38), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02))
	title.add_theme_constant_override("outline_size", 12)
	if won:
		_shine(title, 2.4, 1.0, true)
	column.add_child(title)
	var top: Dictionary = game.final_scores[0]
	var who := "You" if winners.size() == 1 and won else " & ".join(winners.map(func(p: int) -> String: return "you" if p == _seat else _who(p)))
	var sub := _rich(22)
	sub.fit_content = true
	sub.add_theme_color_override("default_color", Color(1, 0.94, 0.82))
	sub.text = "[center]%s %s with [b][color=#ffd36b]%d VP[/color][/b][/center]" % [who, "win" if winners.size() > 1 or won else "wins", top.score]
	column.add_child(sub)

	# Your rank, stamped in wax.
	var seal := _rank_seal(DeckhandGame.rank_for(game.score(_seat)), won)
	seal.size_flags_horizontal = SIZE_SHRINK_CENTER
	column.add_child(seal)

	# The score sheet, on dark wood for contrast.
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.035, 0.96)
	style.border_color = Color(0.85, 0.66, 0.32)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	column.add_child(panel)
	var sheet := GridContainer.new()
	sheet.columns = 6
	sheet.add_theme_constant_override("h_separation", 34)
	sheet.add_theme_constant_override("v_separation", 10)
	panel.add_child(sheet)
	for heading in ["", "Crew cards", "Infamy", "Multipliers", "Total", _img("fx-tentacle", 20)]:
		sheet.add_child(_sheet_cell("[color=#e8c27a][b]%s[/b][/color]" % heading, 15))
	var count := game.final_scores.size()
	for row in count:
		var entry: Dictionary = game.final_scores[row]
		var p: int = entry.player
		var parts := game.score_breakdown(p)
		var winner: bool = winners.has(p)
		var name := ("[color=#ffd36b]★[/color] " if winner else "") + ("[b]You[/b]" if p == _seat else "[b]%s[/b]" % _who(p))
		var gold := "#ffd36b" if winner else "#fff2dc"
		var cells: Array[RichTextLabel] = [
			_sheet_cell(name, 20, false),
			_sheet_cell("", 20), _sheet_cell("", 20), _sheet_cell("", 20),
			_sheet_cell("", 24),
			_sheet_cell("[color=#fff2dc]%d[/color]" % entry.tentacles, 18),
		]
		var values := [parts.crew, parts.infamy, parts.multipliers, entry.score]
		# Pirates appear one after another, last place first, counting up.
		var delay := 1.4 + 0.55 * (count - 1 - row)
		for i in cells.size():
			var cell := cells[i]
			sheet.add_child(cell)
			cell.modulate.a = 0.0
			var tween := cell.create_tween()
			tween.tween_interval(delay)
			tween.tween_property(cell, "modulate:a", 1.0, 0.25)
			if i >= 1 and i <= 4:
				var value: int = values[i - 1]
				var fmt := "[b][color=%s]%%d VP[/color][/b]" % gold if i == 4 else "[color=#fff2dc]%d[/color]"
				tween.parallel().tween_method(func(v: float) -> void: cell.text = "[center]%s[/center]" % (fmt % roundi(v)), 0.0, float(value), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		get_tree().create_timer(delay).timeout.connect(func() -> void: _sfx.play("coin", -8.0))

	# Leave it, or sail again.
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	var view := _big(_button("View the table", func() -> void: _finale.visible = false))
	buttons.add_child(view)
	buttons.add_child(_big(_primary(_button("New game", _open_menu))))

	# The entrance.
	for i in column.get_child_count():
		var part: Control = column.get_child(i)
		if part == seal:
			continue
		part.modulate.a = 0.0
		part.create_tween().tween_property(part, "modulate:a", 1.0, 0.4).set_delay(0.3 + 0.15 * i)
	title.pivot_offset = title.get_combined_minimum_size() / 2.0
	title.create_tween().tween_property(title, "scale", Vector2.ONE, 0.7).from(Vector2(0.4, 0.4)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3)
	var stamp := seal.create_tween()
	seal.modulate.a = 0.0
	seal.pivot_offset = seal.custom_minimum_size / 2.0
	stamp.tween_interval(0.9)
	stamp.tween_property(seal, "modulate:a", 1.0, 0.1)
	stamp.parallel().tween_property(seal, "scale", Vector2.ONE, 0.25).from(Vector2(2.4, 2.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# It lands heavily: squashes a little, and the whole table shakes.
	stamp.tween_callback(func() -> void:
		_sfx.play("card_place")
		seal.pivot_offset = Vector2(seal.custom_minimum_size.x / 2.0, seal.custom_minimum_size.y))
	stamp.tween_property(seal, "scale", Vector2(1.08, 0.9), 0.05).set_ease(Tween.EASE_OUT)
	stamp.tween_property(seal, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(1.15).timeout.connect(func() -> void: _shake(center, 9.0, 0.5))
	# A winner's celebration: fireworks over the finale, around the title.
	if won:
		var tints := [Color(1.0, 0.55, 0.15), Color(1.0, 0.3, 0.2), Color(1.0, 0.8, 0.3), Color(0.95, 0.95, 1.0)]
		for k in 16:
			get_tree().create_timer(0.6 + k * 0.32 + randf() * 0.15).timeout.connect(func() -> void:
				if not is_instance_valid(_finale) or not _finale.visible:
					return
				var screen := get_viewport_rect().size
				var side := -1.0 if k % 2 == 0 else 1.0
				var at := Vector2((0.5 + side * randf_range(0.12, 0.38)) * screen.x, randf_range(0.08, 0.45) * screen.y)
				CardMotion.firework(root, at, tints[k % tints.size()])
				_sfx.play("coin", -14.0, 0.3))

## Shakes `node` as if something heavy just landed: `strength` pixels at
## first, settling over `seconds`.
func _shake(node: Control, strength: float, seconds: float) -> void:
	if not is_instance_valid(node):
		return
	var shake := node.create_tween()
	shake.tween_method(func(t: float) -> void:
		var fade := (1.0 - t) * (1.0 - t)
		node.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * fade, 0.0, 1.0, seconds)
	shake.tween_callback(func() -> void: node.position = Vector2.ZERO)

## The wax seal with your rank on it; a winner's glows, rays turning behind.
func _rank_seal(rank: String, won: bool) -> Control:
	var seal := _wax_seal(Vector2(200, 242))
	_shine(seal.get_child(0), 3.0, 0.0, true)
	if won:
		var rays := ColorRect.new()
		rays.material = ShaderMaterial.new()
		Effects.use(rays.material, RAYS_SHADER, true)
		rays.mouse_filter = MOUSE_FILTER_IGNORE
		rays.show_behind_parent = true
		rays.size = Vector2(520, 520)
		rays.position = seal.custom_minimum_size * Vector2(0.5, 0.4) - rays.size / 2.0
		seal.add_child(rays)
		seal.move_child(rays, 0)
	var text := _seal_text(seal)
	text.add_theme_font_size_override("normal_font_size", _fs(19))
	text.add_theme_font_size_override("bold_font_size", _fs(19))
	text.text = "[center][font_size=%d]YOUR RANK[/font_size]\n[b]%s[/b][/center]" % [_fs(12), rank]
	return seal

## The VP seal art at `seal_size`.
func _wax_seal(seal_size: Vector2) -> Control:
	var seal := Control.new()
	seal.custom_minimum_size = seal_size
	seal.mouse_filter = MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = VP_SEAL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(PRESET_FULL_RECT)
	art.mouse_filter = MOUSE_FILTER_IGNORE
	seal.add_child(art)
	return seal

## Light text pressed into the seal's disc (above its ribbons).
func _seal_text(seal: Control) -> RichTextLabel:
	var text := _rich(16)
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = MOUSE_FILTER_IGNORE
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_color_override("default_color", Color(1, 0.9, 0.72))
	text.add_theme_color_override("font_outline_color", Color(0.22, 0.02, 0.02))
	text.add_theme_constant_override("outline_size", 6)
	text.anchor_left = 0.14
	text.anchor_right = 0.86
	text.anchor_top = 0.1
	text.anchor_bottom = 0.68
	seal.add_child(text)
	return text

## Gives `node` the gold gleam (and, with `gild`, gold letters); `smooth`
## runs it at the full frame rate (see Effects.use).
func _shine(node: CanvasItem, period: float, gild: float = 1.0, smooth: bool = false) -> void:
	var material := ShaderMaterial.new()
	Effects.use(material, SHINE_SHADER, smooth)
	material.set_shader_parameter("period", period)
	material.set_shader_parameter("gild", gild)
	node.material = material
	var control := node as Control
	var fit := func() -> void: material.set_shader_parameter("size", control.size)
	control.resized.connect(fit)
	fit.call()

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
		if is_instance_valid(view) and view.is_inside_tree() and view.is_visible_in_tree() and not poses.has(view.card_id) and not _in_spotlight.has(view.card_id) and not _fresh.has(view.card_id):
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
	_fresh.clear() # the snapshot was taken without them
	var flying: Dictionary = snapshot.flying
	# Cards a Telescope placed, claimed or contested at once: from where they
	# were seen (its dialog) to their Row slot first.
	for id: int in _placing.keys():
		if poses.has(id) and _resolve_placed(id, poses[id]):
			poses = poses.duplicate()
			poses.erase(id)
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
	# Hands were passed, even if a waiting dialog stood in between.
	var draft_passed := _hands_passed and game.phase == DeckhandGame.Phase.DRAFT
	var burned := 0
	for id: int in poses:
		if not present.has(id):
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
	if game.phase != DeckhandGame.Phase.DRAFT:
		_hands_passed = false
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
			_hands_passed = false
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
## `on_show`: called as the band comes on, after the last round's Hooks.
func _round_title(round_number: int, wind: int, delay: float, on_show: Callable = Callable()) -> void:
	var title := "Round %d" % round_number if round_number < DeckhandGame.ROUNDS else "Final round"
	var wind_text := "The wind blows %s" % ("clockwise" if wind == 1 else "counter-clockwise")
	# The round's first choice (the draft) is dealt once the title has gone.
	_band(title, GOLD, wind_text, delay, true, {"after_hooks": true, "on_show": on_show})

## A band across the middle of the table: `title`, and a `subtitle` (BBCode)
## under it. It opens, holds a moment and fades, letting clicks through.
## Bands queue up behind one another; with `hold`, choices wait for it.
## Options:
##   ok: stays longer, with an OK button (or a click on the band) to dismiss
##     it sooner; a bar in the button runs down the time left.
##   extra: a Control shown under the title.
##   footer: BBCode on the OK button's line, left of it.
##   on_close: called once the band has gone.
##   read_time: how long it stays (with ok; default BAND_READ_TIME).
##   after_landing: waits for your cards on their way to the crew first.
##   after_hooks: waits for Hook ceremonies still to take the stage first.
##   on_show: called when the band's turn comes, before it opens.
##   icon: an icon name (assets/icons) shown on both sides of the title.
##   compose: called when the band's turn comes; returns {title, subtitle}
##     and any options above, overriding the ones given.
func _band(title_text: String, color: Color, subtitle: String, delay: float, hold: bool, opts: Dictionary = {}) -> void:
	var ok: bool = opts.get("ok", false)
	var read_time: float = opts.get("read_time", BAND_READ_TIME)
	var g := game
	_bands_queued += 1
	if hold:
		_band_holds += 1
		_hold_choices = true
	if opts.has("compose"):
		await get_tree().process_frame # what comes in together, together
		if not is_inside_tree():
			return
	if opts.get("after_landing", false):
		await _landings_done() # before the ticket (see _hook_ceremony)
		if not is_inside_tree():
			return
	if opts.get("after_hooks", false):
		# A Hook takes its ticket a little after its event: let it.
		while _hooks_waiting > 0 and is_inside_tree():
			await get_tree().process_frame
		if not is_inside_tree():
			return
	var ticket := _stage_take()
	await _stage_wait(ticket)
	if not is_inside_tree() or not is_same(g, game):
		return # closed, or a new game started meanwhile (its stage is new)
	var compose: Callable = opts.get("compose", Callable())
	if compose.is_valid():
		# Made now, on its turn: what came in meanwhile is merged in.
		var made: Dictionary = compose.call()
		title_text = made.get("title", title_text)
		subtitle = made.get("subtitle", subtitle)
		opts.merge(made, true)
	var on_show: Callable = opts.get("on_show", Callable())
	if on_show.is_valid():
		on_show.call()
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_title_layer = layer
	var on_close: Callable = opts.get("on_close", Callable())
	layer.tree_exited.connect(func() -> void:
		_stage_leave(ticket)
		if is_same(g, game): # (a new game starts its count afresh)
			_bands_queued -= 1
		if on_close.is_valid() and is_inside_tree():
			on_close.call()
		if hold:
			_band_holds -= 1
		_release_hold())
	var band := PanelContainer.new()
	band.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.035, 0.02, 0.86)
	style.border_color = Color(color, 0.8)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 30
	style.content_margin_top = 30 if ok else 18
	style.content_margin_bottom = 30 if ok else 18
	band.add_theme_stylebox_override("panel", style)
	band.set_anchors_preset(PRESET_CENTER)
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.grow_vertical = GROW_DIRECTION_BOTH
	layer.add_child(band)
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.mouse_filter = MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 14 if ok else 4)
	band.add_child(lines)
	var title := _label(title_text, 46, color)
	title.add_theme_font_override("font", load(FONT_TITLE))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	title.add_theme_constant_override("outline_size", 8)
	var title_node: Control = title # what slides in
	var icon_name: String = opts.get("icon", "")
	if icon_name.is_empty():
		lines.add_child(title)
	else:
		# The title between two of its icons.
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 22)
		for i in range(2):
			var icon := TextureRect.new()
			icon.texture = load(ICONS + icon_name + ".png")
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(56, 56)
			icon.size_flags_vertical = SIZE_SHRINK_CENTER
			icon.mouse_filter = MOUSE_FILTER_IGNORE
			row.add_child(icon)
			if i == 0:
				row.add_child(title)
		lines.add_child(row)
		title_node = row
	var extra: Control = opts.get("extra")
	if extra != null:
		extra.size_flags_horizontal = SIZE_SHRINK_CENTER
		lines.add_child(extra)
	if not subtitle.is_empty():
		var sub := _band_text(subtitle)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.text = "[center]%s[/center]" % subtitle
		lines.add_child(sub)
	band.pivot_offset = Vector2(get_viewport_rect().size.x / 2.0, band.get_combined_minimum_size().y / 2.0)
	band.modulate.a = 0.0
	var tween := band.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(band, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(band, "scale:y", 1.0, 0.3).from(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(title_node, "position:x", title_node.position.x, 0.5).from(title_node.position.x - 60.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(read_time if ok else (1.1 if hold else 1.8))
	tween.tween_property(band, "modulate:a", 0.0, 0.45)
	tween.tween_callback(layer.queue_free)
	if not ok:
		return
	var dismiss := func() -> void:
		if not tween.is_valid():
			return
		tween.kill()
		var out := band.create_tween()
		out.tween_property(band, "modulate:a", 0.0, 0.2)
		out.tween_callback(layer.queue_free)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 28)
	row.size_flags_horizontal = SIZE_SHRINK_CENTER
	lines.add_child(row)
	var footer: String = opts.get("footer", "")
	if not footer.is_empty():
		var text := _band_text(footer)
		text.autowrap_mode = TextServer.AUTOWRAP_OFF
		text.size_flags_vertical = SIZE_SHRINK_CENTER
		text.size_flags_horizontal = SIZE_SHRINK_BEGIN
		text.text = footer
		row.add_child(text)
	var button := _primary(_button("OK", dismiss))
	button.focus_mode = FOCUS_NONE # the keyboard stays on the hand
	button.custom_minimum_size.x = 120
	button.size_flags_horizontal = SIZE_SHRINK_CENTER
	row.add_child(button)
	_band_ok = button
	_band_dismiss = dismiss
	_band_since = Time.get_ticks_msec() + int(delay * 1000.0)
	_badge(button, "O") # O, Enter or Space (see _input)
	_countdown_bar(button, read_time, read_time, delay + 0.25)
	band.mouse_filter = MOUSE_FILTER_STOP
	band.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			dismiss.call())

## The time left on `button`: a thin bar along its foot, inside its rim and
## following its rounded corners, running down from `left` (of `total`
## seconds) to empty, after `delay`.
func _countdown_bar(button: Button, left: float, total: float, delay: float = 0.0) -> void:
	var countdown_started := [false]
	var frame := button.get_theme_stylebox("normal") as StyleBoxFlat
	var rim_l := frame.border_width_left if frame else 0
	var rim_r := frame.border_width_right if frame else 0
	var rim_b := frame.border_width_bottom if frame else 0
	var bar := Panel.new()
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.72, 0.95, 0.62, 0.9)
	if frame:
		fill.corner_radius_bottom_left = maxi(0, frame.corner_radius_bottom_left - rim_b)
		fill.corner_radius_bottom_right = maxi(0, frame.corner_radius_bottom_right - rim_b)
	fill.anti_aliasing = frame.anti_aliasing if frame else true
	bar.add_theme_stylebox_override("panel", fill)
	button.add_child(bar)
	var start := clampf(left / total, 0.0, 1.0) if total > 0.0 else 0.0
	var fit := func(share: float) -> void:
		if not is_instance_valid(bar):
			return
		var height := 4.0
		bar.position = Vector2(rim_l, button.size.y - rim_b - height)
		bar.size = Vector2(maxf(0.0, (button.size.x - rim_l - rim_r) * share), height)
	fit.call(start)
	button.resized.connect(func() -> void:
		if not countdown_started[0]:
			fit.call(start)) # laid out after it was made
	var countdown := bar.create_tween()
	countdown.tween_interval(maxf(delay, 0.001))
	countdown.tween_callback(func() -> void: countdown_started[0] = true)
	countdown.tween_method(fit, start, 0.0, maxf(left, 0.001))

## A line of BBCode text for a band.
func _band_text(bbcode: String) -> RichTextLabel:
	var text := _rich(19)
	text.fit_content = true
	text.mouse_filter = MOUSE_FILTER_IGNORE
	text.add_theme_color_override("default_color", Color(0.95, 0.88, 0.72))
	return text

## A click on a hand card while a band with an OK is up: in its first
## moment the click is ignored (it was surely not meant for the new band);
## after that it closes the band and goes through. Whether it goes through.
func _hand_click_passes() -> bool:
	if not is_instance_valid(_band_ok) or not _band_ok.is_visible_in_tree() or not _band_dismiss.is_valid():
		return true
	if Time.get_ticks_msec() - _band_since < BAND_CLICK_GRACE_MS:
		return false
	_band_dismiss.call()
	return true

const BAND_CLICK_GRACE_MS := 1000

## How long a band with an OK button stays up, unless dismissed.
const BAND_READ_TIME := 5.0

## Whether a band is on screen. (A band that has just left the tree is still
## a valid object until the end of the frame: waiting for it to exit again
## would wait forever.)
## Something is on stage or waiting for it.
func _stage_busy() -> bool:
	return _stage_now < _stage_next or _hooks_waiting > 0 or _bands_queued > 0 or _band_up()

func _band_up() -> bool:
	return is_instance_valid(_title_layer) and _title_layer.is_inside_tree()

## A Battle is announced: when and how it will be fought. Battles announced
## before the band shows share it.
func _battle_announced(p: int, source: int = -1) -> void:
	# Its card glows from now (once at rest) until the Battle is fought: on
	# from its other effects (a Hook) without a gap before the band.
	_glow_battle(source, p)
	if _announce_batch != null:
		_announce_batch.counts[p] = _announce_batch.counts.get(p, 0) + 1
		return
	var batch := {"counts": {p: 1}}
	_announce_batch = batch
	_band("", BATTLE_COLOR, "", 0.0, false, {"ok": true, "after_landing": true, "icon": "fx-battle",
		"compose": func() -> Dictionary:
			if is_same(_announce_batch, batch):
				_announce_batch = null
			_sfx.play("battle", -10.0 if batch.counts.has(_seat) else -16.0)
			return _announce_text(batch.counts),
	})

## The announcement band for Battles by pirate ({player: count}).
func _announce_text(counts: Dictionary) -> Dictionary:
	var total := 0
	for q: int in counts:
		total += counts[q]
	var title: String
	if total == 1:
		title = "You announce a Battle!" if counts.has(_seat) else "A Battle is announced!"
	else:
		title = "%d Battles are announced!" % total
	var whens: Array[String] = []
	for q: int in counts:
		var when := "[b]your next build[/b]" if q == _seat else "[b]%s's next build[/b]" % _who(q)
		if counts[q] > 1:
			when += " (%d Battles)" % counts[q]
		whens.append(when)
	var list := ", ".join(whens.slice(0, -1)) + " and " + whens[-1] if whens.size() > 1 else whens[0]
	if total == 1:
		return {"title": title, "subtitle": "On %s, whoever builds the best card draws a card." % list}
	return {"title": title, "subtitle": "On %s.\nEach time, whoever builds the best card draws a card." % list}

## A Battle is fought: each builder's score, and who wins. Battles fought
## together (same build: same cards, same winner) share one band, the cards
## drawn added up.
## `count`: the cards drawn; `battles`: how many Battles were fought (a
## pirate's Battles announced together are fought at once).
func _battle_fought(p: int, winner: int, scores: Dictionary, count: int, details: Dictionary = {}, battles: int = 1) -> void:
	# Cards you draw (the last ones in your hand) stay hidden until the band
	# has gone, then come from the Supply.
	var drawn: Array = []
	if winner == _seat and count > 0:
		var hand: Array = game.players[_seat].hand
		drawn = hand.slice(max(0, hand.size() - count))
		for id: int in drawn:
			_in_spotlight[id] = true
	# The cards that announced this pirate's Battles glow on until its
	# result band goes.
	var fought: Array = []
	for id: int in _battle_glow:
		if _battle_glow[id].player == p and not _battle_glow[id].fought:
			_battle_glow[id].fought = true
			fought.append(id)
	if _result_batch != null:
		_result_batch.fought.append_array(fought)
		_result_batch.count += count
		_result_batch.battles += battles
		_result_batch.drawn.append_array(drawn)
		return
	var batch := {"winner": winner, "scores": scores, "details": details, "count": count, "battles": battles, "drawn": drawn, "fought": fought}
	_result_batch = batch
	_band("", BATTLE_COLOR, "", 0.0, false, {"ok": true, "after_landing": true, "icon": "fx-battle",
		"read_time": BAND_READ_TIME * 1.3, # a table to read
		"compose": func() -> Dictionary:
			if is_same(_result_batch, batch):
				_result_batch = null
			_sfx.play("battle")
			return _result_band(batch),
	})

## The result band for a batch of Battles fought together.
func _result_band(batch: Dictionary) -> Dictionary:
	var winner: int = batch.winner
	var scores: Dictionary = batch.scores
	var count: int = batch.count
	var many: bool = batch.battles > 1
	var cards := "%d card%s" % [count, "" if count == 1 else "s"]
	var title: String
	var outcome: String
	if winner < 0:
		title = "%d Battles: a tie" % batch.battles if many else "Battle: a tie"
		outcome = "Nobody draws."
	elif winner == _seat:
		title = "You win %d Battles!" % batch.battles if many else "You win the Battle!"
		outcome = "[color=#ffd36b]You draw %s.[/color]" % cards
	else:
		var name: String = game.players[winner].name
		title = "%s wins %d Battles" % [name, batch.battles] if many else "%s wins the Battle" % name
		outcome = "%s draws %s." % [_who(winner), cards]
	if winner >= 0 and scores.values().count(scores[winner]) > 1:
		outcome = "Tie broken by Tentacles. " + outcome
	return {"title": title, "extra": _battle_table(winner, scores, batch.details), "footer": outcome,
		"on_close": func() -> void:
			_deal_from_supply(batch.drawn)
			for id: int in batch.fought:
				_unglow_battle(id)}

const BATTLE_COLOR := Color(1.0, 0.55, 0.4)

## Cards already in your hand, hidden meanwhile, dealt in from the Supply
## (the refresh deals a hand card it had not seen from its deck).
func _deal_from_supply(ids: Array) -> void:
	if ids.is_empty() or not is_inside_tree():
		return
	for id: int in ids:
		_in_spotlight.erase(id)
		_fresh[id] = true # on the table all along, hidden: not "stayed put"
	_queue_refresh()
	_sfx.play("card_deal", -2.0)

# --- Active cards: a halo while a card's effect resolves --------------------

const ACTIVE_PULSE := 1.6 # a quick effect (a draw): how long its card glows

## Card `id` glows (`on`) or stops (each reason counted: it glows while any
## remains).
func _set_active(id: int, on: bool) -> void:
	if id < 0:
		return
	var n: int = _active.get(id, 0) + (1 if on else -1)
	if n > 0:
		_active[id] = n
	else:
		_active.erase(id)
	for view in _card_views:
		if is_instance_valid(view) and view.card_id == id:
			view.active = n > 0

## Card `id` glows for `seconds`, once it is at rest in its crew (a card
## still flying there, shown mid-table first, or your cards still landing).
## With `player`, that pirate's glows take turns (two cards drawing at once).
## With `cause` (the card whose arrival set it off), both glow together.
func _pulse_active(id: int, seconds: float = ACTIVE_PULSE, player: int = -1, cause: int = -1) -> void:
	if id < 0 or not is_inside_tree():
		return
	var waited := 0.0
	while is_inside_tree() and waited < LANDING_TIMEOUT and not (_rests_in_crew(id) and (cause < 0 or _rests_in_crew(cause))):
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not is_inside_tree():
		return
	var g := game
	if player >= 0:
		var now := Time.get_ticks_msec()
		var start: int = maxi(now, _glow_free_at.get(player, 0))
		_glow_free_at[player] = start + int((seconds + 0.2) * 1000.0)
		if start > now:
			await get_tree().create_timer((start - now) / 1000.0).timeout
			if not is_inside_tree() or not is_same(g, game):
				return
	_set_active(id, true)
	_set_active(cause, true)
	await get_tree().create_timer(seconds).timeout
	if is_inside_tree() and is_same(g, game):
		_set_active(id, false)
		_set_active(cause, false)

## Card `id` announced a Battle for `player`: it glows, once at rest in the
## crew, until that Battle is fought.
func _glow_battle(id: int, player: int) -> void:
	if id < 0 or _battle_glow.has(id) or game.players[player].pending_battles == 0:
		return # (fought already)
	var g := game
	var glow := {"player": player, "fought": false, "lit": false}
	_battle_glow[id] = glow
	var waited := 0.0
	while is_inside_tree() and waited < LANDING_TIMEOUT and not _rests_in_crew(id):
		await get_tree().process_frame
		waited += get_process_delta_time()
	if is_inside_tree() and is_same(g, game) and is_same(_battle_glow.get(id), glow):
		glow.lit = true
		_set_active(id, true)

func _unglow_battle(id: int) -> void:
	var glow: Variant = _battle_glow.get(id)
	if glow == null:
		return
	_battle_glow.erase(id)
	if glow.lit:
		_set_active(id, false)

func _rests_in_crew(id: int) -> bool:
	if not _card_settled(id):
		return false
	return not (game.players[_seat].crew.has(id) and not _landing.is_empty())

## Cards whose effect waits on a pirate's choice (a Telescope, a choice of
## three, a Hook's target) glow until it is made, from when they are at rest.
func _track_pending_sources() -> void:
	var now := {}
	for p: int in game.pending:
		var source: int = (game.pending[p] as Dictionary).get("source", -1)
		if source >= 0:
			now[source] = true
	for id: int in _pending_sources.keys():
		if not now.has(id):
			if _pending_sources[id]:
				_set_active(id, false)
			_pending_sources.erase(id)
	for id: int in now:
		if not _pending_sources.has(id):
			_pending_sources[id] = false # lit once it has landed
			_light_pending(id)

func _light_pending(id: int) -> void:
	var g := game
	var waited := 0.0
	while is_inside_tree() and waited < LANDING_TIMEOUT and not _rests_in_crew(id):
		await get_tree().process_frame
		waited += get_process_delta_time()
	if is_inside_tree() and is_same(g, game) and _pending_sources.get(id) == false:
		_pending_sources[id] = true
		_set_active(id, true)

# --- Landing: a card's effects wait for it to reach your crew ---------------

## A card joins your crew: until it has landed there (flown from your hand,
## or shown mid-table first when claimed), its effects wait: choices are held,
## cards it draws stay hidden, and Hook and Battle moments queue behind it.
func _await_landing(id: int) -> void:
	var gate := {"id": id, "draws": []}
	_landing.append(gate)
	_spotlights += 1
	_hold_choices = true
	# The refresh lays the card out, and its flight starts a frame later.
	for _i in range(3):
		await get_tree().process_frame
		if not is_inside_tree():
			return
	var waited := 0.0
	while not _card_settled(id) and waited < LANDING_TIMEOUT:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		# Waiting its turn to be shown mid-table moves with the stage, which
		# always moves on: only the rest counts towards the timeout.
		if not (_claimed.has(id) or _in_spotlight.has(id)):
			waited += get_process_delta_time()
	if not _landing.has(gate):
		return # a new game started meanwhile
	# Still a gate meanwhile: Hooks and Battles wait for the draws too.
	await _play_draws(gate)
	if not _landing.has(gate):
		return
	_landing.erase(gate)
	_spotlights -= 1
	_release_hold()

const DRAW_GLOW_LEAD := 0.35 # a card glows a moment before its cards are dealt
const DRAW_STEP := 1.0 # then glows on while they fly to the hand

## The cards drawn while a card was landing, dealt card by card that drew
## them: each glows as its cards come from the deck, one after another.
func _play_draws(gate: Dictionary) -> void:
	for group: Dictionary in gate.draws:
		if not is_inside_tree() or not _landing.has(gate):
			return
		var cause: int = group.get("cause", -1)
		_set_active(group.source, true)
		_set_active(cause, true)
		await get_tree().create_timer(DRAW_GLOW_LEAD).timeout
		if not is_inside_tree() or not _landing.has(gate):
			return
		_deal_from_supply(group.cards)
		await get_tree().create_timer(DRAW_STEP).timeout
		if not is_inside_tree() or not _landing.has(gate):
			return
		_set_active(group.source, false)
		_set_active(cause, false)

const LANDING_TIMEOUT := 8.0 # never hold the game on a lost animation

## Whether card `id` is at rest on the table (not waiting to be shown,
## shown mid-table, or flying).
func _card_settled(id: int) -> bool:
	return not (_claimed.has(id) or _lost.has(id) or _in_spotlight.has(id) or _motion.is_flying(id))

## Waits until none of your cards is still landing.
func _landings_done() -> void:
	while not _landing.is_empty() and is_inside_tree():
		await get_tree().process_frame

## The Battle's scores, one row per pirate: the card built, its value, the
## bonus from Battle symbols and the total (the winner's row in gold).
func _battle_table(winner: int, scores: Dictionary, details: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.mouse_filter = MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 4)
	var muted := Color(0.75, 0.68, 0.55)
	var headers: Array = ["Pirate", "Card built", "Value", "Battle bonus", "Total"] if not details.is_empty() else ["Pirate", "Total"]
	grid.columns = headers.size()
	for i in range(headers.size()):
		if headers[i] == "Battle bonus":
			# +1 per Battle symbol in the crew: the symbol itself.
			var rich := _rich(15)
			rich.fit_content = true
			rich.autowrap_mode = TextServer.AUTOWRAP_OFF
			rich.mouse_filter = MOUSE_FILTER_IGNORE
			rich.add_theme_color_override("default_color", muted)
			rich.text = "[center]+1 per %s[/center]" % _img("fx-battle", 16)
			grid.add_child(rich)
			continue
		var head := _label(headers[i], 15, muted)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i < 2 else HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(head)
	for q: int in scores:
		var won := q == winner
		var text_color := GOLD if won else Color(0.95, 0.88, 0.72)
		var cells: Array = ["You" if q == _seat else game.players[q].name]
		if not details.is_empty():
			var d: Dictionary = details.get(q, {})
			var card: int = d.get("card", -1)
			cells.append(CardDB.title(card) if card >= 0 else "—")
			cells.append(str(d.get("value", 0)))
			cells.append("+%d" % d.get("bonus", 0))
		cells.append(str(scores[q]))
		for i in range(cells.size()):
			var color: Color = PLAYER_COLORS[q % PLAYER_COLORS.size()] if i == 0 else text_color
			var cell := _label(cells[i], 18, color, i == 0 or i == cells.size() - 1)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i < 2 else HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(cell)
	return grid

## A claimed Infamy card: shown mid-table ("Silver Ines claims it!"), then
## off to its new owner's crew, glowing, landing in a puff of gold.
func _spotlight_claim(id: int, from: Dictionary, claimer: int) -> void:
	_in_spotlight[id] = true
	var who := "You claim it!" if claimer == _seat else "%s claims it!" % _who(claimer)
	var caption := "[center][font_size=%d][color=#ffd36b]%s[/color][/font_size][/center]" % [_fs(30), _fancy(who)]
	_spotlight(id, from, caption, claimer, func(pose: Dictionary) -> void:
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
		_motion.fly(id, pose, CardMotion.pose_of(target, true), options),
		true, null, 0.85, -1, -1, 1.7, func() -> void: _sfx.play("claim", 0.0 if claimer == _seat else -6.0))

## A contested Infamy card (a tie: nobody gets it): shown mid-table with who
## tied for it, then it burns away.
## A card a Telescope placed in the Row, claimed or contested at once (so
## never laid out there): it is first seen going from the Infamy deck to its
## slot, turning over, then `then` is called with its pose there. False if
## it was not placed.
func _show_placed(id: int, then: Callable, from: Dictionary = {}) -> bool:
	if not _placing.has(id):
		return false
	var slot: int = _placing[id]
	_placing.erase(id)
	var screen := get_viewport_rect().size
	if from.is_empty():
		# Placed by another pirate: from the Infamy deck.
		from = {"center": screen / 2.0, "size": PILE_CARD, "rotation": 0.0, "face_up": false}
		var pile: CardView = _pile_views.get("infamy")
		if is_instance_valid(pile) and pile.is_inside_tree():
			from = CardMotion.pose_of(pile, false)
	_place_flight(id, slot, from, then)
	return true

func _place_flight(id: int, slot: int, from: Dictionary, then: Callable) -> void:
	# The Row was just rebuilt: measure its slot once it is laid out.
	var g := game
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or not is_same(g, game):
		return
	var to := {"center": from.center, "size": ROW_CARD, "rotation": 0.0, "face_up": true}
	var slots := _row_box.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	if slot < slots.size() and (slots[slot] as Control).get_child_count() > 0:
		to.center = ((slots[slot] as Control).get_child(0) as Control).get_global_rect().get_center()
	_sfx.play("card_flip", -4.0)
	_motion.fly(id, from, to, {"duration": 0.8, "lift": 0.15, "arc": 50.0,
		"on_land": func(pose: Dictionary) -> void:
			# It lies in the Row a moment, then is claimed or contested.
			var stand_in := CardView.make(id, pose.size, true)
			stand_in.interactive = false
			stand_in.mouse_filter = MOUSE_FILTER_IGNORE
			stand_in.position = pose.center - pose.size / 2.0
			_motion.add_child(stand_in)
			await get_tree().create_timer(PLACED_SHOW_TIME).timeout
			if is_inside_tree() and is_same(g, game):
				then.call(pose)
			# (the stage's own copy takes its place)
			await get_tree().process_frame
			stand_in.queue_free()})

const PLACED_SHOW_TIME := 1.0 # a placed card lies in the Row before it is claimed or contested

## A card a Telescope placed, claimed or contested at once: shown going to
## its slot (from `from`: where it was seen), then claimed or contested.
func _resolve_placed(id: int, from: Dictionary = {}) -> bool:
	if not _placing.has(id):
		return false
	if _lost.has(id):
		var rivals: Array = _lost[id]
		_lost.erase(id)
		return _show_placed(id, func(pose: Dictionary) -> void: _contested(id, pose, rivals), from)
	if _claimed.has(id):
		var claimer: int = _claimed[id]
		_claimed.erase(id)
		return _show_placed(id, func(pose: Dictionary) -> void: _spotlight_claim(id, pose, claimer), from)
	return false

func _contested(id: int, from: Dictionary, rivals: Array) -> void:
	var names: Array[String] = []
	for p: int in rivals:
		names.append(_who(p))
	var tied := " and ".join(names) if names.size() < 3 else ", ".join(names.slice(0, -1)) + " and " + names[-1]
	var caption := "[center][font_size=%d][color=#ff8a70]%s[/color][/font_size]\n%s tie for it: nobody claims it.[/center]" % [_fs(32), _fancy("Contested!"), tied]
	_spotlight(id, from, caption, -1, func(pose: Dictionary) -> void:
		_sfx.play("burn")
		_motion.burn(id, pose), true, null, 0.85, -1, -1, CONTESTED_SHOW_TIME)

const CONTESTED_SHOW_TIME := 2.7 # on show mid-table: time to read who tied

## Shows Infamy card `id` in the middle of the dimmed table: it flies there
## from pose `from`, turning face up, with `caption` under it; after a moment
## `finish` is called with its pose (to send it on) and the table clears.
## Cards with the same `key` (the claimer; -1 when contested) arriving
## together share the table; other keys get their own turn, one after another.
## `ticket`: a stage ticket already taken for it (else it takes one).
## `companion`: a card shown beside it, a hook between them (the card that
## hooked it).
func _spotlight(id: int, from: Dictionary, caption_text: String, key: int, finish: Callable, reveal_in_place: bool = true, holder: CardView = null, fly_time: float = 0.85, ticket: int = -1, companion: int = -1, show_time: float = 1.7, on_show: Callable = Callable()) -> void:
	# A card claimed as it is revealed first turns over where it lies, and
	# stays there a moment, so everyone sees what came up. (Otherwise it
	# turns over on its way to the middle.)
	var revealed: CardView = null
	var shown_at := Time.get_ticks_msec()
	# A claimed card glows gold from the moment it is claimed, even while it
	# waits its turn on stage.
	var claimed := key >= 0 and key < HOOK_SPOT_KEY
	if holder != null:
		# A copy already on show where the card starts (a hooked card): it
		# stays until the flight starts.
		revealed = holder
		shown_at -= 10000
	elif not from.face_up and reveal_in_place:
		var up := from.duplicate()
		up.face_up = true
		revealed = CardView.make(id, from.size, true)
		revealed.interactive = false
		revealed.mouse_filter = MOUSE_FILTER_IGNORE
		revealed.position = from.center - from.size / 2.0
		revealed.rotation = from.rotation
		_motion.add_child(revealed)
		_sfx.play("card_flip", -4.0)
		_motion.fly(id, from, up, {"target": revealed, "zone": "stage", "duration": 0.45, "arc": 0.0, "lift": 0.12, "glow": claimed})
		from = up
	else:
		# A copy stays where the card lay while it waits its turn on stage,
		# so it does not vanish from the table meanwhile.
		revealed = CardView.make(id, from.size, from.face_up)
		revealed.interactive = false
		revealed.mouse_filter = MOUSE_FILTER_IGNORE
		revealed.position = from.center - from.size / 2.0
		revealed.rotation = from.rotation
		_motion.add_child(revealed)
		shown_at -= 10000
	if claimed and holder == null:
		revealed.mark = CardView.Mark.CLAIMABLE
		revealed.z_index = 1
	var now := Engine.get_process_frames()
	_spot_groups = _spot_groups.filter(func(g: Dictionary) -> bool: return g.frame == now)
	var group: Dictionary = {}
	for g: Dictionary in _spot_groups:
		if g.key == key:
			group = g
	if group.is_empty():
		group = {"key": key, "frame": now, "ids": [], "ticket": ticket if ticket >= 0 else _stage_take()}
		_spot_groups.append(group)
	var ids: Array = group.ids
	var slot := ids.size()
	ids.append(id)
	# The group is complete once this frame is over.
	var g := game
	await get_tree().process_frame
	await _stage_wait(group.ticket)
	if not is_inside_tree() or not is_same(g, game):
		if is_instance_valid(revealed) and revealed != holder:
			revealed.queue_free()
		return # the table was closed, or a new game started, meanwhile
	if on_show.is_valid():
		on_show.call()
	if revealed != null:
		var held := (Time.get_ticks_msec() - shown_at) / 1000.0
		if held < 1.2:
			await get_tree().create_timer(1.2 - held).timeout
		revealed.queue_free()
	var gap := 0.9 # between two cards leaving
	var later := (ids.size() - 1 - slot) * gap # the others still to leave after this one
	var screen := get_viewport_rect().size
	var dim_layer := CanvasLayer.new()
	dim_layer.layer = 4 # under the flying card (layer 5)
	add_child(dim_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	dim.modulate.a = 0.0
	dim.visible = slot == 0 # one dim for the whole group
	dim_layer.add_child(dim)
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var card_size := Vector2(240, 326)
	var spacing := card_size.x + 70.0
	var center := Vector2(screen.x / 2.0 + (slot - (ids.size() - 1) / 2.0) * spacing, screen.y / 2.0 - 50.0)
	var extras: Array[Control] = [] # the companion and its hook: they come and go with the caption
	if companion >= 0 and ids.size() == 1:
		var pair := (card_size.x + PAIR_GAP) / 2.0
		center.x = screen.x / 2.0 + pair
		var other := CardView.make(companion, card_size)
		other.interactive = false
		other.mouse_filter = MOUSE_FILTER_IGNORE
		other.position = Vector2(screen.x / 2.0 - pair, center.y) - card_size / 2.0
		other.pivot_offset = card_size / 2.0
		layer.add_child(other)
		var hook := TextureRect.new()
		hook.texture = load(ICONS + "fx-hook.png")
		hook.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hook.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hook.mouse_filter = MOUSE_FILTER_IGNORE
		hook.size = Vector2(84, 84)
		hook.pivot_offset = hook.size / 2.0
		hook.position = Vector2(screen.x / 2.0, center.y) - hook.size / 2.0
		layer.add_child(hook)
		extras.append_array([other, hook])
		for node: Control in extras:
			node.modulate.a = 0.0
	var view := CardView.make(id, card_size)
	view.interactive = false
	view.mouse_filter = MOUSE_FILTER_IGNORE
	view.position = center - card_size / 2.0
	layer.add_child(view)
	if CardDB.is_infamy(id):
		view.set_requirement(_banners_met(_seat, id))
	var caption := _rich(18)
	caption.fit_content = true
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	var caption_width := 640.0 if ids.size() == 1 else spacing - 10.0
	caption.custom_minimum_size.x = caption_width
	var caption_x := screen.x / 2.0 if not extras.is_empty() else center.x
	caption.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
	caption.add_theme_constant_override("outline_size", 6)
	caption.text = caption_text
	caption.position = Vector2(caption_x - caption_width / 2.0, center.y + card_size.y / 2.0 + 18.0)
	caption.modulate.a = 0.0
	layer.add_child(caption)

	if slot == 0:
		_sfx.play("reveal", -4.0)
	var to := {"center": center, "size": card_size, "rotation": 0.0, "face_up": true}
	# ("stage": a refresh meanwhile must not send it off again.)
	_motion.fly(id, from, to, {"target": view, "zone": "stage", "duration": fly_time, "lift": 0.25, "arc": 70.0})
	var tween := create_tween()
	tween.tween_property(dim, "modulate:a", 1.0, 0.4)
	for node: Control in extras:
		tween.parallel().tween_property(node, "modulate:a", 1.0, 0.4)
		tween.parallel().tween_property(node, "scale", Vector2.ONE, 0.4).from(Vector2(0.85, 0.85)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.5)
	tween.tween_property(caption, "modulate:a", 1.0, 0.3)
	tween.tween_interval(show_time + slot * gap)
	tween.tween_callback(func() -> void:
		var pose := CardMotion.pose_of(view, true)
		view.visible = false
		finish.call(pose))
	tween.tween_property(caption, "modulate:a", 0.0, 0.4)
	for node: Control in extras:
		tween.parallel().tween_property(node, "modulate:a", 0.0, 0.4)
	# The dim lifts once the last card of the group has left.
	tween.parallel().tween_property(dim, "modulate:a", 0.0, 0.6).set_delay(later)
	tween.tween_callback(func() -> void:
		layer.queue_free()
		dim_layer.queue_free()
		if slot == 0: # the group's last to clear (its dim waits for the others)
			_stage_leave(group.ticket)
		_spotlights -= 1
		_release_hold())

const WINDFALL_SPOT_KEY := 2000
const WINDFALL_SHOW_TIME := 3.0 # on show mid-table: time to read its caption

## The game begins: your Windfall comes from the Infamy deck, turning over,
## is shown a moment mid-table, and goes to your hand.
func _present_windfall() -> void:
	var id: int = game.players[_seat].windfall
	if id < 0:
		return
	_in_spotlight[id] = true # hidden in your hand meanwhile
	_spotlights += 1
	_hold_choices = true
	var g := game
	for _i in range(3): # the table is laid out
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if not is_same(g, game):
		return
	var from := {"center": get_viewport_rect().size / 2.0, "size": PILE_CARD, "rotation": 0.0, "face_up": false}
	var pile: CardView = _pile_views.get("infamy")
	if is_instance_valid(pile) and pile.is_inside_tree():
		from = CardMotion.pose_of(pile, false)
	var caption := "[center][font_size=%d][color=#ffd36b]%s[/color][/font_size]\nIt stays in your hand: discard it to pay 2 coins when you build.[/center]" % [_fs(30), _fancy("Your Windfall")]
	_spotlight(id, from, caption, WINDFALL_SPOT_KEY, func(pose: Dictionary) -> void:
		_in_spotlight.erase(id)
		var target := _hand_view(id)
		if target == null:
			_queue_refresh()
			return
		_motion.fly(id, pose, CardMotion.pose_of(target, true), {
			"target": target, "zone": "hand", "duration": 0.8, "lift": 0.08, "arc": 40.0,
		}), false, null, 0.85, -1, -1, WINDFALL_SHOW_TIME)

## Spotlight keys for Hooks, apart from the claimers' (player indices) and
## contested cards (-1).
const HOOK_SPOT_KEY := 1000

## A Hook that touches you: the card taken shown mid-table, beside the card
## that took it (a hook between them). Stolen from you, it is yanked out of
## your hand, then the thief's; stolen by you, it comes from the victim,
## turning over, to your hand. It waits for cards on their way to a crew to
## land first (and a moment more), so one thing moves at a time.
func _hook_ceremony(id: int, thief: int, victim: int, source: int = -1) -> void:
	var keeps: bool = game.symbol_count(thief, "hooks") >= 3
	var title: String
	var note: String
	var from: Dictionary
	if victim == _seat:
		if _hand_view(id) == null:
			return
		_hooked_keep[id] = true # stays in your hand until its turn
		title = "[color=#ff8a70]%s hooks your card![/color]" % _who(thief)
		note = "With 3 Hooks, they keep it." if keeps else "They must give you a card back."
	else:
		_in_spotlight[id] = true # hidden in your hand meanwhile
		from = _opp_pose(victim)
		title = "[color=#ffd36b]You hook it from %s![/color]" % _who(victim)
		note = "With 3 Hooks, you keep it." if keeps else "Now choose a card to give back."
	var caption := "[center][font_size=%d]%s[/font_size]\n%s[/center]" % [_fs(30), _fancy(title), note]
	_spotlights += 1
	_hold_choices = true
	# A card given back must wait for this steal to be shown first.
	_hooks_waiting += 1
	if thief == _seat:
		# Your Hook card reaches your crew first. (Before taking a ticket:
		# a claimed card's spotlight, which the landing waits on, takes its
		# own later.)
		await _landings_done()
		if not is_inside_tree():
			return
	# A card just claimed (an Infamy card with a Hook, say) is shown first:
	# its spotlight takes its stage ticket at the next refresh, so let it.
	await get_tree().process_frame
	while not _claimed.is_empty() and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	# Each Hook gets the table to itself, after whatever came before it.
	var g := game
	var ticket := _stage_take()
	_hooks_waiting -= 1
	await _stage_wait(ticket)
	if not is_inside_tree() or not is_same(g, game):
		return
	await _crew_settled()
	if not is_inside_tree():
		return
	_sfx.play("hook")
	# The card that hooks glows while its Hook is shown.
	_pulse_active(source, (HOOK_TUG_TIME + HOOK_HAUL_TIME if victim == _seat else 0.85) + HOOK_SHOW_TIME + 1.2)
	var tugged: CardView = null
	if victim == _seat:
		var held := _hand_view(id)
		_hooked_keep.erase(id)
		if held == null:
			_stage_leave(ticket)
			_hook_abandoned(id)
			return
		from = CardMotion.pose_of(held, true)
		_in_spotlight[id] = true
		held.modulate.a = 0.0
		tugged = _hooked_copy(id, from)
		_queue_refresh() # out of the hand now (no flight: it is in the spotlight)
		# Yanked out of the hand first; then slowly hauled to the middle.
		_hook_tug(tugged)
		await get_tree().create_timer(HOOK_TUG_TIME).timeout
		if not is_instance_valid(tugged) or not is_inside_tree():
			_stage_leave(ticket)
			_hook_abandoned(id)
			return
		from = CardMotion.pose_of(tugged, true)
	var finish := func(pose: Dictionary) -> void:
		_in_spotlight.erase(id)
		if victim == _seat:
			var to := _opp_pose(thief)
			_motion.fly(id, pose, to, {"fade_out": true, "duration": 0.8, "lift": 0.1, "arc": 60.0})
			return
		var target := _hand_view(id)
		if target == null:
			_motion.burst(pose.center, pose.size)
			return
		_motion.fly(id, pose, CardMotion.pose_of(target, true), {
			"target": target, "zone": "hand", "duration": 0.8, "lift": 0.08, "arc": 40.0, "glow": true,
		})
	_spotlight(id, from, caption, HOOK_SPOT_KEY + ticket, finish, false, tugged, HOOK_HAUL_TIME if tugged != null else 0.85, ticket, source, HOOK_SHOW_TIME)

## Waits until no card is on its way to a crew (yours landing, your build
## still to join, any flight to a crew), then a moment more. A card shown
## mid-table first (a claim) is not waited for: it needs the stage.
func _crew_settled() -> void:
	var waited := 0.0
	while is_inside_tree() and waited < CREW_SETTLE_TIMEOUT and _crew_moving():
		await get_tree().process_frame
		waited += get_process_delta_time()
	if is_inside_tree():
		await get_tree().create_timer(CREW_SETTLE_PAUSE).timeout

const CREW_SETTLE_PAUSE := 0.5
const CREW_SETTLE_TIMEOUT := 6.0

func _crew_moving() -> bool:
	for gate: Dictionary in _landing:
		if not (_claimed.has(gate.id) or _in_spotlight.has(gate.id)):
			return true
	var pl: Dictionary = game.players[_seat]
	var built: int = pl.built_this_step
	if game.phase == DeckhandGame.Phase.BUILD and built >= 0 and not pl.crew.has(built):
		return true # your build joins once the cards before it are in
	var flights := _motion.in_flight()
	for fid: int in flights:
		if flights[fid].zone in ["crew", "opponents"]:
			return true
	return false

const HOOK_TUG_TIME := 0.6
const HOOK_HAUL_TIME := 0.9 # from your hand to the middle
const HOOK_SHOW_TIME := 1.3 # on show mid-table (an Infamy card: 1.7)
const PAIR_GAP := 150.0 # between a stolen card and the card that hooked it

## A Hook ceremony that could not be shown: lets go of what it held.
func _hook_abandoned(id: int) -> void:
	if not is_inside_tree():
		return
	_in_spotlight.erase(id)
	_hooked_keep.erase(id)
	_spotlights -= 1
	_release_hold()

## Choices wait while a card is shown mid-table or lands in your crew, and
## while a holding band is shown or queued; recomputed as each one ends.
func _release_hold() -> void:
	_hold_choices = _spotlights > 0 or _band_holds > 0
	_queue_refresh()

## A copy of the hooked card where it lay in your hand (it stays until the
## spotlight takes over).
func _hooked_copy(id: int, from: Dictionary) -> CardView:
	var ghost := CardView.make(id, from.size, true)
	ghost.interactive = false
	ghost.mouse_filter = MOUSE_FILTER_IGNORE
	ghost.pivot_offset = from.size / 2.0
	ghost.position = from.center - from.size / 2.0
	ghost.rotation = from.rotation
	_motion.add_child(ghost)
	return ghost

## The hooked card jerks up out of your hand, outlined red, and struggles on
## the line a moment.
func _hook_tug(ghost: CardView) -> void:
	ghost.mark = CardView.Mark.PAYMENT
	var up := ghost.position + Vector2(0.0, -90.0)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "position", up, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ghost, "rotation_degrees", -7.0, 0.14)
	tween.tween_property(ghost, "rotation_degrees", 6.0, 0.12)
	tween.tween_property(ghost, "rotation_degrees", -4.0, 0.12)
	tween.tween_property(ghost, "rotation_degrees", 2.0, 0.1)
	tween.tween_property(ghost, "rotation_degrees", 0.0, 0.1)
	tween.parallel().tween_property(ghost, "position", up + Vector2(0.0, -14.0), 0.2)

## A card the Hook's thief gives back to you: it waits for the steal to be
## shown, a moment for effect, then sails from their seat into your hand.
## Your choices wait for it.
func _receive_gift(id: int, giver: int) -> void:
	_in_spotlight[id] = true # hidden in the hand meanwhile
	_spotlights += 1
	_hold_choices = true
	# After the steal it answers (its ceremony may not have queued yet).
	await get_tree().process_frame # the hand is laid out
	while _hooks_waiting > 0 and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	var g := game
	var ticket := _stage_take()
	await _stage_wait(ticket)
	if not is_inside_tree() or not is_same(g, game):
		return
	await get_tree().create_timer(GIFT_PAUSE).timeout
	if not is_inside_tree():
		return
	_in_spotlight.erase(id)
	var target := _hand_view(id)
	if target != null:
		_sfx.play("card_deal", -2.0)
		_motion.fly(id, _opp_pose(giver), CardMotion.pose_of(target, true), {
			"target": target, "zone": "hand", "duration": 0.8, "lift": 0.3, "arc": 110.0, "glow": true,
		})
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree():
			return
	_stage_leave(ticket)
	_spotlights -= 1
	_release_hold()

const GIFT_PAUSE := 0.5

func _stage_take() -> int:
	_stage_next += 1
	return _stage_next - 1

## Waits until `ticket` is on stage.
func _stage_wait(ticket: int) -> void:
	while _stage_now < ticket and is_inside_tree():
		await _stage_moved

## `ticket` is done: the next one goes on.
func _stage_leave(ticket: int) -> void:
	if ticket >= _stage_now:
		_stage_now = ticket + 1
		_stage_moved.emit()

func _hand_view(id: int) -> CardView:
	for view in _hand_views:
		if is_instance_valid(view) and view.is_inside_tree() and view.card_id == id:
			return view
	return null

## A face-down card at player `p`'s seat (their panel), or mid-table.
func _opp_pose(p: int) -> Dictionary:
	var center := get_viewport_rect().size / 2.0
	if _opp_panels.has(p) and is_instance_valid(_opp_panels[p]) and _opp_panels[p].is_inside_tree():
		center = (_opp_panels[p] as Control).get_global_rect().get_center()
	return {"center": center, "size": OPP_CARD, "rotation": 0.0, "face_up": false}

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
	if _gifts.has(id):
		_gifts.erase(id)
		# Given back after a Hook: it rises from the hand and sails, glowing,
		# to the pirate it goes to.
		_motion.fly(id, from, to, {"fade_out": true, "glow": true, "duration": 1.0, "lift": 0.3, "arc": 110.0})
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
			# The new Infamy card stays face down until the round's band:
			# what the last round left on stage (a Hook) plays out first.
			var slot := game.round_index - 1
			_row_held[slot] = true
			# The first round's card waits for the table to fade in.
			_round_title(game.round_index, game.wind(), 1.3 if _curtain.visible else 0.0, func() -> void:
				_sfx.play("bell", -3.0)
				if _row_held.erase(slot):
					_sfx.play("reveal")
					_queue_refresh())
			if game.round_index == 1:
				_present_windfall()
		"reveal":
			pass # sounded when the Row shows it (see "round_start")
		"deal":
			# Another pirate's redraw is played quietly.
			_sfx.play("card_deal", -2.0 if p == _seat else -12.0)
		"draft_pass":
			_sfx.play("card_deal", -9.0)
			_hands_passed = true
		"pass":
			_sfx.play("pass", volume)
		"build":
			if info.paid > 0:
				_sfx.play("coin", volume - 2.0)
		"crew":
			if not CardDB.is_infamy(info.card):
				_sfx.play("card_place", volume)
			if p == _seat:
				_await_landing(info.card)
		"effect":
			# Hooks glow with their ceremony, Battles with their band;
			# Compasses work in the draft.
			if info.effect in ["hook", "battle", "compass"]:
				pass
			elif info.effect.begins_with("draw-"):
				# Yours glow as their cards are dealt (see _play_draws);
				# others' one after another.
				if p != _seat or _landing.is_empty():
					_pulse_active(info.source, ACTIVE_PULSE, p, info.get("cause", -1))
			else:
				_pulse_active(info.source)
		"draw":
			if p == _seat and info.has("cards") and not _landing.is_empty():
				# Drawn by a card still landing: dealt once it has.
				for id: int in info.cards:
					_in_spotlight[id] = true
				_landing[-1].draws.append({"source": info.get("source", -1), "cause": info.get("cause", -1), "cards": info.cards})
			else:
				_sfx.play("card_deal", volume - 4.0)
		"telescope":
			_sfx.play("telescope", volume)
			if info.has("placed"):
				_placing[info.placed] = info.slot
		"shuffle":
			_shuffle_pile(info.deck)
		"hook":
			if _seat in [p, info.target] and info.has("card"):
				_hook_ceremony(info.card, p, info.target, info.get("source", -1)) # sounds on its turn
			else:
				_sfx.play("hook", -6.0)
				_pulse_active(info.get("source", -1))
		"hook_give":
			if p == _seat:
				_gifts[info.card] = true
			elif info.target == _seat:
				_receive_gift(info.card, p)
		"battle_announce":
			_battle_announced(p, info.get("source", -1))
		"battle":
			_battle_fought(p, info.winner, info.get("scores", {}), info.get("count", 1), info.get("details", {}), info.get("battles", 1))
		"claim":
			# Its sound plays when its spotlight comes on.
			_claimed[info.card] = p
			if _placing.has(info.card):
				_in_spotlight[info.card] = true # shown placed in the Row first
			_spotlights += 1
			_hold_choices = true
			# If the card was not on the table to animate from, show it anyway.
			var claimed_card: int = info.card
			get_tree().create_timer(0.5).timeout.connect(func() -> void:
				if _claimed.has(claimed_card):
					if _resolve_placed(claimed_card):
						return
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
					if _resolve_placed(card):
						return
					var rivals: Array = _lost[card]
					_lost.erase(card)
					var center := get_viewport_rect().size / 2.0
					_contested(card, {"center": center, "size": ROW_CARD, "rotation": 0.0, "face_up": false}, rivals))
		"game_end":
			pass # its sound plays with the finale (see _build_finale)

func _on_hand_clicked(view: CardView) -> void:
	var decision: Variant = game.pending.get(_seat)
	if decision == null or view.get_meta("building", false) or _in_spotlight.has(view.card_id):
		return # nothing to choose, or the card is not on show yet
	if not _hand_click_passes():
		return
	var is_windfall: bool = view.get_meta("windfall", false)
	var id := view.card_id
	if decision.type == "build" and _windfall_step:
		return # choosing where the Windfall goes (or back to the payment)
	_sfx.play("card_flip", -6.0)
	_confirming = "" # changing the choice: ask again if need be
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
			if _hold_choices or is_windfall or not game.players[_seat].hand.has(id):
				return
			_give_card = -1 if id == _give_card else id
		_:
			return
	_render_hand()
	_render_action()

func _auto_pay() -> void:
	var others: Array = game.players[_seat].hand.filter(func(id: int) -> bool: return id != _build_card)
	var keep := func(id: int) -> float: return DeckhandBot.keep_value(game, _seat, id)
	# The Windfall pays 2 coins as one discard: worth it for 2, wasteful for
	# 1. Priced at 1.5 of the cheapest card, the planner picks it for 2 coins
	# and a single card for 1.
	var windfall_value := INF
	if game.players[_seat].windfall >= 0:
		var cheapest := INF
		for id: int in others:
			cheapest = minf(cheapest, keep.call(id))
		windfall_value = 1.0 if cheapest == INF else cheapest * 1.5
	var plan := Payment.plan(CardDB.get_card(_build_card).cost, game.crew_production_slots(_seat), others, keep, windfall_value)
	if not plan.ok:
		_flash("Your hand and crew can't pay for %s." % CardDB.title(_build_card))
		return
	_pay.assign(plan.discards)
	_pay_windfall = plan.windfall
	_render_hand()
	_render_action()

func _confirm_build() -> void:
	# Paying with the Windfall: where it goes is asked next (if there is a
	# choice: a face-down Row slot to stack it on).
	if _pay_windfall and not _windfall_step and not game.unrevealed_slots().is_empty():
		_windfall_step = true
		_queue_refresh()
		return
	if not _pay_windfall or game.unrevealed_slots().is_empty():
		_windfall_dest = DeckhandGame.WINDFALL_DECK
	_windfall_step = false
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
# In the menu: its buttons' keys too, Up / Down between them, Enter.

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 3.0:
		_using_keys = false
	if not event is InputEventKey or not event.pressed:
		return
	var key: Key = (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		if _credits.visible:
			_credits.visible = false
		elif _rules.visible:
			_rules.visible = false
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
	if _rules.visible:
		return # its Close button has the focus
	if _menu.visible:
		_menu_key(key)
		return
	if game == null:
		return
	if key in [KEY_O, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and is_instance_valid(_band_ok) and _band_ok.is_visible_in_tree():
		# A band waiting for its OK takes these first.
		_band_ok.pressed.emit()
		get_viewport().set_input_as_handled()
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

func _menu_key(key: Key) -> void:
	# A sheet over the menu may be typed in (the online name and code).
	if _credits.visible or _rules.visible or _online_panel.visible or _settings.visible:
		return
	var focus := get_viewport().gui_get_focus_owner()
	var in_menu := focus != null and (_menu.get_meta("panel") as Control).is_ancestor_of(focus)
	match key:
		KEY_UP, KEY_DOWN:
			if in_menu:
				return # Godot moves the focus.
			for button in _visible_buttons():
				if button.has_meta("primary"):
					button.grab_focus()
					break
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if in_menu:
				return # The focused button takes it.
			for button in _visible_buttons():
				if button.has_meta("primary"):
					button.pressed.emit()
					break
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

## The buttons on screen: the open choice's first, then the action bar's;
## with the menu up, the menu's.
func _visible_buttons() -> Array[Button]:
	var out: Array[Button] = []
	var roots: Array[Node] = []
	if _menu.visible:
		roots.append(_menu.get_meta("panel"))
	else:
		if _overlay.visible and not _overlay_hidden:
			roots.append(_overlay_body)
		roots.append(_buttons)
	for node in roots:
		for button in node.find_children("*", "Button", true, false):
			if button.is_visible_in_tree() and not (button is OptionButton or button is CheckBox) and not button.is_queued_for_deletion():
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
	var buttons := _visible_buttons()
	for button in buttons:
		if button.has_meta("plain_key"):
			taken[button.get_meta("key")] = true
	for button in buttons:
		if button.has_meta("plain_key"):
			continue
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
	badge.visible = _key_hints
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
			need.append(_banner(b, 24))
		rows.append(["Claim with", _icons(need)])
	else:
		var cost := []
		for token: String in card.cost:
			cost.append(_res(token, 22))
		rows.append(["Cost", _icons(cost)])
		if not card.production.is_empty():
			var prod := []
			for slot: Array in card.production:
				prod.append(_slot_icons(slot, 22))
			rows.append(["Produces", _icons(prod)])
		if not card.banners.is_empty():
			var banners := []
			for b: String in card.banners:
				banners.append(_banner(b, 22))
			rows.append(["Banners", _icons(banners)])
	_info_rows(rows)
	if card.kind == "infamy" and game != null and game.row.any(func(slot: Dictionary) -> bool: return slot.cards.has(id)):
		_info_text("[color=#5a4630]Claimed by the first pirate whose banners meet this requirement.[/color]", 14)

	# Effects: an icon column, then the text (wrapping under itself).
	var effects: Array = []
	if card.multiplier != null:
		effects.append([_banner(card.multiplier.banner, 22), "[color=#8a3b12][b]+%d VP[/b][/color] per raised banner at the end" % card.multiplier.vp])
	if card.tentacles > 0:
		effects.append([_img("fx-tentacle", 26), "Wins ties."])
	for effect: String in card.effects:
		effects.append([_img(EFFECT_ICONS[effect], 26), EFFECT_SHORT[effect]])
	if card.trigger != null:
		var on: String = _img("fx-tentacle", 22) if card.trigger.on == "tentacle" else _banner(card.trigger.on, 22)
		effects.append([on, "Each time you add one: %s" % EFFECT_SHORT[card.trigger.effect]])
	if not effects.is_empty():
		_info_line()
		for row: Array in effects:
			_info_effect(row[0], row[1])

	var use := _discard_use(id) if game != null else ""
	if not use.is_empty():
		# Picked to pay for the card being built: what it pays, highlighted.
		_info_line()
		_info_highlight(_info_rows([["Discard", use]]))
	elif game != null and card.kind == "supply" and not game.players[_seat].crew.has(id):
		# What discarding it pays: a coin, or (revealed) one of its resources.
		var options := [_res("cs", 24), _res("c", 24)]
		for token in CardDB.production_tokens(id):
			if not token in ["cs", "c"]:
				options.append(_res(token, 24))
		_info_line()
		_info_rows([["Discard", "[color=#7a6248] / [/color]".join(options)]])
	elif game != null and game.players[_seat].windfall == id:
		# The Windfall pays two coins: two silver, or a gold and a silver.
		var pairs := [_icons([_res("cs", 24), _res("cs", 24)]), _icons([_res("c", 24), _res("cs", 24)])]
		_info_line()
		_info_rows([["Discard", "[color=#7a6248] / [/color]".join(pairs)]])

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
func _info_rows(rows: Array, alpha: float = 1.0) -> RichTextLabel:
	if rows.is_empty():
		return null
	var text := "[table=2]"
	for row: Array in rows:
		text += "[cell padding=0,2,12,2][color=#7a6248][font_size=%d]%s[/font_size][/color][/cell][cell padding=0,2,0,2]%s[/cell]" % [_fs(13), row[0], row[1]]
	var label := _info_text(text + "[/table]", 15)
	label.modulate.a = alpha
	return label

## Sets `label` (in the tooltip) on a light gold box, to stand out.
func _info_highlight(label: RichTextLabel) -> void:
	var box := PanelContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.84, 0.42, 0.5)
	style.border_color = Color(0.72, 0.48, 0.14, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	box.add_theme_stylebox_override("panel", style)
	_zoom_info.add_child(box)
	label.custom_minimum_size.x -= 12.0
	label.reparent(box)

## Card `id` picked to pay for the card being built: what it pays, in
## words ("" if it is not in the payment).
func _discard_use(id: int) -> String:
	var decision: Variant = game.pending.get(_seat)
	if decision == null or decision.type != "build" or _build_card < 0:
		return ""
	var index := _pay.find(id)
	if index < 0:
		if id != game.players[_seat].windfall or not _pay_windfall:
			return ""
		index = _pay.size() # the Windfall
	var title := CardDB.title(_build_card)
	var cost: Array = CardDB.get_card(_build_card).cost
	var payers: Array = game.check_payment(_seat, _build_card, _pay, _pay_windfall).get("payers", [])
	var alone: Array[String] = []
	var paired: Array[String] = []
	for i in range(payers.size()):
		var payer: Dictionary = payers[i]
		match payer.get("kind", ""):
			"single":
				if payer.discard == index:
					alone.append(_res(cost[i], 22))
			"windfall":
				if index == _pay.size():
					alone.append(_res(cost[i], 22))
			"pair":
				if (payer.discards as Array).has(index):
					var other: int = payer.discards[0] if payer.discards[1] == index else payer.discards[1]
					paired.append("%s together with %s" % [_res(cost[i], 22), _pay_card_name(other)])
	if alone.is_empty() and paired.is_empty():
		return "[color=#b02010][b]Not needed for %s[/b][/color]" % title
	var parts: Array[String] = []
	if not alone.is_empty():
		parts.append("Pays %s for %s" % [" ".join(alone), title])
	for text in paired:
		parts.append("Pays %s" % text)
	return "\n".join(parts)

## One effect: its icon, then its text wrapping in a block of its own.
func _info_effect(icon: String, text: String) -> void:
	const ICON_WIDTH := 40.0
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

class_name CardView
extends Control
## A card face (or back) with rounded corners, hover and selection states.

signal clicked(view: CardView)
signal hovered(view: CardView)
signal unhovered(view: CardView)

enum Mark { NONE, SELECTED, PAYMENT, DISABLED, HIGHLIGHT, FREE, CLAIMABLE }

const CARD_ASPECT := 1632.0 / 2220.0
const SUPPLY_BACK := "res://backs/back-supply.png"
const INFAMY_BACK := "res://backs/back-infamy.png"
const MARK_COLORS := {
	Mark.SELECTED: Color(1.0, 0.74, 0.0),
	Mark.PAYMENT: Color(1.0, 0.16, 0.1),
	Mark.HIGHLIGHT: Color(0.25, 0.75, 1.0),
	Mark.FREE: Color(0.3, 0.92, 0.25),
}

## Rim halos: a claimable / claimed card (gold), a card whose effect is
## being resolved (sea green).
const CLAIM_HALO := Color(1.0, 0.78, 0.32)
const ACTIVE_HALO := Color(0.3, 1.0, 0.82)

## Largest lean of a lifted card towards the pointer (radians).
const MAX_TILT := 0.2

static var _textures := {}
static var _cross: ImageTexture
static var _check: ImageTexture
## The card whose sheen last swept, so a card rebuilt while lifted (the table
## redraws often) does not glint again.
static var _swept_id := -1
static var _shader: Shader = preload("res://scenes/cards_stack/shaders/card_display.gdshader")

var card_id := -1
var face_up := true
var mark := Mark.NONE:
	set(value):
		mark = value
		_refresh_mark()
## Its effect is being resolved: a halo runs round its rim (like a
## claimable card's, in another colour).
var active := false:
	set(value):
		if value == active:
			return
		active = value
		_refresh_mark()
var interactive := true
## Opacity of the drop shadow under the card (0 = none), for lifted cards.
var shadow := 0.0:
	set(value):
		shadow = value
		_shadow.modulate.a = value
		_shadow.visible = value > 0.01

## Keyboard / pointer focus: a bright ring around the card.
var focused := false:
	set(value):
		focused = value
		_focus_ring.visible = value

## In focus: a glint sweeps across it once, and it leans towards the pointer.
var lifted := false:
	set(value):
		if value == lifted:
			return
		lifted = value
		if value:
			if card_id != _swept_id:
				_swept_id = card_id
				_sweep_sheen()
			else:
				_set_param("sheen_alpha", RESTING_SHEEN)
			set_process(true)
		else:
			if card_id == _swept_id:
				_swept_id = -1
			var tween := create_tween()
			tween.tween_method(func(a: float) -> void: _set_param("sheen_alpha", a), _get_param("sheen_alpha"), 0.0, 0.2)

const RESTING_SHEEN := 0.12

var _tilt := Vector2.ZERO # x: lean left/right, y: up/down, -1..1
var _sheen_tween: Tween

var _shadow := Panel.new()
var _focus_ring := Panel.new()
var _texture_rect := TextureRect.new()
var _border := Panel.new()
var _caption := Label.new()
var _badge := TextureRect.new() # green check: to build; red cross: to discard
var _checks: Array[TextureRect] = [] # on an Infamy card's printed banners you have

static func texture_for(id: int, show_face: bool) -> Texture2D:
	var path: String
	if show_face and id > 0:
		path = CardDB.get_card(id).file
	elif id > 0 and CardDB.is_infamy(id):
		path = INFAMY_BACK
	else:
		path = SUPPLY_BACK
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]

static func make(id: int, card_size: Vector2, show_face: bool = true) -> CardView:
	var view := CardView.new()
	view.card_id = id
	view.face_up = show_face
	view.custom_minimum_size = card_size
	view.size = card_size
	return view

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var drop := StyleBoxFlat.new()
	drop.bg_color = Color(0, 0, 0, 0.35)
	drop.shadow_color = Color(0, 0, 0, 0.55)
	drop.shadow_size = 16
	drop.shadow_offset = Vector2(0, 10)
	_shadow.add_theme_stylebox_override("panel", drop)
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shadow.visible = false
	add_child(_shadow)

	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = Effects.frozen(_shader) # animated only while it shimmers
	# Card images include a 3 mm bleed around the 63 x 88 mm trim.
	material.set_shader_parameter("bleed_margin_uv", Vector2(3.0 / 69.0, 3.0 / 94.0))
	material.set_shader_parameter("content_inset_px", 2.0)
	_texture_rect.material = material
	add_child(_texture_rect)

	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(4)
	style.set_corner_radius_all(8)
	style.shadow_size = 10
	_border.add_theme_stylebox_override("panel", style)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_border.visible = false
	add_child(_border)

	_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	add_child(_badge)

	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -30.0
	_caption.add_theme_color_override("font_color", Color.WHITE)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.add_theme_font_size_override("font_size", 16)
	add_child(_caption)

	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Color(1.0, 0.95, 0.75)
	ring.set_border_width_all(3)
	ring.set_expand_margin_all(4)
	ring.shadow_color = Color(1.0, 0.8, 0.35, 0.6)
	ring.shadow_size = 10
	_focus_ring.add_theme_stylebox_override("panel", ring)
	_focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_focus_ring.visible = false
	add_child(_focus_ring)

	set_process(false)
	mouse_entered.connect(func() -> void: hovered.emit(self))
	mouse_exited.connect(func() -> void: unhovered.emit(self))
	resized.connect(_on_resized)

func _ready() -> void:
	_texture_rect.texture = texture_for(card_id, face_up)
	pivot_offset = size / 2.0
	_on_resized()
	_refresh_mark()

func set_card(id: int, show_face: bool = true) -> void:
	card_id = id
	face_up = show_face
	_texture_rect.texture = texture_for(id, show_face)

## Burns the card away (0 = intact, 1 = gone), see card_display.gdshader.
func set_burn(amount: float) -> void:
	var material := _texture_rect.material as ShaderMaterial
	if material.get_shader_parameter("burn_seed") == 0.0:
		material.set_shader_parameter("burn_seed", randf() * 100.0)
	material.set_shader_parameter("burn", amount)

func _set_param(param: String, value: Variant) -> void:
	(_texture_rect.material as ShaderMaterial).set_shader_parameter(param, value)

func _get_param(param: String) -> Variant:
	return (_texture_rect.material as ShaderMaterial).get_shader_parameter(param)

func _sweep_sheen() -> void:
	if _sheen_tween:
		_sheen_tween.kill()
	_sheen_tween = create_tween()
	_set_param("sheen_alpha", 0.5)
	_sheen_tween.tween_method(func(t: float) -> void: _set_param("sheen", t), -0.25, 1.3, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sheen_tween.tween_method(func(a: float) -> void: _set_param("sheen_alpha", a), 0.5, RESTING_SHEEN, 0.01)
	_sheen_tween.tween_method(func(t: float) -> void: _set_param("sheen", t), 1.3, 0.55, 0.01)

## Leans towards the pointer while lifted; eases back flat otherwise.
func _process(delta: float) -> void:
	var target := Vector2.ZERO
	if lifted and size.x > 0.0:
		var mouse := get_local_mouse_position() / size * 2.0 - Vector2.ONE
		if absf(mouse.x) <= 1.1 and absf(mouse.y) <= 1.1:
			target = mouse.clampf(-1.0, 1.0)
	_tilt = _tilt.lerp(target, minf(1.0, delta * 10.0))
	# Settled: stop until the pointer moves again (see _gui_input), or the
	# card would keep the whole screen redrawing while the pointer rests on it.
	if _tilt.distance_to(target) < 0.002:
		_tilt = target
		set_process(false)
	_apply_tilt()
	# The resting glare drifts with the lean, like light on a turned card.
	if lifted and (_sheen_tween == null or not _sheen_tween.is_running()):
		_set_param("sheen", 0.55 + (_tilt.x - _tilt.y) * 0.3)

func _apply_tilt() -> void:
	var a := -_tilt.x * MAX_TILT
	var b := _tilt.y * MAX_TILT
	var d := maxf(size.y, 1.0) * 2.5
	# Shrinks a little as it leans, so the near edge stays inside the rect.
	var s := 1.0 - 0.06 * _tilt.length()
	# Card plane -> screen, a homography (columns of the matrix).
	var h := Basis(
		Vector3(s * cos(a), s * sin(a) * sin(b), -sin(a) * cos(b) / d),
		Vector3(0.0, s * cos(b), sin(b) / d),
		Vector3(0.0, 0.0, 1.0))
	_set_param("tilt_inverse", h.inverse())

## Infamy cards: a check on each printed banner whose requirement is met
## (`met`, one bool per banner, left to right; empty for none).
func set_requirement(met: Array) -> void:
	for check in _checks:
		check.queue_free()
	_checks.clear()
	for i in met.size():
		if not met[i]:
			continue
		var check := TextureRect.new()
		check.texture = _mark_badge(true)
		check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		check.set_meta("slot", Vector2(i, met.size()))
		add_child(check)
		_checks.append(check)
	_place_checks()

## The printed banners sit on the bottom strip, centred, 15.2% of the card
## image apart (the image includes a 3 mm bleed round the card).
func _place_checks() -> void:
	var side := size.x * 0.11
	for check in _checks:
		var slot: Vector2 = check.get_meta("slot")
		var image_x := 0.5 + (slot.x - (slot.y - 1.0) / 2.0) * 0.152 + 0.05
		var x := (image_x - 3.0 / 69.0) / (1.0 - 6.0 / 69.0) * size.x
		var y := (0.83 - 3.0 / 94.0) / (1.0 - 6.0 / 94.0) * size.y
		check.size = Vector2(side, side)
		check.position = Vector2(x - side / 2.0, y - side / 2.0)

func set_caption(text: String) -> void:
	_caption.text = text

func _on_resized() -> void:
	pivot_offset = size / 2.0
	(_texture_rect.material as ShaderMaterial).set_shader_parameter("rect_size", size)
	(_texture_rect.material as ShaderMaterial).set_shader_parameter("corner_radius_px", size.x * 0.055)
	(_border.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(int(size.x * 0.06))
	(_shadow.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(int(size.x * 0.06))
	(_focus_ring.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(int(size.x * 0.06) + 4)
	# Top-left corner, overhanging it a little (the corner a fanned hand
	# leaves uncovered).
	var badge := size.x * 0.3
	_badge.size = Vector2(badge, badge)
	_badge.position = Vector2(-badge * 0.25, -badge * 0.25)
	_place_checks()

func _refresh_mark() -> void:
	if not is_inside_tree():
		return
	_border.visible = MARK_COLORS.has(mark)
	if _border.visible:
		var style := _border.get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = MARK_COLORS[mark]
		# Build and discard choices glow, so they stand out in a fanned hand.
		var glow := mark == Mark.SELECTED or mark == Mark.PAYMENT
		style.shadow_color = Color(MARK_COLORS[mark], 0.6 if glow else 0.0)
	_badge.visible = mark == Mark.PAYMENT or mark == Mark.SELECTED
	if _badge.visible:
		_badge.texture = _mark_badge(mark == Mark.SELECTED)
	var claimable := mark == Mark.CLAIMABLE or active
	_set_param("shimmer", 1.0 if claimable else 0.0)
	_set_param("shimmer_color", ACTIVE_HALO if active and mark != Mark.CLAIMABLE else CLAIM_HALO)
	# Only a shimmering card needs TIME: the rest stay frozen, so they never
	# force the screen to redraw (see Effects).
	var material := _texture_rect.material as ShaderMaterial
	if claimable:
		Effects.use(material, _shader)
	else:
		material.remove_meta("effects_base")
		material.shader = Effects.frozen(_shader)
	modulate = Color(0.55, 0.55, 0.55) if mark == Mark.DISABLED else Color.WHITE

## A green check (to build) or a red cross (to discard) with a light rim,
## drawn once for all cards.
static func _mark_badge(check: bool) -> ImageTexture:
	if check and _check:
		return _check
	if not check and _cross:
		return _cross
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var strokes: Array = [
		[Vector2(0.22, 0.52), Vector2(0.42, 0.72)], [Vector2(0.42, 0.72), Vector2(0.78, 0.3)],
	] if check else [
		[Vector2(0.24, 0.24), Vector2(0.76, 0.76)], [Vector2(0.76, 0.24), Vector2(0.24, 0.76)],
	]
	var ink_color := Color(0.12, 0.62, 0.16) if check else Color(0.86, 0.08, 0.05)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var dist := INF
			for stroke: Array in strokes:
				dist = minf(dist, _segment_distance(p, stroke[0] * size, stroke[1] * size))
			var ink := clampf(size * 0.09 + 0.5 - dist, 0.0, 1.0)
			var rim := clampf(size * 0.14 + 0.5 - dist, 0.0, 1.0)
			var color := Color(1.0, 0.95, 0.88).lerp(ink_color, ink)
			color.a = rim
			img.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(img)
	if check:
		_check = texture
	else:
		_cross = texture
	return texture

static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and lifted:
		set_process(true) # lean towards the pointer again
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()

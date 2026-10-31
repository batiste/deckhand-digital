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
	Mark.SELECTED: Color(1.0, 0.8, 0.25),
	Mark.PAYMENT: Color(0.95, 0.35, 0.3),
	Mark.HIGHLIGHT: Color(0.45, 0.85, 1.0),
	Mark.FREE: Color(0.45, 0.9, 0.4),
}

## Largest lean of a lifted card towards the pointer (radians).
const MAX_TILT := 0.2

static var _textures := {}
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
	material.shader = _shader
	# Card images include a 3 mm bleed around the 63 x 88 mm trim.
	material.set_shader_parameter("bleed_margin_uv", Vector2(3.0 / 69.0, 3.0 / 94.0))
	material.set_shader_parameter("content_inset_px", 2.0)
	_texture_rect.material = material
	add_child(_texture_rect)

	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	_border.add_theme_stylebox_override("panel", style)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_border.visible = false
	add_child(_border)

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
	if not lifted and _tilt.length() < 0.002:
		_tilt = Vector2.ZERO
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

func set_caption(text: String) -> void:
	_caption.text = text

func _on_resized() -> void:
	pivot_offset = size / 2.0
	(_texture_rect.material as ShaderMaterial).set_shader_parameter("rect_size", size)
	(_texture_rect.material as ShaderMaterial).set_shader_parameter("corner_radius_px", size.x * 0.055)
	(_border.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(int(size.x * 0.06))
	(_shadow.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(int(size.x * 0.06))
	(_focus_ring.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(int(size.x * 0.06) + 4)

func _refresh_mark() -> void:
	if not is_inside_tree():
		return
	_border.visible = MARK_COLORS.has(mark)
	if _border.visible:
		(_border.get_theme_stylebox("panel") as StyleBoxFlat).border_color = MARK_COLORS[mark]
	_set_param("shimmer", 1.0 if mark == Mark.CLAIMABLE else 0.0)
	modulate = Color(0.55, 0.55, 0.55) if mark == Mark.DISABLED else Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()

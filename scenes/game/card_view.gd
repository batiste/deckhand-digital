class_name CardView
extends Control
## A card face (or back) with rounded corners, hover and selection states.

signal clicked(view: CardView)
signal hovered(view: CardView)
signal unhovered(view: CardView)

enum Mark { NONE, SELECTED, PAYMENT, DISABLED, HIGHLIGHT }

const CARD_ASPECT := 1632.0 / 2220.0
const SUPPLY_BACK := "res://backs/back-supply.png"
const INFAMY_BACK := "res://backs/back-infamy.png"
const MARK_COLORS := {
	Mark.SELECTED: Color(1.0, 0.8, 0.25),
	Mark.PAYMENT: Color(0.95, 0.35, 0.3),
	Mark.HIGHLIGHT: Color(0.45, 0.85, 1.0),
}

static var _textures := {}
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

var _shadow := Panel.new()
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

func set_caption(text: String) -> void:
	_caption.text = text

func _on_resized() -> void:
	pivot_offset = size / 2.0
	(_texture_rect.material as ShaderMaterial).set_shader_parameter("rect_size", size)
	(_texture_rect.material as ShaderMaterial).set_shader_parameter("corner_radius_px", size.x * 0.055)
	(_border.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(int(size.x * 0.06))
	(_shadow.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(int(size.x * 0.06))

func _refresh_mark() -> void:
	if not is_inside_tree():
		return
	_border.visible = MARK_COLORS.has(mark)
	if _border.visible:
		(_border.get_theme_stylebox("panel") as StyleBoxFlat).border_color = MARK_COLORS[mark]
	modulate = Color(0.55, 0.55, 0.55) if mark == Mark.DISABLED else Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()

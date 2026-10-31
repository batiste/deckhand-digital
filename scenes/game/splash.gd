class_name SplashScreen
extends Control
## Title screen: the kraken art drifts slowly, the logo drops in, and any
## click or key sets sail.

signal finished

const ART := "res://assets/art/kraken.jpg"
const LOGO := "res://assets/new-logo.png"

var _art := TextureRect.new()
var _logo := TextureRect.new()
var _prompt := Label.new()
var _done := false

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	_art.texture = load(ART)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.set_anchors_preset(PRESET_FULL_RECT)
	_art.modulate = Color(1, 1, 1, 0)
	add_child(_art)

	add_child(make_vignette())

	_logo.texture = load(LOGO)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.modulate = Color(1, 1, 1, 0)
	add_child(_logo)

	_prompt.text = "Click to set sail"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_override("font", load("res://scenes/shared/fonts/signika/Signika-SemiBold.ttf"))
	_prompt.add_theme_font_size_override("font_size", 28)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	_prompt.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	_prompt.add_theme_constant_override("outline_size", 10)
	_prompt.modulate = Color(1, 1, 1, 0)
	add_child(_prompt)

	resized.connect(_layout)
	_layout()
	_animate()

## A dark radial vignette, also used behind the menu.
static func make_vignette(strength: float = 0.85) -> TextureRect:
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

func _layout() -> void:
	var logo_width := minf(size.x * 0.62, 1100.0)
	_logo.size = Vector2(logo_width, logo_width * 1024.0 / 2169.0)
	_logo.pivot_offset = _logo.size / 2.0
	_logo.position = Vector2((size.x - _logo.size.x) / 2.0, size.y * 0.1)
	_prompt.size = Vector2(size.x, 40)
	_prompt.position = Vector2(0, size.y * 0.84)
	_art.pivot_offset = size / 2.0

func _animate() -> void:
	var intro := create_tween()
	intro.tween_property(_art, "modulate:a", 1.0, 1.2)
	intro.parallel().tween_property(_logo, "modulate:a", 1.0, 0.5).set_delay(0.6)
	intro.parallel().tween_property(_logo, "scale", Vector2.ONE, 0.9).from(Vector2(1.6, 1.6)).set_delay(0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(_prompt, "modulate:a", 1.0, 0.5)
	intro.tween_callback(_pulse_prompt)

	# Slow drift over the art, back and forth.
	var drift := create_tween().set_loops()
	drift.tween_property(_art, "scale", Vector2(1.12, 1.12), 14.0).from(Vector2.ONE).set_trans(Tween.TRANS_SINE)
	drift.tween_property(_art, "scale", Vector2.ONE, 14.0).set_trans(Tween.TRANS_SINE)

	# The logo bobs like it is afloat.
	var bob := create_tween().set_loops()
	bob.tween_property(_logo, "rotation_degrees", 1.2, 2.4).set_trans(Tween.TRANS_SINE).set_delay(1.5)
	bob.tween_property(_logo, "rotation_degrees", -1.2, 2.4).set_trans(Tween.TRANS_SINE)

func _pulse_prompt() -> void:
	var pulse := create_tween().set_loops()
	pulse.tween_property(_prompt, "modulate:a", 0.35, 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_prompt, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_leave()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed:
		_leave()

func _leave() -> void:
	if _done:
		return
	_done = true
	var out := create_tween()
	out.tween_property(_logo, "scale", Vector2(0.8, 0.8), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	out.parallel().tween_property(self, "modulate:a", 0.0, 0.45)
	out.tween_callback(func() -> void:
		finished.emit()
		queue_free())

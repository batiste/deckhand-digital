class_name PerfOverlay
extends CanvasLayer
## F3, or ⌘⇧D (Ctrl+Shift+D): what the game costs, once a second, in the top-left corner (and on
## stdout). "drawn" counts real redraws: Godot's own FPS counts loop ticks,
## which stay at the cap even when nothing is drawn. The readout itself
## redraws once a second.

var _label: Label
var _drawn := 0
var _elapsed := 0.0

func _ready() -> void:
	layer = 100
	visible = false
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	RenderingServer.frame_post_draw.connect(func() -> void: _drawn += 1)
	set_process(false)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	# F3 is Mission Control on a Mac (fn+F3 works), hence the second shortcut.
	var debug_d := key.keycode == KEY_D and key.shift_pressed and key.is_command_or_control_pressed()
	if key.keycode == KEY_F3 or debug_d:
		visible = not visible
		set_process(visible)
		_drawn = 0
		_elapsed = 0.0
		_label.text = "measuring…"

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 1.0:
		return
	# (Performance.TIME_PROCESS is left out: in low-processor mode it counts
	# the sleep between ticks, so it reads high on an idle table.)
	var text := "drawn %d/s · ticks %d/s · draw calls %d · nodes %d · tweens %d" % [
		roundi(_drawn / _elapsed),
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		get_tree().get_processed_tweens().filter(func(t: Tween) -> bool: return t.is_running()).size()]
	text += "\nreduced effects %s · low-processor %s" % [Effects.reduced, OS.low_processor_usage_mode]
	# What could be asking for redraws: nodes running code every frame, the
	# control under the pointer, and the window state.
	var busy := {}
	for node in get_tree().root.find_children("*", "", true, false):
		if node != self and (node.is_processing() or node.is_physics_processing()):
			var what: String = node.get_script().resource_path.get_file() if node.get_script() else node.get_class()
			busy[what] = busy.get(what, 0) + 1
	var hovered := get_viewport().gui_get_hovered_control()
	text += "\nprocessing: %s" % [busy]
	text += "\nhovered: %s · focused %s · mouse in window %s" % [
		"%s %s" % [hovered.get_class(), hovered.name] if hovered else "none",
		get_window().has_focus(),
		get_window().get_visible_rect().has_point(get_viewport().get_mouse_position())]
	_label.text = text
	print("[perf] ", text.replace("\n", " · "))
	_drawn = 0
	_elapsed = 0.0

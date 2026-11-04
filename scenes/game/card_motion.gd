class_name CardMotion
extends CanvasLayer
## Card movement between table refreshes. The table rebuilds its cards on every
## refresh, so motion is played by stand-in copies ("ghosts") that fly from a
## card's old pose to its new one while the real card stays hidden, flipping
## over on the way when the card changes face.
##
## A pose is {center: Vector2, size: Vector2, rotation: float, face_up: bool}
## in canvas coordinates.

const TRAVEL := 0.42
const ARC := 18.0
const BURN := 0.55

var _flights := {} # card id -> {ghost: CardView, tween: Tween, target: CardView, to: pose, zone: String}

static func pose_of(view: Control, face_up: bool = true) -> Dictionary:
	var xf := view.get_global_transform()
	return {
		"center": xf * (view.size / 2.0),
		"size": view.size * xf.get_scale().abs(),
		"rotation": xf.get_rotation(),
		"face_up": face_up,
	}

## Flies card `id` from pose `from` to pose `to`. Options:
##   target: CardView hidden until the ghost lands, then shown.
##   delay: seconds to wait (at the start pose) before moving.
##   fade_in / fade_out: fade the ghost while it travels.
##   duration: travel time.
##   zone: where the card is going, so a later refresh can retarget the flight.
##   lift: how much the card grows mid-flight (default 0.05); arc: its rise in px.
##   glow: a gold shimmer round the card while it flies.
##   on_land: called with the destination pose when the card arrives.
func fly(id: int, from: Dictionary, to: Dictionary, options: Dictionary = {}) -> void:
	if _flights.has(id):
		_land(id)
	var ghost := CardView.make(id, to.size, from.face_up)
	ghost.interactive = false
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost)
	var target: CardView = options.get("target")
	if target != null:
		target.modulate.a = 0.0
	if options.get("glow", false):
		ghost.mark = CardView.Mark.CLAIMABLE
		ghost.z_index = 1
	var step := _step.bind(ghost, id, from, to, options)
	step.call(0.0)
	var tween := create_tween()
	tween.tween_interval(options.get("delay", 0.0))
	tween.tween_method(step, 0.0, 1.0, options.get("duration", TRAVEL))
	tween.tween_callback(_land.bind(id))
	_flights[id] = {"ghost": ghost, "tween": tween, "target": target, "to": to, "zone": options.get("zone", ""), "on_land": options.get("on_land", Callable())}

## Flights heading to a card on the table, by card id:
## {pose: where the ghost is now, zone, face_up: the face it lands on}.
func in_flight() -> Dictionary:
	var result := {}
	for id: int in _flights:
		var flight: Dictionary = _flights[id]
		if flight.target == null:
			continue # Leaving the table; let it finish.
		var ghost: CardView = flight.ghost
		var pose := pose_of(ghost, ghost.face_up)
		# A ghost squashed mid-flip still has its full height.
		pose.size.x = pose.size.y * ghost.size.x / ghost.size.y
		result[id] = {"pose": pose, "zone": flight.zone, "face_up": flight.to.face_up}
	return result

func is_flying(id: int) -> bool:
	return _flights.has(id)

## Keeps the flight of card `id` going, now towards `target` at pose `to`
## (after the table was rebuilt with the card in the same place).
func retarget(id: int, target: CardView, to: Dictionary) -> void:
	var flight: Dictionary = _flights[id]
	flight.target = target
	target.modulate.a = 0.0
	# The step callable holds this same dictionary.
	flight.to.center = to.center
	flight.to.rotation = to.rotation

## Burns card `id` away where it stands (`at` pose), with a few embers
## drifting up. For discards.
func burn(id: int, at: Dictionary, delay: float = 0.0) -> void:
	var ghost := CardView.make(id, at.size, at.face_up)
	ghost.interactive = false
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost)
	ghost.position = at.center - at.size / 2.0
	ghost.rotation = at.rotation
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(_embers.bind(at))
	tween.tween_method(ghost.set_burn, 0.0, 1.0, BURN)
	tween.parallel().tween_property(ghost, "position:y", ghost.position.y - 10.0, BURN).set_ease(Tween.EASE_OUT)
	tween.tween_callback(ghost.queue_free)

func _embers(at: Dictionary) -> void:
	var embers := CPUParticles2D.new()
	embers.position = at.center
	embers.one_shot = true
	embers.explosiveness = 0.15
	embers.amount = 26
	embers.lifetime = 0.9
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = at.size / 2.0
	embers.direction = Vector2.UP
	embers.spread = 35.0
	embers.gravity = Vector2(0.0, -60.0)
	embers.initial_velocity_min = 20.0
	embers.initial_velocity_max = 60.0
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 0.35, 1.0))
	ramp.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
	embers.color_ramp = ramp
	add_child(embers)
	embers.emitting = true
	embers.finished.connect(embers.queue_free)

## A puff of gold dust at `center`, spread over `extent` (claims).
func burst(center: Vector2, extent: Vector2, amount: int = 40) -> void:
	var dust := CPUParticles2D.new()
	dust.position = center
	dust.one_shot = true
	dust.explosiveness = 0.85
	dust.amount = amount
	dust.lifetime = 1.1
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = extent / 2.0
	dust.direction = Vector2.UP
	dust.spread = 180.0
	dust.gravity = Vector2(0.0, 40.0)
	dust.initial_velocity_min = 40.0
	dust.initial_velocity_max = 140.0
	dust.damping_min = 60.0
	dust.damping_max = 120.0
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	ramp.add_point(0.35, Color(1.0, 0.78, 0.3, 0.9))
	ramp.set_color(1, Color(0.9, 0.55, 0.15, 0.0))
	dust.color_ramp = ramp
	add_child(dust)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)

## A firework of glowing sparks bursting from `center`, in `parent` (so it can
## be drawn above another layer). `tint` colours the sparks as they cool.
static func firework(parent: Node, center: Vector2, tint: Color) -> void:
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var sparks := CPUParticles2D.new()
	sparks.position = center
	sparks.material = glow
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.amount = 90
	sparks.lifetime = 1.6
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.gravity = Vector2(0.0, 110.0)
	sparks.initial_velocity_min = 160.0
	sparks.initial_velocity_max = 340.0
	sparks.damping_min = 90.0
	sparks.damping_max = 160.0
	sparks.scale_amount_min = 2.5
	sparks.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 0.92, 1.0))
	ramp.add_point(0.25, Color(1.0, 0.85, 0.4, 1.0))
	ramp.add_point(0.6, Color(tint, 0.8))
	ramp.set_color(1, Color(tint.darkened(0.4), 0.0))
	sparks.color_ramp = ramp
	parent.add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
	# The flash at its heart.
	var flash := sparks.duplicate() as CPUParticles2D
	flash.amount = 12
	flash.lifetime = 0.35
	flash.initial_velocity_min = 0.0
	flash.initial_velocity_max = 30.0
	flash.scale_amount_min = 14.0
	flash.scale_amount_max = 22.0
	flash.gravity = Vector2.ZERO
	parent.add_child(flash)
	flash.emitting = true
	flash.finished.connect(flash.queue_free)

## Ends every flight at once (e.g. when a new game starts).
func settle() -> void:
	for id: int in _flights.keys():
		_land(id)

func _step(t: float, ghost: CardView, id: int, from: Dictionary, to: Dictionary, options: Dictionary) -> void:
	var e: float = Tween.interpolate_value(0.0, 1.0, t, 1.0, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	var arc := sin(PI * t)
	var center: Vector2 = from.center.lerp(to.center, e) + Vector2(0.0, -options.get("arc", ARC) * arc)
	ghost.position = center - ghost.size / 2.0
	ghost.rotation = lerp_angle(from.rotation, to.rotation, e)
	var lift: float = options.get("lift", 0.05)
	var s := lerpf(from.size.x / to.size.x, to.size.x / ghost.size.x, e) * (1.0 + lift * arc)
	var sx := s
	if from.face_up != to.face_up:
		sx *= absf(cos(PI * e))
		if e >= 0.5 and ghost.face_up != to.face_up:
			ghost.set_card(id, to.face_up)
	ghost.scale = Vector2(maxf(sx, 0.001), s)
	var alpha := 1.0
	if options.get("fade_in", false):
		alpha = minf(alpha, clampf(t * 3.0, 0.0, 1.0))
	if options.get("fade_out", false):
		alpha = minf(alpha, 1.0 - smoothstep(0.55, 1.0, t))
	ghost.modulate.a = alpha

func _land(id: int) -> void:
	var flight: Dictionary = _flights[id]
	_flights.erase(id)
	(flight.tween as Tween).kill()
	if is_instance_valid(flight.target):
		flight.target.modulate.a = 1.0
	if flight.on_land.is_valid():
		flight.on_land.call(flight.to)
	flight.ghost.queue_free()

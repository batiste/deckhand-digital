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
	var step := _step.bind(ghost, id, from, to, options.get("fade_in", false), options.get("fade_out", false))
	step.call(0.0)
	var tween := create_tween()
	tween.tween_interval(options.get("delay", 0.0))
	tween.tween_method(step, 0.0, 1.0, options.get("duration", TRAVEL))
	tween.tween_callback(_land.bind(id))
	_flights[id] = {"ghost": ghost, "tween": tween, "target": target, "to": to, "zone": options.get("zone", "")}

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

## Ends every flight at once (e.g. when a new game starts).
func settle() -> void:
	for id: int in _flights.keys():
		_land(id)

func _step(t: float, ghost: CardView, id: int, from: Dictionary, to: Dictionary, fade_in: bool, fade_out: bool) -> void:
	var e: float = Tween.interpolate_value(0.0, 1.0, t, 1.0, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	var arc := sin(PI * t)
	var center: Vector2 = from.center.lerp(to.center, e) + Vector2(0.0, -ARC * arc)
	ghost.position = center - ghost.size / 2.0
	ghost.rotation = lerp_angle(from.rotation, to.rotation, e)
	var s := lerpf(from.size.x / to.size.x, to.size.x / ghost.size.x, e) * (1.0 + 0.05 * arc)
	var sx := s
	if from.face_up != to.face_up:
		sx *= absf(cos(PI * e))
		if e >= 0.5 and ghost.face_up != to.face_up:
			ghost.set_card(id, to.face_up)
	ghost.scale = Vector2(maxf(sx, 0.001), s)
	var alpha := 1.0
	if fade_in:
		alpha = minf(alpha, clampf(t * 3.0, 0.0, 1.0))
	if fade_out:
		alpha = minf(alpha, 1.0 - smoothstep(0.55, 1.0, t))
	ghost.modulate.a = alpha

func _land(id: int) -> void:
	var flight: Dictionary = _flights[id]
	_flights.erase(id)
	(flight.tween as Tween).kill()
	if is_instance_valid(flight.target):
		flight.target.modulate.a = 1.0
	flight.ghost.queue_free()

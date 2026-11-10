class_name Effects
## A shader that reads TIME makes Godot redraw the whole screen every frame
## (60 a second), even if nothing else moves, and each redraw is the whole
## table. So the ambient animation (lantern, shimmer, gleams)
## runs on its own clock instead, ticked AMBIENT_HZ times a second: an idle
## table redraws that often, not 60 (with low-processor mode on, see
## project.godot). "Reduced effects" stops the clock: an idle table does not
## redraw at all.

## Ticks of the ambient clock per second: enough for a slow flicker, a
## sixth of the redraws.
const AMBIENT_HZ := 10.0
const CLOCK := "effects_clock" # the uniform that replaces TIME

static var reduced := false
static var _clock := 0.0
static var _since_tick := 0.0
static var _clocked := {} # Shader -> its copy on the ambient clock
static var _frozen := {} # Shader -> its copy with TIME fixed
static var _live: Array[WeakRef] = [] # materials following the setting

## Gives `material` the shader `base` on the ambient clock (frozen while
## effects are reduced), and keeps it following the setting (see set_reduced).
## `smooth` skips the ambient clock and keeps the real TIME, at the full frame
## rate: for the few effects where 10 Hz shows (the menu logo's gleam), and
## only where the screen is light enough to redraw every frame.
static func use(material: ShaderMaterial, base: Shader, smooth: bool = false) -> void:
	if not material.has_meta("effects_base"):
		_live.append(weakref(material)) # once: a card's shimmer comes and goes
	material.set_meta("effects_base", base)
	material.set_meta("effects_smooth", smooth)
	material.shader = _shader_for(material)
	material.set_shader_parameter(CLOCK, _clock)

## Switches the setting, swapping the shaders already on screen.
static func set_reduced(on: bool) -> void:
	reduced = on
	for material in _materials():
		material.shader = _shader_for(material)
		material.set_shader_parameter(CLOCK, _clock)

## Advances the ambient clock; called every frame (GameTable._process).
## True when it ticked: the caller then asks for a redraw, as a shader
## parameter change alone does not cause one.
static func tick(delta: float) -> bool:
	if reduced:
		return false
	_clock += delta
	_since_tick += delta
	if _since_tick < 1.0 / AMBIENT_HZ:
		return false
	# Carry the remainder over, so ticks keep to AMBIENT_HZ (not rounded
	# down to a whole number of frames).
	_since_tick = fmod(_since_tick, 1.0 / AMBIENT_HZ)
	for material in _materials():
		material.set_shader_parameter(CLOCK, _clock)
	return true

## `base` on the ambient clock, or frozen with "Reduced effects" on.
static func shader(base: Shader) -> Shader:
	return frozen(base) if reduced else clocked(base)

## The shader `material` should have now, given its meta and the setting.
static func _shader_for(material: ShaderMaterial) -> Shader:
	var base: Shader = material.get_meta("effects_base")
	if material.get_meta("effects_smooth", false) and not reduced:
		return base
	return shader(base)

## `base` with TIME read from the ambient clock uniform.
static func clocked(base: Shader) -> Shader:
	if not base.code.contains("TIME"):
		return base
	if not _clocked.has(base):
		var code := base.code.replace("TIME", CLOCK)
		# Declared right after the `shader_type ...;` line.
		var at := code.find(";", code.find("shader_type")) + 1
		var copy := Shader.new()
		copy.code = code.insert(at, "\nuniform float %s = 0.0;" % CLOCK)
		_clocked[base] = copy
	return _clocked[base]

## `base` with TIME fixed at 0: for shaders whose animation is switched off
## (the rounded panel without its lantern), so they never force redraws.
static func frozen(base: Shader) -> Shader:
	if not base.code.contains("TIME"):
		return base
	if not _frozen.has(base):
		var copy := Shader.new()
		copy.code = base.code.replace("TIME", "0.0")
		_frozen[base] = copy
	return _frozen[base]

## The live materials still following the setting, dropping freed ones. A
## material that went back to frozen-for-good (a card no longer shimmering)
## has dropped its meta and is skipped.
static func _materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	var kept: Array[WeakRef] = []
	for ref in _live:
		var material := ref.get_ref() as ShaderMaterial
		if material == null:
			continue
		kept.append(ref)
		if material.has_meta("effects_base"):
			out.append(material)
	_live = kept
	return out

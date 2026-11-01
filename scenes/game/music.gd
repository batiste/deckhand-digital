class_name Music
extends Node
## The music. A track plays in passes on two players: when a pass reaches
## its `handover` point, the next pass starts `jump` seconds earlier in the
## track and the two crossfade (equal power), so a section loops without a
## seam. The next pass starts from the playing pass's exact position, so the
## beats line up even if a frame comes late.
##
## After `loops` passes, a track either flows into the track named in `then`
## through its `exit` (see below), or fades to silence and rests, then starts
## its loop again. A track with `once` plays to its end, rests, and goes on to
## `then`.
##
## An `exit` is a seamless way out of a looping track into another one: at
## `at` seconds in the loop (instead of looping back), the next track starts
## from its beginning, its first beat (`first_beat`) landing on that point,
## while an equal-power blend of `length` s starts `lead` s before it.

## The intro's way into the gameplay music, chosen by ear: from the end of
## its loop (beat 100), both tracks are at ~110 BPM and open on D/A/G.
const INTRO_EXIT := {"at": 54.983, "lead": 1.85, "length": 2.0, "first_beat": 0.383}

## Title music. The loop was chosen by ear (tools/intro_loop.py): at 110 BPM,
## from beat 100 (54.98 s) back to beat 20 (11.34 s), 80 beats, with a 0.5 s
## crossfade starting 0.36 s before the beat. Full intro, three loops, fade,
## rest, and the loop again.
const INTRO := {
	"name": "intro", "path": "res://assets/intro.mp3", "db": -4.0,
	"handover": 54.623, "jump": 43.640, "crossfade": 0.5,
	"loops": 3, "rest_fade": 4.0, "rest": 3.0, "exit": INTRO_EXIT,
}
## In a game: the gameplay track once, a pause, the intro with two loops (at
## the gameplay level) flowing back into the gameplay track, and round again.
const GAME := {
	"name": "game", "path": "res://assets/gameplay.mp3", "db": -13.0,
	"once": true, "rest": 4.0, "then": "intro_game",
}
const INTRO_GAME := {
	"name": "intro_game", "path": "res://assets/intro.mp3", "db": -13.0,
	"handover": 54.623, "jump": 43.640, "crossfade": 0.5,
	"loops": 2, "exit": INTRO_EXIT, "then": "game",
}
const TRACKS := {"intro": INTRO, "game": GAME, "intro_game": INTRO_GAME}
## Tracks that take turns during a game: starting another game keeps them going.
const GAME_CYCLE: Array[String] = ["game", "intro_game"]

const SILENT_DB := -80.0
## A track starting after a rest fades in over this long.
const RESTART_FADE := 1.0

var track := {} # what plays now (INTRO, GAME...), empty when silent

var _players: Array[AudioStreamPlayer] = []
var _current: AudioStreamPlayer
var _passes := 0 # loop passes since the track started or rested
var _state := "idle" # playing, leaving (by the exit), blending, fading (to rest), resting
var _rest_until := 0
var _mix: Tween
var _next := {} # leaving: the track to go into
var _exit_this_pass := false # leaving: the exit comes in the pass playing now
var _streams := {} # path -> stream, loaded up front (no hitch when switching)

func _ready() -> void:
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		add_child(player)
		_players.append(player)
	for t: Dictionary in TRACKS.values():
		_streams[t.path] = load(t.path)

## Switches to `next`. A track with an exit plays on to it and flows into
## `next` there; otherwise they crossfade over `fade_in` seconds.
func play(next: Dictionary, fade_in: float) -> void:
	if next == track or (next.name in GAME_CYCLE and track.get("name", "") in GAME_CYCLE):
		return
	if _state == "playing" and track.has("exit") and _current.playing:
		_leave_by_exit(next)
		return
	if _state in ["leaving", "blending"]:
		_next = next
		return
	_switch(next, fade_in)

## Fades everything out.
func stop(seconds: float = 1.2) -> void:
	track = {}
	_state = "idle"
	if _mix:
		_mix.kill()
	_mix = create_tween().set_parallel()
	for player in _players:
		if player.playing:
			_mix.tween_property(player, "volume_db", SILENT_DB, seconds).set_trans(Tween.TRANS_SINE)
	_mix.chain().tween_callback(func() -> void:
		for player in _players:
			player.stop())

func _switch(next: Dictionary, fade_in: float) -> void:
	track = next
	_passes = 0
	_start_pass(0.0, fade_in)

## Keeps playing the loop until its exit, then flows into `next`.
func _leave_by_exit(next: Dictionary) -> void:
	_next = next
	_state = "leaving"
	# Too close to this pass's exit to blend: take the next pass's.
	_exit_this_pass = _position() < track.exit.at - track.exit.lead

func _process(_delta: float) -> void:
	if track.is_empty() or _current == null:
		return
	match _state:
		"resting":
			if Time.get_ticks_msec() >= _rest_until:
				if track.has("then"):
					_switch(TRACKS[track.then], RESTART_FADE)
				else:
					_passes = 1
					_start_pass(_handover() - _jump(), RESTART_FADE)
		"leaving":
			var pos := _position()
			if _exit_this_pass:
				if pos >= track.exit.at - track.exit.lead:
					_blend_out()
			elif pos >= _handover():
				# Loop once more; the exit comes in the new pass.
				_start_pass(pos - _jump(), track.crossfade)
				_state = "leaving"
				_exit_this_pass = true
		"playing":
			_follow()

## A playing pass: hand over to the next pass, or end it.
func _follow() -> void:
	if track.get("once", false):
		if not _current.playing:
			_rest()
		return
	var pos := _position()
	var loops: int = track.get("loops", 0)
	if loops > 0 and _passes >= loops:
		if track.has("then") and track.has("exit"):
			# The last pass flows on into the next track.
			_leave_by_exit(TRACKS[track.then])
			return
		# Or fades to silence by the end of the loop, and rests.
		var end: float = _handover() + track.crossfade
		if pos >= end - track.rest_fade:
			_state = "fading"
			var player := _current
			_fade_out(player, maxf(end - pos, 0.1), _rest)
		return
	if pos >= _handover():
		_passes += 1
		_start_pass(pos - _jump(), track.crossfade)

## The exit: the loop plays on past its handover while the next track comes
## in, its first beat on the exit point, under an equal-power blend.
func _blend_out() -> void:
	_state = "blending"
	var exit: Dictionary = track.exit
	var old := _current
	var old_db := old.volume_db
	var next := _next
	var player: AudioStreamPlayer = _players[1] if old == _players[0] else _players[0]
	player.stream = _streams[next.path]
	player.volume_db = SILENT_DB
	var blend_start := _position()
	# When (in the blend) the next track's start is due: its first beat must
	# fall on the exit point.
	var start_at: float = exit.at - exit.first_beat
	var started := {"done": false} # (a lambda cannot assign to a local)
	if _mix:
		_mix.kill()
	_mix = create_tween()
	_mix.tween_method(func(p: float) -> void:
		var pos := old.get_playback_position() + AudioServer.get_time_since_last_mix()
		if not started.done and pos >= start_at:
			started.done = true
			player.play(pos - start_at)
		old.volume_db = old_db + linear_to_db(maxf(cos(p * PI / 2.0), 0.0001))
		player.volume_db = next.db + linear_to_db(maxf(sin(p * PI / 2.0), 0.0001)),
		# The blend's length, less however late it started.
		0.0, 1.0, maxf(exit.length - (blend_start - (exit.at - exit.lead)), 0.1))
	_mix.tween_callback(func() -> void:
		if not started.done:
			player.play(0.0)
		old.stop()
		_current = player
		track = next
		_passes = 0
		_state = "playing")

func _rest() -> void:
	if _state in ["fading", "playing"]:
		_state = "resting"
		_rest_until = Time.get_ticks_msec() + int(track.rest * 1000.0)

## Where the current pass is in its track, as heard.
func _position() -> float:
	return _current.get_playback_position() + AudioServer.get_time_since_last_mix()

## Where a pass hands over to the next (default: just before the end).
func _handover() -> float:
	var length: float = _streams[track.path].get_length()
	return track.get("handover", length - track.get("crossfade", 0.0))

## How far back the next pass starts (default: back to the beginning).
func _jump() -> float:
	return track.get("jump", _handover())

func _start_pass(from: float, fade: float) -> void:
	var old := _current
	var player: AudioStreamPlayer = _players[1] if _current == _players[0] else _players[0]
	player.stream = _streams[track.path]
	player.volume_db = SILENT_DB
	player.play(maxf(from, 0.0))
	_current = player
	_state = "playing"
	_crossfade(old, player, fade)

## Equal power: as one fades out the other fades in, keeping the loudness even.
func _crossfade(old: AudioStreamPlayer, new: AudioStreamPlayer, seconds: float) -> void:
	if _mix:
		_mix.kill()
	var db: float = track.db
	var fading := old != null and old.playing and old != new
	var old_db := old.volume_db if fading else SILENT_DB
	_mix = create_tween()
	_mix.tween_method(func(p: float) -> void:
		new.volume_db = db + linear_to_db(maxf(sin(p * PI / 2.0), 0.0001))
		if fading:
			old.volume_db = old_db + linear_to_db(maxf(cos(p * PI / 2.0), 0.0001)),
		0.0, 1.0, maxf(seconds, 0.01))
	_mix.tween_callback(func() -> void:
		if fading and old != _current:
			old.stop())

## Fades `player` to silence and stops it, then calls `done`.
func _fade_out(player: AudioStreamPlayer, seconds: float, done: Callable = Callable()) -> void:
	if _mix:
		_mix.kill()
	_mix = create_tween()
	_mix.tween_property(player, "volume_db", SILENT_DB, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_mix.tween_callback(func() -> void:
		player.stop()
		if done.is_valid():
			done.call())

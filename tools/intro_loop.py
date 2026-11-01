"""Renders the title music as the game plays it, to judge the loop by ear:
the full intro, then the loop (LOOP_FROM..LOOP_TO) twice, each pass joined
to the next with a crossfade, then a fade to silence, a pause, and the loop
again. The loop points come from the hand-made edit (out.aiff): it jumps
back 43.577 s, from 54.6 s to 11.02 s, fading the new pass in over ~1.6 s.

    afconvert -f WAVE -d LEI16@48000 assets/intro.mp3 /tmp/intro48.wav
    python3 tools/intro_loop.py /tmp/intro48.wav ~/Downloads/intro-loop-preview.wav
"""
import array
import math
import sys
import wave

LOOP_FROM = 11.023    # s: where each loop pass starts in the intro
LOOP_TO = 54.6        # s: where a pass hands over to the next
FADE_IN = 1.6         # s: the next pass fading in (from FADE_IN_START)
FADE_IN_START = 0.3   # its level as it starts
FADE_OUT = 0.35       # s: the pass ending, fading away
LOOPS = 2             # passes before resting
REST_FADE = 4.0       # s: fade to silence at the end of the last pass
REST = 3.0            # s: silence before the loop starts again

src, out_path = sys.argv[1], sys.argv[2]
w = wave.open(src)
rate, channels = w.getframerate(), w.getnchannels()
pcm = array.array("h", w.readframes(w.getnframes()))


def at(t):
    return int(t * rate) * channels


track = array.array("f", [0.0]) * 0


def place(start, src_from, src_to, gain):
    """Adds the intro from src_from to src_to (s) at `start` (s) in the
    output, scaled by gain(t) where t is seconds into the piece."""
    global track
    a, b = at(src_from), min(at(src_to), len(pcm))
    o = at(start)
    need = o + (b - a)
    if len(track) < need:
        track.extend([0.0] * (need - len(track)))
    for k in range(0, b - a, channels):
        g = gain(k / channels / rate)
        for c in range(channels):
            track[o + k + c] += pcm[a + k + c] * g


def fade_in(t):
    if t >= FADE_IN:
        return 1.0
    x = t / FADE_IN
    return FADE_IN_START + (1 - FADE_IN_START) * math.sin(x * math.pi / 2)


def pass_gain(length, first, last):
    """A loop pass: fades in (unless it is the full intro), hands over at
    the end, or fades to silence if it is the last before the rest."""
    def g(t):
        v = 1.0 if first else fade_in(t)
        if last:
            if t > length - REST_FADE:
                v *= max(0.0, math.cos((t - (length - REST_FADE)) / REST_FADE * math.pi / 2))
        elif t > length:
            v *= max(0.0, math.cos((t - length) / FADE_OUT * math.pi / 2))
        return v
    return g


loop_len = LOOP_TO - LOOP_FROM
t = 0.0
# The full intro, handing over at LOOP_TO.
place(0.0, 0.0, LOOP_TO + FADE_OUT, pass_gain(LOOP_TO, True, False))
t = LOOP_TO
for cycle in range(2):  # two rounds of the pattern, to hear the restart
    for n in range(LOOPS):
        last = n == LOOPS - 1
        place(t, LOOP_FROM, LOOP_TO + (0 if last else FADE_OUT), pass_gain(loop_len, False, last))
        t += loop_len
    t += REST
    if cycle == 1:
        break

total = len(track)
peak = max(1.0, max(abs(x) for x in track) / 32000.0)
out = array.array("h", (int(max(-32767, min(32767, x / peak))) for x in track))
o = wave.open(out_path, "wb")
o.setnchannels(channels)
o.setsampwidth(2)
o.setframerate(rate)
o.writeframes(out.tobytes())
print("wrote %s: %.1f s (intro to %.1f s, loop %.2f s x%d, fade %.0f s, rest %.0f s, repeat)" % (
    out_path, total / channels / rate, LOOP_TO, loop_len, LOOPS, REST_FADE, REST))

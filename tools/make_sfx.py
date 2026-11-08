"""Synthesizes the game's sound effects into assets/sfx/*.wav.

Pure standard library, deterministic (fixed random seed), so the sounds can be
regenerated or tweaked at any time:  python3 tools/make_sfx.py
"""

import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
rng = random.Random(7)


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mix(*tracks, offsets=None):
    offsets = offsets or [0.0] * len(tracks)
    length = max(int(o * RATE) + len(t) for t, o in zip(tracks, offsets))
    out = [0.0] * length
    for track, offset in zip(tracks, offsets):
        start = int(offset * RATE)
        for i, v in enumerate(track):
            out[start + i] += v
    return out


def gain(track, g):
    return [v * g for v in track]


def envelope(n, attack, decay):
    """Linear attack then exponential decay (decay = time constant, s)."""
    a = max(1, int(attack * RATE))
    out = []
    for i in range(n):
        t = i / RATE
        e = min(1.0, i / a) if i < a else math.exp(-(t - attack) / decay)
        out.append(e)
    return out


def tone(freq, seconds, attack=0.005, decay=0.2, harmonics=(1.0,), glide_to=None, vibrato=0.0):
    n = int(RATE * seconds)
    env = envelope(n, attack, decay)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq if glide_to is None else freq * (glide_to / freq) ** (t / seconds)
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * 5.5 * t)
        phase += 2 * math.pi * f / RATE
        v = sum(a * math.sin((k + 1) * phase) for k, a in enumerate(harmonics))
        out.append(v * env[i])
    return out


def bell(freq, seconds, partials=((1, 1.0, 1.2), (2.0, 0.5, 0.8), (2.76, 0.35, 0.5), (5.4, 0.2, 0.25), (8.9, 0.1, 0.12))):
    """Inharmonic partials (ratio, amplitude, decay) like a struck bell."""
    tracks = [gain(tone(freq * r, seconds, 0.002, d), a) for r, a, d in partials]
    return mix(*tracks)


def noise(seconds, attack, decay, low=0.0, high=1.0, sweep_to=None):
    """Filtered white noise. `low`/`high` are one-pole filter coefficients;
    `sweep_to` moves the low-pass coefficient over time."""
    n = int(RATE * seconds)
    env = envelope(n, attack, decay)
    out = []
    lp = 0.0
    hp_prev_in = 0.0
    hp = 0.0
    for i in range(n):
        x = rng.uniform(-1, 1)
        k = high if sweep_to is None else high + (sweep_to - high) * i / n
        lp += k * (x - lp)
        # Simple high-pass: remove the slow part.
        hp = (1 - low) * (hp + lp - hp_prev_in)
        hp_prev_in = lp
        out.append(hp * env[i])
    return out


def normalize(track, peak=0.8):
    m = max(abs(v) for v in track) or 1.0
    return [v * peak / m for v in track]


def fade_out(track, seconds=0.02):
    n = min(len(track), int(seconds * RATE))
    for i in range(n):
        track[-1 - i] *= i / n
    return track


def save(name, track, peak=0.8):
    track = fade_out(normalize(track, peak))
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in track))


NOTE = lambda semis: 440.0 * 2 ** (semis / 12)  # semitones from A4
BRASS = (1.0, 0.6, 0.45, 0.3, 0.2, 0.12, 0.08)


def fanfare(notes, step, last):
    parts = []
    offsets = []
    for i, semis in enumerate(notes):
        final = i == len(notes) - 1
        parts.append(tone(NOTE(semis), last if final else step * 1.6, 0.012, last * 0.5 if final else step, BRASS, vibrato=0.004 if final else 0))
        offsets.append(i * step)
    return mix(*parts, offsets=offsets)


def lowpass(track, cutoff):
    """One-pole low-pass at `cutoff` Hz: takes the fizz off noise and highs."""
    k = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out = []
    y = 0.0
    for v in track:
        y += k * (v - y)
        out.append(y)
    return out


def fade_in(track, seconds=0.003):
    """A few ms of fade-in, so a sound never starts with a click."""
    n = min(len(track), int(seconds * RATE))
    for i in range(n):
        track[i] *= i / n
    return track


def room(track, wet=0.18, size=1.0):
    """A small wooden room (Schroeder reverb: 4 combs, 2 all-passes), so
    sounds sit in a space instead of hitting dry. Adds a short tail."""
    src = track + [0.0] * int(0.6 * size * RATE)
    combs = [(0.0297, 0.72), (0.0371, 0.70), (0.0411, 0.68), (0.0437, 0.66)]
    wet_sum = [0.0] * len(src)
    for delay, feedback in combs:
        d = int(delay * size * RATE)
        buf = [0.0] * d
        lp = 0.0
        for i, x in enumerate(src):
            y = buf[i % d]
            lp += 0.4 * (y - lp)  # damping: the walls absorb the highs
            buf[i % d] = x + lp * feedback
            wet_sum[i] += y
    for delay in (0.005, 0.0017):
        d = int(delay * RATE)
        buf = [0.0] * d
        out = []
        for i, x in enumerate(wet_sum):
            b = buf[i % d]
            y = -x + b
            buf[i % d] = x + b * 0.5
            out.append(y)
        wet_sum = out
    return [x + w * wet * 0.25 for x, w in zip(src, wet_sum)]


def finish(track, cutoff=7000, wet=0.18, size=1.0):
    """Softened, de-clicked and placed in the room."""
    return room(fade_in(lowpass(track, cutoff)), wet, size)


def main():
    # Cards: paper swishes and soft thumps on the wooden table.
    swish = lambda length=0.11, bright=0.35: mix(
        noise(length, length * 0.35, length * 0.25, low=0.25, high=bright, sweep_to=bright * 0.4),
        gain(tone(190, 0.05, 0.002, 0.012), 0.25))
    save("card_flip", finish(swish(), 5000, 0.12), 0.4)
    save("card_deal", finish(mix(swish(0.12, 0.3), gain(swish(0.12, 0.3), 0.8), gain(swish(0.12, 0.3), 0.65), offsets=[0, 0.075, 0.15]), 5000, 0.14), 0.38)
    save("card_place", finish(mix(tone(130, 0.2, 0.003, 0.05, (1.0, 0.25), glide_to=72), gain(noise(0.04, 0.002, 0.01, high=0.2), 0.4)), 2500, 0.2), 0.55)

    # Coins for paying: a softer, lower clink of two coins.
    coin = lambda: bell(1500 * rng.uniform(0.96, 1.04), 0.35, ((1, 1.0, 0.09), (1.47, 0.45, 0.06), (2.09, 0.2, 0.035)))
    save("coin", finish(mix(coin(), gain(coin(), 0.55), offsets=[0, 0.06]), 6000, 0.2), 0.36)

    # Round start: two strikes of the ship's bell.
    save("bell", finish(mix(bell(523, 1.8), gain(bell(523, 1.6), 0.75), offsets=[0, 0.45]), 5500, 0.25, 1.3), 0.5)

    # An Infamy card is revealed: low ominous swell.
    swell = mix(
        tone(98, 1.4, 0.35, 0.5, (1.0, 0.4, 0.2), vibrato=0.01),
        tone(147, 1.4, 0.45, 0.45, (1.0, 0.3), vibrato=0.01),
        gain(noise(1.2, 0.4, 0.35, low=0.05, high=0.08), 0.5),
    )
    save("reveal", finish(swell, 3000, 0.25, 1.3), 0.5)

    # Infamy claimed: short, warm brass fanfare (C E G C).
    save("claim", finish(fanfare([3, 7, 10, 15], 0.09, 0.6), 3200, 0.25, 1.2), 0.48)

    # Battle: a distant cannon shot.
    boom = mix(
        gain(noise(0.8, 0.004, 0.18, high=0.2, sweep_to=0.02), 1.0),
        tone(90, 0.7, 0.003, 0.2, (1.0, 0.5), glide_to=38),
        gain(noise(0.03, 0.001, 0.006, high=0.6), 0.5),
    )
    save("battle", finish(boom, 2200, 0.3, 1.4), 0.62)

    # Hook: whoosh then a metal ting.
    whoosh = noise(0.28, 0.12, 0.07, low=0.4, high=0.05, sweep_to=0.4)
    save("hook", finish(mix(whoosh, gain(bell(2200, 0.35, ((1, 1.0, 0.12), (2.4, 0.3, 0.06))), 0.35), offsets=[0, 0.22]), 6000, 0.2), 0.45)

    # Telescope: a rising glint.
    save("telescope", finish(mix(tone(700, 0.45, 0.05, 0.18, (1.0, 0.25), glide_to=1400, vibrato=0.01), gain(tone(1400, 0.45, 0.1, 0.15, glide_to=2600), 0.25)), 5000, 0.25), 0.32)

    # Passing: two soft knocks on wood.
    knock = lambda: mix(tone(300, 0.12, 0.002, 0.025, (1.0, 0.3)), gain(noise(0.02, 0.001, 0.004, high=0.3), 0.4))
    save("pass", finish(mix(knock(), gain(knock(), 0.8), offsets=[0, 0.11]), 3500, 0.2), 0.4)

    # UI: a soft wooden tap for buttons.
    save("click", finish(mix(tone(950, 0.05, 0.001, 0.007, (1.0, 0.3)), gain(noise(0.015, 0.001, 0.003, high=0.3), 0.3)), 4000, 0.1), 0.26)

    # End of game.
    save("victory", finish(fanfare([3, 7, 10, 15, 10, 15, 19], 0.11, 1.4), 3500, 0.28, 1.3), 0.5)
    save("defeat", finish(mix(*[tone(NOTE(s), 0.9, 0.03, 0.35, BRASS[:4]) for s in (-2, -5, -9)], offsets=[0, 0.35, 0.7]), 3000, 0.28, 1.3), 0.45)

    # A discarded card burns: a soft flame swell with a few crackles.
    flame = noise(0.6, 0.12, 0.2, low=0.02, high=0.06, sweep_to=0.2)
    crackles = [gain(noise(0.015, 0.0005, 0.003, low=0.4, high=0.7), rng.uniform(0.3, 0.7)) for _ in range(7)]
    save("burn", finish(mix(flame, *crackles, offsets=[0] + sorted(rng.uniform(0.05, 0.5) for _ in range(7))), 4500, 0.15), 0.36)

    print("wrote sounds to", os.path.normpath(OUT))


LOOP = 4.0  # seconds; every part of a loop repeats a whole number of times in it


def save_loop(name, track, peak=0.8):
    """Like save(), without the fade: the end runs straight into the start."""
    track = normalize(track, peak)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in track))


def drone(partials, seconds=LOOP):
    """Steady sines [(Hz, level)]; each Hz a multiple of 1/LOOP, so it loops."""
    n = int(RATE * seconds)
    return [sum(a * math.sin(2 * math.pi * f * i / RATE) for f, a in partials) for i in range(n)]


def steam_bed(cutoff, seconds=LOOP, crossfade=0.5):
    """Low steam rush that loops: its own end crossfaded into its start."""
    n, x = int(RATE * seconds), int(RATE * crossfade)
    a = lowpass(noise(seconds + crossfade, 0.0, 1e9, low=0.02, high=0.5), cutoff)
    return [a[i] * (i / x) + a[n + i] * (1 - i / x) if i < x else a[i] for i in range(n)]


def pulse(track, rate, depth, seconds=LOOP):
    """A slow throb `rate` times a second (a multiple of 1/LOOP)."""
    return [v * (1.0 - depth * 0.5 * (1 + math.cos(2 * math.pi * rate * i / RATE))) for i, v in enumerate(track)]


def hum_loops():
    """Loops kept for later (not used by the game yet)."""
    # The engine at work: a low hum throbbing like pistons, the steam
    # breathing with it. For a card's effect at work, perhaps.
    tone = pulse(drone([(41.0, 1.0), (82.0, 0.6), (123.0, 0.35), (164.0, 0.2), (205.0, 0.1)]), 1.5, 0.45)
    save_loop("hum_b", mix(tone, gain(pulse(steam_bed(700), 1.5, 0.6), 0.6)), 0.3)

if __name__ == "__main__":
    main()

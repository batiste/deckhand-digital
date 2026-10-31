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


def main():
    # Cards
    save("card_flip", noise(0.09, 0.002, 0.022, low=0.3, high=0.6, sweep_to=0.15), 0.55)
    save("card_deal", mix(*[noise(0.12, 0.03, 0.04, low=0.2, high=0.35) for _ in range(3)], offsets=[0, 0.07, 0.14]), 0.45)
    save("card_place", mix(tone(150, 0.18, 0.002, 0.05, glide_to=70), gain(noise(0.03, 0.001, 0.006, high=0.5), 0.6)), 0.7)

    # Coins for paying
    coin = lambda: bell(2100 * rng.uniform(0.97, 1.03), 0.4, ((1, 1.0, 0.12), (1.34, 0.6, 0.09), (2.03, 0.3, 0.05)))
    save("coin", mix(coin(), gain(coin(), 0.6), offsets=[0, 0.07]), 0.5)

    # Round start: two strikes of the ship's bell.
    save("bell", mix(bell(523, 1.8), gain(bell(523, 1.6), 0.8), offsets=[0, 0.45]), 0.6)

    # An Infamy card is revealed: low ominous swell.
    swell = mix(
        tone(98, 1.4, 0.35, 0.5, (1.0, 0.4, 0.2), vibrato=0.01),
        tone(147, 1.4, 0.45, 0.45, (1.0, 0.3), vibrato=0.01),
        gain(noise(1.2, 0.4, 0.35, low=0.05, high=0.08), 0.5),
    )
    save("reveal", swell, 0.6)

    # Infamy claimed: short brass fanfare (C E G C).
    save("claim", fanfare([3, 7, 10, 15], 0.09, 0.6), 0.6)

    # Battle: a cannon shot.
    boom = mix(
        gain(noise(0.8, 0.002, 0.18, high=0.25, sweep_to=0.02), 1.0),
        tone(90, 0.7, 0.002, 0.2, (1.0, 0.5), glide_to=38),
        gain(noise(0.03, 0.0005, 0.006, high=0.9), 0.8),
    )
    save("battle", boom, 0.85)

    # Hook: whoosh then a metal ting.
    whoosh = noise(0.28, 0.12, 0.07, low=0.4, high=0.05, sweep_to=0.5)
    save("hook", mix(whoosh, gain(bell(2600, 0.35, ((1, 1.0, 0.15), (2.4, 0.4, 0.08))), 0.4), offsets=[0, 0.22]), 0.6)

    # Telescope: a rising glint.
    save("telescope", mix(tone(700, 0.45, 0.05, 0.18, (1.0, 0.25), glide_to=1500, vibrato=0.01), gain(tone(1400, 0.45, 0.1, 0.15, glide_to=2800), 0.3)), 0.4)

    # Passing: two soft knocks on wood.
    knock = lambda: mix(tone(320, 0.12, 0.001, 0.025, (1.0, 0.3)), gain(noise(0.02, 0.0005, 0.004, high=0.4), 0.5))
    save("pass", mix(knock(), gain(knock(), 0.8), offsets=[0, 0.11]), 0.5)

    # UI: tiny tick for selecting cards and buttons.
    save("click", mix(tone(1800, 0.04, 0.0005, 0.008), gain(noise(0.02, 0.0005, 0.003, low=0.5, high=0.9), 0.4)), 0.35)

    # End of game.
    save("victory", fanfare([3, 7, 10, 15, 10, 15, 19], 0.11, 1.4), 0.65)
    save("defeat", mix(*[tone(NOTE(s), 0.9, 0.03, 0.35, BRASS[:4]) for s in (-2, -5, -9)], offsets=[0, 0.35, 0.7]), 0.55)
    print("wrote sounds to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()

"""The game's sound (M7 polish), made from scratch so there's nothing to license.

    python3 tools/gen_audio.py        -> assets/audio/*.wav, main/audio/*.sound, main/audio/audio.go

Everything is synthesised with numpy: soft UI ticks, a card sliding, a d20 rattling across
the tray, paper, a phone ping, bells for good moments, a chip bag, a pencil, rain on the
window, and two quiet music loops (prep: warm F major; game night: D dorian with a harp and
a frame drum). 22,050 Hz mono, 16-bit. Deterministic: the same file every run.
The script that plays them is main/audio/audio.script (hand-written, not generated).
"""
import math
import os
import wave

import numpy as np

from gen_common import path

SR = 22050
rng = np.random.default_rng(2024)


def t_axis(seconds):
    return np.arange(int(SR * seconds)) / SR


def env_ad(n, attack, decay_rate):
    """Linear attack (seconds), then exponential decay (per second)."""
    t = np.arange(n) / SR
    e = np.exp(-decay_rate * np.maximum(t - attack, 0))
    a = max(int(attack * SR), 1)
    e[:a] *= np.linspace(0, 1, a)
    return e


def lowpass(x, cutoff):
    """One-pole low-pass, run forward and back so it doesn't smear the timing."""
    a = math.exp(-2 * math.pi * cutoff / SR)
    def run(sig):
        y = np.empty_like(sig)
        acc = 0.0
        for i, v in enumerate(sig):
            acc = (1 - a) * v + a * acc
            y[i] = acc
        return y
    return run(run(x)[::-1])[::-1]


def fast_lowpass(x, cutoff):
    """FFT brick-ish low-pass with a soft knee (for long signals)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def bandpass(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= (1 / (1 + (lo / np.maximum(f, 1)) ** 4)) * (1 / (1 + (f / hi) ** 4))
    return np.fft.irfft(X, len(x))


def noise(seconds):
    return rng.standard_normal(int(SR * seconds))


def place(buf, sig, at):
    i = int(at * SR)
    j = min(len(buf), i + len(sig))
    if j > i:
        buf[i:j] += sig[: j - i]


def place_wrap(buf, sig, at):
    """Add sig at time `at`, wrapping past the end back to the start (seamless loops)."""
    i = int(at * SR) % len(buf)
    n = len(sig)
    first = min(n, len(buf) - i)
    buf[i:i + first] += sig[:first]
    rest = n - first
    while rest > 0:
        k = min(rest, len(buf))
        buf[:k] += sig[first:first + k]
        first += k
        rest -= k


def fade_out(x, ms=6):
    n = min(int(SR * ms / 1000), len(x))
    x[-n:] *= np.linspace(1, 0, n)
    return x


def normalize(x, peak):
    m = np.max(np.abs(x)) or 1.0
    return x * (peak / m)


def fade_edges(x, ms=4):
    n = int(SR * ms / 1000)
    if n and len(x) > 2 * n:
        x[:n] *= np.linspace(0, 1, n)
        x[-n:] *= np.linspace(1, 0, n)
    return x


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# ------------------------------------------------------------------ instruments

def bell(freq, seconds, decay=4.0, bright=1.0):
    """A soft glassy bell: a few inharmonic partials, the high ones dying first."""
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for ratio, amp, d in [(1.0, 1.0, 1.0), (2.0, 0.35 * bright, 1.6), (2.76, 0.25 * bright, 2.2),
                          (5.4, 0.12 * bright, 3.5), (8.9, 0.05 * bright, 5.0)]:
        out += amp * np.sin(2 * math.pi * freq * ratio * t) * np.exp(-decay * d * t)
    out *= env_ad(len(t), 0.003, 0)
    return out


def pluck(freq, seconds, bright=0.6, decay=2.2):
    """Harp/guitar-like pluck: harmonics with faster decay up the series."""
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for h in range(1, 9):
        amp = (bright ** (h - 1)) / h
        out += amp * np.sin(2 * math.pi * freq * h * t + h * 0.3) * np.exp(-decay * (1 + 0.55 * (h - 1)) * t)
    out *= env_ad(len(t), 0.004, 0)
    return out


def epiano(freq, seconds, decay=1.4):
    """Warm electric-piano-ish tone: sine plus a little 2nd harmonic and a tine."""
    t = t_axis(seconds)
    body = np.sin(2 * math.pi * freq * t) + 0.25 * np.sin(2 * math.pi * 2 * freq * t)
    tine = 0.12 * np.sin(2 * math.pi * 7.0 * freq * t) * np.exp(-14 * t)
    out = (body * np.exp(-decay * t) + tine) * env_ad(len(t), 0.006, 0)
    return out


def pad(freqs, seconds, attack=1.2, release=1.2):
    """Slow soft chord: detuned sines, gently swelling."""
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for f in freqs:
        for det in (-0.12, 0.12):
            out += np.sin(2 * math.pi * (f * (1 + det / 100)) * t + rng.uniform(0, 6.28))
    e = np.ones_like(t)
    a, r = int(attack * SR), int(release * SR)
    e[:a] = np.linspace(0, 1, a) ** 1.5
    e[-r:] *= np.linspace(1, 0, r) ** 1.5
    return out * e / (2 * len(freqs))


def frame_drum(seconds=0.6, low=True):
    t = t_axis(seconds)
    f0 = 95 if low else 180
    f = f0 * (1 + 0.6 * np.exp(-30 * t))
    ph = 2 * math.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-7 * t)
    skin = bandpass(noise(seconds), 400, 2500) * np.exp(-40 * t) * 0.25
    return (body + skin) * env_ad(len(t), 0.002, 0)


# ------------------------------------------------------------------ effects

def sfx_click():
    t = t_axis(0.05)
    tick = np.sin(2 * math.pi * 1900 * t) * np.exp(-140 * t)
    knock = np.sin(2 * math.pi * 520 * t) * np.exp(-90 * t) * 0.6
    grit = bandpass(noise(0.05), 1500, 6000) * np.exp(-260 * t) * 0.3
    return normalize(fade_out(tick + knock + grit), 0.5)


def sfx_tap():
    t = t_axis(0.09)
    knock = np.sin(2 * math.pi * 310 * t) * np.exp(-55 * t)
    wood = np.sin(2 * math.pi * 1240 * t) * np.exp(-120 * t) * 0.35
    return normalize(fade_out(knock + wood), 0.55)


def sfx_card():
    sec = 0.32
    t = t_axis(sec)
    swish = bandpass(noise(sec), 900, 5200)
    e = np.sin(np.pi * np.clip(t / 0.24, 0, 1)) ** 2
    out = swish * e * 0.6
    place(out, sfx_tap() * 0.5, 0.235)
    return normalize(fade_edges(out), 0.6)


def sfx_page():
    sec = 0.42
    t = t_axis(sec)
    rustle = bandpass(noise(sec), 1200, 7000)
    flutter = 0.6 + 0.4 * np.sin(2 * math.pi * 23 * t + 1.0) * np.sin(2 * math.pi * 7 * t)
    e = np.minimum(t / 0.05, 1) * np.exp(-6.5 * t)
    return normalize(fade_edges(rustle * flutter * e), 0.5)


def sfx_pencil():
    sec = 0.55
    t = t_axis(sec)
    scratch = bandpass(noise(sec), 2500, 8000)
    strokes = np.clip(np.sin(2 * math.pi * 6.0 * t) * 1.4, 0, 1)
    e = np.minimum(t / 0.03, 1) * np.minimum((sec - t) / 0.08, 1)
    return normalize(fade_edges(scratch * strokes * e), 0.4)


def sfx_crinkle():
    sec = 0.6
    out = np.zeros(int(SR * sec))
    k = 0
    tt = 0.0
    while tt < sec - 0.03:
        n = int(SR * rng.uniform(0.004, 0.015))
        burst = bandpass(rng.standard_normal(n + 64), 2000, 9000)[:n] * np.exp(-np.arange(n) / (n * 0.3))
        place(out, burst * rng.uniform(0.3, 1.0) * (1 - tt / sec * 0.6), tt)
        tt += rng.exponential(0.018)
        k += 1
    return normalize(fade_edges(out), 0.45)


def sfx_dice():
    """A d20 thrown into the felt tray: a first knock, then shorter, quieter rattles."""
    sec = 1.1
    out = np.zeros(int(SR * sec))
    at, gap, amp = 0.0, 0.16, 1.0
    for k in range(10):
        n = int(SR * 0.05)
        tt = np.arange(n) / SR
        f = rng.uniform(1400, 2800)
        click = (np.sin(2 * math.pi * f * tt) * np.exp(-150 * tt)
                 + 0.6 * np.sin(2 * math.pi * rng.uniform(380, 620) * tt) * np.exp(-70 * tt))
        place(out, click * amp, at)
        at += gap * rng.uniform(0.8, 1.15)
        gap *= 0.72
        amp *= 0.78
        if at > sec - 0.06:
            break
    # felt: everything a bit muffled
    return normalize(fade_edges(lowpass(out, 4200)), 0.75)


def sfx_ping():
    out = np.zeros(int(SR * 0.7))
    place(out, bell(midi(88), 0.6, decay=6, bright=0.5), 0.0)
    place(out, bell(midi(93), 0.55, decay=6, bright=0.5) * 0.85, 0.11)
    return normalize(fade_edges(out), 0.45)


def sfx_chime():
    out = np.zeros(int(SR * 1.5))
    for i, n in enumerate([84, 88, 91, 96]):
        place(out, bell(midi(n), 1.2, decay=3.0, bright=0.6) * (0.9 - 0.1 * i), i * 0.09)
    return normalize(fade_edges(out), 0.5)


def sfx_sparkle():
    out = np.zeros(int(SR * 2.0))
    notes = [79, 84, 88, 91, 96, 100, 103]
    for i, n in enumerate(notes):
        place(out, bell(midi(n), 1.3, decay=3.2, bright=0.7) * (0.55 + 0.06 * i), i * 0.07)
    shimmer = bandpass(noise(2.0), 5000, 10000) * np.exp(-2.2 * t_axis(2.0)) * 0.05
    out += shimmer
    return normalize(fade_edges(out), 0.55)


def rain_loop(seconds=12.0):
    n = int(SR * seconds)
    # steady hiss: shaped noise, made seamless by building it with the circular FFT
    X = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    shape = 1 / np.sqrt(np.maximum(f, 20)) * (1 / (1 + (f / 3500) ** 2)) * (1 / (1 + (250 / np.maximum(f, 1)) ** 2))
    hiss = np.fft.irfft(X * shape, n)
    hiss = normalize(hiss, 1.0)
    swell = 0.85 + 0.15 * np.sin(2 * math.pi * np.arange(n) / n * 3)  # whole cycles: seamless
    out = hiss * swell * 0.55
    # drops on the glass
    drop_n = int(SR * 0.03)
    tt = np.arange(drop_n) / SR
    for _ in range(int(seconds * 14)):
        fr = rng.uniform(2500, 5500)
        d = np.sin(2 * math.pi * fr * tt) * np.exp(-180 * tt) * rng.uniform(0.05, 0.22)
        place_wrap(out, d, rng.uniform(0, seconds))
    return normalize(out, 0.6)


# ------------------------------------------------------------------ music

def music_prep():
    """F major, 70 bpm, 8 bars: pad chords, an e-piano arpeggio, a few melody bells."""
    bpm = 70
    beat = 60 / bpm
    bars = 8
    n = int(SR * beat * 4 * bars)
    out = np.zeros(n)
    # F  Dm  Bb  C  |  F  Am  Bb  C
    chords = [[53, 57, 60, 65], [50, 57, 62, 65], [46, 58, 62, 65], [48, 55, 60, 64],
              [53, 57, 60, 65], [45, 57, 60, 64], [46, 58, 62, 65], [48, 55, 60, 67]]
    for b, ch in enumerate(chords):
        start = b * 4 * beat
        place_wrap(out, pad([midi(x) for x in ch[1:]], 4 * beat + 1.0, attack=0.9, release=1.0) * 0.55, start)
        place_wrap(out, epiano(midi(ch[0] - 12), 4 * beat, decay=0.6) * 0.35, start)
        arp = [ch[1], ch[2], ch[3], ch[2] + 12, ch[3], ch[2], ch[1] + 12, ch[2]]
        for k, note in enumerate(arp):
            v = 0.16 if k % 2 == 0 else 0.11
            place_wrap(out, epiano(midi(note + 12), 1.6, decay=2.0) * v, start + k * beat / 2)
    melody = [(0, 77, 2), (2.5, 76, 1), (3, 74, 1), (4, 72, 3), (8, 74, 2), (10, 72, 1), (11, 70, 1),
              (12, 72, 3), (16, 77, 2), (18.5, 79, 1), (19, 81, 2), (21, 79, 1), (24, 77, 2), (26, 76, 1),
              (27, 74, 1), (28, 72, 3)]
    for at, note, _len in melody:
        place_wrap(out, bell(midi(note), 2.4, decay=1.6, bright=0.35) * 0.13, at * beat)
    out = fast_lowpass(out, 5000)
    return normalize(out, 0.7)


def music_night():
    """D dorian, 64 bpm, 8 bars: a low drone, a harp arpeggio and a soft frame drum."""
    bpm = 64
    beat = 60 / bpm
    bars = 8
    n = int(SR * beat * 4 * bars)
    out = np.zeros(n)
    # Dm  C  G  Dm  |  Dm  F  C  Am
    chords = [[50, 57, 62, 65], [48, 55, 60, 64], [43, 55, 59, 62], [50, 57, 62, 65],
              [50, 57, 62, 69], [41, 57, 60, 65], [48, 55, 60, 64], [45, 57, 60, 64]]
    # the drone: whole cycles over the loop, so it never clicks at the seam
    tt = np.arange(n) / SR
    length = n / SR
    for f0, amp in ((midi(38), 0.2), (midi(45), 0.14), (midi(50), 0.06)):
        f = round(f0 * length) / length
        out += amp * np.sin(2 * math.pi * f * tt) * (0.8 + 0.2 * np.sin(2 * math.pi * 2 * tt / length))
    for b, ch in enumerate(chords):
        start = b * 4 * beat
        place_wrap(out, pad([midi(x) for x in ch[1:]], 4 * beat + 1.2, attack=1.4, release=1.2) * 0.3, start)
        pattern = [ch[0] + 12, ch[1], ch[2], ch[3], ch[2] + 12, ch[3], ch[2], ch[1]]
        for k, note in enumerate(pattern):
            v = 0.2 if k == 0 else 0.13
            place_wrap(out, pluck(midi(note), 2.2, bright=0.55, decay=1.9) * v, start + k * beat / 2)
        place_wrap(out, frame_drum(0.7, low=True) * 0.28, start)
        place_wrap(out, frame_drum(0.4, low=False) * 0.1, start + 1.5 * beat)
        place_wrap(out, frame_drum(0.7, low=True) * 0.2, start + 2 * beat)
        place_wrap(out, frame_drum(0.4, low=False) * 0.08, start + 3.5 * beat)
    melody = [(0, 74, 2), (2, 72, 1), (3, 69, 1), (4, 67, 3), (8, 69, 2), (10, 71, 1), (11, 72, 1),
              (12, 74, 3), (16, 77, 2), (18, 76, 1), (19, 74, 1), (20, 72, 2), (24, 69, 2), (26, 67, 1),
              (27, 69, 1), (28, 64, 3)]
    for at, note, _len in melody:
        place_wrap(out, pluck(midi(note), 2.6, bright=0.4, decay=1.3) * 0.12, at * beat)
    out = fast_lowpass(out, 4200)
    return normalize(out, 0.7)


# ------------------------------------------------------------------ writing

SOUNDS = {
    # name: (builder, looping, group, gain)
    "click": (sfx_click, False, "sfx", 1.0),
    "tap": (sfx_tap, False, "sfx", 1.0),
    "card": (sfx_card, False, "sfx", 1.0),
    "page": (sfx_page, False, "sfx", 1.0),
    "pencil": (sfx_pencil, False, "sfx", 1.0),
    "crinkle": (sfx_crinkle, False, "sfx", 1.0),
    "dice": (sfx_dice, False, "sfx", 1.0),
    "ping": (sfx_ping, False, "sfx", 1.0),
    "chime": (sfx_chime, False, "sfx", 1.0),
    "sparkle": (sfx_sparkle, False, "sfx", 1.0),
    "rain": (rain_loop, True, "ambience", 1.0),
    "music_prep": (music_prep, True, "music", 1.0),
    "music_night": (music_night, True, "music", 1.0),
}


def write_wav(rel, x):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(path(rel), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(data)


def main():
    comps = []
    total = 0
    for name, (build, looping, group, gain) in SOUNDS.items():
        x = build()
        write_wav(f"assets/audio/{name}.wav", x)
        total += len(x) * 2
        with open(path(f"main/audio/{name}.sound"), "w", newline="\n") as f:
            f.write(f'sound: "/assets/audio/{name}.wav"\nlooping: {1 if looping else 0}\ngroup: "{group}"\n'
                    f'gain: {gain}\n')
        comps.append((name, f"/main/audio/{name}.sound"))
    comps.append(("audio", "/main/audio/audio.script"))
    with open(path("main/audio/audio.go"), "w", newline="\n") as f:
        for cid, comp in comps:
            f.write(f'components {{\n  id: "{cid}"\n  component: "{comp}"\n}}\n')
    print(f"wrote {len(SOUNDS)} sounds, {total / 1e6:.1f} MB")


if __name__ == "__main__":
    main()

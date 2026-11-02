"""A 40-second trailer cue, synthesized: python3 tools/trailer/music.py out.wav

128 BPM in D minor. A heartbeat open, a driving build with toms and a pulsing bass, a full
combat stretch, a lighter "reading the table" stretch, a riser and drum roll, a silence, then
one big hit under the title and a long tail. Section times are in SECTIONS (seconds), so the
cut can be laid against them.
"""
import sys

import numpy as np

SR = 44100
BPM = 128
BEAT = 60.0 / BPM
BAR = 4 * BEAT
LEN = 40.0

# Where each part starts (s): open, build, drive, combat, read, build-up, silence, hit.
SECTIONS = {"open": 0.0, "build": 2 * BAR, "drive": 6 * BAR, "combat": 10 * BAR, "read": 13 * BAR,
            "rise": 17 * BAR, "gap": 19 * BAR - 0.18, "hit": 19 * BAR}

rng = np.random.default_rng(7)
N = int(SR * LEN)
L = np.zeros(N)
R = np.zeros(N)


def t_of(n):
    return np.arange(n) / SR


def add(sig, at, gain=1.0, pan=0.0):
    i = int(at * SR)
    if i >= N:
        return
    sig = sig[: N - i]
    l = gain * np.cos((pan + 1) * np.pi / 4) * np.sqrt(2)
    r = gain * np.sin((pan + 1) * np.pi / 4) * np.sqrt(2)
    L[i:i + len(sig)] += sig * l
    R[i:i + len(sig)] += sig * r


def onepole_lp(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def lp(x, cutoff, passes=2):
    # (vectorised enough: scipy's lfilter if there, a one-pole otherwise)
    try:
        from scipy.signal import lfilter
        a = np.exp(-2 * np.pi * cutoff / SR)
        for _ in range(passes):
            x = lfilter([1 - a], [1, -a], x)
        return x
    except ImportError:
        for _ in range(passes):
            x = onepole_lp(x, cutoff)
        return x


def hp(x, cutoff):
    return x - lp(x, cutoff, 1)


def env(n, attack, decay):
    t = t_of(n)
    e = np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-t / decay)
    return e


def note_hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# --- instruments ---------------------------------------------------------------------------------

def kick(big=1.0):
    n = int(0.55 * SR)
    t = t_of(n)
    f = 45 + 95 * np.exp(-t / 0.035)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / (0.28 * big))
    click = rng.standard_normal(n) * np.exp(-t / 0.004) * 0.3
    return np.tanh(1.6 * (body + click)) * 0.9


def tom(pitch=95, decay=0.35):
    n = int(0.8 * SR)
    t = t_of(n)
    f = pitch * (1 + 0.6 * np.exp(-t / 0.03))
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / decay)
    skin = lp(rng.standard_normal(n), 900) * np.exp(-t / 0.06) * 0.6
    return np.tanh(1.3 * (body + skin)) * 0.8


def snare():
    n = int(0.3 * SR)
    t = t_of(n)
    noise = hp(lp(rng.standard_normal(n), 7000), 900) * np.exp(-t / 0.09)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.05)
    return (noise * 0.8 + tone * 0.5) * 0.8


def clap():
    n = int(0.25 * SR)
    out = np.zeros(n)
    for k, d in enumerate([0.0, 0.011, 0.022]):
        i = int(d * SR)
        m = n - i
        tt = t_of(m)
        out[i:] += hp(rng.standard_normal(m), 1200) * np.exp(-tt / (0.012 if k < 2 else 0.12))
    return out * 0.5


def hat(open_=False):
    n = int((0.25 if open_ else 0.06) * SR)
    t = t_of(n)
    return hp(hp(rng.standard_normal(n), 7000), 7000) * np.exp(-t / (0.08 if open_ else 0.015)) * 0.3


def crash(length=3.5):
    n = int(length * SR)
    t = t_of(n)
    x = hp(hp(rng.standard_normal(n), 3500), 3500) * np.exp(-t / 1.1)
    return x * 0.5


def boom(length=4.0):
    n = int(length * SR)
    t = t_of(n)
    f = 32 + 40 * np.exp(-t / 0.15)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / 1.4)
    grit = lp(rng.standard_normal(n), 300) * np.exp(-t / 0.4) * 0.8
    return np.tanh(2.0 * (body + grit)) * 0.95


def saw(freq, n, detune=0.0):
    t = t_of(n)
    out = np.zeros(n)
    for d in ([-detune, 0, detune] if detune else [0]):
        f = freq * (1 + d)
        out += 2 * ((t * f) % 1.0) - 1
    return out / (3 if detune else 1)


def pad(midis, length, cutoff=1400, gain=0.16):
    n = int(length * SR)
    t = t_of(n)
    x = np.zeros(n)
    for m in midis:
        x += saw(note_hz(m), n, detune=0.006)
    x = lp(x, cutoff)
    e = np.minimum(1, t / 0.35) * np.minimum(1, (length - t) / 0.3).clip(0, 1)
    return x * e * gain


def bass_note(midi, length, cutoff=500):
    n = int(length * SR)
    t = t_of(n)
    x = saw(note_hz(midi), n) + 0.6 * np.sin(2 * np.pi * note_hz(midi - 12) * t)
    x = lp(x, cutoff)
    return np.tanh(2.2 * x) * env(n, 0.004, length * 0.7) * 0.32


def pluck(midi, length=0.22, gain=0.14):
    n = int(length * SR)
    t = t_of(n)
    f = note_hz(midi)
    x = (2 * ((t * f) % 1.0) - 1) * 0.6 + np.sign(np.sin(2 * np.pi * f * t)) * 0.4
    x = lp(x, 2600)
    return x * env(n, 0.002, 0.09) * gain


def riser(length):
    n = int(length * SR)
    t = t_of(n)
    noise = rng.standard_normal(n)
    # a sweeping band: low-passed noise whose cutoff climbs (done in chunks)
    out = np.zeros(n)
    chunk = 2048
    for i in range(0, n, chunk):
        frac = i / n
        c = 300 + 9000 * frac ** 2
        seg = noise[i:i + chunk]
        out[i:i + chunk] = hp(lp(seg, c), c * 0.3)
    sweep = np.sin(2 * np.pi * np.cumsum(120 + 900 * (t / length) ** 2) / SR) * 0.25
    e = (t / length) ** 1.6
    return (out * 0.5 + sweep) * e * 0.6


def whoosh(length=0.6):
    n = int(length * SR)
    t = t_of(n)
    x = hp(lp(rng.standard_normal(n), 2500), 300)
    e = np.sin(np.pi * t / length) ** 2
    return x * e * 0.25


# --- the arrangement -------------------------------------------------------------------------------

# Dm  Bb  F  C, one chord a bar (roots for the bass, triads for the pad).
PROG = [(50, [62, 65, 69]), (46, [58, 62, 65]), (53, [60, 65, 69]), (48, [60, 64, 67])]


def bar_t(b):
    return b * BAR


# The open: heartbeat kicks and a low drone, a whoosh into the build.
for b in range(0, 2):
    add(kick(0.8), bar_t(b), 0.7)
    add(kick(0.6), bar_t(b) + BEAT * 0.75, 0.45)
    add(kick(0.8), bar_t(b) + 2 * BEAT, 0.7)
    add(kick(0.6), bar_t(b) + 2.75 * BEAT, 0.45)
add(pad([38, 45, 50], 2 * BAR, cutoff=600, gain=0.22), 0.0)
add(riser(BAR), bar_t(1), 0.6)

# The build (bars 2-5) and the drive (6-9): toms, bass, pad; hats and claps join in the drive.
for b in range(2, 10):
    root, chord = PROG[(b - 2) % 4]
    add(pad(chord, BAR, cutoff=1200 if b < 6 else 2000, gain=0.13), bar_t(b))
    for e in range(8):
        add(bass_note(root - 12 if e % 2 == 0 else root, BEAT / 2 * 0.95), bar_t(b) + e * BEAT / 2, 0.9)
    add(kick(), bar_t(b), 0.9)
    add(kick(), bar_t(b) + 2 * BEAT, 0.9)
    for i, (beat, p) in enumerate([(0.5, 110), (1.5, 95), (2.5, 110), (3.25, 80), (3.5, 80)]):
        add(tom(p), bar_t(b) + beat * BEAT, 0.55, pan=(-0.4 if i % 2 else 0.4))
    if b >= 6:
        add(clap(), bar_t(b) + BEAT, 0.7)
        add(clap(), bar_t(b) + 3 * BEAT, 0.7)
        for s in range(8):
            add(hat(open_=(s % 4 == 2)), bar_t(b) + s * BEAT / 2, 0.45, pan=0.3)
        arp = [chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[1] + 12]
        for s in range(16):
            add(pluck(arp[s % 4]), bar_t(b) + s * BEAT / 4, 1.0, pan=-0.3 if s % 2 else 0.3)
add(crash(2.0), bar_t(6), 0.6)
add(whoosh(0.8), bar_t(6) - 0.5, 1.0)

# Combat (bars 10-12): everything, harder; tom fills; a hit on each bar.
for b in range(10, 13):
    root, chord = PROG[(b - 10) % 4]
    add(pad(chord, BAR, cutoff=2600, gain=0.15), bar_t(b))
    for e in range(16):
        add(bass_note(root - 12 if e % 4 == 0 else root, BEAT / 4 * 0.95, cutoff=900), bar_t(b) + e * BEAT / 4, 0.8)
    for q in range(4):
        add(kick(), bar_t(b) + q * BEAT, 1.0)
    add(snare(), bar_t(b) + BEAT, 0.8)
    add(snare(), bar_t(b) + 3 * BEAT, 0.8)
    for s in range(16):
        add(hat(), bar_t(b) + s * BEAT / 4, 0.4, pan=0.3)
    for i in range(8):
        add(tom(120 - i * 6, 0.25), bar_t(b) + 3 * BEAT + i * BEAT / 8, 0.45, pan=-0.5 + i / 8)
    add(boom(1.2), bar_t(b), 0.5)
    add(crash(1.5), bar_t(b), 0.4)

# Reading the table (bars 13-16): lighter, plucks and a softer beat, still moving.
for b in range(13, 17):
    root, chord = PROG[(b - 13) % 4]
    add(pad(chord, BAR, cutoff=1600, gain=0.14), bar_t(b))
    for e in range(4):
        add(bass_note(root - 12, BEAT * 0.9, cutoff=400), bar_t(b) + e * BEAT, 0.9)
    add(kick(), bar_t(b), 0.8)
    add(kick(), bar_t(b) + 2.5 * BEAT, 0.6)
    add(clap(), bar_t(b) + BEAT, 0.5)
    add(clap(), bar_t(b) + 3 * BEAT, 0.5)
    arp = [chord[0] + 12, chord[2] + 12, chord[1] + 24, chord[2] + 12]
    for s in range(16):
        add(pluck(arp[s % 4], gain=0.16), bar_t(b) + s * BEAT / 4, 1.0, pan=-0.4 if s % 2 else 0.4)
add(whoosh(0.7), bar_t(13) - 0.45, 1.0)

# The build-up (bars 17-18): a snare roll that speeds up, toms, a riser; then a breath of silence.
for b in range(17, 19):
    root, chord = PROG[(b - 17) % 4]
    add(pad(chord, BAR, cutoff=2400, gain=0.15), bar_t(b))
    for e in range(8):
        add(bass_note(root - 12, BEAT / 2 * 0.95, cutoff=700), bar_t(b) + e * BEAT / 2, 0.85)
    add(kick(), bar_t(b), 1.0)
    add(kick(), bar_t(b) + 2 * BEAT, 1.0)
t = bar_t(17)
step = BEAT / 2
end = SECTIONS["gap"]
while t < end - 0.02:
    frac = (t - bar_t(17)) / (end - bar_t(17))
    add(snare(), t, 0.35 + 0.5 * frac)
    t += step * (1 - 0.75 * frac)
add(riser(end - bar_t(17)), bar_t(17), 0.9)

# The hit under the title, and its tail: the opening chord, held.
hit = SECTIONS["hit"]
add(boom(5.0), hit, 1.0)
add(kick(1.5), hit, 1.0)
add(crash(4.0), hit, 0.8)
add(tom(70, 0.9), hit, 0.7)
add(pad([38, 50, 57, 62, 65], LEN - hit, cutoff=1800, gain=0.2), hit)
add(pluck(74, 1.2, 0.18), hit + 2 * BEAT, 1.0)
add(pluck(77, 1.2, 0.16), hit + 3 * BEAT, 1.0)
add(pluck(81, 1.6, 0.16), hit + 4 * BEAT, 1.0)

# Silence before the hit (everything that rang into the gap is cut).
g0, g1 = int(SECTIONS["gap"] * SR), int(hit * SR)
fade = np.linspace(1, 0, g1 - g0) ** 3
L[g0:g1] *= fade
R[g0:g1] *= fade

# Master: a soft clip, a fade out at the very end, -1 dBFS.
mix = np.stack([L, R], axis=1)
mix = np.tanh(mix * 1.1)
tail = int(2.5 * SR)
mix[-tail:] *= np.linspace(1, 0, tail)[:, None] ** 1.5
mix /= np.max(np.abs(mix)) + 1e-9
mix *= 10 ** (-1 / 20)

out = sys.argv[1] if len(sys.argv) > 1 else "trailer_music.wav"
import wave

with wave.open(out, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((mix * 32767).astype("<i2").tobytes())
print("wrote", out, "sections:", {k: round(v, 2) for k, v in SECTIONS.items()})

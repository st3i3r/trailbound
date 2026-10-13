#!/usr/bin/env python3
"""tb_sfx.py — synthesize the placeholder UI sfx set (0 gens).

Writes tiny 16-bit mono WAVs into game/assets/pinewatch/sfx/.  These are
deliberate placeholders: soft, short, warm — close to Eastward's
woodblock-pluck register so the shipped set can be re-rendered 1:1 by
name later.  Deterministic (no RNG): safe to re-run in CI.

Run:  python tools/tb_sfx.py
"""
import math
import os
import struct
import wave

SR = 22050
ROOT = os.path.join(os.path.dirname(__file__),
                    "..", "game", "assets", "pinewatch")
OUT = os.path.join(ROOT, "sfx")


def _env(t, n, attack=0.06):
    """Attack + exponential-decay envelope."""
    a = max(1, int(n * attack))
    if t < a:
        return t / a
    x = (t - a) / (n - a)
    return math.exp(-4.0 * x)


def sine(freq_fn, secs, amp=0.5, attack=0.06, harmonics=((2.0, 0.15),)):
    """freq_fn(u) -> Hz over normalized time; adds light harmonics."""
    n = int(SR * secs)
    out = []
    phase = 0.0
    for t in range(n):
        u = t / n
        f = freq_fn(u)
        phase += 2.0 * math.pi * f / SR
        s = math.sin(phase)
        for h, g in harmonics:
            s += g * math.sin(phase * h)
        out.append(amp * _env(t, n, attack) * s)
    return out


def noise_thump(secs, amp=0.5, base=90.0, attack=0.02):
    """Soft mallet thud — decaying sine + a tick of noise."""
    n = int(SR * secs)
    out = []
    phase = 0.0
    for t in range(n):
        u = t / n
        f = base * (1.0 - 0.4 * u)
        phase += 2.0 * math.pi * f / SR
        # deterministic pseudo-noise: high-frequency sine hash
        nz = math.sin(t * 1.6180339) * math.sin(t * 0.7548776)
        s = math.sin(phase) + 0.25 * nz * math.exp(-30.0 * u)
        out.append(amp * _env(t, n, attack) * s)
    return out


def square(freq, secs, amp=0.28, duty=0.5, attack=0.02, decay=7.0):
    """Harsh-ish blip kept quiet — warn/alert register."""
    n = int(SR * secs)
    out = []
    phase = 0.0
    for t in range(n):
        u = t / n
        phase += 2.0 * math.pi * freq / SR
        s = 1.0 if (phase % (2 * math.pi)) < duty * 2 * math.pi else -1.0
        out.append(amp * (1.0 if t < n * attack else
                          math.exp(-decay * u)) * s)
    return out


def sweep(f0, f1, secs, amp=0.4):
    return sine(lambda u: f0 + (f1 - f0) * u, secs, amp)


def cat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def write(name, samples, sub="sfx"):
    out = os.path.join(ROOT, sub)
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, name + ".wav")
    peak = max(1e-9, max(abs(s) for s in samples))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s / peak))
                              * 0.85 * 32767))
            for s in samples))
    print(sub + "/" + name, "%.0fms" % (len(samples) / SR * 1000))


# ---------------------------------------------------------------- loops
# Music + ambience beds loop (LOOP_FORWARD is set on the stream in
# audio.gd, so seamless edges matter here): every loop fades its first
# and last ~60 ms to silence so the seam can never click.

def loop_fade(samples, ms=60):
    n = min(len(samples) // 2, int(SR * ms / 1000))
    for i in range(n):
        w = i / n
        samples[i] *= w
        samples[-1 - i] *= w
    return samples


def pad(chords, secs, amp=0.30):
    """Sustained chord slices with slow swells — the warm synth pad
    under title/camp.  Phase keyed to absolute t so slices blend."""
    n = int(SR * secs)
    out = [0.0] * n
    nch = len(chords)
    for ci, freqs in enumerate(chords):
        t0 = int(n * ci / nch)
        t1 = int(n * (ci + 1) / nch)
        for t in range(t0, t1):
            u = (t - t0) / max(1, t1 - t0)
            swell = math.sin(math.pi * u) ** 0.7
            s = sum(math.sin(2.0 * math.pi * f * t / SR)
                    + 0.3 * math.sin(4.0 * math.pi * f * t / SR)
                    for f in freqs) / len(freqs)
            out[t] += amp * swell * s
    return out


def pluck(freq, at, out, amp=0.45, dur=0.45):
    """Music-box note: sine + 4th harmonic, fast decay."""
    n0 = int(at * SR)
    n = int(dur * SR)
    phase = 0.0
    for i in range(n):
        idx = n0 + i
        if idx >= len(out):
            break
        phase += 2.0 * math.pi * freq / SR
        out[idx] += amp * math.exp(-6.0 * i / n) \
            * (math.sin(phase) + 0.25 * math.sin(phase * 4.0))
    return out


def bed(out, amp=0.05, swells=3):
    """Air/noise bed — deterministic sine-hash at low level with slow
    broad swells so the bed breathes instead of hissing flatly."""
    n = len(out)
    for t in range(n):
        u = t / n
        swell = 0.7 + 0.3 * math.sin(2.0 * math.pi * u * swells)
        nz = math.sin(t * 1.6180339) * math.sin(t * 0.7548776)
        out[t] += amp * swell * nz
    return out


def chirp(f0, f1, at, out, dur=0.11, amp=0.30):
    """Small bird chirp: fast up-sweep with a bell envelope."""
    n0 = int(at * SR)
    n = int(dur * SR)
    ph = 0.0
    for i in range(n):
        idx = n0 + i
        if idx >= len(out):
            break
        u = i / n
        ph += 2.0 * math.pi * (f0 + (f1 - f0) * u) / SR
        out[idx] += amp * math.sin(ph) * math.sin(math.pi * u)
    return out


def cricket(at, out, rate=4200.0, pulses=6, gap=0.028, pdur=0.011,
            amp=0.22):
    """One cricket voice: a burst of short high sine pulses."""
    t = at
    for _ in range(pulses):
        n0 = int(t * SR)
        n = int(pdur * SR)
        for i in range(n):
            idx = n0 + i
            if idx >= len(out):
                return out
            out[idx] += amp * math.sin(2.0 * math.pi * rate * idx / SR)
        t += pdur + gap
    return out


def main():
    # press — short woodblock tick
    write("press", sine(lambda u: 950 - 250 * u, 0.055, amp=0.5,
                        harmonics=((3.0, 0.2),)))
    # confirm — two rising plucks
    write("confirm", cat(sweep(620, 620, 0.07),
                       sweep(620, 930, 0.10)))
    # warn — two low square buzzes
    write("warn", cat(square(150, 0.07), [0.0] * int(SR * 0.03),
                    square(120, 0.10)))
    # open — sheet slides up
    write("open", sweep(340, 760, 0.14))
    # close — slide back down
    write("close", sweep(720, 380, 0.12))
    # coin — bright two-note ping (pay/count-up)
    write("coin", cat(sweep(1568, 1568, 0.07, amp=0.4),
                      sweep(2093, 2093, 0.13, amp=0.4)))
    # pop — squash-stretch landing (seats, drops)
    write("pop", sine(lambda u: 300 + 420 * math.sin(u * math.pi),
                      0.09, amp=0.5))
    # tick — count-up step / hover tick
    write("tick", sine(lambda u: 1800 - 300 * u, 0.03, amp=0.35,
                       harmonics=()))
    # stamp — ceremony thud (pages, keepsakes)
    write("stamp", noise_thump(0.16, amp=0.6))
    # thunder — lightning crack: low boom with a noise tick up front
    write("thunder", noise_thump(1.1, amp=0.8, base=62.0,
                                 attack=0.01))

    # -------------------------------------------------- music (loops)
    A3, C4, E4, G3, B3, D4, F3 = 220.0, 261.6, 329.6, 196.0, 246.9, \
        293.7, 174.6
    A4, C5, E5, G4, D5 = 440.0, 523.3, 659.3, 392.0, 587.3
    # title — Am F C G, sparse music-box fragments over the swell
    t = pad([[A3, C4, E4], [F3, A3, C4], [C4 * 0.5, E4, G3],
             [G3, B3, D4]], 8.0, amp=0.30)
    pluck(A4, 1.0, t); pluck(E5, 2.5, t); pluck(C5, 4.0, t)
    pluck(G4, 6.0, t); pluck(A4, 7.0, t, amp=0.35)
    write("title", loop_fade(t), "music")
    # camp — C Am F G, warmer pentatonic pluck line
    c = pad([[C4 * 0.5, E4, G3], [A3, C4, E4], [F3, A3, C4],
             [G3, B3, D4]], 8.0, amp=0.30)
    pluck(C5, 0.5, c); pluck(D5, 1.5, c); pluck(E5, 2.5, c)
    pluck(G4, 4.0, c); pluck(A4, 5.0, c); pluck(E5, 6.5, c, amp=0.35)
    write("camp", loop_fade(c), "music")

    # ------------------------------------------------ ambience (loops)
    d = bed([0.0] * int(SR * 10.0), amp=0.045)
    for at, f0, f1 in [(0.7, 2800, 3400), (2.3, 3100, 2600),
                       (4.1, 2400, 3300), (5.9, 2900, 3500),
                       (7.8, 2700, 3100)]:
        chirp(f0, f1, at, d)
        chirp(f0 * 1.02, f1 * 1.02, at + 0.16, d, dur=0.08, amp=0.18)
    write("day", loop_fade(d), "amb")
    ng = bed([0.0] * int(SR * 10.0), amp=0.030)
    for at in [0.4, 1.7, 3.0, 4.6, 6.1, 7.5, 8.8]:
        cricket(at, ng)
        cricket(at + 0.55, ng, rate=4600.0, pulses=4, amp=0.15)
    write("night", loop_fade(ng), "amb")
    # storm — dense rain wash over a slow low-pressure rumble; the
    # front scalar rides this in at 0.85*f^2 under the wildlife beds
    s = bed([0.0] * int(SR * 10.0), amp=0.10, swells=4)
    r = pad([[55.0], [48.0]], 10.0, amp=0.06)
    for i, v in enumerate(r):
        s[i] += v
    write("storm", loop_fade(s), "amb")


if __name__ == "__main__":
    main()

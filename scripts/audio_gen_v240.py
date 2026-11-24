#!/usr/bin/env python3
"""LEVERAGE v2.4.0 'Alive City' SFX additions (originals, pure numpy DSP):
  sfx_ped_scream     - short panic yelp (pedestrians flee/cower)
  sfx_wanted_clear   - evasion payoff stinger (wanted cleared)
  sfx_heli_loop      - 5-star air unit rotor loop (loopable)
  sfx_medal          - mission medal fanfare (3-note arp)
Writes .wav into leverage/assets/audio/sfx/ (Godot import makes the .ogg).
"""
import numpy as np
import os
import wave

SR = 44100
OUT = "/home/z/my-project/leverage/assets/audio/sfx"


def write_wav(path, data, vol=1.0):
    data = data * vol
    if data.ndim == 1:
        data = np.stack([data, data], axis=1)
    peak = np.max(np.abs(data)) + 1e-9
    if peak > 1.0:
        data = data / peak * 0.95
    ints = (data * 32767).astype(np.int16)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(ints.tobytes())
    print("WROTE", path)


def env(n, a=0.01, r=0.3):
    e = np.ones(n)
    ai = int(a * SR)
    ri = int(r * SR)
    if ai > 0:
        e[:ai] = np.linspace(0, 1, ai)
    if ri > 0:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def sine(f, n, ph=0.0):
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * f * t + ph)


def tri(f, n):
    t = np.arange(n) / SR
    x = (t * f) % 1.0
    return 4 * np.abs(x - 0.5) - 1


def noise(n):
    return np.random.default_rng(7).standard_normal(n)


# --- sfx_ped_scream: 0.45 s panic yelp - descending chirp + vibrato + breath
def ped_scream():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f0 = 900.0 - 480.0 * (t / t[-1])          # 900 -> 420 Hz
    vib = 1.0 + 0.03 * np.sin(2 * np.pi * 9.0 * t)
    ph = 2 * np.pi * np.cumsum(f0 * vib) / SR
    tone = np.sin(ph) * 0.7 + np.sin(2 * ph) * 0.18
    breath = noise(n) * 0.10 * np.exp(-t * 4.0)
    e = env(n, a=0.015, r=0.22)
    return (tone + breath) * e


# --- sfx_wanted_clear: 0.9 s two-note "all clear" chime (E5 -> A5) w/ shimmer
def wanted_clear():
    n = int(0.9 * SR)
    out = np.zeros(n)
    for i, (f, start) in enumerate([(659.26, 0.0), (880.0, 0.28)]):
        nn = int(0.55 * SR)
        s = int(start * SR)
        seg = sine(f, nn) * 0.55 + sine(f * 2, nn) * 0.12 + tri(f, nn) * 0.10
        # gentle shimmer tremolo
        t = np.arange(nn) / SR
        seg *= (1.0 + 0.12 * np.sin(2 * np.pi * 5.5 * t))
        seg *= env(nn, a=0.012, r=0.3)
        end = min(s + nn, n)
        out[s:end] += seg[: end - s]
    return out


# --- sfx_heli_loop: 5.0 s loopable rotor thump (13 Hz chop over low tone+rumble)
def heli_loop():
    n = int(5.0 * SR)
    t = np.arange(n) / SR
    chop = 0.5 * (1.0 + np.sin(2 * np.pi * 13.0 * t))       # 13 Hz blades
    chop = 0.35 + 0.65 * chop ** 2                            # punchy
    low = sine(64.0, n) * 0.5 + sine(97.0, n) * 0.15
    rumble = noise(n) * 0.20
    # band-limit the rumble with a cheap one-pole lowpass
    lp = np.zeros(n)
    acc = 0.0
    for i in range(n):
        acc += 0.02 * (rumble[i] - acc)
        lp[i] = acc
    body = (low + lp * 3.0) * chop
    # seamless loop: crossfade last/first 0.25 s
    xf = int(0.25 * SR)
    fade_in = np.linspace(0, 1, xf)
    fade_out = np.linspace(1, 0, xf)
    body[:xf] = body[:xf] * fade_in + body[-xf:] * fade_out
    body = body[:-xf]
    peak = np.max(np.abs(body)) + 1e-9
    return body / peak * 0.9


# --- sfx_medal: 1.0 s three-note ascending arp (A4 C#5 E5) triangle+sine
def medal():
    n = int(1.0 * SR)
    out = np.zeros(n)
    for f, start, amp in [(440.0, 0.0, 0.5), (554.37, 0.16, 0.55), (659.26, 0.32, 0.65)]:
        nn = int(0.6 * SR)
        s = int(start * SR)
        seg = (sine(f, nn) * 0.6 + tri(f, nn) * 0.25) * amp
        seg *= env(nn, a=0.01, r=0.28)
        end = min(s + nn, n)
        out[s:end] += seg[: end - s]
    return out


write_wav(os.path.join(OUT, "sfx_ped_scream.wav"), ped_scream(), 0.85)
write_wav(os.path.join(OUT, "sfx_wanted_clear.wav"), wanted_clear(), 0.9)
write_wav(os.path.join(OUT, "sfx_heli_loop.wav"), heli_loop(), 0.9)
write_wav(os.path.join(OUT, "sfx_medal.wav"), medal(), 0.9)
print("done")

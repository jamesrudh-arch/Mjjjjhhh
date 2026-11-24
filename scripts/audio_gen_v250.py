#!/usr/bin/env python3
"""LEVERAGE v2.5.0 'The Living City' SFX additions (originals, pure numpy DSP):
  sfx_train_horn      - two-tone air horn (Cinder Line)
  sfx_train_rumble    - loopable low rail rumble
  sfx_station_bell    - platform ding-ding bell
  sfx_water_lap       - loopable gentle river lapping
  sfx_splash          - fish jump splash
  sfx_gull            - gull cry
  sfx_pigeon_flutter  - pigeon wing burst
  sfx_crickets        - loopable night crickets
  sfx_logo_sting      - DE YOUNG GAMES logo sting (swell -> hit -> shimmer)
  sfx_explosion       - deep cinematic boom (gas pumps / set-pieces)
Writes .wav then converts to .ogg with ffmpeg (game loads the .ogg).
"""
import numpy as np
import os
import wave
import subprocess

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
    return path


def to_ogg(wav_path):
    ogg = wav_path.replace(".wav", ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                    "-c:a", "libvorbis", "-qscale:a", "4", ogg], check=True)
    print("OGG", ogg)


def env(n, a=0.01, r=0.3):
    e = np.ones(n)
    ai = min(int(a * SR), n)
    ri = min(int(r * SR), n)
    if ai > 0:
        e[:ai] = np.linspace(0, 1, ai)
    if ri > 0:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def sine(f, n, ph=0.0):
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * f * t + ph)


def noise(n, seed=7):
    return np.random.default_rng(seed).standard_normal(n)


def lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


# --- sfx_train_horn: 1.7 s two-tone air horn (Bb3 + Eb4), swell in, tail out
def train_horn():
    n = int(1.7 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f, amp in [(233.08, 0.5), (311.13, 0.42), (466.16, 0.18)]:
        out += sine(f, n) * amp
    grit = lowpass(noise(n, 3), 0.02) * 0.35
    swell = np.minimum(t / 0.16, 1.0) * np.exp(-np.maximum(t - 1.15, 0) * 3.2)
    return (out + grit) * swell


# --- sfx_train_rumble: 6 s seamless loop, brown noise + rail clacks + AM
def train_rumble():
    n = int(6.0 * SR)
    t = np.arange(n) / SR
    brown = np.cumsum(noise(n, 11)) * 0.002
    brown = lowpass(brown, 0.06)
    brown -= brown.mean()
    clack = np.zeros(n)
    for off in np.arange(0, 6.0, 0.86):
        i = int(off * SR)
        if i + 3000 < n:
            clack[i:i + 3000] += lowpass(noise(3000, 21), 0.3) * env(3000, 0.001, 0.05) * 0.22
    am = 1.0 + 0.22 * np.sin(2 * np.pi * 0.8 * t) + 0.1 * np.sin(2 * np.pi * 2.1 * t)
    x = (brown * 1.6 + clack) * am
    # crossfade loop seam
    xf = int(0.35 * SR)
    x[:xf] *= np.linspace(0, 1, xf)
    x[-xf:] *= np.linspace(1, 0, xf)
    return x


# --- sfx_station_bell: two metallic ding strikes (2.1 kHz + partials)
def station_bell():
    n = int(1.3 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for start in [0.0, 0.38]:
        s = int(start * SR)
        nn = n - s
        seg = np.zeros(nn)
        for f, a, d in [(2093.0, 0.5, 5.0), (2637.0, 0.22, 6.0), (3520.0, 0.12, 7.0), (5274.0, 0.06, 9.0)]:
            seg += sine(f, nn) * a * np.exp(-t[:nn] * d)
        strike = lowpass(noise(nn, 31), 0.4)[:nn] * np.exp(-t[:nn] * 60.0) * 0.25
        out[s:] += (seg + strike) * env(nn, 0.002, 0.4)
    return out


# --- sfx_water_lap: 8 s loop, filtered noise swells at irregular intervals
def water_lap():
    n = int(8.0 * SR)
    t = np.arange(n) / SR
    base = lowpass(noise(n, 41), 0.045)
    base -= base.mean()
    swells = np.zeros(n)
    rng = np.random.default_rng(43)
    off = 0.0
    while off < 7.6:
        dur = rng.uniform(0.5, 1.3)
        amp = rng.uniform(0.25, 0.6)
        i = int(off * SR)
        j = min(n, i + int(dur * SR))
        seg_t = np.arange(j - i) / SR
        swells[i:j] += np.sin(np.pi * seg_t / dur) ** 2 * amp
        off += dur + rng.uniform(0.15, 0.7)
    x = base * (0.5 + swells)
    # stereo width: slight detimed copy
    x2 = np.roll(x, int(0.011 * SR))
    xf = int(0.4 * SR)
    fade = np.linspace(0, 1, xf)
    for ch in (x, x2):
        ch[:xf] *= fade
        ch[-xf:] *= fade[::-1]
    return np.stack([x, x2], axis=1)


# --- sfx_splash: 0.55 s splash, noise burst with falling lowpass + droplets
def splash():
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    body = lowpass(noise(n, 51), 0.5) * np.exp(-t * 7.0)
    # falling cutoff feel: mix a progressively lowpassed copy in
    deep = lowpass(noise(n, 52), 0.04) * np.exp(-t * 4.0)
    droplets = np.zeros(n)
    rng = np.random.default_rng(53)
    for off in np.arange(0.08, 0.45, 0.05):
        i = int(off * SR)
        if i + 1200 < n:
            droplets[i:i + 1200] += sine(rng.uniform(900, 2400), 1200) * env(1200, 0.001, 0.02) * 0.18
    return (body * 0.8 + deep * 0.7 + droplets) * env(n, 0.004, 0.2)


# --- sfx_gull: 0.8 s cry, descending "kee-ah" with vibrato
def gull():
    n = int(0.8 * SR)
    t = np.arange(n) / SR
    f0 = 1500.0 - 700.0 * (t / t[-1]) ** 1.4
    vib = 1.0 + 0.05 * np.sin(2 * np.pi * 11.0 * t)
    ph = 2 * np.pi * np.cumsum(f0 * vib) / SR
    tone = np.sin(ph) * 0.6 + np.sin(2 * ph) * 0.15
    breath = lowpass(noise(n, 61), 0.3) * 0.12
    gate = ((t > 0.05) & (t < 0.30)) | ((t > 0.38) & (t < 0.66))
    return (tone + breath) * gate.astype(float) * env(n, 0.01, 0.25)


# --- sfx_pigeon_flutter: 0.9 s wing burst - amplitude-modulated noise flaps
def pigeon_flutter():
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    flap_rate = 14.0 - 6.0 * (t / t[-1])
    flaps = 0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(flap_rate) / SR)
    wings = lowpass(noise(n, 71), 0.25) * flaps
    wings *= np.exp(-t * 2.2) * env(n, 0.01, 0.4)
    return wings * 1.4


# --- sfx_crickets: 6 s night loop, chirp pulses ~4.2 kHz with trill AM
def crickets():
    n = int(6.0 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    rng = np.random.default_rng(83)
    off = 0.0
    while off < 5.7:
        dur = rng.uniform(0.25, 0.5)
        i = int(off * SR)
        j = min(n, i + int(dur * SR))
        seg_t = np.arange(j - i) / SR
        trill = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(22, 30) * seg_t)
        chirp = sine(rng.uniform(3800, 4600), j - i) * trill
        out[i:j] += chirp * np.sin(np.pi * seg_t / dur) ** 2 * rng.uniform(0.10, 0.2)
        off += dur + rng.uniform(0.1, 0.55)
    bed = lowpass(noise(n, 91), 0.02) * 0.10
    x = out + bed
    xf = int(0.5 * SR)
    x[:xf] *= np.linspace(0, 1, xf)
    x[-xf:] *= np.linspace(1, 0, xf)
    return x


# --- sfx_logo_sting: 2.4 s DE YOUNG GAMES ident - swell, impact, shimmer
def logo_sting():
    n = int(2.4 * SR)
    t = np.arange(n) / SR
    # low swell (0.0-0.9 s): rising minor pad
    swell_t = np.clip(t / 0.9, 0, 1)
    swell = (sine(87.31, n) * 0.30 + sine(130.81, n) * 0.22 + sine(174.61, n) * 0.14)
    swell *= swell_t ** 2 * (t < 1.0) * 0.9
    # impact at 0.9 s: deep hit + noise thump
    hit = np.exp(-np.maximum(t - 0.9, 0) * 6.5) * (t >= 0.9)
    body = sine(58.27, n) * 0.85 + sine(87.31, n) * 0.4 + sine(116.54, n) * 0.18
    thump = lowpass(noise(n, 101), 0.05) * 0.5
    impact = (body + thump) * hit
    # shimmer tail: rising 5th arpeggio (D-A-D-F#) with bell tones
    shimmer = np.zeros(n)
    for i, (f, start) in enumerate([(293.66, 1.02), (440.0, 1.18), (587.33, 1.34), (739.99, 1.52)]):
        s = int(start * SR)
        nn = n - s
        seg = sine(f, nn) * 0.20 + sine(f * 2, nn) * 0.06
        seg *= np.exp(-np.arange(nn) / SR * 1.6)
        shimmer[s:] += seg
    x = swell + impact + shimmer
    return x * env(n, 0.02, 0.5)


# --- sfx_explosion: 1.6 s cinematic boom - sub drop + crack + debris
def explosion():
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    # sub drop 70 -> 30 Hz
    f0 = 70.0 * np.exp(-t * 1.9) + 30.0
    ph = 2 * np.pi * np.cumsum(f0) / SR
    sub = np.sin(ph) * np.exp(-t * 2.4) * 0.9
    # crack (start transient)
    crack = lowpass(noise(n, 111), 0.6) * np.exp(-t * 26.0) * 0.8
    # body rumble
    rumble = lowpass(noise(n, 112), 0.03) * np.exp(-t * 2.8) * 0.8
    # debris ticks
    debris = np.zeros(n)
    rng = np.random.default_rng(113)
    for off in np.arange(0.15, 1.2, 0.09):
        i = int(off * SR)
        if i + 900 < n:
            debris[i:i + 900] += lowpass(noise(900, 121), 0.5) * env(900, 0.001, 0.03) * rng.uniform(0.1, 0.25)
    x = sub + crack + rumble + debris
    return x * env(n, 0.002, 0.45)


if __name__ == "__main__":
    for name, fn, vol in [
            ("sfx_train_horn", train_horn, 0.9),
            ("sfx_train_rumble", train_rumble, 0.8),
            ("sfx_station_bell", station_bell, 0.85),
            ("sfx_water_lap", water_lap, 0.9),
            ("sfx_splash", splash, 0.9),
            ("sfx_gull", gull, 0.8),
            ("sfx_pigeon_flutter", pigeon_flutter, 0.85),
            ("sfx_crickets", crickets, 0.7),
            ("sfx_logo_sting", logo_sting, 0.95),
            ("sfx_explosion", explosion, 0.95)]:
        p = write_wav(os.path.join(OUT, name + ".wav"), fn(), vol)
        to_ogg(p)
        os.remove(p)
    print("DONE - 10 new SFX")

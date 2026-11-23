#!/usr/bin/env python3
"""LEVERAGE audio synthesis - all music moods, ambience beds, SFX set,
radio loops and jingles as original .wav files (neo-noir identity).
Outputs to leverage/assets/audio/{music,sfx}/.
Pure numpy DSP - no third-party samples (see asset_register.md)."""
import numpy as np
import os
import wave
import math

SR = 44100
OUT = "/home/z/my-project/leverage/assets/audio"
MUSIC = os.path.join(OUT, "music")
SFX = os.path.join(OUT, "sfx")


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


def saw(f, n):
    t = np.arange(n) / SR
    return 2 * ((t * f) % 1.0) - 1


def tri(f, n):
    t = np.arange(n) / SR
    x = (t * f) % 1.0
    return 4 * np.abs(x - 0.5) - 1


def noise(n, lp=0.2):
    r = np.random.default_rng(7)
    x = r.standard_normal(n)
    # cheap lowpass via cumulative smoothing
    k = int(lp * SR)
    if k > 2:
        kern = np.ones(k) / k
        x = np.convolve(x, kern, "same")
    return x


def fade_loop(x, seconds=0.6):
    f = int(seconds * SR)
    if len(x) <= f * 2:
        return x
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    return x


def addto(x, i0, seg):
    """Safely add seg into x at index i0, clipping to x length."""
    if i0 >= len(x):
        return x
    room = min(len(seg), len(x) - i0)
    if room > 0:
        x[i0:i0 + room] += seg[:room]
    return x


def kick(n=None, dur=0.16, tone=52.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = tone * (1 + 6 * np.exp(-t * 26))
    amp = np.exp(-t * 15)
    return np.sin(2 * np.pi * f * t) * amp


def brush(n=None, dur=0.12, hp=2000):
    n = int(dur * SR)
    x = noise(n, lp=0.002)
    b = np.exp(-np.arange(n) / SR * 22)
    return x * b


def snare(dur=0.2):
    n = int(dur * SR)
    b = np.exp(-np.arange(n) / SR * 18)
    x = noise(n, lp=0.004) * b
    return x


def bass_note(f, dur, decay=4.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = tri(f, n) * 0.6 + saw(f, n) * 0.25
    x += sine(f / 2, n) * 0.3
    x *= np.exp(-t * decay * 0.4)
    return x


def pad_chord(freqs, dur, detune=0.004):
    n = int(dur * SR)
    x = np.zeros(n)
    for f in freqs:
        x += sine(f * (1 - detune), n) * 0.5
        x += sine(f * (1 + detune), n) * 0.5
        x += sine(f * 2.0, n) * 0.12
    x /= len(freqs)
    return x


def brassy(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = saw(f, n) * 0.5 + saw(f * 1.005, n) * 0.3 + sine(f, n) * 0.4
    x *= np.exp(-t * 3.0) * (1 - np.exp(-t * 60))
    return x


# ---------------- MUSIC ----------------
def mus_menu():
    """Dark menu theme: low drone + sparse piano-ish tones."""
    dur = 34.0
    n = int(dur * SR)
    x = np.zeros(n)
    # drone on D minor-ish
    for f in [73.42, 110.0, 146.83]:
        x += sine(f, n) * 0.16
    # sparse tones
    rng = np.random.default_rng(3)
    tpos = 0.0
    scale = [293.66, 349.23, 440.0, 523.25, 587.33]
    while tpos < dur - 4:
        f = scale[int(rng.integers(0, len(scale)))]
        d = int(2.5 * SR)
        i0 = int(tpos * SR)
        seg = sine(f, d) * env(d, 0.02, 1.6) * 0.22
        addto(x, i0, seg)
        tpos += 1.8
    x = fade_loop(x, 1.5)
    return x


def mus_explore(day=True):
    """Brushed drums + upright bass walking - the daily detective stride."""
    dur = 40.0
    n = int(dur * SR)
    x = np.zeros(n)
    bpm = 92 if day else 74
    beat = 60.0 / bpm
    bassline = [110.0, 130.81, 98.0, 87.31, 110.0, 130.81, 116.54, 98.0]
    bi = 0
    tpos = 0.0
    while tpos < dur - 1:
        # upright bass
        f = bassline[bi % len(bassline)]
        b = bass_note(f, beat * 0.95)
        i0 = int(tpos * SR)
        addto(x, i0, b * 0.4)
        # brushed swing
        if bi % 2 == 0:
            k = kick()
            addto(x, i0, k * 0.5)
        br = brush()
        addto(x, i0 + int(beat * 0.5 * SR), br * 0.25)
        if bi % 4 == 2:
            s = snare()
            addto(x, i0, s * 0.3)
        # sparkle keys (day) or dark pad (night)
        if day and bi % 4 == 3:
            f2 = [587.33, 659.26, 698.46][bi % 3]
            d = int(beat * 1.5 * SR)
            seg = sine(f2, d) * env(d, 0.01, 0.8) * 0.1
            addto(x, i0, seg)
        if not day:
            p = pad_chord([146.83, 174.61, 220.0], beat * 2)
            room = min(len(p), n - i0)
            if room > 0:
                x[i0:i0 + room] += p[:room] * 0.18
        tpos += beat
        bi += 1
    x = fade_loop(x, 2.0)
    return x


def mus_tension():
    dur = 30.0
    n = int(dur * SR)
    x = np.zeros(n)
    # tritone drone + pulse
    for f in [55.0, 78.0]:
        x += sine(f, n) * 0.2
    for f in [220.0, 311.0]:
        x += sine(f, n) * 0.05 * (0.5 + 0.5 * np.sin(np.arange(n) / SR * 0.7))
    pulse = int(0.46 * SR)
    for i0 in range(0, n - pulse, pulse * 2):
        x[i0:i0 + pulse] += np.hanning(pulse) * 0.08
    # ticking
    for i0 in range(0, n - 2000, int(1.02 * SR)):
        x[i0:i0 + 2000] += brush(dur=2000.0 / SR) * 0.2
    x = fade_loop(x, 1.0)
    return x


def mus_combat():
    dur = 32.0
    n = int(dur * SR)
    x = np.zeros(n)
    bpm = 132
    beat = 60.0 / bpm
    riff = [98.0, 98.0, 130.81, 98.0, 110.0, 98.0, 87.31, 98.0]
    bi = 0
    tpos = 0.0
    while tpos < dur - 1:
        f = riff[bi % len(riff)]
        b = bass_note(f, beat * 0.6, decay=7)
        i0 = int(tpos * SR)
        addto(x, i0, b * 0.55)
        k = kick(dur=0.14)
        addto(x, i0, k * 0.7)
        if bi % 2 == 1:
            s = snare(dur=0.14)
            addto(x, i0 + int(beat / 2 * SR), s * 0.5)
        if bi % 8 == 7:
            br = brassy(392.0, beat * 1.8)
            addto(x, i0, br * 0.25)
        tpos += beat
        bi += 1
    x = fade_loop(x, 1.5)
    return x


def mus_story():
    dur = 36.0
    n = int(dur * SR)
    x = pad_chord([130.81, 155.56, 196.0, 233.08], dur, detune=0.003) * 0.5
    # gentle arpeggio
    arp = [261.63, 311.13, 392.0, 466.16, 392.0, 311.13]
    tpos = 0.0
    ai = 0
    while tpos < dur - 2:
        d = int(1.2 * SR)
        i0 = int(tpos * SR)
        seg = sine(arp[ai % len(arp)], d) * env(d, 0.02, 0.9) * 0.16
        addto(x, i0, seg)
        tpos += 0.9
        ai += 1
    x = fade_loop(x, 2.0)
    return x


def mus_chase():
    dur = 30.0
    n = int(dur * SR)
    x = np.zeros(n)
    bpm = 150
    beat = 60.0 / bpm
    ost = [110.0, 116.54, 110.0, 103.83] * 2
    bi = 0
    tpos = 0.0
    while tpos < dur - 1:
        f = ost[bi % len(ost)]
        b = saw(f, int(beat * 0.5 * SR)) * env(int(beat * 0.5 * SR), 0.005, 0.12) * 0.4
        b += sine(f / 2, int(beat * 0.5 * SR)) * 0.2
        i0 = int(tpos * SR)
        addto(x, i0, b)
        k = kick(dur=0.12)
        addto(x, i0, k * 0.7)
        s = snare(dur=0.12)
        addto(x, i0 + int(beat / 2 * SR), s * 0.4)
        if bi % 4 == 0:
            br = brassy(220.0, beat * 0.9)
            addto(x, i0, br * 0.3)
        tpos += beat
        bi += 1
    x = fade_loop(x, 1.2)
    return x


def mus_sad():
    dur = 34.0
    n = int(dur * SR)
    x = pad_chord([98.0, 116.54, 146.83], dur, detune=0.002) * 0.4
    # lonely melody
    mel = [(0.0, 392.0, 2.4), (2.6, 466.16, 2.0), (4.9, 392.0, 1.8),
           (7.0, 349.23, 3.2), (10.6, 392.0, 2.6), (13.5, 311.13, 3.0),
           (17.0, 349.23, 2.2), (19.6, 293.66, 4.0), (24.2, 311.13, 4.0), (28.6, 293.66, 4.0)]
    for (tp, f, d) in mel:
        d = int(d * SR)
        i0 = int(tp * SR)
        seg = sine(f, d) * env(d, 0.05, 1.8) * 0.22
        seg += tri(f, d) * env(d, 0.05, 1.8) * 0.06
        x[i0:i0 + d] += seg[:max(0, min(d, n - i0))]
    x = fade_loop(x, 2.5)
    return x


def mus_ending():
    dur = 40.0
    n = int(dur * SR)
    x = mus_story()
    if len(x) < n:
        x = np.pad(x, (0, n - len(x)))
    elif len(x) > n:
        x = x[:n]
    # pad with deeper resolution chord swell at the end
    swell = pad_chord([65.41, 98.0, 130.81, 155.56], 8.0) * env(int(8.0 * SR), 2.0, 3.0) * 0.6
    i0 = n - len(swell)
    x[i0:i0 + len(swell)] += swell
    x = fade_loop(x, 3.0)
    return x


# ---------------- AMBIENCE ----------------
def amb_generic(base_hum=60.0, bird=False, water=False, crowd=False, industrial=False, dur=30.0):
    n = int(dur * SR)
    x = noise(n, lp=0.02) * 0.10
    x += sine(base_hum, n) * 0.03
    if water:
        x += noise(n, lp=0.006) * 0.16 * (0.6 + 0.4 * np.sin(np.arange(n) / SR * 0.3))
        # gulls
        rng = np.random.default_rng(11)
        tpos = 3.0
        while tpos < dur - 3:
            f0 = 1200 + rng.random() * 500
            d = int(0.4 * SR)
            i0 = int(tpos * SR)
            cry = sine(f0, d) * env(d, 0.02, 0.2) * 0.08
            cry += sine(f0 * 1.5, d) * env(d, 0.02, 0.2) * 0.04
            x[i0:i0 + d] += cry
            tpos += rng.random() * 9 + 3
    if crowd:
        x += noise(n, lp=0.004) * 0.12 * (0.7 + 0.3 * np.sin(np.arange(n) / SR * 0.9))
    if industrial:
        for i0 in range(0, n - int(0.8 * SR), int(1.6 * SR)):
            d = int(0.8 * SR)
            thud = kick(dur=0.3, tone=38.0) * 0.3
            x[i0:i0 + len(thud)] += thud
        x += saw(46.0, n) * 0.015
    x = fade_loop(x, 2.0)
    return x


# ---------------- SFX ----------------
def sfx(name):
    if name == "sfx_punch_swing":
        n = int(0.18 * SR)
        return noise(n, lp=0.01) * env(n, 0.01, 0.08) * 0.8
    if name == "sfx_punch_hit":
        n = int(0.16 * SR)
        x = kick(dur=0.16, tone=140) * 0.9
        x += noise(n, lp=0.003) * env(n, 0.001, 0.06) * 0.5 * np.ones(n)
        return x
    if name == "sfx_kick_hit":
        n = int(0.2 * SR)
        return kick(dur=0.2, tone=90) * 1.0 + noise(n, lp=0.004) * env(n, 0.002, 0.1) * 0.4
    if name == "sfx_bodyfall":
        n = int(0.5 * SR)
        x = np.zeros(n)
        kd = int(0.3 * SR)
        x[:kd] += kick(dur=0.3, tone=48) * 1.0
        x += noise(n, lp=0.005) * env(n, 0.01, 0.3) * 0.5
        return x
    if name == "sfx_gunshot":
        n = int(0.35 * SR)
        x = noise(n, lp=0.0008) * env(n, 0.0005, 0.12) * 1.0
        addto(x, 0, kick(dur=0.12, tone=180) * 0.8)
        return x
    if name == "sfx_bullet_impact":
        n = int(0.15 * SR)
        return noise(n, lp=0.002) * env(n, 0.001, 0.08) * 0.9
    if name == "sfx_reload":
        n = int(0.7 * SR)
        x = np.zeros(n)
        for tp, tone in [(0.05, 900), (0.3, 600), (0.55, 1100)]:
            i0 = int(tp * SR)
            d = int(0.06 * SR)
            x[i0:i0 + d] += sine(tone, d) * env(d, 0.002, 0.02) * 0.6
        return x
    if name == "sfx_car_door":
        n = int(0.4 * SR)
        x = np.zeros(n)
        addto(x, 0, kick(dur=0.15, tone=70) * 0.8)
        x += noise(n, lp=0.004) * env(n, 0.002, 0.2) * 0.3
        return x
    if name == "sfx_car_crash":
        n = int(1.0 * SR)
        x = noise(n, lp=0.002) * env(n, 0.001, 0.5) * 0.9
        addto(x, 0, kick(dur=0.4, tone=40) * 0.8)
        return x
    if name == "sfx_horn":
        n = int(0.5 * SR)
        t = np.arange(n) / SR
        x = (sine(370, n) + sine(466, n)) * np.clip(np.sin(t * 44 / 0.5) * 4, 0, 1) * 0.5
        return x
    if name == "sfx_engine_loop":
        n = int(2.0 * SR)
        t = np.arange(n) / SR
        f = 42.0
        x = saw(f, n) * 0.4 + saw(f * 2.01, n) * 0.2 + sine(f, n) * 0.3
        x *= 0.55 + 0.45 * np.sin(2 * np.pi * 2.4 * t)
        return fade_loop(x, 0.2)
    if name == "sfx_siren":
        n = int(3.0 * SR)
        t = np.arange(n) / SR
        w = 0.5 + 0.5 * np.sin(2 * np.pi * 0.9 * t)
        f = 660 + 240 * w
        phase = np.cumsum(f) / SR
        return np.sin(2 * np.pi * phase) * 0.35
    if name == "sfx_police_radio":
        n = int(0.9 * SR)
        x = noise(n, lp=0.006) * env(n, 0.01, 0.4) * 0.4
        for i0 in range(int(0.1 * SR), n - int(0.1 * SR), int(0.12 * SR)):
            d = int(0.05 * SR)
            x[i0:i0 + d] += sine(1400, d) * env(d, 0.002, 0.01) * 0.3
        return x
    if name == "sfx_thunder":
        n = int(3.2 * SR)
        x = noise(n, lp=0.003) * env(n, 0.05, 2.4) * 1.0
        addto(x, 0, kick(dur=0.8, tone=30) * 0.6)
        return x
    if name == "sfx_rain_loop":
        n = int(4.0 * SR)
        x = noise(n, lp=0.0015) * 0.5
        x *= 0.8 + 0.2 * np.sin(np.arange(n) / SR * 1.3)
        return fade_loop(x, 0.3)
    if name == "sfx_token":
        n = int(0.5 * SR)
        t = np.arange(n) / SR
        x = np.zeros(n)
        for f, a in [(1320, 0.5), (1760, 0.4), (2640, 0.2)]:
            x += sine(f, n) * np.exp(-t * 8) * a
        return x
    if name == "sfx_ui_click":
        n = int(0.12 * SR)
        return sine(900, n) * env(n, 0.001, 0.06) * 0.5 + sine(1800, n) * env(n, 0.001, 0.05) * 0.2
    if name == "sfx_ui_back":
        n = int(0.16 * SR)
        return sine(500, n) * env(n, 0.001, 0.1) * 0.5 + sine(300, n) * env(n, 0.001, 0.12) * 0.3
    if name == "sfx_notification":
        n = int(0.7 * SR)
        t = np.arange(n) / SR
        x = sine(880, n) * np.exp(-t * 4) * 0.4
        x += sine(1174.66, n) * np.exp(-t * 3) * 0.3 * (t > 0.18)
        return x
    if name == "sfx_phone_ring":
        n = int(2.4 * SR)
        x = np.zeros(n)
        for rep in range(4):
            i0 = int(rep * 0.6 * SR)
            for f, tp in [(941, 0.0), (1209, 0.0), (941, 0.1), (1209, 0.1)]:
                pass
            d = int(0.4 * SR)
            x[i0:i0 + d] += (sine(941, d) * 0.3 + sine(1209, d) * 0.3)
        return fade_loop(x, 0.05)
    if name == "sfx_radio_click":
        n = int(0.25 * SR)
        return noise(n, lp=0.004) * env(n, 0.001, 0.1) * 0.7 + sine(1200, n) * env(n, 0.001, 0.05) * 0.3
    if name == "sfx_footstep":
        n = int(0.14 * SR)
        return noise(n, lp=0.003) * env(n, 0.001, 0.07) * 0.6
    if name == "sfx_jump":
        n = int(0.3 * SR)
        t = np.arange(n) / SR
        f = 300 + 500 * t / 0.3
        phase = np.cumsum(f) / SR
        return np.sin(2 * np.pi * phase) * env(n, 0.01, 0.15) * 0.4
    if name == "sfx_dodge":
        n = int(0.25 * SR)
        return noise(n, lp=0.006) * env(n, 0.002, 0.12) * 0.5
    if name == "sfx_counter":
        n = int(0.5 * SR)
        x = np.zeros(n)
        t = np.arange(n) / SR
        kd = int(0.2 * SR)
        x[:kd] += kick(dur=0.2, tone=110) * 0.8
        x += sine(1500, n) * np.exp(-t * 6) * 0.3
        return x
    if name == "sfx_grab":
        n = int(0.4 * SR)
        return noise(n, lp=0.004) * env(n, 0.01, 0.25) * 0.5
    if name == "sfx_unlock":
        n = int(0.8 * SR)
        t = np.arange(n) / SR
        x = np.zeros(n)
        for f, delay in [(660, 0.0), (880, 0.2), (1100, 0.4)]:
            i0 = int(delay * SR)
            d = int(0.3 * SR)
            x[i0:i0 + d] += sine(f, d) * env(d, 0.01, 0.2) * 0.4
        return x
    if name == "sfx_achievement":
        return sfx("sfx_unlock") * 1.2
    # ambience files
    if name.startswith("amb_"):
        if "old_quarter" in name:
            return amb_generic(crowd=True, dur=28.0)
        if "docklands" in name:
            return amb_generic(water=True, industrial=True, dur=28.0)
        if "kestrel" in name:
            return amb_generic(base_hum=72, dur=28.0) + noise(int(28.0 * SR), lp=0.002) * 0.05
        if "neon_strip" in name:
            return amb_generic(crowd=True, base_hum=88, dur=28.0)
        if "ironworks" in name:
            return amb_generic(industrial=True, base_hum=44, dur=28.0)
        if "heights" in name:
            return amb_generic(base_hum=30, bird=True, dur=28.0)
        if "interior" in name:
            return amb_generic(base_hum=52, dur=28.0)
    return None


# ---------------- RADIO loops ----------------
def radio_cinder_fm():
    """Cinder FM: late-night neo-noir with Moses monologue spaces."""
    x = mus_explore(day=False)
    # interleave a short voice-band murmur (radio DJ feel)
    n = len(x)
    mur = noise(n, lp=0.008) * 0.06
    x += mur * (0.5 + 0.5 * np.sin(np.arange(n) / SR * 0.1))
    return fade_loop(x, 2.0)


def radio_strip_wave():
    dur = 32.0
    n = int(dur * SR)
    bpm = 118
    beat = 60.0 / bpm
    x = np.zeros(n)
    chords = [[220.0, 261.63, 329.63], [246.94, 293.66, 369.99], [174.61, 220.0, 261.63], [196.0, 246.94, 293.66]]
    bi = 0
    tpos = 0.0
    while tpos < dur - 1:
        i0 = int(tpos * SR)
        p = pad_chord(chords[bi % 4], beat * 2) * 0.3
        addto(x, i0, p)
        k = kick(dur=0.12)
        addto(x, i0, k * 0.5)
        cl = noise(int(0.05 * SR), lp=0.001) * env(int(0.05 * SR), 0.001, 0.02) * 0.4
        addto(x, i0 + int(beat * 0.75 * SR), cl)
        tpos += beat
        bi += 1
    return fade_loop(x, 1.5)


def radio_iron_pulse():
    dur = 30.0
    n = int(dur * SR)
    x = saw(49.0, n) * 0.22 + saw(49.5, n) * 0.18
    for i0 in range(0, n - int(0.5 * SR), int(0.5 * SR)):
        d = int(0.1 * SR)
        x[i0:i0 + d] += noise(d, lp=0.001) * env(d, 0.001, 0.04) * 0.6
    x += noise(n, lp=0.01) * 0.08
    return fade_loop(x, 1.0)


def main():
    os.makedirs(MUSIC, exist_ok=True)
    os.makedirs(SFX, exist_ok=True)
    # music
    write_wav(os.path.join(MUSIC, "mus_menu.wav"), mus_menu(), 0.9)
    write_wav(os.path.join(MUSIC, "mus_explore_day.wav"), mus_explore(True), 0.9)
    write_wav(os.path.join(MUSIC, "mus_explore_night.wav"), mus_explore(False), 0.9)
    write_wav(os.path.join(MUSIC, "mus_tension.wav"), mus_tension(), 0.85)
    write_wav(os.path.join(MUSIC, "mus_combat.wav"), mus_combat(), 0.9)
    write_wav(os.path.join(MUSIC, "mus_story.wav"), mus_story(), 0.9)
    write_wav(os.path.join(MUSIC, "mus_chase.wav"), mus_chase(), 0.9)
    write_wav(os.path.join(MUSIC, "mus_sad.wav"), mus_sad(), 0.9)
    write_wav(os.path.join(MUSIC, "mus_ending.wav"), mus_ending(), 0.9)
    # ambience per area
    for area in ["old_quarter", "docklands", "kestrel_district", "neon_strip", "ironworks", "heights", "interior"]:
        write_wav(os.path.join(SFX, "amb_%s.wav" % area), sfx("amb_" + area), 0.8)
    write_wav(os.path.join(SFX, "sfx_rain_loop.wav"), sfx("sfx_rain_loop"), 0.6)
    # sfx
    for name in ["sfx_punch_swing", "sfx_punch_hit", "sfx_kick_hit", "sfx_bodyfall", "sfx_gunshot",
                 "sfx_bullet_impact", "sfx_reload", "sfx_car_door", "sfx_car_crash", "sfx_horn",
                 "sfx_engine_loop", "sfx_siren", "sfx_police_radio", "sfx_thunder", "sfx_token",
                 "sfx_ui_click", "sfx_ui_back", "sfx_notification", "sfx_phone_ring", "sfx_radio_click",
                 "sfx_footstep", "sfx_jump", "sfx_dodge", "sfx_counter", "sfx_grab", "sfx_unlock"]:
        write_wav(os.path.join(SFX, name + ".wav"), sfx(name), 0.9)
    # radio stations
    write_wav(os.path.join(MUSIC, "radio_cinder_fm.wav"), radio_cinder_fm(), 0.9)
    write_wav(os.path.join(MUSIC, "radio_strip_wave.wav"), radio_strip_wave(), 0.9)
    write_wav(os.path.join(MUSIC, "radio_iron_pulse.wav"), radio_iron_pulse(), 0.9)
    print("AUDIO DONE")


if __name__ == "__main__":
    main()

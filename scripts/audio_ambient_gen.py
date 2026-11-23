#!/usr/bin/env python3
"""LEVERAGE ambient one-shot synthesis (P1 city-life audio pass).
Six new spatial-ambient SFX: city horn (doppler), distant siren wail,
street chatter murmur, birds, car pass-by whoosh, wind gust.
Same numpy DSP idiom as audio_gen.py; outputs .wav to assets/audio/sfx/.
Then converted to .ogg by the existing import pipeline (see docs)."""
import numpy as np
import os
import wave

SR = 44100
SFX = "/home/z/my-project/leverage/assets/audio/sfx"


def write_wav(path, data, vol=1.0):
    data = data * vol
    if data.ndim == 1:
        data = np.stack([data, data], axis=1)
    peak = np.max(np.abs(data)) + 1e-9
    if peak > 1.0:
        data = data / peak * 0.95
    ints = (data * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(ints.tobytes())


def env(n, attack, release):
    e = np.ones(n)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] = np.linspace(1, 0, r)
    return e


def sine(freq, n, bend=0.0):
    t = np.arange(n) / SR
    f = freq * (1.0 + bend * t)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase)


def noise(n, lp=0.01):
    """White noise lowpassed via FFT-domain rolloff (lp = cutoff fraction of SR)."""
    x = np.random.default_rng(7).standard_normal(n)
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / SR) / SR          # fraction of SR
    spec *= 1.0 / (1.0 + (freqs / max(lp, 1e-5)) ** 2)
    out = np.fft.irfft(spec, n)
    return out / (np.max(np.abs(out)) + 1e-9) * 3.0


def bandpass_noise(n, lo, hi):
    return noise(n, hi) - noise(n, lo)


def horn():
    """Two-tone city horn with slight doppler droop, 0.5 s."""
    n = int(0.5 * SR)
    x = sine(370, n, bend=-0.06) * 0.5 + sine(466, n, bend=-0.05) * 0.4
    x += sine(740, n, bend=-0.08) * 0.1
    return x * env(n, 0.01, 0.12) * 0.7


def distant_siren():
    """Wail, heavily lowpassed = far away, 2.2 s."""
    n = int(2.2 * SR)
    w = 0.55 * np.sin(2 * np.pi * 0.7 * np.arange(n) / SR) + 0.5
    x = np.zeros(n)
    f0 = 760.0
    phase = np.cumsum(np.full(n, f0 * (1 + 0.28 * w)) / SR * 2 * np.pi)
    x = np.sin(phase)
    x = x + 0.35 * np.sin(phase * 2.01)
    # distance: muffling + low level
    x = np.convolve(x, np.ones(48) / 48, mode="same")
    return x * env(n, 0.3, 0.6) * 0.4


def chatter():
    """Street murmur: babbling band-limited noise + voice blips, 1.4 s."""
    n = int(1.4 * SR)
    rng = np.random.default_rng(11)
    x = bandpass_noise(n, 0.02, 0.35) * 0.35
    # syllable blips at random pitches (talking)
    t_cursor = int(0.08 * SR)
    while t_cursor < n - int(0.1 * SR):
        dur = int(rng.uniform(0.04, 0.12) * SR)
        f = rng.uniform(150, 340)
        x[t_cursor:t_cursor + dur] += sine(f, dur) * env(dur, 0.01, 0.03) * 0.5
        t_cursor += int(dur * rng.uniform(1.5, 2.8))
    x = np.convolve(x, np.ones(6) / 6, mode="same")
    return x * env(n, 0.05, 0.3) * 0.8


def birds():
    """3-4 chirps, 0.9 s."""
    n = int(0.9 * SR)
    rng = np.random.default_rng(13)
    x = np.zeros(n)
    t_cursor = 0
    for _ in range(rng.integers(3, 5)):
        dur = int(rng.uniform(0.06, 0.11) * SR)
        f = rng.uniform(2100, 3400)
        x[t_cursor:t_cursor + dur] += sine(f, dur, bend=rng.uniform(-0.2, 0.15)) * env(dur, 0.004, 0.02)
        t_cursor += int(rng.uniform(0.12, 0.3) * SR)
    return x * 0.5


def car_passby():
    """Whoosh: filtered noise + engine hum with doppler rise-fall, 1.8 s."""
    n = int(1.8 * SR)
    t = np.arange(n) / SR
    # doppler curve: pitch falls as it passes mid-way
    dop = 1.0 + 0.22 * np.cos(np.pi * t / 1.8) ** 2
    phase = np.cumsum(118.0 * dop / SR * 2 * np.pi)
    x = np.sin(phase) * 0.4
    x += noise(n, 0.02) * 0.5 * (np.sin(np.pi * t / 1.8) ** 2)
    x += noise(n, 0.3) * 0.12
    return x * env(n, 0.35, 0.5) * 0.75


def wind_gust():
    """Slow swell of low-mid noise, 2.6 s."""
    n = int(2.6 * SR)
    t = np.arange(n) / SR
    x = noise(n, 0.012) * 0.8 + noise(n, 0.05) * 0.3
    swell = np.sin(np.pi * t / 2.6) ** 1.5
    flutter = 1.0 + 0.25 * np.sin(2 * np.pi * 2.7 * t)
    return x * swell * flutter * 0.5


if __name__ == "__main__":
    out = {
        "sfx_city_horn": horn,
        "sfx_distant_siren": distant_siren,
        "sfx_chatter": chatter,
        "sfx_birds": birds,
        "sfx_car_passby": car_passby,
        "sfx_wind_gust": wind_gust,
    }
    for name, fn in out.items():
        write_wav(os.path.join(SFX, name + ".wav"), fn(), 0.8)
        print("wrote", name)

#!/usr/bin/env python3
"""Erzeugt alle Platzhalter-Sounds für iNFERNO; als WAV nach audio/.

Alles ist synthetisch (Sinus, Sägezahn, gefiltertes Rauschen), damit das Spiel
ohne fremde Samples klingt. Jede Datei kann später durch eine echte Aufnahme
gleichen Namens ersetzt werden; der Code merkt davon nichts.

    python3 tools/gen_audio.py
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio"))
_seed = [1000]


# --- Bausteine ----------------------------------------------------------

def n_of(dur):
    return int(round(SR * dur))


def tt(dur):
    return np.arange(n_of(dur)) / SR


def decay(dur, tau):
    return np.exp(-tt(dur) / tau)


def edges(x, a=0.002, r=0.01):
    """Kurzes Ein- und Ausblenden gegen Knackser."""
    y = np.array(x, dtype=float)
    na = min(len(y), max(1, n_of(a)))
    nr = min(len(y), max(1, n_of(r)))
    y[:na] *= np.linspace(0.0, 1.0, na)
    y[-nr:] *= np.linspace(1.0, 0.0, nr)
    return y


def sweep(f0, f1, dur, curve=1.0):
    """Phase eines exponentiellen Frequenzverlaufs f0 -> f1."""
    t = tt(dur)
    k = (t / max(dur, 1e-9)) ** curve
    f = f0 * (f1 / f0) ** k
    return 2.0 * np.pi * np.cumsum(f) / SR


def bandnoise(dur, lo, hi, tilt=0.0):
    """Bandbegrenztes Rauschen. Per FFT erzeugt, deshalb nahtlos loopbar."""
    n = n_of(dur)
    _seed[0] += 1
    r = np.random.default_rng(_seed[0])
    spec = r.normal(size=n // 2 + 1) + 1j * r.normal(size=n // 2 + 1)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    fs = np.maximum(f, 1e-6)
    mask = 1.0 / np.sqrt(1.0 + (lo / fs) ** 8) / np.sqrt(1.0 + (fs / hi) ** 8)
    if tilt:
        mask *= (np.maximum(f, 20.0) / 1000.0) ** tilt
    mask[0] = 0.0
    x = np.fft.irfft(spec * mask, n)
    return x / np.max(np.abs(x))


def saw(phase, fund, cutoff=5000.0):
    """Bandbegrenzter Sägezahn: Obertöne bis cutoff, sanft abfallend."""
    x = np.zeros_like(phase)
    k = 1
    while k * fund < min(cutoff * 3.0, SR * 0.45) and k < 80:
        x += np.sin(k * phase) / k / (1.0 + (k * fund / cutoff) ** 2)
        k += 1
    return x * 0.6


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def place(buf, x, at, wrap=False):
    """Mischt x ab Sekunde `at` in buf. wrap=True: Ausklang läuft in den Loop-Anfang."""
    i = n_of(at)
    if wrap:
        idx = (i + np.arange(len(x))) % len(buf)
        np.add.at(buf, idx, x)
    else:
        j = min(len(buf), i + len(x))
        buf[i:j] += x[: j - i]


def drive(x, amount=2.0):
    return np.tanh(x * amount) / np.tanh(amount)


def save(name, x, peak=0.89):
    x = np.asarray(x, dtype=float)
    m = np.max(np.abs(x))
    if m > 0:
        x = x * (peak / m)
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    channels = 1 if pcm.ndim == 1 else pcm.shape[1]
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return x


# --- Waffe & Treffer ----------------------------------------------------

def shot():
    d = 0.24
    body = np.sin(sweep(230, 62, d, 0.5)) * decay(d, 0.055)
    zap = saw(sweep(1100, 190, 0.12, 0.6), 500, 4500) * decay(0.12, 0.028) * 0.55
    crack = bandnoise(0.09, 1400, 8000) * decay(0.09, 0.014) * 0.8
    return edges(drive(mix(body, zap, crack), 1.6), 0.0005, 0.03)


def shot_dry():
    x = np.zeros(n_of(0.09))
    place(x, bandnoise(0.03, 1800, 6000) * decay(0.03, 0.004), 0.0)
    place(x, bandnoise(0.03, 900, 3500) * decay(0.03, 0.006) * 0.7, 0.045)
    return edges(x, 0.0005, 0.005)


def impact():
    d = 0.14
    return edges(mix(bandnoise(d, 700, 5500) * decay(d, 0.022), np.sin(sweep(210, 120, d)) * decay(d, 0.035) * 0.7), 0.0005, 0.02)


def ping(freqs, d, tau, click=0.5):
    t = tt(d)
    x = np.zeros(len(t))
    for i, f in enumerate(freqs):
        x += np.sin(2 * np.pi * f * t) * np.exp(-t / (tau / (1.0 + i * 0.35))) / (1.0 + i * 0.5)
    return edges(mix(x, bandnoise(0.02, 2500, 9000) * decay(0.02, 0.004) * click), 0.0005, 0.02)


def enemy_die():
    d = 0.7
    t = tt(d)
    crunch = bandnoise(d, 180, 3200) * decay(d, 0.16) * (0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 37 * t)))
    fall = np.sin(sweep(520, 55, d, 0.7)) * decay(d, 0.22) * 0.8
    return edges(drive(mix(crunch, fall), 1.8), 0.001, 0.08)


def enemy_alert():
    x = np.zeros(n_of(0.3))
    for i, f in enumerate([830, 1245]):
        d = 0.11
        tone = np.sign(np.sin(2 * np.pi * f * tt(d))) * 0.35 + np.sin(2 * np.pi * f * tt(d))
        place(x, edges(tone * decay(d, 0.06), 0.002, 0.02), i * 0.13)
    return x


def enemy_charge():
    d = 0.55
    t = tt(d)
    ph = sweep(260, 1500, d, 1.6)
    return edges((np.sin(ph) + saw(ph, 800, 5000) * 0.5) * (t / d) ** 1.5 * (0.7 + 0.3 * np.sin(2 * np.pi * 28 * t)), 0.01, 0.01)


def enemy_shot():
    d = 0.32
    return edges(mix(saw(sweep(560, 110, d, 0.6), 300, 2600) * decay(d, 0.09), bandnoise(d, 500, 4000) * decay(d, 0.03) * 0.5), 0.001, 0.05)


# --- Enterhaken & Bewegung ----------------------------------------------

def hook_fire():
    d = 0.2
    t = tt(d)
    hiss = bandnoise(d, 1800, 10000, 0.4) * np.exp(-((t - 0.035) / 0.04) ** 2)
    zip_ = np.sin(sweep(280, 1500, 0.12, 0.8)) * decay(0.12, 0.05) * 0.5
    return edges(mix(hiss, zip_), 0.001, 0.03)


def hook_hit():
    clank = ping([510, 1370, 2890, 4130], 0.3, 0.09, 0.9)
    thud = np.sin(sweep(150, 70, 0.14)) * decay(0.14, 0.04)
    return edges(mix(clank, thud), 0.0005, 0.04)


def reel_loop():
    d = 1.0
    t = tt(d)
    ratchet = 0.55 + 0.45 * np.clip(np.sin(2 * np.pi * 34 * t) * 4.0, -1, 1)
    whir = saw(2 * np.pi * 138 * t, 138, 2600) * ratchet
    whine = np.sin(2 * np.pi * 690 * t) * 0.16 * (0.7 + 0.3 * np.sin(2 * np.pi * 5 * t))
    return mix(whir, whine, bandnoise(d, 1500, 6000) * 0.14)


def wind_loop():
    d = 4.0
    t = tt(d)
    low = bandnoise(d, 120, 900) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.5 * t))
    high = bandnoise(d, 900, 4200, -0.3) * (0.55 + 0.45 * np.sin(2 * np.pi * 0.75 * t + 1.3)) * 0.55
    return mix(low, high)


def gas():
    d = 0.55
    t = tt(d)
    hiss = bandnoise(d, 1500, 11000, 0.3) * np.minimum(t / 0.006, 1.0) * np.exp(-t / 0.14)
    thump = np.sin(sweep(120, 55, 0.12)) * decay(0.12, 0.035) * 0.9
    return edges(mix(hiss, thump), 0.0005, 0.08)


def whoosh(d=0.32, lo=260, hi=3200):
    t = tt(d)
    return edges(bandnoise(d, lo, hi, -0.2) * np.sin(np.pi * t / d) ** 2, 0.005, 0.02)


def claw_hit():
    d = 0.28
    return edges(drive(mix(bandnoise(d, 140, 2600) * decay(d, 0.06), np.sin(sweep(130, 60, d)) * decay(d, 0.07), np.sin(2 * np.pi * 720 * tt(d)) * decay(d, 0.03) * 0.3), 2.0), 0.0005, 0.05)


def step(variant):
    d = 0.1
    return edges(mix(bandnoise(d, 70 + variant * 25, 800 + variant * 250) * decay(d, 0.02), np.sin(sweep(95 - variant * 12, 55, d)) * decay(d, 0.025) * 0.8), 0.001, 0.02)


def land():
    d = 0.22
    return edges(mix(np.sin(sweep(105, 45, d)) * decay(d, 0.06), bandnoise(d, 90, 1300) * decay(d, 0.04) * 0.7), 0.001, 0.05)


def hurt():
    d = 0.32
    return edges(drive(mix(np.sin(sweep(170, 65, d)) * decay(d, 0.09), bandnoise(d, 300, 2500) * decay(d, 0.04) * 0.6), 2.5), 0.001, 0.05)


def death():
    d = 1.3
    t = tt(d)
    return edges(mix(np.sin(sweep(300, 36, d, 0.6)) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)) * decay(d, 0.5), bandnoise(d, 150, 1800) * decay(d, 0.35) * 0.4), 0.005, 0.25)


# --- Oberfläche ---------------------------------------------------------

def radio():
    x = np.zeros(n_of(0.2))
    place(x, edges(bandnoise(0.05, 900, 3600), 0.002, 0.01) * 0.8, 0.0)
    place(x, edges(np.sin(2 * np.pi * 1180 * tt(0.045)), 0.003, 0.01) * 0.35, 0.06)
    place(x, edges(bandnoise(0.07, 700, 3000), 0.002, 0.03) * 0.5, 0.11)
    return x


def blip(f0, f1, d=0.09):
    return edges(np.sin(sweep(f0, f1, d)) * decay(d, 0.05), 0.003, 0.02)


def chord(freqs, d, tau, detune=0.004):
    t = tt(d)
    x = np.zeros(len(t))
    for f in freqs:
        x += np.sin(2 * np.pi * f * t) + np.sin(2 * np.pi * f * (1 + detune) * t) * 0.7
    return x * np.exp(-t / tau)


def ui_spend():
    d = 0.4
    return edges(mix(chord([196.0, 277.2], d, 0.14), bandnoise(d, 200, 1400) * decay(d, 0.05) * 0.5), 0.004, 0.08)


def levelup():
    x = np.zeros(n_of(1.1))
    for i, f in enumerate([220.0, 261.6, 329.6, 440.0, 523.3]):
        d = 0.5
        place(x, edges(chord([f], d, 0.16), 0.004, 0.1) * (0.8 + i * 0.08), i * 0.11)
    return x


def objective():
    x = np.zeros(n_of(0.4))
    place(x, edges(chord([523.3], 0.2, 0.09), 0.004, 0.04), 0.0)
    place(x, edges(chord([392.0], 0.28, 0.12), 0.004, 0.06), 0.11)
    return x


# --- Boss & Tor ---------------------------------------------------------

def boss_charge():
    d = 1.1
    t = tt(d)
    ph = sweep(55, 230, d, 1.4)
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * np.cumsum(6 + 30 * (t / d) ** 2) / SR)
    return edges((np.sin(ph) + saw(ph * 2.02, 220, 2400) * 0.6) * (0.15 + 0.85 * (t / d) ** 1.3) * trem, 0.02, 0.01)


def boss_slam():
    d = 1.1
    sub = np.sin(sweep(120, 30, d, 0.45)) * decay(d, 0.3)
    blast = bandnoise(d, 50, 1700, -0.3) * decay(d, 0.11)
    return edges(drive(mix(sub, blast * 0.9), 2.4), 0.0005, 0.2)


def boss_fan():
    d = 0.45
    x = np.zeros(n_of(d))
    for i in range(5):
        place(x, saw(sweep(760 - i * 40, 150, 0.2, 0.6), 400, 3000) * decay(0.2, 0.05), i * 0.04)
    return edges(mix(x, bandnoise(d, 600, 5000) * decay(d, 0.05) * 0.4), 0.001, 0.05)


def boss_roar(d=1.7, base=68.0):
    t = tt(d)
    env = np.minimum(t / 0.25, 1.0) * np.exp(-np.maximum(t - 0.5, 0) / 0.45)
    mod = np.sin(2 * np.pi * base * 0.63 * t) * (4.0 + 3.0 * np.sin(2 * np.pi * 3 * t))
    growl = np.sin(2 * np.pi * base * t + mod)
    scream = bandnoise(d, 250, 2600) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t))
    return edges(drive(mix(growl, scream * 0.6) * env, 2.0), 0.02, 0.2)


def boss_die():
    d = 2.4
    t = tt(d)
    fall = np.sin(sweep(260, 28, d, 0.5) + np.sin(2 * np.pi * 41 * t) * 3.0) * decay(d, 0.9)
    debris = bandnoise(d, 120, 4000) * decay(d, 0.5) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 17 * t)))
    return edges(drive(mix(fall, debris * 0.7), 2.0), 0.005, 0.5)


def door_loop():
    d = 2.0
    t = tt(d)
    rumble = bandnoise(d, 28, 240) * (0.7 + 0.3 * np.sin(2 * np.pi * 6 * t))
    hum = np.sin(2 * np.pi * 48 * t) * 0.5 + np.sin(2 * np.pi * 96.5 * t) * 0.2
    grind = bandnoise(d, 180, 900) * (0.55 + 0.45 * np.clip(np.sin(2 * np.pi * 6 * t) * 3.0, -1, 1)) * 0.7
    squeal = bandnoise(d, 880, 1150) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.5 * t)) * 0.25
    return mix(rumble * 0.7, hum * 0.7, grind, squeal)


def door_stop():
    return edges(mix(np.sin(sweep(95, 40, 0.5)) * decay(0.5, 0.12), ping([310, 835, 1490], 0.6, 0.2, 0.6) * 0.6, bandnoise(0.2, 100, 1500) * decay(0.2, 0.04)), 0.0005, 0.1)


# --- Flächen & Musik ----------------------------------------------------

def title():
    d = 4.5
    t = tt(d)
    env = np.minimum(t / 1.2, 1.0) * np.exp(-np.maximum(t - 1.6, 0) / 1.1)
    out = []
    for det in (0.0, 0.35):
        x = np.zeros(len(t))
        for f, a in [(55.0, 1.0), (82.4, 0.6), (130.8, 0.4), (138.6, 0.22), (277.2, 0.1)]:
            x += np.sin(2 * np.pi * (f + det) * t) * a
        x += bandnoise(d, 180, 900) * 0.18
        out.append(edges(x * env, 0.05, 0.6))
    return np.stack(out, axis=1)


def ambient_loop():
    """16 s, stereo, nahtlos: tiefer Bordun, Luft, ferne Metall-Ächzer."""
    d = 16.0
    t = tt(d)
    out = []
    for ch in range(2):
        x = np.zeros(len(t))
        # Bordun: Frequenzen sind Vielfache von 1/16 Hz, damit der Loop schließt
        # Obertöne bis 330 Hz, damit der Bordun auch auf kleinen Lautsprechern trägt
        for f, a, lfo in [(55.0, 0.5, 0.0625), (55.25 + ch * 0.0625, 0.4, 0.125), (82.375, 0.5, 0.1875), (110.0625, 0.55, 0.0625),
                          (164.8125 - ch * 0.0625, 0.42, 0.25), (220.125 + ch * 0.0625, 0.26, 0.125), (329.5625, 0.13, 0.1875)]:
            x += np.sin(2 * np.pi * f * t + ch) * a * (0.75 + 0.25 * np.sin(2 * np.pi * lfo * t + f))
        air = bandnoise(d, 110, 950) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.125 * t + ch * 2.0)) * 1.5
        hiss = bandnoise(d, 2200, 6000) * 0.035 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.0625 * t + 1.0 + ch))
        eerie = bandnoise(d, 1180, 1230) * 0.11 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.1875 * t + ch * 1.4))
        x += air * 0.5 + hiss + eerie
        # Ächzen: irgendwo arbeitet Stahl
        for at, lo, hi, dur, amp in [(4.2, 190, 250, 3.0, 0.5), (10.8, 300, 360, 2.2, 0.36), (13.4, 420, 480, 2.4, 0.3)]:
            g = bandnoise(dur, lo, hi) * np.sin(np.pi * tt(dur) / dur) ** 2 * amp * (0.6 + 0.4 * (ch == (int(at) % 2)))
            place(x, g, at, wrap=True)
        out.append(x)
    return np.stack(out, axis=1)


def boss_music_loop():
    """4 Takte bei 128 BPM (7,5 s), nahtlos. Kick, Hats, Clap, Bass, Fläche."""
    bpm = 128.0
    s16 = 60.0 / bpm / 4.0
    d = s16 * 64
    n = n_of(d)
    kick_env = np.zeros(n)
    drums = np.zeros(n)
    bass = np.zeros(n)

    kd = 0.34
    kick = drive(np.sin(sweep(170, 43, kd, 0.35)) * decay(kd, 0.13) + bandnoise(kd, 1500, 6000) * decay(kd, 0.004) * 0.4, 2.2)
    kick = edges(kick, 0.0005, 0.05)
    hat = edges(bandnoise(0.07, 7000, 14000) * decay(0.07, 0.016), 0.0005, 0.01)
    open_hat = edges(bandnoise(0.22, 6000, 13000) * decay(0.22, 0.07), 0.0005, 0.03)
    clap = np.zeros(n_of(0.22))
    for i in range(3):
        place(clap, bandnoise(0.16, 900, 3800) * decay(0.16, 0.05 if i == 2 else 0.008), i * 0.011)
    clap = edges(clap, 0.0005, 0.03)

    for i in range(64):
        at = i * s16
        if i % 4 == 0:
            place(drums, kick, at, True)
            place(kick_env, decay(0.26, 0.09), at, True)
        if i % 4 == 2:
            place(drums, hat * 0.3, at, True)
        elif i % 2 == 1:
            place(drums, hat * 0.1, at, True)
        if i % 8 == 4:
            place(drums, clap * 0.42, at, True)
        if i % 16 == 14:
            place(drums, open_hat * 0.2, at, True)

    # Bass: A1 mit Ausreißern nach C und B (kleine Sekunde = Unbehagen)
    A = 55.0
    bars = [
        [0, None, 0, 0, None, 0, None, 0, 0, None, 3, None, 0, None, 0, None],
        [0, None, 0, 0, None, 0, None, 0, 0, None, 1, None, 0, 0, None, 1],
        [0, None, 0, 0, None, 0, None, 0, 0, None, 3, None, 0, None, 0, None],
        [0, None, 0, 0, None, 5, None, 0, 3, None, 1, None, 0, 1, 0, 1],
    ]
    for b, pattern in enumerate(bars):
        for i, note in enumerate(pattern):
            if note is None:
                continue
            f = A * 2 ** (note / 12.0)
            nd = 0.2
            ph = 2 * np.pi * f * tt(nd)
            tone = saw(ph, f, 420) * 0.6 + saw(ph, f, 1600) * decay(nd, 0.035) * 0.9 + np.sin(ph) * 0.5
            place(bass, edges(tone * decay(nd, 0.085), 0.002, 0.03), (b * 16 + i) * s16, True)
    bass *= 1.0 - 0.75 * np.clip(kick_env, 0.0, 1.0)

    t = np.arange(n) / SR
    out = []
    for ch in range(2):
        pad = np.zeros(n)
        # Fläche: Frequenzen sind Vielfache von 1/7,5 Hz
        for k, a in [(825, 0.5), (1236 + ch, 0.35), (1748 - ch, 0.3)]:
            f = k / d
            pad += saw(2 * np.pi * f * t, f, 900) * a
        pad *= (0.55 + 0.45 * np.sin(2 * np.pi * (2 / d) * t + ch * 1.2)) * (1.0 - 0.5 * np.clip(kick_env, 0, 1))
        stab = np.zeros(n)
        for at, f in [(0.0, 440.0), (42 * s16, 466.2)]:
            sd = 0.6
            st = tt(sd)
            place(stab, edges(np.sin(2 * np.pi * f * st + np.sin(2 * np.pi * f * 1.41 * st) * 2.5 * np.exp(-st / 0.15)) * np.exp(-st / 0.18), 0.002, 0.1) * (0.9 if (ch == 0) == (at == 0.0) else 0.5), at, True)
        out.append(drive(drums * 1.0 + bass * 0.85 + pad * 0.16 + stab * 0.16, 1.3))
    return np.stack(out, axis=1)


# --- Ausgabe ------------------------------------------------------------

SOUNDS = {
    "shot": shot,
    "shot_dry": shot_dry,
    "impact": impact,
    "enemy_hit": lambda: ping([1320, 2130, 3410], 0.16, 0.05),
    "enemy_die": enemy_die,
    "enemy_alert": enemy_alert,
    "enemy_charge": enemy_charge,
    "enemy_shot": enemy_shot,
    "hook_fire": hook_fire,
    "hook_hit": hook_hit,
    "reel_loop": reel_loop,
    "wind_loop": wind_loop,
    "gas": gas,
    "whoosh": whoosh,
    "claw_hit": claw_hit,
    "step1": lambda: step(0),
    "step2": lambda: step(1),
    "jump": lambda: whoosh(0.16, 150, 1400),
    "land": land,
    "hurt": hurt,
    "death": death,
    "radio": radio,
    "ui_open": lambda: blip(620, 980),
    "ui_close": lambda: blip(980, 620),
    "ui_spend": ui_spend,
    "levelup": levelup,
    "objective": objective,
    "boss_charge": boss_charge,
    "boss_slam": boss_slam,
    "boss_fan": boss_fan,
    "boss_roar": boss_roar,
    "boss_die": boss_die,
    "door_loop": door_loop,
    "door_stop": door_stop,
    "title": title,
    "ambient_loop": ambient_loop,
    "boss_music_loop": boss_music_loop,
}


def main():
    print(f"{'Datei':<18} {'Dauer':>7} {'Kanäle':>6} {'RMS dB':>7} {'Loop-Naht':>9}")
    for name, make in SOUNDS.items():
        x = save(name, make())
        mono = x if x.ndim == 1 else x.mean(axis=1)
        rms = 20 * np.log10(np.sqrt(np.mean(mono ** 2)) + 1e-12)
        seam = ""
        if name.endswith("_loop"):
            # Sprung an der Nahtstelle im Verhältnis zum üblichen Schritt zwischen zwei Samples
            typical = np.percentile(np.abs(np.diff(mono)), 95) + 1e-12
            seam = f"{abs(mono[0] - mono[-1]) / typical:9.2f}"
        print(f"{name:<18} {len(mono) / SR:6.2f}s {1 if x.ndim == 1 else 2:>6} {rms:7.1f} {seam:>9}")


if __name__ == "__main__":
    main()

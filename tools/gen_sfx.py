#!/usr/bin/env python3
"""gen_sfx.py — placeholder sound effects for Tellen.

Writes mono 22050 Hz 16-bit WAV files to game/audio/sfx/. No third-party
dependencies. Every sound is a placeholder: replace a file with a real
recording of the same name (or point game/audio/sound_bank.tres at another
file) and nothing else changes.

Run from the project root:   python3 tools/gen_sfx.py
Then let Godot import them (open the editor, or run --import).
"""

import wave, math, random, os
from array import array as _array

# ── Constants ──────────────────────────────────────────────────────────────────

RATE    = 22050   # Hz
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "game", "audio", "sfx")

# ── Low-level helpers ──────────────────────────────────────────────────────────

def frames(duration_s: float) -> int:
    return int(RATE * duration_s)


def sine(freq: float, duration_s: float, phase: float = 0.0) -> list:
    n = frames(duration_s)
    return [math.sin(2 * math.pi * freq * (i / RATE) + phase) for i in range(n)]


def noise(duration_s: float) -> list:
    return [random.uniform(-1.0, 1.0) for _ in range(frames(duration_s))]


def freq_sweep(f0: float, f1: float, duration_s: float) -> list:
    """Sine with linearly swept frequency f0 → f1."""
    n = frames(duration_s)
    result = []
    phase = 0.0
    for i in range(n):
        t    = i / RATE
        freq = f0 + (f1 - f0) * (t / duration_s)
        phase += 2 * math.pi * freq / RATE
        result.append(math.sin(phase))
    return result


def env(sig: list, attack_s: float = 0.003, release_s: float = 0.020) -> list:
    """Linear attack + linear release envelope."""
    n   = len(sig)
    atk = min(int(attack_s * RATE), n)
    rel = min(int(release_s * RATE), n)
    out = list(sig)
    for i in range(atk):
        out[i] *= i / atk if atk > 0 else 1.0
    for i in range(rel):
        idx       = n - rel + i
        out[idx] *= (rel - i - 1) / rel if rel > 0 else 1.0
    return out


def amp(sig: list, gain: float) -> list:
    return [s * gain for s in sig]


def mix(*signals) -> list:
    """Sum signals, trimmed to the shortest."""
    n = min(len(s) for s in signals)
    return [sum(s[i] for s in signals) for i in range(n)]


def pad_mix(*signals) -> list:
    """Sum signals, padded to the longest."""
    n = max(len(s) for s in signals)
    padded = [list(s) + [0.0] * (n - len(s)) for s in signals]
    return [sum(p[i] for p in padded) for i in range(n)]


def cat(*signals) -> list:
    """Concatenate signals."""
    out = []
    for s in signals:
        out.extend(s)
    return out


def lowpass(sig: list, alpha: float = 0.25) -> list:
    """Single-pole IIR lowpass (alpha ≈ cutoff / nyquist)."""
    out  = [0.0] * len(sig)
    prev = 0.0
    for i, s in enumerate(sig):
        prev   = prev + alpha * (s - prev)
        out[i] = prev
    return out


def highpass(sig: list, alpha: float = 0.8) -> list:
    """Single-pole IIR highpass."""
    out      = [0.0] * len(sig)
    prev_in  = 0.0
    prev_out = 0.0
    for i, s in enumerate(sig):
        out[i]  = alpha * (prev_out + s - prev_in)
        prev_in = s
        prev_out = out[i]
    return out


def normalize(sig: list, peak: float = 0.82) -> list:
    m = max(abs(s) for s in sig) if sig else 1.0
    if m < 1e-9:
        return sig
    return [s / m * peak for s in sig]


def save(sig: list, name: str) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    path    = os.path.join(OUT_DIR, name + ".wav")
    normed  = normalize(sig)
    samples = _array("h", [
        int(max(-32767, min(32767, s * 32767))) for s in normed
    ])
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(samples.tobytes())
    ms = len(sig) / RATE * 1000
    print(f"  {name:20s}  {ms:5.0f} ms   {path}")


# ── Extra helpers ──────────────────────────────────────────────────────────────

def square(freq: float, duration_s: float, duty: float = 0.5) -> list:
    n = frames(duration_s)
    period = RATE / freq
    return [1.0 if (i % period) / period < duty else -1.0 for i in range(n)]


def at(total_s: float, *parts) -> list:
    """Place (signal, start_seconds) pairs into one buffer."""
    buf = [0.0] * frames(total_s)
    for sig, start in parts:
        s = int(start * RATE)
        for i, v in enumerate(sig):
            if s + i < len(buf):
                buf[s + i] += v
    return buf


def tone(freq: float, dur: float, gain: float = 1.0, harmonic: float = 0.2, release: float = None) -> list:
    base = mix(sine(freq, dur), amp(sine(freq * 2, dur), harmonic))
    return amp(env(base, attack_s=0.004, release_s=release if release is not None else dur * 0.6), gain)


# ── UI ─────────────────────────────────────────────────────────────────────────

def ui():
    save(amp(env(sine(1046, 0.028), 0.002, 0.020), 0.5), "cursor_move")
    save(amp(env(sine(784, 0.035), 0.002, 0.025), 0.6), "menu_move")
    save(cat(tone(659, 0.045, 0.8, 0.15), tone(988, 0.07, 0.8, 0.15)), "confirm")
    save(cat(tone(523, 0.045, 0.8, 0.1), tone(392, 0.065, 0.8, 0.1)), "cancel")
    save(amp(env(lowpass(square(110, 0.14, 0.3), 0.3), 0.003, 0.05), 0.8), "error")
    save(amp(env(freq_sweep(500, 900, 0.07), 0.004, 0.04), 0.6), "menu_open")


# ── Dialogue and progression ───────────────────────────────────────────────────

def dialogue_and_progress():
    # A soft square "voice" blip; each character plays it at its own pitch.
    blip = lowpass(square(520, 0.045, 0.35), 0.35)
    save(amp(env(blip, 0.002, 0.03), 0.7), "text_blip")
    # EXP bar: a tiny bright tick played repeatedly with rising pitch.
    save(amp(env(mix(sine(1320, 0.022), amp(square(1320, 0.022, 0.5), 0.15)), 0.001, 0.016), 0.6), "exp_tick")
    # Bar full: a sparkling ding.
    save(at(0.45, (tone(1568, 0.40, 0.8, 0.35), 0.0), (tone(2093, 0.30, 0.45, 0.2), 0.05)), "exp_full")
    # Level up: rising arpeggio with a held top note.
    notes = [(523.2, 0.0), (659.3, 0.08), (784.0, 0.16), (1046.5, 0.24)]
    parts = [(tone(f, 0.12 if k < 3 else 0.42, 0.8, 0.3), t) for k, (f, t) in enumerate(notes)]
    parts.append((tone(1318.5, 0.36, 0.35, 0.2), 0.30))
    save(at(0.70, *parts), "level_up")
    n1 = tone(880, 0.042, 1.0, 0.1, 0.018)
    n2 = pad_mix(tone(1319, 0.058, 1.0, 0.1, 0.038), amp(tone(2637, 0.058, 1.0, 0.0, 0.038), 0.12))
    save(cat(n1, n2), "stat_up")
    save(at(0.5, (tone(784, 0.12, 0.7), 0.0), (tone(1175, 0.30, 0.7, 0.3), 0.09)), "item_get")


# ── Combat ─────────────────────────────────────────────────────────────────────

def combat():
    burst = env(highpass(noise(0.080), 0.75), 0.001, 0.055)
    save(mix(burst, amp(env(sine(1200, 0.080), 0.001, 0.06), 0.3)), "hit_slash")
    save(mix(env(highpass(noise(0.050), 0.8), 0.001, 0.035), amp(env(sine(1700, 0.05), 0.001, 0.04), 0.25)), "hit_stab")
    save(mix(env(highpass(noise(0.065), 0.65), 0.001, 0.045), amp(env(sine(900, 0.065), 0.001, 0.045), 0.25)), "hit_poke")
    save(mix(env(lowpass(noise(0.110), 0.12), 0.006, 0.08), amp(env(sine(140, 0.110), 0.005, 0.08), 0.55)), "hit_swing")
    save(mix(env(lowpass(noise(0.095), 0.08), 0.004, 0.075), amp(env(sine(80, 0.095), 0.004, 0.075), 0.65)), "hit_brawl")
    save(mix(env(highpass(noise(0.042), 0.80), 0.001, 0.028), amp(env(sine(1800, 0.042), 0.001, 0.032), 0.22)), "hit_arrow")
    dark = mix(amp(env(lowpass(noise(0.16), 0.15), 0.01, 0.1), 0.6), amp(env(freq_sweep(300, 90, 0.16), 0.01, 0.1), 0.6))
    save(dark, "hit_dark")
    light = at(0.2, (amp(env(highpass(noise(0.05), 0.85), 0.001, 0.04), 0.5), 0.0), (tone(1760, 0.18, 0.5, 0.4), 0.0), (tone(2637, 0.14, 0.3, 0.0), 0.03))
    save(light, "hit_light")
    save(mix(env(highpass(noise(0.07), 0.7), 0.001, 0.05), amp(env(sine(600, 0.07), 0.001, 0.05), 0.3)), "hit")
    save(mix(amp(env(freq_sweep(650, 200, 0.090), 0.01, 0.045), 0.55), amp(env(lowpass(noise(0.09), 0.2), 0.01, 0.045), 0.3)), "miss")
    crit = at(0.30, (env(highpass(noise(0.10), 0.6), 0.001, 0.07), 0.0), (amp(env(sine(1500, 0.25), 0.001, 0.2), 0.4), 0.0),
              (amp(env(sine(2300, 0.2), 0.001, 0.15), 0.25), 0.0), (amp(env(freq_sweep(160, 60, 0.18), 0.003, 0.1), 0.7), 0.0))
    save(crit, "crit")
    # Stagger: a clank and a wobbling, falling tone.
    wob = [math.sin(2 * math.pi * (300 - 140 * i / frames(0.3)) * (i / RATE) + 3 * math.sin(2 * math.pi * 14 * i / RATE)) for i in range(frames(0.3))]
    save(at(0.32, (env(highpass(noise(0.04), 0.7), 0.001, 0.03), 0.0), (amp(env(wob, 0.01, 0.15), 0.6), 0.02)), "stagger")
    save(mix(env(freq_sweep(440, 110, 0.48), 0.025, 0.2), amp(env(freq_sweep(660, 165, 0.48), 0.025, 0.2), 0.3)), "defeat")
    heal_notes = [(261.6, 0.0), (329.6, 0.075), (392.0, 0.15), (523.2, 0.225)]
    save(at(0.45, *[(tone(f * 2, 0.16, 0.7, 0.25), t) for f, t in heal_notes]), "heal")
    save(at(0.22, (env(highpass(noise(0.05), 0.75), 0.001, 0.04), 0.0), (tone(1046, 0.16, 0.5, 0.3), 0.02)), "chain")
    sweep = env(freq_sweep(200, 900, 0.28), 0.03, 0.06)
    save(at(0.36, (sweep, 0.0), (amp(env(highpass(noise(0.1), 0.5), 0.001, 0.08), 0.85), 0.2)), "awaken")
    rew = env(freq_sweep(1400, 300, 0.45), 0.01, 0.15)
    shimmer = env(highpass(noise(0.45), 0.9), 0.2, 0.2)
    save(mix(amp(rew, 0.6), amp(shimmer, 0.15)), "rewind")


# ── Phases and results ─────────────────────────────────────────────────────────

def phases():
    save(cat(mix(tone(392, 0.11, 1.0, 0.25), amp(tone(588, 0.11), 0.25)), mix(tone(523, 0.16, 1.0, 0.25), amp(tone(784, 0.16), 0.25))), "phase_player")
    save(cat(mix(tone(330, 0.11, 1.0, 0.2), amp(tone(495, 0.11), 0.2)), mix(tone(220, 0.16, 1.0, 0.2), amp(tone(330, 0.16), 0.2))), "phase_enemy")
    save(cat(tone(440, 0.10, 1.0, 0.2), tone(554, 0.15, 1.0, 0.2)), "phase_ally")
    v = [(523.2, 0.0, 0.14), (659.3, 0.14, 0.14), (784.0, 0.28, 0.14), (1046.5, 0.42, 0.6)]
    save(at(1.1, *[(tone(f, d, 0.8, 0.3), t) for f, t, d in v], (tone(784, 0.6, 0.35, 0.2), 0.42), (tone(659.3, 0.6, 0.3, 0.2), 0.42)), "victory")
    g = [(392.0, 0.0, 0.25), (370.0, 0.25, 0.25), (349.2, 0.5, 0.25), (329.6, 0.75, 0.7)]
    save(at(1.5, *[(tone(f, d, 0.8, 0.2), t) for f, t, d in g]), "game_over")


if __name__ == "__main__":
    random.seed(7)  # same files every run
    print("Writing placeholder SFX to", os.path.normpath(OUT_DIR))
    ui()
    dialogue_and_progress()
    combat()
    phases()

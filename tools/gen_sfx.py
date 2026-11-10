#!/usr/bin/env python3
"""gen_sfx.py — Procedural SFX generator for the Fire Emblem Prototype.

Produces 20 mono 22050 Hz 16-bit WAV files in assets/audio/.
No third-party dependencies — uses only wave, math, random, array, os.

Run from the project root:
    python tools/gen_sfx.py

Sounds generated
----------------
  UI / navigation:
    cursor_move     — quiet 30ms blip (moving between tiles)
    cursor_confirm  — two-tone ascending click (selecting / confirming)
    cursor_cancel   — two-tone descending click (going back)
    stat_up         — bright two-note chime (level-up stat gain)

  Combat — per weapon type:
    hit_slash       — metallic noise burst (sword, dagger)
    hit_poke        — shorter stabbing noise + ring (lance)
    hit_swing       — heavy low thud (axe)
    hit_fire        — crackle + rising tone (fire tome)
    hit_thunder     — sharp crack + low rumble (thunder / levin_sword / bolting)
    hit_wind        — sweeping filtered noise (wind tome)
    hit_arrow       — short thwip + high ting (bow)
    hit_brawl       — punchy low thud (brawl / gauntlets)

  Combat — events:
    miss            — descending whoosh
    crit            — loud impact with dual metallic rings
    death           — descending mournful sweep (~450ms)
    heal            — ascending chime arpeggio (C-E-G-C)

  Phase transitions:
    player_phase    — bright two-note ascent (G4 → C5)
    enemy_phase     — darker two-note descent (E4 → A3)

  Special:
    level_up        — triumphant 4-note arpeggio (C4-E4-G4-C5)
    engage          — power-up sweep + impact burst
"""

import wave, math, random, os
from array import array as _array

# ── Constants ──────────────────────────────────────────────────────────────────

RATE    = 22050   # Hz
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

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


# ── Sound definitions ──────────────────────────────────────────────────────────

def gen_cursor_move():
    """Quiet 30ms sine blip at 880 Hz."""
    sig = env(sine(880, 0.030), attack_s=0.002, release_s=0.020)
    save(amp(sig, 0.45), "cursor_move")


def gen_cursor_confirm():
    """Two ascending notes: D5 (587 Hz) → A5 (880 Hz)."""
    n1 = env(sine(587, 0.050), attack_s=0.003, release_s=0.025)
    n2 = env(sine(880, 0.065), attack_s=0.003, release_s=0.040)
    save(cat(n1, n2), "cursor_confirm")


def gen_cursor_cancel():
    """Two descending notes: A4 (440 Hz) → E4 (330 Hz)."""
    n1 = env(sine(440, 0.045), attack_s=0.003, release_s=0.020)
    n2 = env(sine(330, 0.060), attack_s=0.003, release_s=0.035)
    save(cat(n1, n2), "cursor_cancel")


def gen_stat_up():
    """Quick bright two-note chime: A5 (880 Hz) → E6 (1319 Hz) — level-up stat gain."""
    n1 = env(sine(880,  0.042), attack_s=0.002, release_s=0.018)
    n2 = env(sine(1319, 0.058), attack_s=0.002, release_s=0.038)
    # Thin harmonic shimmer on the second note for sparkle quality.
    h2 = amp(env(sine(2637, 0.058), attack_s=0.002, release_s=0.038), 0.12)
    save(cat(n1, pad_mix(n2, h2)), "stat_up")


def gen_hit_slash():
    """Metallic noise burst + 1200 Hz ring (sword / dagger)."""
    burst = env(highpass(noise(0.080), 0.75), attack_s=0.001, release_s=0.055)
    ring  = env(sine(1200, 0.080), attack_s=0.001, release_s=0.060)
    save(mix(burst, amp(ring, 0.30)), "hit_slash")


def gen_hit_poke():
    """Shorter stab noise + 900 Hz ring (lance)."""
    burst = env(highpass(noise(0.065), 0.65), attack_s=0.001, release_s=0.045)
    ring  = env(sine(900, 0.065), attack_s=0.001, release_s=0.045)
    save(mix(burst, amp(ring, 0.25)), "hit_poke")


def gen_hit_swing():
    """Heavy low thud — filtered noise + 140 Hz sine (axe)."""
    thud  = env(lowpass(noise(0.110), 0.12), attack_s=0.006, release_s=0.080)
    bass  = env(sine(140, 0.110), attack_s=0.005, release_s=0.080)
    save(mix(thud, amp(bass, 0.55)), "hit_swing")


def gen_hit_fire():
    """Crackle noise + ascending sweep (fire tome)."""
    crackle = env(lowpass(noise(0.110), 0.22), attack_s=0.005, release_s=0.075)
    sweep   = env(freq_sweep(280, 640, 0.110), attack_s=0.010, release_s=0.055)
    save(mix(amp(crackle, 0.75), amp(sweep, 0.45)), "hit_fire")


def gen_hit_thunder():
    """Sharp high crack + deep 65 Hz rumble (thunder / bolting / levin_sword)."""
    crack  = env(highpass(noise(0.060), 0.55), attack_s=0.001, release_s=0.040)
    rumble = env(sine(65, 0.180), attack_s=0.015, release_s=0.120)
    # Crack is short; rumble continues afterward.
    crack_padded = crack + [0.0] * (frames(0.180) - len(crack))
    save(pad_mix(crack_padded, amp(rumble, 0.50)), "hit_thunder")


def gen_hit_wind():
    """Sweeping bandpass-ish noise (wind tome)."""
    raw    = noise(0.130)
    lpd    = lowpass(raw, 0.18)
    hpd    = highpass(lpd, 0.92)
    sig    = env(hpd, attack_s=0.025, release_s=0.060)
    # Slight pitch character via mixed sine.
    whoosh = env(freq_sweep(500, 200, 0.130), attack_s=0.025, release_s=0.060)
    save(mix(amp(sig, 0.80), amp(whoosh, 0.25)), "hit_wind")


def gen_hit_arrow():
    """Very short thwip + high 1800 Hz ting (bow)."""
    thwip = env(highpass(noise(0.042), 0.80), attack_s=0.001, release_s=0.028)
    ting  = env(sine(1800, 0.042), attack_s=0.001, release_s=0.032)
    save(mix(thwip, amp(ting, 0.22)), "hit_arrow")


def gen_hit_brawl():
    """Low punchy thud — heavy lowpass noise + 80 Hz sine (brawl / gauntlets)."""
    thud = env(lowpass(noise(0.095), 0.08), attack_s=0.004, release_s=0.075)
    bass = env(sine(80, 0.095), attack_s=0.004, release_s=0.075)
    save(mix(thud, amp(bass, 0.65)), "hit_brawl")


def gen_miss():
    """Descending whoosh: sweep 650 → 200 Hz + soft noise underlayer."""
    sweep = env(freq_sweep(650, 200, 0.090), attack_s=0.010, release_s=0.045)
    soft  = env(lowpass(noise(0.090), 0.20), attack_s=0.010, release_s=0.045)
    save(mix(amp(sweep, 0.55), amp(soft, 0.30)), "miss")


def gen_crit():
    """Louder impact: wide noise + dual metallic rings at 1500 Hz & 2300 Hz."""
    burst = env(highpass(noise(0.085), 0.70), attack_s=0.001, release_s=0.060)
    ring1 = env(sine(1500, 0.085), attack_s=0.001, release_s=0.065)
    ring2 = env(sine(2300, 0.060), attack_s=0.001, release_s=0.045)
    save(mix(burst, amp(ring1, 0.40), amp(ring2, 0.22)), "crit")


def gen_death():
    """Mournful descending sweep A4 → A2 over ~480 ms with a harmonic."""
    sweep = env(freq_sweep(440, 110, 0.480), attack_s=0.025, release_s=0.200)
    harm  = env(freq_sweep(660, 165, 0.480), attack_s=0.025, release_s=0.200)
    save(mix(sweep, amp(harm, 0.30)), "death")


def gen_heal():
    """Ascending chime arpeggio: C4 – E4 – G4 – C5, each 110 ms, staggered 75 ms."""
    notes = [
        env(amp(sine(261.6, 0.140), 0.70), attack_s=0.010, release_s=0.085),  # C4
        env(amp(sine(329.6, 0.140), 0.70), attack_s=0.010, release_s=0.085),  # E4
        env(amp(sine(392.0, 0.140), 0.70), attack_s=0.010, release_s=0.085),  # G4
        env(amp(sine(523.2, 0.160), 0.80), attack_s=0.010, release_s=0.110),  # C5
    ]
    stride = frames(0.075)   # offset between each note
    total  = frames(0.160 + 0.075 * 3 + 0.05)
    buf    = [0.0] * total
    for k, note in enumerate(notes):
        start = k * stride
        for i, v in enumerate(note):
            if start + i < total:
                buf[start + i] += v
    save(buf, "heal")


def gen_player_phase():
    """Bright ascending fanfare: G4 (392 Hz) → C5 (523 Hz)."""
    n1 = env(sine(392, 0.110), attack_s=0.005, release_s=0.050)
    n2 = env(sine(523, 0.145), attack_s=0.005, release_s=0.090)
    # Slight harmonic body.
    h1 = env(amp(sine(588, 0.110), 0.25), attack_s=0.005, release_s=0.050)
    h2 = env(amp(sine(784, 0.145), 0.25), attack_s=0.005, release_s=0.090)
    save(cat(mix(n1, h1), mix(n2, h2)), "player_phase")


def gen_enemy_phase():
    """Darker descending tone: E4 (330 Hz) → A3 (220 Hz)."""
    n1 = env(sine(330, 0.110), attack_s=0.010, release_s=0.050)
    n2 = env(sine(220, 0.145), attack_s=0.010, release_s=0.095)
    h1 = env(amp(sine(495, 0.110), 0.20), attack_s=0.010, release_s=0.050)
    h2 = env(amp(sine(330, 0.145), 0.20), attack_s=0.010, release_s=0.095)
    save(cat(mix(n1, h1), mix(n2, h2)), "enemy_phase")


def gen_level_up():
    """Triumphant 4-note arpeggio: C4 – E4 – G4 – C5, each 85 ms, no overlap."""
    freqs = [261.6, 329.6, 392.0, 523.2]
    notes = []
    for f in freqs:
        base = sine(f, 0.085)
        harm = amp(sine(f * 2, 0.085), 0.20)   # add octave harmonic for brightness
        n    = env(mix(base, harm), attack_s=0.005, release_s=0.040)
        notes.append(n)
    save(cat(*notes), "level_up")


def gen_engage():
    """Power-up sweep (200 → 900 Hz) over 280 ms, landing on an impact burst."""
    sweep  = env(freq_sweep(200, 900, 0.280), attack_s=0.030, release_s=0.060)
    impact = env(highpass(noise(0.100), 0.50), attack_s=0.001, release_s=0.080)
    # Overlap the impact at the tail of the sweep.
    sweep_len  = len(sweep)
    impact_len = len(impact)
    gap        = frames(0.200)   # impact starts 200 ms in
    total      = max(sweep_len, gap + impact_len)
    buf = [0.0] * total
    for i, v in enumerate(sweep):
        buf[i] += v
    for i, v in enumerate(impact):
        if gap + i < total:
            buf[gap + i] += v * 0.85
    save(buf, "engage")


def gen_battle_bgm():
    """2-second looping battle BGM — C-minor feel, BPM 120.

    Layers:
      - Walking bass: C2-Eb2-G2-Bb1 (one note per beat)
      - Sustained C-minor chord (C4-Eb4-G4), fades cleanly at loop boundary
      - Simple counter-melody (C5-Bb4-G4-A4)
      - Light hi-hat on off-beats (2 & 4)
      - Kick on beat 1

    Notes are sized so none extend past the 2s loop boundary.
    """
    BEAT = 0.5   # s per beat at BPM 120
    LOOP = 2.0   # 4 beats — one bar
    total = frames(LOOP)
    buf = [0.0] * total

    def place(sig: list, t_start: float) -> None:
        start = int(t_start * RATE)
        for i, v in enumerate(sig):
            idx = start + i
            if idx < total:
                buf[idx] += v

    # Walking bass: note dur 0.34s + 0.14s release = 0.48s; last note at 1.5s → ends 1.98s ✓
    for k, f in enumerate([65.4, 77.8, 98.0, 87.3]):   # C2, Eb2, G2, Bb1
        note = env(amp(sine(f, 0.34), 0.55), attack_s=0.010, release_s=0.14)
        place(note, k * BEAT)

    # Sustained chord: 1.60s hold + 0.40s release = exactly 2.0s ✓
    for f, g in [(261.6, 0.17), (311.1, 0.15), (392.0, 0.12)]:  # C4, Eb4, G4
        note = env(amp(sine(f, 1.60), g), attack_s=0.020, release_s=0.40)
        place(note, 0)

    # Counter-melody: last note at 1.5s + 0.16s + 0.07s release = 1.73s ✓
    for f, dur, t in [(523.2, 0.22, 0.0), (466.2, 0.18, 0.5),
                      (392.0, 0.22, 1.0), (440.0, 0.16, 1.5)]:
        note = env(amp(sine(f, dur), 0.16), attack_s=0.008, release_s=0.07)
        place(note, t)

    # Hi-hat on beats 2 and 4
    for beat in [1, 3]:
        hit = env(highpass(noise(0.032), 0.90), attack_s=0.001, release_s=0.022)
        place(amp(hit, 0.25), beat * BEAT)

    # Kick on beat 1
    kick = env(freq_sweep(100, 50, 0.070), attack_s=0.001, release_s=0.045)
    place(amp(kick, 0.50), 0.0)

    save(buf, "battle_bgm")


# ── Entry point ────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print(f"Writing SFX to: {os.path.abspath(OUT_DIR)}\n")
    gen_cursor_move()
    gen_cursor_confirm()
    gen_cursor_cancel()
    gen_stat_up()
    gen_hit_slash()
    gen_hit_poke()
    gen_hit_swing()
    gen_hit_fire()
    gen_hit_thunder()
    gen_hit_wind()
    gen_hit_arrow()
    gen_hit_brawl()
    gen_miss()
    gen_crit()
    gen_death()
    gen_heal()
    gen_player_phase()
    gen_enemy_phase()
    gen_level_up()
    gen_engage()
    gen_battle_bgm()
    print(f"\nDone — {21} files written.")

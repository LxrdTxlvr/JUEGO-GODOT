import wave
import math
import struct
import random
import os

SAMPLE_RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT_DIR, exist_ok=True)

def save_wav(filename, samples):
    filepath = os.path.join(OUT_DIR, filename)
    with wave.open(filepath, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        # Normalize and clamp
        max_val = max(max(abs(s) for s in samples), 0.001)
        scale = 32000.0 / max_val
        raw_data = bytearray()
        for s in samples:
            val = int(s * scale)
            val = max(-32767, min(32767, val))
            raw_data.extend(struct.pack('<h', val))
        wf.writeframes(raw_data)
    print(f"Generated: {filename} ({len(samples)} samples)")

def clamp(v, mn=-1.0, mx=1.0):
    return max(mn, min(mx, v))

# 1. SFX SHOOT PISTOL
def gen_shoot_pistol():
    dur = 0.28
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Fast noise burst
        env_noise = math.exp(-t * 32.0)
        noise = (random.random() * 2.0 - 1.0) * env_noise
        # Low punch pitch drop (160 -> 40 Hz)
        freq = 160.0 * math.exp(-t * 22.0) + 40.0
        env_tone = math.exp(-t * 14.0)
        tone = math.sin(2.0 * math.pi * freq * t) * env_tone * 1.5
        # Click transient at start
        click = math.sin(2.0 * math.pi * 900.0 * t) * math.exp(-t * 90.0) if t < 0.04 else 0.0
        s = clamp(noise * 1.2 + tone + click * 0.8)
        samples.append(s)
    save_wav("sfx_shoot_pistol.wav", samples)

# 2. SFX SHOOT SMG
def gen_shoot_smg():
    dur = 0.17
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 42.0)
        noise = (random.random() * 2.0 - 1.0) * env
        freq = 240.0 * math.exp(-t * 30.0) + 60.0
        tone = math.sin(2.0 * math.pi * freq * t) * env * 1.3
        crack = math.sin(2.0 * math.pi * 1400.0 * t) * math.exp(-t * 120.0) if t < 0.025 else 0.0
        samples.append(clamp(noise * 1.1 + tone + crack))
    save_wav("sfx_shoot_smg.wav", samples)

# 3. SFX KNIFE SLASH
def gen_knife_slash():
    dur = 0.22
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (t / dur)) ** 1.8
        # Swept bandpass filtered noise
        freq = 1200.0 - t * 3500.0
        sine = math.sin(2.0 * math.pi * max(150.0, freq) * t)
        noise = (random.random() * 2.0 - 1.0)
        samples.append(clamp((noise * 0.7 + sine * 0.6) * env))
    save_wav("sfx_knife_slash.wav", samples)

# 4. SFX WALL IMPACT (Bullet hits concrete/wall)
def gen_wall_impact():
    dur = 0.20
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Concrete crack
        crack = (random.random() * 2.0 - 1.0) * math.exp(-t * 60.0)
        # Metallic ping / ricochet (1750 Hz decaying)
        ping_freq = 1850.0 - t * 1200.0
        ping = math.sin(2.0 * math.pi * ping_freq * t) * math.exp(-t * 28.0) * 0.9
        samples.append(clamp(crack * 1.2 + ping))
    save_wav("sfx_wall_impact.wav", samples)

# 5. SFX FLESH IMPACT (Bullet hits zombie)
def gen_flesh_impact():
    dur = 0.22
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 24.0)
        # Low squelch thump (90 Hz)
        thump = math.sin(2.0 * math.pi * 85.0 * t) * env * 1.5
        squish = (random.random() * 2.0 - 1.0) * math.exp(-t * 40.0) * math.sin(2.0 * math.pi * 320.0 * t)
        samples.append(clamp(thump + squish * 0.8))
    save_wav("sfx_flesh_impact.wav", samples)

# 6. SFX PLAYER HURT
def gen_player_hurt():
    dur = 0.32
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 12.0) * math.sin(math.pi * min(1.0, t * 12.0))
        # Vocal grunt resonance (130 Hz descending to 90 Hz)
        freq = 140.0 - t * 120.0
        vocal = (math.sin(2.0 * math.pi * freq * t) + 0.4 * math.sin(2.0 * math.pi * freq * 2.0 * t)) * env
        thud = math.sin(2.0 * math.pi * 65.0 * t) * math.exp(-t * 20.0)
        samples.append(clamp(vocal * 1.2 + thud * 0.8))
    save_wav("sfx_player_hurt.wav", samples)

# 7. SFX PLAYER DEATH
def gen_player_death():
    dur = 0.85
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.5)
        # Sub-bass impact then fading heartbeat
        freq = 70.0 * math.exp(-t * 2.5) + 30.0
        bass = math.sin(2.0 * math.pi * freq * t) * env
        heartbeat = math.sin(2.0 * math.pi * 50.0 * t) * math.exp(-((t - 0.4) * 10.0)**2) * 0.6 if t > 0.2 else 0.0
        samples.append(clamp(bass * 1.4 + heartbeat))
    save_wav("sfx_player_death.wav", samples)

# 8. SFX ZOMBIE GROAN 1 & 2
def gen_zombie_groans():
    for idx, base_f in [(1, 95.0), (2, 80.0)]:
        dur = 0.65
        n = int(SAMPLE_RATE * dur)
        samples = []
        for i in range(n):
            t = i / SAMPLE_RATE
            env = math.sin(math.pi * (t / dur)) ** 1.3
            # Low throat formant + raspy AM vibrato
            am = 1.0 + 0.4 * math.sin(2.0 * math.pi * 28.0 * t)
            freq = base_f + 15.0 * math.sin(2.0 * math.pi * 2.5 * t)
            tone = (math.sin(2.0 * math.pi * freq * t) + 
                    0.5 * math.sin(2.0 * math.pi * freq * 2.0 * t) +
                    0.25 * math.sin(2.0 * math.pi * freq * 3.0 * t))
            noise = (random.random() * 2.0 - 1.0) * 0.35
            samples.append(clamp((tone * am + noise) * env * 0.9))
        save_wav(f"sfx_zombie_groan_{idx}.wav", samples)

# 9. SFX ZOMBIE ATTACK (Swipe / bite snarl)
def gen_zombie_attack():
    dur = 0.28
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 15.0)
        # Fast aggressive bite snap
        f = 180.0 * math.exp(-t * 25.0) + 70.0
        tone = math.sin(2.0 * math.pi * f * t) * env
        snap = (random.random() * 2.0 - 1.0) * math.exp(-t * 30.0)
        samples.append(clamp(tone * 1.1 + snap * 0.9))
    save_wav("sfx_zombie_attack.wav", samples)

# 10. SFX ZOMBIE DEATH
def gen_zombie_death():
    dur = 0.45
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 7.0)
        # Wet collapse
        f = 110.0 - t * 140.0
        tone = math.sin(2.0 * math.pi * max(35.0, f) * t) * env
        squish = (random.random() * 2.0 - 1.0) * math.exp(-t * 16.0) * 0.6
        samples.append(clamp(tone + squish))
    save_wav("sfx_zombie_death.wav", samples)

# 11. SFX BOSS ROAR
def gen_boss_roar():
    dur = 1.35
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (t / dur)) ** 1.2
        # Monstrous deep pitch bend (110 Hz down to 45 Hz with strong sub-octave)
        freq = 110.0 * math.exp(-t * 1.2) + 40.0
        tremolo = 1.0 + 0.35 * math.sin(2.0 * math.pi * 32.0 * t)
        tone = (math.sin(2.0 * math.pi * freq * t) + 
                0.8 * math.sin(2.0 * math.pi * (freq * 0.5) * t) +
                0.5 * math.sin(2.0 * math.pi * (freq * 1.5) * t) +
                0.3 * math.sin(2.0 * math.pi * (freq * 2.0) * t))
        noise = (random.random() * 2.0 - 1.0) * 0.4
        samples.append(clamp((tone * tremolo + noise) * env * 1.3))
    save_wav("sfx_boss_roar.wav", samples)

# 12. SFX BOSS SLAM (Shockwave ground pound)
def gen_boss_slam():
    dur = 0.70
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 6.0)
        # Subwoofer seismic drop
        freq = 90.0 * math.exp(-t * 10.0) + 28.0
        sub = math.sin(2.0 * math.pi * freq * t) * env * 1.7
        rumble = (random.random() * 2.0 - 1.0) * math.exp(-t * 14.0)
        samples.append(clamp(sub + rumble * 0.8))
    save_wav("sfx_boss_slam.wav", samples)

# 13. SFX PICKUP AMMO
def gen_pickup_ammo():
    dur = 0.22
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Dual mechanical clicks
        c1 = math.sin(2.0 * math.pi * 880.0 * t) * math.exp(-t * 50.0) if t < 0.08 else 0.0
        c2 = math.sin(2.0 * math.pi * 1250.0 * (t - 0.08)) * math.exp(-(t - 0.08) * 60.0) if t >= 0.08 else 0.0
        samples.append(clamp((c1 + c2) * 1.3))
    save_wav("sfx_pickup_ammo.wav", samples)

# 14. SFX PICKUP HEALTH (Chime)
def gen_pickup_health():
    dur = 0.35
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Two rising harmonious chimes: E5 (659Hz) then B5 (987Hz)
        chime1 = math.sin(2.0 * math.pi * 659.25 * t) * math.exp(-t * 12.0)
        chime2 = math.sin(2.0 * math.pi * 987.77 * (t - 0.09)) * math.exp(-(t - 0.09) * 10.0) if t > 0.09 else 0.0
        samples.append(clamp((chime1 * 0.8 + chime2 * 1.1)))
    save_wav("sfx_pickup_health.wav", samples)

# 15. SFX PICKUP WEAPON (Heavy cocking slide)
def gen_pickup_weapon():
    dur = 0.32
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Slide pull then lock
        s1 = math.sin(2.0 * math.pi * 420.0 * t) * math.exp(-t * 30.0)
        s2 = math.sin(2.0 * math.pi * 780.0 * (t - 0.12)) * math.exp(-(t - 0.12) * 45.0) if t > 0.12 else 0.0
        noise = (random.random() * 2.0 - 1.0) * math.exp(-t * 25.0) * 0.3
        samples.append(clamp((s1 + s2 + noise) * 1.2))
    save_wav("sfx_pickup_weapon.wav", samples)

# 16. SFX WAVE ALERT
def gen_wave_alert():
    dur = 0.65
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 4.0) * math.sin(math.pi * min(1.0, t * 16.0))
        # Dramatic warning chord: Root 220Hz (A3) + Fifth 330Hz (E4) + Octave 440Hz
        tone = (math.sin(2.0 * math.pi * 220.0 * t) * 0.7 +
                math.sin(2.0 * math.pi * 330.0 * t) * 0.5 +
                math.sin(2.0 * math.pi * 440.0 * t) * 0.4)
        samples.append(clamp(tone * env * 1.3))
    save_wav("sfx_wave_alert.wav", samples)

# 17. SFX UI CLICK
def gen_ui_click():
    dur = 0.06
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 90.0)
        tone = math.sin(2.0 * math.pi * 920.0 * t) * env
        samples.append(clamp(tone))
    save_wav("sfx_ui_click.wav", samples)

# 18. SFX UI HOVER
def gen_ui_hover():
    dur = 0.04
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 120.0)
        tone = math.sin(2.0 * math.pi * 640.0 * t) * env * 0.6
        samples.append(clamp(tone))
    save_wav("sfx_ui_hover.wav", samples)

# 19. SFX VICTORY
def gen_victory():
    dur = 1.3
    n = int(SAMPLE_RATE * dur)
    samples = []
    # Major triad fanfare: C4 (261.6), E4 (329.6), G4 (392.0), C5 (523.25)
    notes = [
        (0.0, 0.22, 261.63),
        (0.18, 0.22, 329.63),
        (0.36, 0.22, 392.00),
        (0.54, 0.76, 523.25),
    ]
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        for start, length, freq in notes:
            if start <= t < start + length:
                local_t = t - start
                env = math.exp(-local_t * (3.0 if freq > 500 else 6.0)) * math.sin(math.pi * min(1.0, local_t * 20.0))
                val += math.sin(2.0 * math.pi * freq * local_t) * env
                val += 0.3 * math.sin(2.0 * math.pi * freq * 2.0 * local_t) * env
        samples.append(clamp(val * 0.9))
    save_wav("sfx_victory.wav", samples)

# 20. SFX GAME OVER
def gen_game_over():
    dur = 1.4
    n = int(SAMPLE_RATE * dur)
    samples = []
    # Ominous descending minor chord
    notes = [
        (0.0, 0.35, 220.0),   # A3
        (0.28, 0.35, 174.61), # F3
        (0.55, 0.85, 130.81), # C3
    ]
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        for start, length, freq in notes:
            if start <= t < start + length:
                local_t = t - start
                env = math.exp(-local_t * 3.0) * math.sin(math.pi * min(1.0, local_t * 14.0))
                val += math.sin(2.0 * math.pi * freq * local_t) * env
                val += 0.4 * math.sin(2.0 * math.pi * (freq * 0.5) * local_t) * env
        samples.append(clamp(val * 0.85))
    save_wav("sfx_game_over.wav", samples)

if __name__ == "__main__":
    gen_shoot_pistol()
    gen_shoot_smg()
    gen_knife_slash()
    gen_wall_impact()
    gen_flesh_impact()
    gen_player_hurt()
    gen_player_death()
    gen_zombie_groans()
    gen_zombie_attack()
    gen_zombie_death()
    gen_boss_roar()
    gen_boss_slam()
    gen_pickup_ammo()
    gen_pickup_health()
    gen_pickup_weapon()
    gen_wave_alert()
    gen_ui_click()
    gen_ui_hover()
    gen_victory()
    gen_game_over()
    print("All 20 sound effects generated successfully!")

import wave
import struct
import numpy as np
import os
from scipy.signal import butter, sosfilt

SAMPLE_RATE = 44100

def butter_bandpass(lowcut, highcut, fs, order=4):
    return butter(order, [lowcut, highcut], fs=fs, btype='band', output='sos')

def save_wav(filepath, samples):
    # Normalize to -1.0 to 1.0 with headroom (-1dB)
    max_val = np.max(np.abs(samples))
    if max_val > 1e-5:
        samples = samples / max_val * 0.90
    
    int_samples = np.clip(samples * 32767.0, -32767.0, 32767.0).astype(np.int16)
    
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with wave.open(filepath, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(int_samples.tobytes())
    print(f"Generated: {filepath} ({len(samples)} samples, {len(samples)/SAMPLE_RATE:.3f}s)")

def synthesize_footstep(dur=0.15, heel_freq=100.0, punch_decay=35.0, grit_low=800.0, grit_high=2600.0, grit_vol=0.7, toe_delay=0.035, toe_freq=350.0):
    n = int(SAMPLE_RATE * dur)
    t = np.linspace(0, dur, n, endpoint=False)
    
    # 1. Heel impact: fast pitch drop + exponential decay
    heel_f = heel_freq * np.exp(-t * 28.0) + 45.0
    heel_phase = 2.0 * np.pi * np.cumsum(heel_f) / SAMPLE_RATE
    heel_env = np.exp(-t * punch_decay)
    heel = np.sin(heel_phase) * heel_env * 1.3
    
    # 2. Grit / friction noise (bandpass filtered)
    noise = np.random.uniform(-1.0, 1.0, n)
    # Attack-decay envelope for grit
    grit_env = np.exp(-t * (punch_decay * 0.8)) * (1.0 - np.exp(-t * 800.0))
    sos = butter_bandpass(grit_low, grit_high, SAMPLE_RATE, order=3)
    filtered_grit = sosfilt(sos, noise) * grit_env * grit_vol
    
    # 3. Toe roll / secondary tap
    toe = np.zeros(n)
    toe_idx = int(SAMPLE_RATE * toe_delay)
    if toe_idx < n:
        t_toe = t[toe_idx:] - toe_delay
        toe_f = toe_freq * np.exp(-t_toe * 40.0) + 120.0
        toe_phase = 2.0 * np.pi * np.cumsum(toe_f) / SAMPLE_RATE
        toe_env = np.exp(-t_toe * (punch_decay * 1.2))
        toe[toe_idx:] = np.sin(toe_phase) * toe_env * 0.6
    
    # Combine and add subtle click transient (very start)
    click = np.sin(2.0 * np.pi * 1200.0 * t) * np.exp(-t * 250.0) * 0.4
    
    out = heel + filtered_grit + toe + click
    return out

def generate_all_footsteps():
    np.random.seed(42)
    
    assets_audio = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
    new_snds = os.path.join(os.path.dirname(__file__), "..", "NEW SNDS")
    
    # 4 Walk variations (Combat boots on pavement/concrete)
    walk_params = [
        {"dur": 0.16, "heel_freq": 95.0, "punch_decay": 28.0, "grit_low": 750.0, "grit_high": 2400.0, "grit_vol": 0.65, "toe_delay": 0.038, "toe_freq": 340.0},
        {"dur": 0.15, "heel_freq": 110.0, "punch_decay": 32.0, "grit_low": 850.0, "grit_high": 2800.0, "grit_vol": 0.70, "toe_delay": 0.034, "toe_freq": 380.0},
        {"dur": 0.17, "heel_freq": 90.0, "punch_decay": 26.0, "grit_low": 700.0, "grit_high": 2300.0, "grit_vol": 0.60, "toe_delay": 0.040, "toe_freq": 320.0},
        {"dur": 0.15, "heel_freq": 105.0, "punch_decay": 30.0, "grit_low": 800.0, "grit_high": 2600.0, "grit_vol": 0.68, "toe_delay": 0.036, "toe_freq": 360.0},
    ]
    
    walk_samples = []
    for i, p in enumerate(walk_params):
        s = synthesize_footstep(**p)
        walk_samples.append(s)
        save_wav(os.path.join(assets_audio, f"sfx_footstep_walk_{i+1}.wav"), s)
    
    # Also save primary walk step to NEW SNDS with user-friendly naming
    save_wav(os.path.join(new_snds, "PASOS CAMINAR SOBREVIVIENTE 1.wav"), walk_samples[0])
    save_wav(os.path.join(new_snds, "PASOS CAMINAR SOBREVIVIENTE 2.wav"), walk_samples[1])
    
    # 4 Run variations (Faster, heavier, punchier)
    run_params = [
        {"dur": 0.13, "heel_freq": 130.0, "punch_decay": 38.0, "grit_low": 900.0, "grit_high": 3200.0, "grit_vol": 0.85, "toe_delay": 0.024, "toe_freq": 420.0},
        {"dur": 0.12, "heel_freq": 145.0, "punch_decay": 42.0, "grit_low": 1000.0, "grit_high": 3500.0, "grit_vol": 0.90, "toe_delay": 0.022, "toe_freq": 460.0},
        {"dur": 0.14, "heel_freq": 125.0, "punch_decay": 36.0, "grit_low": 850.0, "grit_high": 3000.0, "grit_vol": 0.80, "toe_delay": 0.026, "toe_freq": 400.0},
        {"dur": 0.12, "heel_freq": 140.0, "punch_decay": 40.0, "grit_low": 950.0, "grit_high": 3400.0, "grit_vol": 0.88, "toe_delay": 0.023, "toe_freq": 440.0},
    ]
    
    run_samples = []
    for i, p in enumerate(run_params):
        s = synthesize_footstep(**p)
        run_samples.append(s)
        save_wav(os.path.join(assets_audio, f"sfx_footstep_run_{i+1}.wav"), s)
    
    save_wav(os.path.join(new_snds, "PASOS CORRER SOBREVIVIENTE 1.wav"), run_samples[0])
    save_wav(os.path.join(new_snds, "PASOS CORRER SOBREVIVIENTE 2.wav"), run_samples[1])
    
    print("All footstep sounds generated successfully!")

if __name__ == "__main__":
    generate_all_footsteps()

#!/usr/bin/env python3
"""
Arrbit VAD + Language ID Worker

Fast primary language detection over speech-only windows.

Features:
  * Silero-VAD (torch.hub) for speech segmentation
  * Evenly distributed fixed-size analysis windows over cumulative speech time
  * faster-whisper language detection (probability vector per window)
  * Energy (RMS) based confidence weighting
  * Early-exit when high confidence reached after sufficient coverage
  * Serve mode for warm model reuse (stdin JSON lines)

JSON Output Schema (one line per run):
{
  "primary": "en",
  "share": 0.83,
  "distribution": {"en":0.83, "fr":0.10, ...},
  "speech_windows": [
       {"start": 1.23, "dur": 3.0, "rms": 0.041, "lang": "en", "top_p": 0.92},
       ...
  ],
  "sr": 16000,
  "decision": "accept|ambiguous|review",
  "early_exit": true/false,
  "observed_speech": 18.0
}

Decision Thresholds:
  * accept if share >= accept
  * ambiguous if ambig_low <= share < accept (tag + (mixed))
  * review if share < ambig_low

Exit Codes:
  0 success, 2 argument / usage error, 3 processing error

Environment:
  TORCH_HOME fixed by caller (/app/arrbit/data/torch) to keep cache internal.
  ARRBIT_TORCH_THREADS can set torch.set_num_threads.
"""
from __future__ import annotations
import argparse
import sys
import json
import os
import math
import time
from typing import List, Dict, Tuple

import numpy as np
import soundfile as sf
import torch

# Lazy import of faster_whisper only after parsing arguments to allow --help without deps
WhisperModel = None  # type: ignore

# ------------------------- Utility Functions -------------------------

def log_err(msg: str):
    print(f"[ERR] {msg}", file=sys.stderr)

def rms_energy(x: np.ndarray) -> float:
    if x.size == 0:
        return 0.0
    # Normalize RMS and clamp to avoid overweighting loud windows
    rms = float(np.sqrt(np.mean(np.square(x), dtype=np.float64)))
    # Scale into 0..1 typical speech ~0.02-0.2 after ffmpeg normalization; map w/ soft curve
    scaled = min(1.0, rms / 0.1)
    # Confidence floor 0.6 so windows still contribute
    return max(0.6, scaled)

def load_audio_mono(path: str) -> Tuple[np.ndarray, int]:
    data, sr = sf.read(path)
    if data.ndim > 1:
        data = np.mean(data, axis=1)
    if data.dtype != np.float32:
        data = data.astype(np.float32)
    return data, sr

# ------------------------- Window Selection -------------------------

def pick_windows(speech_ts: List[Dict[str, int]], sr: int, window_s: float, target_speech_s: float, max_windows: int) -> List[Tuple[float, float]]:
    """Select evenly spaced windows across cumulative speech time.

    speech_ts: list of {start: sample_idx, end: sample_idx}
    Returns list of (start_seconds, duration_seconds)
    """
    # Flatten speech segments into cumulative axis
    segs = []
    total_speech = 0.0
    for seg in speech_ts:
        dur = (seg['end'] - seg['start']) / sr
        if dur <= 0:
            continue
        segs.append((seg['start'] / sr, seg['end'] / sr, dur))
        total_speech += dur
    if total_speech == 0:
        return []
    budget = min(target_speech_s, total_speech)
    # Number of windows (cap by max_windows and budget / window)
    nominal = int(math.ceil(budget / window_s))
    n_win = min(max_windows, max(1, nominal))
    # Evenly space centers over [0, budget]
    # Build cumulative mapping
    cumulative = []  # (speech_offset_start, speech_offset_end, abs_start)
    acc = 0.0
    for s, e, d in segs:
        cumulative.append((acc, acc + d, s))
        acc += d
    def speech_to_abs(t: float) -> float:
        for off_s, off_e, abs_s in cumulative:
            if off_s <= t < off_e:
                # t resides inside this segment
                rel = t - off_s
                return abs_s + rel
        # Edge: t == total_speech
        return cumulative[-1][2]
    windows = []
    for i in range(n_win):
        # Position along cumulative speech axis
        center_speech = ( (i + 0.5) / n_win ) * budget
        center_abs = speech_to_abs(center_speech)
        start_abs = max(0.0, center_abs - window_s / 2.0)
        windows.append( (start_abs, window_s) )
    return windows

# ------------------------- Probability Aggregation -------------------------

def aggregate_prob_windows(items: List[Dict]) -> Tuple[str, float, Dict[str, float]]:
    weight_sums: Dict[str, float] = {}
    total_weight = 0.0
    for it in items:
        probs: Dict[str, float] = it['probs']
        w = float(it['dur'] * it['conf'])
        if w <= 0:
            continue
        total_weight += w
        for lang, p in probs.items():
            weight_sums[lang] = weight_sums.get(lang, 0.0) + p * w
    if total_weight == 0:
        return "und", 0.0, {"und": 1.0}
    # Normalize
    for k in list(weight_sums.keys()):
        weight_sums[k] /= total_weight
    # Sort
    primary = max(weight_sums.items(), key=lambda kv: kv[1])[0]
    share = weight_sums[primary]
    # Order distribution descending
    ordered = dict(sorted(weight_sums.items(), key=lambda kv: kv[1], reverse=True))
    return primary, share, ordered

# ------------------------- Core Run Logic -------------------------

def run_once(path: str, model_name: str = "tiny", compute_type: str = "int8", window: float = 3.0, target_speech: float = 24.0, max_windows: int = 8, early: float = 0.90, accept: float = 0.70, ambig_low: float = 0.55, shared_models=None) -> Dict:
    t0 = time.time()
    try:
        audio, sr = load_audio_mono(path)
    except Exception as e:
        return {"error": f"audio_load_failed: {e}"}
    if sr != 16000:
        # Expect enforced by extraction pipeline
        log_err(f"Warning: sample rate {sr}, expected 16000")
    # VAD
    try:
        if shared_models and 'vad' in shared_models:
            vad_model = shared_models['vad']
            get_speech_timestamps = shared_models['get_speech_timestamps']
        else:
            vad_model, utils = torch.hub.load('snakers4/silero-vad', 'silero_vad', trust_repo=True)
            (get_speech_timestamps, _, _, _, _) = utils
        speech_ts = get_speech_timestamps(audio, vad_model, sampling_rate=sr)
    except Exception as e:
        return {"error": f"vad_failed: {e}"}
    windows = pick_windows(speech_ts, sr, window, target_speech, max_windows)
    observed_speech = min(sum( (seg['end']-seg['start'])/sr for seg in speech_ts ), target_speech)
    items = []
    early_exit = False
    # Load whisper model (language detection only)
    global WhisperModel
    if shared_models and 'whisper' in shared_models:
        wmodel = shared_models['whisper']
    else:
        if WhisperModel is None:
            from faster_whisper import WhisperModel as _WM
            WhisperModel = _WM
        wmodel = WhisperModel(model_name, device="cpu", compute_type=compute_type)
    for idx, (start_s, dur_s) in enumerate(windows):
        start_sample = int(start_s * sr)
        end_sample = int(min(len(audio), start_sample + int(dur_s * sr)))
        segment = audio[start_sample:end_sample]
        conf = rms_energy(segment)
        # detect_language expects entire audio; we pass segment
        try:
            _, probs = wmodel.detect_language(segment)
        except Exception as e:
            return {"error": f"detect_failed:{e}"}
        top_lang = max(probs.items(), key=lambda kv: kv[1])[0]
        top_p = probs[top_lang]
        items.append({"dur": dur_s, "conf": conf, "probs": probs, "start": start_s, "rms": conf, "lang": top_lang, "top_p": top_p})
        primary, share, distribution = aggregate_prob_windows(items)
        processed_speech = (idx + 1) * dur_s
        coverage_ratio = processed_speech / target_speech
        if share >= early and coverage_ratio >= 0.75:
            early_exit = True
            break
    primary, share, distribution = aggregate_prob_windows(items)
    decision = "review"
    if share >= accept:
        decision = "accept"
    elif share >= ambig_low:
        decision = "ambiguous"
    elapsed = time.time() - t0
    return {
        "primary": primary,
        "share": round(share, 4),
        "distribution": {k: round(v, 4) for k, v in distribution.items()},
        "speech_windows": [
            {"start": round(it['start'], 3), "dur": it['dur'], "rms": round(it['rms'], 4), "lang": it['lang'], "top_p": round(it['top_p'], 4)} for it in items
        ],
        "sr": sr,
        "decision": decision,
        "early_exit": early_exit,
        "observed_speech": round(observed_speech, 3),
        "elapsed_s": round(elapsed, 3),
        "params": {"model": model_name, "window": window, "target_speech": target_speech, "max_windows": max_windows, "early": early, "accept": accept, "ambig_low": ambig_low}
    }

# ------------------------- Serve Mode -------------------------

def serve_loop(args):
    # Preload models
    if args.threads:
        try:
            torch.set_num_threads(args.threads)
        except Exception:
            pass
    vad_model, utils = torch.hub.load('snakers4/silero-vad', 'silero_vad', trust_repo=True)
    (get_speech_timestamps, _, _, _, _) = utils
    from faster_whisper import WhisperModel as _WM
    wmodel = _WM(args.model, device="cpu", compute_type=args.compute_type)
    shared = {"vad": vad_model, "get_speech_timestamps": get_speech_timestamps, "whisper": wmodel}
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        if line.lower() in {"quit", "exit", "stop"}:
            break
        try:
            job = json.loads(line)
        except json.JSONDecodeError:
            print(json.dumps({"error": "invalid_json"}))
            continue
        wav = job.get("wav")
        if not wav or not os.path.isfile(wav):
            print(json.dumps({"error": "missing_wav"}))
            continue
        res = run_once(wav, model_name=args.model, compute_type=args.compute_type, window=args.window, target_speech=args.target_speech, max_windows=args.max_windows, early=args.early, accept=args.accept, ambig_low=args.ambig_low, shared_models=shared)
        print(json.dumps(res, ensure_ascii=False))
        sys.stdout.flush()

# ------------------------- CLI -------------------------

def parse_args(argv=None):
    p = argparse.ArgumentParser(description="Arrbit VAD+LID worker")
    p.add_argument('wav', nargs='?', help='Path to 16 kHz mono wav (omit in --serve)')
    p.add_argument('--model', default='tiny')
    p.add_argument('--compute_type', default='int8')
    p.add_argument('--window', type=float, default=3.0)
    p.add_argument('--target_speech', type=float, default=24.0)
    p.add_argument('--max_windows', type=int, default=8)
    p.add_argument('--early', type=float, default=0.90)
    p.add_argument('--accept', type=float, default=0.70)
    p.add_argument('--ambig_low', type=float, default=0.55)
    p.add_argument('--serve', action='store_true')
    p.add_argument('--threads', type=int, default=int(os.environ.get('ARRBIT_TORCH_THREADS', '1')))
    return p.parse_args(argv)

def main(argv=None):
    args = parse_args(argv)
    if args.serve and args.wav:
        log_err('--serve cannot be combined with wav path')
        return 2
    if not args.serve and not args.wav:
        log_err('wav path required unless --serve')
        return 2
    if args.serve:
        serve_loop(args)
        return 0
    res = run_once(args.wav, model_name=args.model, compute_type=args.compute_type, window=args.window, target_speech=args.target_speech, max_windows=args.max_windows, early=args.early, accept=args.accept, ambig_low=args.ambig_low)
    print(json.dumps(res, ensure_ascii=False))
    return 0 if 'error' not in res else 3

if __name__ == '__main__':
    sys.exit(main())

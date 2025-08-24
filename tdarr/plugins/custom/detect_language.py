#!/usr/bin/env python3
"""
Audio Language Detection Script for Tdarr (WhisperX + mkvpropedit)

Usage:
    python3 detect_language.py <mkv_file> <sample_duration_seconds> <confidence_threshold_percent> <dry_run(true|false)> <backup(true|false)>

Outputs JSON to stdout with detection details per audio track.
"""
import sys
import json
import subprocess
import tempfile
import os
import logging
from pathlib import Path
import whisperx

logging.basicConfig(level=logging.INFO)

BASE_DIR = Path(__file__).parent
LANG_MAP_PATH = BASE_DIR / "language_map.json"
SAMPLE_RATE = 16000
CHUNK_SECONDS = 10

def load_language_map():
    if LANG_MAP_PATH.exists():
        return json.loads(LANG_MAP_PATH.read_text())
    return {}

class AudioLanguageDetector:
    def __init__(self, confidence_threshold=85, model_size="base"):
        self.confidence_threshold = float(confidence_threshold)
        self.model_size = model_size
        self.device = "cpu"
        self.compute_type = "int8"
        logging.info("Loading WhisperX model (cpu, int8)...")
        self.model = whisperx.load_model(self.model_size, self.device, compute_type=self.compute_type)
        self.language_map = load_language_map()

    def get_audio_tracks(self, mkv_file):
        cmd = ["mkvmerge", "-J", mkv_file]
        res = subprocess.run(cmd, capture_output=True, text=True)
        info = json.loads(res.stdout)
        audio_tracks = []
        for t in info.get("tracks", []):
            if t.get("type") == "audio":
                audio_tracks.append({
                    "id": t.get("id"),
                    "properties": t.get("properties", {}),
                })
        return audio_tracks

    def extract_audio_sample(self, mkv_file, audio_stream_index, duration=60):
        tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        tmp.close()
        out = tmp.name
        cmd = [
            "ffmpeg", "-hide_banner", "-loglevel", "error",
            "-i", mkv_file,
            "-map", f"0:a:{audio_stream_index}",
            "-t", str(duration),
            "-acodec", "pcm_s16le",
            "-ar", str(SAMPLE_RATE),
            "-ac", "1",
            "-y",
            out
        ]
        subprocess.run(cmd, check=True)
        return out

    def detect_language_on_file(self, audio_file):
        # load raw audio (numpy)
        audio = whisperx.load_audio(audio_file, sr=SAMPLE_RATE)
        chunk_samples = CHUNK_SECONDS * SAMPLE_RATE
        total_samples = len(audio)
        languages = []
        confidences = []
        for start in range(0, total_samples, chunk_samples):
            end = min(start + chunk_samples, total_samples)
            chunk = audio[start:end]
            if len(chunk) < 1000:
                continue
            result = self.model.transcribe(chunk, batch_size=1)
            lang = result.get("language", "unknown")
            languages.append(lang.lower())
            # estimate confidence from segments if available
            segs = result.get("segments", [])
            if segs:
                seg_conf = []
                for s in segs:
                    if "confidence" in s:
                        seg_conf.append(s["confidence"])
                    elif "avg_logprob" in s:
                        # heuristic: convert avg_logprob (negative) to 0-1
                        try:
                            v = float(s["avg_logprob"])
                            seg_conf.append(max(0.0, min(1.0, 1.0 - abs(v)/10.0)))
                        except:
                            pass
                if seg_conf:
                    confidences.append(sum(seg_conf)/len(seg_conf))
        # aggregate
        if confidences:
            avg_conf = float(sum(confidences)/len(confidences))*100.0
        else:
            avg_conf = 90.0
        detected = {}
        detected["language"] = languages[0] if languages else "unknown"
        detected["detected_languages"] = sorted(set(languages))
        detected["is_mixed"] = len(set(languages)) > 1
        detected["confidence"] = avg_conf
        return detected

    def iso_for(self, lang_name):
        if not lang_name:
            return "und"
        key = lang_name.lower()
        return self.language_map.get(key, "und")

    def backup_original_tags(self, mkv_file, audio_tracks):
        info = []
        for index, t in enumerate(audio_tracks):
            lang = t["properties"].get("language", "und")
            info.append(f"track_{index}:{lang}")
        backup_str = ",".join(info)
        try:
            subprocess.run([
                "mkvpropedit", mkv_file,
                "--edit", "info", "--set", f"comment=ORIGINAL_LANGUAGES={backup_str}"
            ], capture_output=True, check=True)
        except Exception:
            # best-effort; ignore failures
            pass
        return backup_str

    def update_track_language(self, mkv_file, audio_index, language_code, dry_run=False):
        if dry_run:
            return f"[DRY RUN] Would set audio track {audio_index} -> {language_code}"
        # mkvpropedit audio track numbering is 1-based among audio tracks
        track_selector = f"track:a{audio_index+1}"
        cmd = ["mkvpropedit", mkv_file, "--edit", track_selector, "--set", f"language={language_code}"]
        subprocess.run(cmd, capture_output=True, check=True)
        return f"Updated audio track {audio_index} -> {language_code}"

    def process_file(self, mkv_file, sample_duration=60, dry_run=False, backup=True):
        result = {"file": mkv_file, "tracks": [], "changes_made": False, "errors": []}
        try:
            audio_tracks = self.get_audio_tracks(mkv_file)
            if not audio_tracks:
                result["errors"].append("no_audio_tracks")
                return result
            if backup and not dry_run:
                result["backup"] = self.backup_original_tags(mkv_file, audio_tracks)
            for audio_index, t in enumerate(audio_tracks):
                track_result = {"audio_index": audio_index, "original_language": t["properties"].get("language", "und")}
                try:
                    sample = self.extract_audio_sample(mkv_file, audio_index, duration=sample_duration)
                    detection = self.detect_language_on_file(sample)
                    track_result.update(detection)
                    os.unlink(sample)
                    iso = self.iso_for(detection["language"])
                    if detection["is_mixed"]:
                        track_result["action"] = "skipped_mixed"
                    elif detection["confidence"] < self.confidence_threshold:
                        track_result["action"] = "skipped_low_confidence"
                    elif iso == track_result["original_language"]:
                        track_result["action"] = "no_change"
                    else:
                        upd = self.update_track_language(mkv_file, audio_index, iso, dry_run=dry_run)
                        track_result["action"] = "updated" if not dry_run else "would_update"
                        track_result["note"] = upd
                        if not dry_run:
                            result["changes_made"] = True
                except Exception as e:
                    track_result["action"] = "error"
                    track_result["error"] = str(e)
                result["tracks"].append(track_result)
        except Exception as e:
            result["errors"].append(str(e))
        return result

def main():
    if len(sys.argv) < 6:
        print(json.dumps({"error": "invalid_args"}))
        sys.exit(1)
    mkv_file = sys.argv[1]
    sample_duration = int(sys.argv[2])
    confidence_threshold = float(sys.argv[3])
    dry_run = sys.argv[4].lower() == "true"
    backup = sys.argv[5].lower() == "true"
    detector = AudioLanguageDetector(confidence_threshold=confidence_threshold)
    out = detector.process_file(mkv_file, sample_duration=sample_duration, dry_run=dry_run, backup=backup)
    print(json.dumps(out))

if __name__ == "__main__":
    main()
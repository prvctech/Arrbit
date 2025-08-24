# Arrbit Audio Language Tagger

Purpose

This Tdarr plugin detects audio track language using WhisperX (CPU) and updates MKV audio track language tags using mkvpropedit without transcoding.

Features:

- Per-audio-track detection (60s sample max)
- CPU-only WhisperX (int8)
- ISO 639-2 mapping via language_map.json
- Dry-run mode, configurable confidence threshold
- Non-destructive mkvpropedit metadata updates

Files included:

- tdarr/plugins/custom/detect_language.py
- tdarr/plugins/custom/language_map.json
- tdarr/plugins/custom/Tdarr_Plugin_Arrbit_Audio_Language_Tagger.js

Tdarr inputs:

- confidence_threshold (number, default 85)
- sample_duration (number, default 60)
- dry_run (boolean)
- backup_original (boolean)

Installation:

1. Copy plugin files to Tdarr's plugins/custom directory.
2. Run tdarr/scripts/setup/dependencies.bash to install runtime and Python venv.
3. Ensure mkvtoolnix and ffmpeg are installed and mkvpropedit is available.

Usage:

- Add plugin to a "Pre-processing" step in your Tdarr flow.
- Run in dry-run first to review planned changes.
- Then run with dry_run=false to apply tags.

Notes and limitations:

- Mixed-language tracks are skipped and flagged.
- Very short or music-only tracks may be misclassified; adjust confidence threshold as needed.
- This plugin only edits MKV metadata; no transcoding is performed.

Troubleshooting:

- Check Tdarr plugin logs and the Python virtualenv at /app/arrbit/environments/whisperx-env if model loading fails.

License: MIT (respect project license)

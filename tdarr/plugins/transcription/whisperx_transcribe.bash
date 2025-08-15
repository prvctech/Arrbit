#!/usr/bin/env bash
PLUGIN_NAME="Arrbit WhisperX Transcription"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Transcribe audio using WhisperX isolated environment"

main() {
  in="$1"; outdir="$2"
  [ -f "$in" ] || { echo "Input missing: $in" >&2; return 1; }
  mkdir -p "$outdir"
  base="$(basename "$in")"
  text="$outdir/${base%.*}_transcript.txt"
  /app/arrbit/tdarr/scripts/transcribe_audio.bash "$in" "$text"
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

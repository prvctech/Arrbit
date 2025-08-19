#!/usr/bin/env bash
# shellcheck disable=SC2034 # PLUGIN_* are consumed by external plugin managers
PLUGIN_NAME="Arrbit WhisperX Transcription"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Transcribe audio using WhisperX isolated environment"

main() {
	local in="$1" outdir="$2" base text
	if [[ ! -f "$in" ]]; then
		echo "Input missing: $in" >&2
		return 1
	fi
	mkdir -p "$outdir"
	base="$(basename "$in")"
	text="$outdir/${base%.*}_transcript.txt"
	/app/arrbit/tdarr/scripts/transcribe_audio.bash "$in" "$text"
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	main "$@"
fi

#!/usr/bin/env bash
set -euo pipefail
ENV="/app/arrbit/tdarr/environments/whisperx-env"
CONF="/app/arrbit/tdarr/config/whisperx.conf"
# shellcheck disable=SC1090
# shellcheck source=/app/arrbit/tdarr/config/whisperx.conf
[[ -f "${CONF}" ]] && source "${CONF}"
MODELS="/app/arrbit/tdarr/data/models/whisper"
CACHE="/app/arrbit/tdarr/data/cache"
TEMP="/app/arrbit/tdarr/data/temp"
LOGS="/app/arrbit/tdarr/data/logs"
# config already sourced above if present

mkdir -p "$MODELS" "$CACHE" "$TEMP" "$LOGS"

in="$1"
out="${2:-${in%.*}.txt}"
[[ -z "${in-}" ]] && {
	echo "Usage: $0 <input_file> [output_file]"
	exit 1
}
[[ -f "$in" ]] || {
	echo "Input not found: $in"
	exit 1
}

log="$LOGS/transcription_$(date +%Y%m%d_%H%M%S).log"
echo "Transcribing $in -> $out" | tee "$log"

"$ENV/bin/python" -m whisperx \
	--model "${WHISPERX_MODEL:-tiny}" \
	--language "${WHISPERX_LANGUAGE:-auto}" \
	--output_dir "$(dirname "$out")" \
	--output_format "${WHISPERX_OUTPUT_FORMAT:-txt}" \
	"$in" 2>&1 | tee -a "$log"

echo "Done. Output: $out" | tee -a "$log"

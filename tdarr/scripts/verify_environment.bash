#!/usr/bin/env bash
set -euo pipefail
BASE="/app/arrbit"
TDARR="$BASE/tdarr"
ENV="$TDARR/environments/whisperx-env"
echo "=== Arrbit Verify ==="
for d in \
	"$BASE" "$TDARR" "$TDARR/environments" "$TDARR/plugins/transcription" \
	"$TDARR/data/models/whisper" "$TDARR/data/cache" "$TDARR/data/temp" "$TDARR/data/logs" \
	"$TDARR/scripts" "$TDARR/config" "$TDARR/setup_scripts"; do
	[[ -d $d ]] && echo "[OK] $d" || echo "[MISS] $d"
done
if [[ -f "$ENV/bin/python" ]]; then
	echo "[OK] venv python present"
	"$ENV/bin/python" -c 'import sys; print("Python:", sys.version.split()[0])' || true
	"$ENV/bin/python" -c 'import whisperx; print("WhisperX:", whisperx.__version__)' 2>/dev/null || echo "[MISS] whisperx module"
else
	echo "[MISS] venv not created yet (run dependencies.bash)"
fi

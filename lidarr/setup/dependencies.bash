#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - dependencies.bash
# Version: v1.0.0-gs3.1.2
# Purpose: Install/verify Lidarr service dependencies with adaptive verbosity (Golden Standard v3.1.2)
# -------------------------------------------------------------------------------------------------------------

set -euo pipefail

ARRBIT_BASE="/app/arrbit"
source "${ARRBIT_BASE}/universal/helpers/logging_utils.bash"
source "${ARRBIT_BASE}/universal/helpers/helpers.bash"
arrbitPurgeOldLogs

SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v1.0.0-gs3.1.2"
LOG_FILE="${ARRBIT_BASE}/data/logs/arrbit-${SCRIPT_NAME}-${log_level}-$(date +%Y_%m_%d-%H_%M).log"
arrbitInitLog "$LOG_FILE"
arrbitBanner "$SCRIPT_NAME" "$SCRIPT_VERSION"

# --- Setup version tracking (prevent re-installation) ---
SETUP_VERSION_FILE="${ARRBIT_BASE}/data/setup_version-lidarr-deps.txt"
CURRENT_VERSION="1.0.0"

# Virtual env (to isolate tidal-dl-ng/python-ffmpeg from ffmpeg-python)
# Location moved per user preference
ARRBIT_VENV="${ARRBIT_BASE}/environments/lidarr-music-tools"
VENV_PY="$ARRBIT_VENV/bin/python3"
VENV_PIP="$ARRBIT_VENV/bin/pip"
mkdir -p "$(dirname "$ARRBIT_VENV")" || true

# --- What we consider required (tools + python modules) ---
REQUIRED_CMDS="beet atomicparsley python3 uv eyeD3 yq xq jq ffmpeg \
vorbiscomment metaflac opustags aria2c rg convert tidy lame"
REQUIRED_PY_MODS=(
	eyed3 yq mutagen beautifulsoup4 jellyfish pyacoustid requests
	yt_dlp pyxDamerauLevenshtein colorama pylast r128gain
	cryptography requests_oauthlib plexapi
)

list_missing_cmds() {
	local missing=""
	for cmd in $REQUIRED_CMDS; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			missing+=" $cmd"
		fi
	done
	echo "$missing"
}

list_missing_py() {
	if ! command -v python3 >/dev/null 2>&1; then
		# python3 not available yet; assume all required Python modules are missing
		printf '%s ' "${REQUIRED_PY_MODS[@]}"
		echo
		return 0
	fi
	python3 - <<'PY'
name_map = {
  "beautifulsoup4": "bs4",
  "pyacoustid": "acoustid",
  "yt_dlp": "yt_dlp",
  "pyxDamerauLevenshtein": "pyxdameraulevenshtein",
  "requests_oauthlib": "requests_oauthlib",
  "tidal-dl-ng": "tidal_dl_ng",
}
mods = [
  "eyed3","yq","mutagen","beautifulsoup4","jellyfish","pyacoustid","requests",
  "yt_dlp","pyxDamerauLevenshtein","colorama","pylast","r128gain",
  "cryptography","requests_oauthlib","plexapi"
]
missing = []
for pkg in mods:
    mod = name_map.get(pkg, pkg.replace("-","_").replace(".","_"))
    try:
        __import__(mod)
    except Exception:
        missing.append(pkg)
print(" ".join(missing))
PY
}

# Early-skip logic
if [[ -f $SETUP_VERSION_FILE ]]; then
	# shellcheck disable=SC1090
	source "${SETUP_VERSION_FILE}"
	if [[ $CURRENT_VERSION == "${setupversion-}" ]]; then
		m_cmds="$(list_missing_cmds)"
		m_py="$(list_missing_py)"
		if [[ -z $m_cmds && -z $m_py && -x $VENV_PY ]]; then
			log_info "Dependencies already installed (version match)"
			log_info "Done."
			exit 0
		fi
	fi
fi

# --- Install missing dependencies (silent, log-only) ---
missing_cmds="$(list_missing_cmds)"
missing_py_mods="$(list_missing_py)"

if [[ -z $missing_cmds && -z $missing_py_mods && -x $VENV_PY ]]; then
	echo "setupversion=$CURRENT_VERSION" >"$SETUP_VERSION_FILE"
	exit 0
fi

log_info "Missing commands: ${missing_cmds:-none}"
log_info "Missing python modules: ${missing_py_mods:-none}"

# If nothing is missing, mark version and exit quickly to avoid re-downloading
if [[ -z $missing_cmds && -z $missing_py_mods && -x $VENV_PY ]]; then
	echo "setupversion=$CURRENT_VERSION" >"$SETUP_VERSION_FILE"
	printf '[Arrbit] Dependencies installation completed successfully.\n' | arrbitLogClean >>"$LOG_FILE"
	exit 0
fi

# System-level packages
run_step() {
	local desc="$1"; shift || true
	local -a cmd=("$@")
	log_info "$desc"
	if [[ "$log_level" == "info" ]]; then
		if ! "${cmd[@]}" >/dev/null 2>&1; then
			log_error "${desc} failed"
			exit 1
		fi
		return 0
	fi
	log_trace "Running: ${cmd[*]}"
	if ! "${cmd[@]}" 2>&1 | while IFS= read -r line; do [[ -z "$line" ]] && continue; log_trace "$line"; done; then
		log_error "${desc} failed"
		exit 1
	fi
}

run_step "apk add uv" apk add --no-cache uv
run_step "apk add build toolchain" apk add --no-cache build-base python3 python3-dev py3-pip py3-virtualenv musl-dev libffi-dev openssl-dev cargo rust cmake
run_step "apk add media & misc packages" apk add --no-cache tidyhtml musl-locales musl-locales-lang flac jq git ffmpeg imagemagick opus-tools opustags vorbis-tools parallel npm ripgrep lame aria2
run_step "apk add beets (edge community)" apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/community beets
run_step "apk add atomicparsley faac (edge testing)" apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley faac
run_step "apk add chromaprint" apk add --no-cache chromaprint

# Python system site-packages (respect PEP 668 with override)
run_step "pip bootstrap" python3 -m pip install -U --no-cache-dir --break-system-packages "Cython<3" setuptools wheel
run_step "pip install python libs" python3 -m pip install -U --no-cache-dir --break-system-packages eyed3 yq mutagen beautifulsoup4 jellyfish requests yt-dlp pyxDamerauLevenshtein colorama pylast r128gain cryptography requests-oauthlib plexapi pyacoustid

# Create isolated venv for tidal-dl-ng + python-ffmpeg to avoid ffmpeg-python conflict
if [[ ! -x $VENV_PY ]]; then
	run_step "create venv" python3 -m venv "$ARRBIT_VENV"
fi
if [[ -x $VENV_PIP ]]; then
	run_step "install tidal-dl-ng & python-ffmpeg" "$VENV_PIP" install -U --no-cache-dir tidal-dl-ng python-ffmpeg || true
	# Wrappers (fixed path model)
	cat >/usr/local/bin/tidal-dl-ng <<'SH'
#!/bin/sh
exec "/app/arrbit/environments/lidarr-music-tools/bin/tdn" "$@"
SH
	chmod +x /usr/local/bin/tidal-dl-ng
	cat >/usr/local/bin/tdn <<'SH'
#!/bin/sh
exec "/app/arrbit/environments/lidarr-music-tools/bin/tdn" "$@"
SH
	chmod +x /usr/local/bin/tdn
	hash -r 2>/dev/null || true
fi

# Verify ffmpeg wrapper in venv (not system)
ffmpeg_py_missing=""
if [[ -x $VENV_PY ]]; then
	"$VENV_PY" - <<'PY' 2>&1 | while IFS= read -r line; do [[ -z "$line" ]] && continue; log_trace "$line"; done
try:
    from ffmpeg import FFmpeg
	print("[Arrbit] venv python-ffmpeg wrapper OK")
except Exception as e:
	print("[Arrbit] venv python-ffmpeg wrapper FAIL:", e)
    raise
PY
	if [[ $? -ne 0 ]]; then ffmpeg_py_missing="venv python-ffmpeg"; fi
else
	ffmpeg_py_missing="venv missing"
fi

# --- Post-install verification ---
missing_after_cmds="$(list_missing_cmds)"
missing_after_py="$(list_missing_py)"
if [[ -n $ffmpeg_py_missing ]]; then
	missing_after_py="$missing_after_py $ffmpeg_py_missing"
fi

if [[ -n $missing_after_cmds || -n $missing_after_py ]]; then
	log_error "Failed to install required dependencies: cmds:(${missing_after_cmds:-none}) py:(${missing_after_py:-none})"
	exit 1
fi

echo "setupversion=$CURRENT_VERSION" >"$SETUP_VERSION_FILE"
log_info "Installation successful"
log_info "Done."
exit 0

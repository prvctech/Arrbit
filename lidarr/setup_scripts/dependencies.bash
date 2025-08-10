#!/usr/bin/env bash
# -------------------------------------------------------------------------------------------------------------
# Arrbit - dependencies.bash
# Version: v1.0.10-gs2.8.2
# Purpose: Silent dependency installer for Arrbit (Golden Standard v2.8.2 compliant)
# -------------------------------------------------------------------------------------------------------------

source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
arrbitPurgeOldLogs

SCRIPT_NAME="dependencies"
SCRIPT_VERSION="v1.0.10-gs2.8.2"
LOG_FILE="/config/logs/arrbit-${SCRIPT_NAME}-$(date +%Y_%m_%d-%H_%M).log"

mkdir -p /config/logs && touch "$LOG_FILE" && chmod 777 "$LOG_FILE"

# --- Setup version tracking (prevent re-installation) ---
SETUP_VERSION_FILE="/config/setup_version.txt"
CURRENT_VERSION="1.0.9"

# --- What we consider required (tools + python modules) ---
REQUIRED_CMDS="beet atomicparsley python3 uv eyed3 yq xq jq ffmpeg \
vorbiscomment metaflac opustags aria2c rg convert tidy lame"
REQUIRED_PY_MODS=(
  eyed3 yq mutagen beautifulsoup4 jellyfish pyacoustid requests
  yt_dlp pyxDamerauLevenshtein colorama pylast r128gain tidal-dl-ng
  cryptography requests_oauthlib plexapi
)

# Helper: list missing commands
list_missing_cmds() {
  local missing=""
  for cmd in $REQUIRED_CMDS; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=" $cmd"
    fi
  done
  echo "$missing"
}

# Helper: list missing python modules (prints space-separated)
list_missing_py() {
  python3 - <<'PY'
name_map = {
  "beautifulsoup4": "bs4",
  "pyacoustid": "acoustid",
  "yt_dlp": "yt_dlp",
  "pyxDamerauLevenshtein": "pyxDamerauLevenshtein",
  "requests_oauthlib": "requests_oauthlib",
  "tidal-dl-ng": "tidal_dl_ng",
}
mods = [
  "eyed3","yq","mutagen","beautifulsoup4","jellyfish","pyacoustid","requests",
  "yt_dlp","pyxDamerauLevenshtein","colorama","pylast","r128gain","tidal-dl-ng",
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

# Early-skip logic: only skip if current version AND nothing missing
if [[ -f "$SETUP_VERSION_FILE" ]]; then
  source "$SETUP_VERSION_FILE"
  if [[ "$CURRENT_VERSION" == "${setupversion:-}" ]]; then
    m_cmds="$(list_missing_cmds)"
    m_py="$(list_missing_py)"
    if [[ -z "$m_cmds" && -z "$m_py" ]]; then
      printf '[Arrbit] Dependencies already installed. Skipping.\n' | arrbitLogClean >> "$LOG_FILE"
      exit 0
    fi
  fi
fi

# --- Install missing dependencies (silent operation, all output to log) ---
missing_cmds="$(list_missing_cmds)"
missing_py_mods="$(list_missing_py)"

if [[ -z "$missing_cmds" && -z "$missing_py_mods" ]]; then
  echo "setupversion=$CURRENT_VERSION" > "$SETUP_VERSION_FILE"
  exit 0
fi

printf '[Arrbit] Installing missing commands: %s\n' "${missing_cmds:-none}" | arrbitLogClean >> "$LOG_FILE"
printf '[Arrbit] Installing missing python modules: %s\n' "${missing_py_mods:-none}" | arrbitLogClean >> "$LOG_FILE"

# Install uv package manager first
apk add --no-cache uv >>"$LOG_FILE" 2>&1

# Base toolchain and headers for building Python wheels
apk add --no-cache \
  build-base \
  python3 python3-dev py3-pip \
  musl-dev libffi-dev openssl-dev \
  cargo rust \
  cmake >>"$LOG_FILE" 2>&1 || true

# Install core packages on Alpine (binary tools)
apk add --no-cache \
  tidyhtml \
  musl-locales musl-locales-lang \
  flac jq git \
  ffmpeg \
  imagemagick \
  opus-tools opustags vorbis-tools \
  parallel npm ripgrep \
  lame \
  aria2 >>"$LOG_FILE" 2>&1

# Some packages may be in edge repositories
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/community beets >>"$LOG_FILE" 2>&1
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley faac >>"$LOG_FILE" 2>&1 || true

# Optional: chromaprint provides fpcalc (used by acoustid workflows)
apk add --no-cache chromaprint >>"$LOG_FILE" 2>&1 || true

# Ensure Cython < 3 for pyxDamerauLevenshtein compatibility, then install modules (system override per PEP 668)
python3 -m pip install -U --no-cache-dir --break-system-packages \
  "Cython<3" setuptools wheel >>"$LOG_FILE" 2>&1
python3 -m pip install -U --no-cache-dir --break-system-packages \
  eyed3 yq mutagen beautifulsoup4 jellyfish requests \
  yt-dlp pyxDamerauLevenshtein colorama \
  pylast r128gain tidal-dl-ng \
  cryptography requests-oauthlib \
  plexapi pyacoustid >>"$LOG_FILE" 2>&1

# Fix ffmpeg Python wrapper conflict: remove incorrect wrappers and install the correct one (>=2 exports FFmpeg)
python3 -m pip uninstall -y ffmpeg ffmpeg-python >>"$LOG_FILE" 2>&1 || true
python3 -m pip install -U --no-cache-dir --break-system-packages "ffmpeg>=2,<3" >>"$LOG_FILE" 2>&1 || true

# Verify python ffmpeg wrapper exports FFmpeg
ffmpeg_py_missing=""
python3 - <<'PY' >>"$LOG_FILE" 2>&1
try:
    from ffmpeg import FFmpeg  # noqa
    print("[Arrbit] python-ffmpeg wrapper OK")
except Exception as e:
    print("[Arrbit] python-ffmpeg wrapper FAIL:", e)
    raise
PY
if [[ $? -ne 0 ]]; then
  ffmpeg_py_missing="python ffmpeg wrapper (>=2)"
fi

# Fallback: force-build pyxDamerauLevenshtein from source if still missing
python3 - <<'PY' >/dev/null 2>&1
import importlib, sys
try:
    importlib.import_module('pyxDamerauLevenshtein')
except Exception:
    sys.exit(1)
PY
if [[ $? -ne 0 ]]; then
  python3 -m pip install --no-cache-dir --break-system-packages --no-binary :all: pyxDamerauLevenshtein >>"$LOG_FILE" 2>&1 || true
fi

# --- Post-install verification ---
missing_after_cmds="$(list_missing_cmds)"
missing_after_py="$(list_missing_py)"

# Append ffmpeg python wrapper issue to missing list if detected
if [[ -n "$ffmpeg_py_missing" ]]; then
  missing_after_py="$missing_after_py $ffmpeg_py_missing"
fi

if [[ -n "$missing_after_cmds" || -n "$missing_after_py" ]]; then
  # Error case - only output on failure (setup script rule)
  log_error "Failed to install required dependencies: cmds:(${missing_after_cmds:-none}) py:(${missing_after_py:-none}) (see log at /config/logs)"
  cat <<EOF | arrbitLogClean >> "$LOG_FILE"
[Arrbit] ERROR Failed to install required dependencies
[WHY]: One or more packages failed to install or are not available in repositories/PyPI
[FIX]: See details below, verify repository availability, or manually install missing items
[Missing Commands] ${missing_after_cmds:-none}
[Missing Python Modules] ${missing_after_py:-none}
[Installation Log]
$(cat "$LOG_FILE")
[/Installation Log]
EOF
  exit 1
fi

# --- Update setup version and success exit ---
echo "setupversion=$CURRENT_VERSION" > "$SETUP_VERSION_FILE"

# Success - silent exit (setup script rule)
printf '[Arrbit] Dependencies installation completed successfully.\n' | arrbitLogClean >> "$LOG_FILE"
exit 0

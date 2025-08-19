#!/usr/bin/env bash
set -euo pipefail
BASE="/tmp/arrbit_log_test_$$"
mkdir -p "$BASE/config" "$BASE/data/logs"
export ARRBIT_BASE="$BASE" # though logging_utils hardcodes /app/arrbit, we use alt config path fallback
cp ../logging_utils.bash "$BASE/logging_utils.bash" 2>/dev/null || true
CONFIG_MAIN="/config/arrbit/config"
mkdir -p /config/arrbit/config 2>/dev/null || true

run_case(){
  local level="$1" file="/config/arrbit/config/arrbit-config.conf"
  echo "LOG_LEVEL=$level" > "$file"
  unset ARRBIT_LOG_LEVEL ARRBIT_LOG_LEVEL_OVERRIDE
  source /mnt/user/coding/Arrbit/universal/helpers/logging_utils.bash
  LOG_FILE="/config/arrbit/data/logs/arrbit-test-${log_level}-$(date +%H_%M_%S).log"
  mkdir -p /config/arrbit/data/logs
  arrbitInitLog "$LOG_FILE"
  log_trace "trace message $level"
  log_info "info message $level"
  log_warning "warn message $level"
  log_error "error message $level"
  echo "$level => $(basename "$LOG_FILE")"
  grep -q "trace message" "$LOG_FILE" && echo "TRACE_PRESENT" || echo "TRACE_ABSENT"
}

run_case trace
run_case verbose
run_case info

echo "Override test"
export ARRBIT_LOG_LEVEL_OVERRIDE=INFO
source /mnt/user/coding/Arrbit/universal/helpers/logging_utils.bash
if [ "$ARRBIT_LOG_LEVEL" = INFO ]; then echo "override_ok"; else echo "override_fail"; fi

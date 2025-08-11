# Copilot Instructions for Arrbit

## Project Overview
Arrbit is a modular automation toolkit for configuring and managing *Arr* applications (Lidarr, Radarr, Sonarr) via Bash scripts. It enforces strict conventions for script structure, logging, API access, and configuration management to ensure reproducibility and maintainability.

## Architecture & Data Flow
- **Modules:** Each module (e.g., `custom_formats.bash`, `quality_profiles.bash`) is a Bash script under `lidarr/process_scripts/modules/` and sources its JSON payload from `modules/data/`.
- **Mother Scripts:** Scripts like `autoconfig.bash` orchestrate module execution, emitting only four terminal messages (banner, start, finish, done).
- **Helpers:** All scripts source `helpers.bash` and `logging_utils.bash` for utility functions and standardized logging.
- **API Integration:** All API calls are routed through `arr_bridge.bash` using the `arr_api` wrapper. Never use raw curl/wget.
- **Logs:** Each script writes to its own log file in `/config/logs/` with a strict naming and formatting convention.

## Critical Workflows
- **Script Execution:** Always start scripts with the required `source` lines and run `arrbitPurgeOldLogs` first.
- **Payload Management:** JSON payloads for modules must never be hardcoded; always read from `modules/data/payload-<module>.json`.
- **Logging:** Use only `log_info`, `log_warning`, `log_error` for output. Color and format are controlled by `logging_utils.bash`.
- **Error Handling:** Terminal errors are minimal; detailed diagnostics (`[WHY]`, `[FIX]`, `[API Response]`) go to the log file only.
- **Versioning:** Scripts must define `SCRIPT_NAME` and `SCRIPT_VERSION` (with `-gs<golden standard version>` suffix). Update version on any change.

## Project-Specific Conventions
- **No ANSI codes:** Only use color constants from `logging_utils.bash`.
- **No file overwrites:** Never overwrite files in `/config/arrbit/*` unless writing config.
- **No flag logic:** Modules are flagless except for `autoconfig.bash`.
- **No debug/dev output:** Only specified messages are allowed.
- **Consistent output:** All output/log lines must look identical across modules.
- **Strict compliance:** Always refactor for full Golden Standard compliance.

## Key Files & Directories
- `lidarr/process_scripts/modules/` — Main module scripts
- `lidarr/process_scripts/modules/data/` — JSON payloads for modules
- `universal/helpers/helpers.bash` — Utility functions
- `universal/helpers/logging_utils.bash` — Logging/color constants
- `universal/connectors/arr_bridge.bash` — API integration
- `.cursor/rules/.cursorrules` — Full Golden Standard ruleset (must read for all script changes)
- `README.md` — Project intro

## Example Patterns
```bash
# Script preamble (required)
source /config/arrbit/helpers/logging_utils.bash
source /config/arrbit/helpers/helpers.bash
arrbitPurgeOldLogs

# Logging
log_info "[Arrbit] Importing predefined settings..."
log_error "[Arrbit] ERROR Failed to import format: Acousticness (see log at /config/logs)"
```

> always check for more golden_standard details in `.github/golden_standard.md`

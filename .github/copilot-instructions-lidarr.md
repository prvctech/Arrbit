# Copilot Instructions for Lidarr (Arrbit)

These instructions are for AI agents and contributors working on Arrbit's Lidarr modules.

## Base Standard

- All code must comply with the Golden Standard in `.github/golden_standard.md` (read and follow for all script changes).

## Lidarr-Specific Guidance

- Reference the Lidarr v1 API spec at `.github/reference/lidarr-v1-api.json` for endpoint details and integration logic.
- Use only the modules, helpers, and logging conventions described in the Golden Standard, but apply them to Lidarr-specific workflows and payloads.
- All module scripts and payloads for Lidarr are under `lidarr/process_scripts/modules/` and `lidarr/process_scripts/modules/data/`.
- API calls must use the `arr_api` wrapper via `arr_bridge.bash` (never raw curl/wget).
- For examples and patterns, see the main Copilot instructions or the Golden Standard.

## Key Files

- `lidarr/process_scripts/modules/` — Lidarr module scripts
- `lidarr/process_scripts/modules/data/` — JSON payloads for Lidarr modules
- `.github/reference/lidarr-v1-api.json` — Lidarr API reference

> For general rules, always check `.github/golden_standard.md`.

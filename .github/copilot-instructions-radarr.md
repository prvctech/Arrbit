# Copilot Instructions for Radarr (Arrbit)

These instructions are for AI agents and contributors working on Arrbit's Radarr modules.

## Base Standard

- All code must comply with the Golden Standard in `.github/golden_standard.md` (read and follow for all script changes).

## Radarr-Specific Guidance

- Reference the Radarr v3 API spec at `.github/reference/radarr-v3-api.json` for endpoint details and integration logic.
- Use only the modules, helpers, and logging conventions described in the Golden Standard, but apply them to Radarr-specific workflows and payloads.
- All module scripts and payloads for Radarr should be under `radarr/process_scripts/modules/` and `radarr/process_scripts/modules/data/` (if present).
- API calls must use the `arr_api` wrapper via `arr_bridge.bash` (never raw curl/wget).

## Key Files

- `radarr/process_scripts/modules/` — Radarr module scripts
- `radarr/process_scripts/modules/data/` — JSON payloads for Radarr modules
- `.github/reference/radarr-v3-api.json` — Radarr API reference

> For general rules, always check `.github/golden_standard.md`.

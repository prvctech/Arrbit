# Copilot Instructions for Sonarr (Arrbit)

These instructions are for AI agents and contributors working on Arrbit's Sonarr modules.

## Base Standard

- All code must comply with the Golden Standard in `.github/golden_standard.md` (read and follow for all script changes).

## Sonarr-Specific Guidance

- Reference the Sonarr v3 API spec at `.github/reference/sonarr-v3-api.json` for endpoint details and integration logic.
- Use only the modules, helpers, and logging conventions described in the Golden Standard, but apply them to Sonarr-specific workflows and payloads.
- All module scripts and payloads for Sonarr should be under `sonarr/process_scripts/modules/` and `sonarr/process_scripts/modules/data/` (if present).
- API calls must use the `arr_api` wrapper via `arr_bridge.bash` (never raw curl/wget).

## Key Files

- `sonarr/process_scripts/modules/` — Sonarr module scripts
- `sonarr/process_scripts/modules/data/` — JSON payloads for Sonarr modules
- `.github/reference/sonarr-v3-api.json` — Sonarr API reference

> For general rules, always check `.github/golden_standard.md`.

# Copilot Instructions for Bazarr (Arrbit)

These instructions are for AI agents and contributors working on Arrbit's Bazarr modules.

## Base Standard

- All code must comply with the Golden Standard in `.github/golden_standard.md` (read and follow for all script changes).

## Bazarr-Specific Guidance

- Reference any Bazarr API or integration docs as needed (add to `.github/reference/` if available).
- Use only the modules, helpers, and logging conventions described in the Golden Standard, but apply them to Bazarr-specific workflows and payloads.
- All module scripts and payloads for Bazarr should be under `bazarr/process_scripts/modules/` and `bazarr/process_scripts/modules/data/` (if present).
- API calls must use the `arr_api` wrapper via `arr_bridge.bash` (never raw curl/wget).

## Key Files

- `bazarr/process_scripts/modules/` — Bazarr module scripts
- `bazarr/process_scripts/modules/data/` — JSON payloads for Bazarr modules

> For general rules, always check `.github/golden_standard.md`.

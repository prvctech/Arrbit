# Copilot Instructions for Tdarr (Arrbit)

These instructions are for AI agents and contributors working on Arrbit's Tdarr modules.

## Base Standard

- All code must comply with the Golden Standard in `.github/golden_standard.md` (read and follow for all script changes).

## Tdarr-Specific Guidance

- Reference any Tdarr API or integration docs as needed (add to `.github/reference/` if available).
- Use only the modules, helpers, and logging conventions described in the Golden Standard, but apply them to Tdarr-specific workflows and payloads.
- All module scripts and payloads for Tdarr should be under `tdarr/process_scripts/modules/` and `tdarr/process_scripts/modules/data/` (if present).
- API calls must use the `arr_api` wrapper via `arr_bridge.bash` (never raw curl/wget).

## Key Files

- `tdarr/process_scripts/modules/` — Tdarr module scripts
- `tdarr/process_scripts/modules/data/` — JSON payloads for Tdarr modules

> For general rules, always check `.github/golden_standard.md`.

ARRBIT - GOLDEN STANDARD V2.8.2

# Script Structure & Boilerplate
- All scripts MUST start with:
    source /config/arrbit/helpers/logging_utils.bash
    source /config/arrbit/helpers/helpers.bash
    arrbitPurgeOldLogs   # always run as the first command (default: purge >2 days old)
- Every script must define:
    SCRIPT_NAME, SCRIPT_VERSION (must include -gs<golden standard version number> suffix), LOG_FILE, create log dir/file with chmod 777
    Always update the script version with any changes made. Exmaple v1.2.x where the x mark small changes in the code like editing a small block of code v1.x.0 where the x mark a big change logic changed, or enchanment in code. 
    If golden standard gets updated then the version gets reset to v1.0.0-gs(new version number)
    
- Never hardcode ANSI color codes; only use color constants from logging_utils.bash
- All module logic must be flagless (no enable/disable logic except autoconfig.bash)
- Never overwrite any file in /config/arrbit/* unless the script is for config writing
- Setup.bash has the folder structure.
- Each Module script will source its json data from /config/arrbit/modules/data
  No module should have its json paylod hardcoded into its code. 
  the json payload are named as payload-(module_name).json so it is easier for each module to identify and already exist in /config/arrbit/modules/data

# Code Style
- Global/constants:    UPPER_SNAKE_CASE
- Locals/functions:    lower_snake_case
- No camelCase (unless legacy)
- Always comment one line above all logic blocks
- Always redact secrets in logs
- Never log/echo full URLs with sensitive data/tokens

# Logging & Output (Terminal & Log Files)
- Use only log_info, log_warning, log_error for all output, except banner. (logic present in logging_utils).
- [Arrbit] tag: CYAN in terminal (from logging_utils.bash), plain in logs
- ERROR: RED, WARNING: YELLOW, BANNER: GREEN (with MAGENTA for plugins, if present)
- All colors from logging_utils.bash (neon/bright, 256-color)
- Only first line (banner) via echo -e; GREEN for script/module name, MAGENTA for plugin (if present)
  example echo -e "${CYAN}[Arrbit]${NC} ${GREEN}Starting ${SCRIPT_NAME} service${NC} ${SCRIPT_VERSION} ..."
- Scripts MUST set LOG_FILE before logging
- All logs: /config/logs/arrbit-[module]-YYYY_MM_DD-HH_MM.log
- arrbitLogClean must always sanitize all log output
- Terminal: [Arrbit] <message> (colorized)
- Log file: [Arrbit] <message> (plain)
- No emojis unless explicitly allowed
- Messages used in termnal for modules scripts: 
  for when the script finishes runins [Arrbit] The module was configured successfully. [Arrbit] Done.
  for when it is importing json data [Arrbit] Importing predefined settings... If the payload already exist then [Arrbit] Predefined settings already present. Skipping...
  for when the module has more than 1 single value in the json payload (example custom_formats.bash module) then it will list each single data example [Arrbit] Importing custom format: ${format_name}" [Importing custom format: ${format_name}"]  


# API Calls
- Always source arr_bridge.bash after logging_utils.bash and helpers.bash
- Only use arr_api wrapper for API access (never raw curl/wget except legacy)
- Never hardcode API URLs/versions/keys; always use exported values from arr_bridge.bash
- Always use real API key in calls, only redact in logs/output
- arr_bridge.bash is responsible for all API extraction, validation, exports, arr_api, etc.

# Helpers & Log Management
- arrbitPurgeOldLogs always runs first
- arrbitLogClean must sanitize all log output
- All helpers (getFlag, joinBy, etc.) from helpers.bash used as intended

# Final Consistency
- Color tags only defined/sourced from logging_utils.bash
- Remove duplicates for [Arrbit] color (centralized in logging_utils.bash)
- All output/log lines look identical in every module
- Always rewrite any code that isn't a 100% match for this ruleset

# Strict Compliance
- Always rewrite/refactor scripts for FULL Golden Standard compliance—never partial
- All scripts are responsible for their own logging/output/compliance
- The Golden Standard is enforced at every commit, review, and generation

# Logging Error Diagnostics (NEW)
- All output to terminal must remain minimal and human-friendly.
- On error, the terminal message must always include:
    [Arrbit] ERROR <main error message> (see log at /config/logs)
  Example: [Arrbit] ERROR Failed to import format: Acousticness (see log at /config/logs)
- Never show deep error detail, stacktrace, or payload in the terminal.
- For every ERROR in the log file, ALWAYS add: (In a multiline style, never a single line)
    [WHY]: The detected or likely cause (if available)
    [FIX]: What the user can do (if fixable/known), or always include “see log at /config/logs” if more detail is present in the log.
  Example in log:
    [Arrbit] ERROR Failed to import format: Acousticness
    [WHY]: API responded with HTTP 400 - Bad request (invalid payload)
    [FIX]: Check your payload JSON structure, or see the [API Response] section below
    [API Response] ... [/API Response]
- Only the primary error message appears in the terminal; full /WHY/FIX context is log file only.
- log_info, log_warning, and log_error write plain [Arrbit] (no color) to the log file; only the terminal sees color.
- always import the payload response into the .logs

# Other Notes
- No output except what is specified above (no debug, internal, or dev lines).
- All “Reading ... from ...” lines, metadata/provider/payload dump notifications, and success messages are removed from terminal output; errors and skip/important status only.
- Success is indicated by [Arrbit] Done. as the final message for modules, unless fatal error (then script exits on error).
- The scripts runs in hierchay, meaning one mother scripts runs other smaller scripts. Mother scripts such as autoconfig.bash will only execute its modules (smaller scripts) it will only have 4 messages 1- [Arrbit] (The banner title) ,(ususes logging_utils for the messages) 2- [Arrbit] Starting modules... 3. [Arrbit]Finished running all modules 4. [Arrbit] Done
- The setup and run scripts are silent no messages unless error.
- arr_bridge logs to itself, if any other module or scripts calls for it will not write its log to arr-bridge.log. Each script will write to its own log in verbose. 


# Lidarr API (and All Arr APIs)
- All /api/v1/ endpoints (album, artist, command, etc.) supported.
- Only arr_bridge.bash handles API keys, URL, and arr_api logic.
- All ARR API code uses arr_api and extracts credentials from arr_bridge.bash.
- Any script referencing ARR API must follow all new API/color/logging rules

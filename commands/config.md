---
description: Open plugin config files for editing
allowed-tools: Bash, AskUserQuestion
---

Plugin root: `${CLAUDE_PLUGIN_ROOT}`

Files (at `<cache-dir>` = `dirname "${CLAUDE_PLUGIN_ROOT}"`):
- `config.json` — quote API (`{ "active": "zenquotes", "apis": { "<name>": { "url", "parse", "field?" } } }`)
- `.env` — usage providers + secrets

References (at plugin root, read-only):
- `presets.json` — built-in APIs: `zenquotes`, `jinrishici`
- `.env.example` — `.env` format reference
- `weather.json` — weather config: env var name declarations for `hostEnv`, `locationEnv`, `keyEnv`

## Flow

1. Run `CACHE_DIR=$(dirname "${CLAUDE_PLUGIN_ROOT}") && echo "$CACHE_DIR"` via Bash. Print the result.
2. Use `test -f` via Bash to check if `$CACHE_DIR/config.json` exists. If not, copy `${CLAUDE_PLUGIN_ROOT}/presets.json` → `$CACHE_DIR/config.json`.
3. Use `test -f` via Bash to check if `$CACHE_DIR/.env` exists. If not, copy `${CLAUDE_PLUGIN_ROOT}/.env.example` → `$CACHE_DIR/.env`.
4. Print a summary of copy actions taken.
5. Ask the user which file to configure: **Usages/Weather** (`.env`) or **Quote API** (`config.json`).
6. Detect editor: check `zed` first, then `code`. Open the selected file from `$CACHE_DIR`. If neither is available, print the absolute path and tell the user to edit manually.

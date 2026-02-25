---
description: Open plugin config files for editing
allowed-tools: Bash, Read, Write, AskUserQuestion
---

Plugin root: `${CLAUDE_PLUGIN_ROOT}`

Files:
- `config.json` — quote API (`{ "active": "zenquotes", "apis": { "<name>": { "url", "parse", "field?" } } }`)
- `.env` — usage providers + secrets (gitignored)
- `presets.json` — built-in APIs reference (read-only): `zenquotes`, `jinrishici`
- `.env.example` — `.env` format reference
- `weather.json` — weather config: env var name declarations for `hostEnv`, `locationEnv`, `keyEnv`

## Flow

1. Print the absolute path of `${CLAUDE_PLUGIN_ROOT}`.
2. If `config.json` does not exist, copy `presets.json` to `config.json`.
3. If `.env` does not exist:
   a. Check if `${CLAUDE_PLUGIN_ROOT}` contains the segment `claude-tools/claude-tools/<version>/` (or `claude-tools\claude-tools\<version>\` on Windows).
   b. If matched, enumerate sibling version directories under the same `claude-tools/claude-tools/` parent; find the most-recent prior version that has both `.env` and `.env.example`, and compare that `.env.example` with the current one.
   c. If identical, copy the prior version's `.env` to the current plugin root.
   d. Otherwise, copy the current `.env.example` to `.env`.
4. Ask the user which file to configure: **Usages/Weather** (`.env`) or **Quote API** (`config.json`).
5. Detect editor: check `zed` first, then `code`. Open the selected file. If neither is available, print the absolute path of the file and tell the user to edit it manually.

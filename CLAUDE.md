# claude-tools

Statusline, toast notifications, and agent skills for Claude Code.

## Structure

```
assets/          Icons (favicon.ico, help.png, success.png)
commands/        Slash commands (*.md with frontmatter)
skills/          Agent skills (SKILL.md per skill directory)
hooks/           Static hooks config (committed) — auto-loaded by Claude Code
scripts/
  hooks.ts       Hook entry point (bun) — dispatches to win/ or linux/
  statusline.ts  StatusLine entry point (bun) — reads installed_plugins.json, dispatches to win/ or linux/
  win/           Windows PowerShell scripts
  linux/         Linux shell scripts
presets.json     Built-in quote API definitions (read-only)
usages.json      Usage provider config: env var name declarations (committed)
weather.json     Weather config: env var name declarations (committed)
```

## Setup

Run `/claude-tools:setup` to enable. Writes a version-agnostic wrapper to `<plugin-cache-dir>/statusline.ts` and `statusLine` into `~/.claude/settings.json`, then creates the Start Menu shortcut. All steps are idempotent — setup only needs to run once.

## Hooks

Defined statically in `hooks/hooks.json` (committed). `scripts/hooks.ts` is the entry point (bun) — detects platform (`win32` → pwsh, else → bash) and dispatches:
- `PermissionRequest` → `hooks.ts permission` → `win/permission.ps1` / `linux/permission.sh`
- `Stop` → `hooks.ts stop` → `win/stop.ps1` / `linux/stop.sh`

## Quote API

- Both `presets.json` and `config.json` share the same format: `{ "active": "<name>", "apis": { "<name>": { "url", "parse", "field?" } } }`
- `stop.ps1`/`stop.sh`: use `config.json` (at `<plugin-cache-dir>/`) if present, else fall back to `presets.json` (at plugin root)
- `/claude-tools:config` copies `presets.json` → `<plugin-cache-dir>/config.json` on first run

## Config Command

Run `/claude-tools:config` to edit plugin config files. `config.json` and `.env` live at `<plugin-cache-dir>/` (version-agnostic) — never need migration on update. Opens files with `zed` → `code` → shows paths as fallback.

## Usage Providers

- Provider config in `usages.json`: declares env var names per provider (committed)
- Secrets in `.env` (at `<plugin-cache-dir>/`): `ENABLED_PROVIDER`, session cookies — never commit
- A provider is active when its name appears in `ENABLED_PROVIDER` (comma-separated)
- Config format: `{ "<provider>": { "sessionIdEnv": "VAR_NAME", "sessionSigEnv": "VAR_NAME" } }`
- When debugging usage logic, do not print resolved values of cookie env vars

## Weather

- Config in `weather.json`: declares env var names for `hostEnv`, `locationEnv`, `keyEnv` (committed)
- Secrets in `.env` (at `<plugin-cache-dir>/`): `QWEATHER_ENABLED=true`, `QWEATHER_HOST`, `QWEATHER_LOCATION`, `QWEATHER_KEY`
- Displays: `☁ 15° 多云 13~22°` — real-time temp+condition from `/v7/weather/now` + today's high/low from `/v7/weather/3d`
- Cache: 10 minutes at `$TEMP\claude_weather_cache.txt` (win) / `/tmp/claude_weather_cache.txt` (linux)
- Auth: `X-QW-Api-Key` header; API host is per-account (from QWeather console)

## Versioning

Version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` must stay in sync. Bump both when releasing.

## Scripts

- `hooks.ts` — cross-platform dispatcher (bun); takes event name as argv[2], routes to win/ or linux/
- `statusline.ts` — reads `installed_plugins.json` for current install path, dispatches to win/ or linux/; copied by setup to `<plugin-cache-dir>/statusline.ts` (version-agnostic location)
- `win/setup.ps1` — create Start Menu shortcut with `AppUserModelID` for toast sender identity
- `win/permission.ps1` — switch on `tool_name` to build detail text
- `win/stop.ps1` — fetch quote from active API, fallback to "Done"
- `win/statusline.ps1` — rich status bar (model, git branch, context %, calls, cost, duration, datetime, weather)


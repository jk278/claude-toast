# claude-tools

Toast notifications, statusline, and agent skills for Claude Code.

- **Permission** — notifies when Claude requests tool permission (PermissionRequest)
- **Work Done** — notifies when Claude finishes a task (Stop), with a daily quote
- **Statusline** — rich status bar showing model, git branch, context usage, API calls, cost, duration, etc.
- **Codex** — invoke OpenAI Codex CLI (codex exec, codex resume) from Claude Code

## Requirements

- Windows 10+ with PowerShell 7 (`pwsh`) or Linux
- [Bun](https://bun.sh/) (hook entry point)
- Terminal using a [Nerd Font](https://www.nerdfonts.com/) for statusline icons (recommended: [JetBrains Maple Mono](https://github.com/SpaceTimee/Fusion-JetBrainsMapleMono))

## Install

```
/plugin marketplace add jk278/claude-tools
/plugin install claude-tools
```

## Setup

Run `/claude-tools:setup` to enable toast notifications and statusline. This writes statusLine config into `~/.claude/settings.json` and (Windows) creates a Start Menu shortcut with a custom `AppUserModelID` for toast sender identity.

## Config

Run `/claude-tools:config` to edit plugin config files (quote API, usage providers, weather).

## Update

```
/plugin marketplace update claude-tools
/plugin update claude-tools
```

Then restart Claude Code.

## Uninstall (Windows only)

Uninstalling the plugin does not remove the Start Menu shortcut. Setup may have installed the BurntToast module if it wasn't already present. Remove manually if needed:

```powershell
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Claude Code.lnk" -Force
Uninstall-Module BurntToast
```

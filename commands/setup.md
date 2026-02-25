---
description: Set up toast notifications and statusline for Claude Code
allowed-tools: Read, Write, Edit, Bash
---

Execute all steps immediately using tool calls — do not narrate or describe steps before executing them.

Detect platform first. Use `win` scripts on Windows, `linux` scripts on Linux/macOS.
Steps 1 & 2 have no dependencies — run them in parallel.

## Flow

### 1. Platform setup

**Windows:** (if `pwsh` is not found, stop and tell the user to install PowerShell 7)
```
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/win/setup.ps1"
```

**Linux:**
```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/linux/setup.sh"
```

### 2. Deploy statusLine

Run via Bash to get the cache dir and copy the wrapper:
```
CACHE_DIR=$(dirname "${CLAUDE_PLUGIN_ROOT}") && cp "${CLAUDE_PLUGIN_ROOT}/scripts/statusline.ts" "$CACHE_DIR/statusline.ts" && echo "$CACHE_DIR"
```

Read `~/.claude/settings.json` (create `{}` if missing). Set `statusLine.command` to `bun "<CACHE_DIR>/statusline.ts"` using the echoed path literally. Write back.

### 3. Report success.

### 4. Remind the user (Windows only)

To remove the Start Menu shortcut (uninstall cleanup), run:
```
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Claude Code.lnk" -Force
```

Setup installs the **BurntToast** PowerShell module if not already present (community, not Microsoft). To uninstall: `Uninstall-Module BurntToast`

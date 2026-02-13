---
description: Set up toast notifications and statusline for Claude Code
allowed-tools: Read, Write, Edit, Bash(powershell -NoProfile -ExecutionPolicy Bypass -File *), Bash(bash *)
---

Execute all steps immediately using tool calls — do not narrate or describe steps before executing them.

Detect platform first. Use `win` scripts on Windows, `linux` scripts on Linux/macOS.
Steps 1 & 2 have no dependencies — run them in parallel.

**Shell note:** The Bash tool runs through an outer shell that interprets `$`.
Use `\$env:USERPROFILE` when passing PowerShell `$env:` variables via Bash tool.

## Flow

### 1. Platform setup

**Windows:**
```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/win/setup.ps1"
```

**Linux:**
```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/linux/setup.sh"
```

### 2. Read `~/.claude/settings.json` (create `{}` if missing). Preserve all existing settings.

### 3. Merge `statusLine` into `~/.claude/settings.json` (skip if already present, no agents):

**Windows:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PLUGIN_ROOT}/scripts/win/statusline.ps1\""
  }
}
```

**Linux:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/linux/statusline.sh\""
  }
}
```

### 4. Write hooks to `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`:

**Windows:**
```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PLUGIN_ROOT}/scripts/win/permission.ps1\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PLUGIN_ROOT}/scripts/win/stop.ps1\""
          }
        ]
      }
    ]
  }
}
```

**Linux:**
```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/linux/permission.sh\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/linux/stop.sh\""
          }
        ]
      }
    ]
  }
}
```

### 5. Write back. Report success.

### 6. Remind the user

To remove the Start Menu shortcut (uninstall cleanup), run:
```
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Claude Code.lnk" -Force
```

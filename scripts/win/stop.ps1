# Stop hook toast notification with quote
$AppId = 'Claude Code'
$AssetsDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..\assets')).Path
$SuccessIconPath = Join-Path $AssetsDir 'success.png'

$json = $input | ConvertFrom-Json

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data, ContentType=WindowsRuntime] | Out-Null

$configPath  = Join-Path $PSScriptRoot '..\..\config.json'
$presetsPath = Join-Path $PSScriptRoot '..\..\presets.json'
$detail = 'Done'
try {
    $file = if (Test-Path $configPath) { $configPath } else { $presetsPath }
    $cfg  = Get-Content $file -Raw | ConvertFrom-Json
    $spec = $cfg.apis.($cfg.active)
    if ($spec.parse -eq 'text') {
        $detail = (Invoke-WebRequest -Uri $spec.url -TimeoutSec 3 -UseBasicParsing).Content.Trim()
    } else {
        $raw = Invoke-RestMethod -Uri $spec.url -TimeoutSec 3
        $detail = $raw
        foreach ($seg in ($spec.field -replace '^\.' -split '(?=\[)|\.')) {
            if ($seg -match '^\[(\d+)\]$') { $detail = $detail[$matches[1]] }
            elseif ($seg) { $detail = $detail.$seg }
        }
    }
} catch {}

$Xml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <image src="$SuccessIconPath" placement="appLogoOverride"/>
      <text>Work Done</text>
      <text hint-maxLines="3">$detail</text>
    </binding>
  </visual>
</toast>
"@

$XmlDoc = New-Object Windows.Data.Xml.Dom.XmlDocument
$XmlDoc.LoadXml($Xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($XmlDoc)

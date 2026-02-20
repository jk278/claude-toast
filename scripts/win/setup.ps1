# Install BurntToast module if not present
if (-not (Get-Module -ListAvailable BurntToast)) {
    Install-Module BurntToast -Scope CurrentUser -Force
}

# Create Start Menu shortcut with AppUserModelID for toast sender identity
$AppId = 'Claude Code'
$AssetsDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..\assets')).Path
$AppIconPath = Join-Path $AssetsDir 'favicon.ico'
$ShortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Claude Code.lnk"

$Wsh = New-Object -ComObject WScript.Shell
$Sc = $Wsh.CreateShortcut($ShortcutPath)
$Sc.TargetPath = 'powershell.exe'
$Sc.IconLocation = $AppIconPath
$Sc.Save()

$CsPath = Join-Path $PSScriptRoot 'AppIdHelper.cs'
Add-Type -Path $CsPath | Out-Null
[AppIdHelper]::SetAppId($ShortcutPath, $AppId) | Out-Null

Write-Host 'Start Menu shortcut created (or updated).'

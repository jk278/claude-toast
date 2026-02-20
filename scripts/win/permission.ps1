# Permission toast notification
$AssetsDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..\assets')).Path
$HelpIconPath = Join-Path $AssetsDir 'help.png'

$json = $input | ConvertFrom-Json
$toolName = $json.tool_name
$toolInput = $json.tool_input

# Build detail text based on tool type
$detail = switch ($toolName) {
    { $_ -in @('Read', 'Edit', 'Write') } {
        "$toolName`: $(Split-Path $toolInput.file_path -Leaf)"
    }
    { $_ -in @('Glob', 'Grep') } {
        "$toolName`: $($toolInput.pattern)"
    }
    { $_ -in @('Bash', 'Task') } {
        "$toolName`: $($toolInput.description)"
    }
    'AskUserQuestion' {
        "Ask: $($toolInput.questions[0].question)"
    }
    default { $toolName }
}

Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class AppId {
    [DllImport("shell32.dll")]
    public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string v);
}
'@
[AppId]::SetCurrentProcessExplicitAppUserModelID('Claude Code') | Out-Null

Import-Module BurntToast -ErrorAction Stop
New-BurntToastNotification -Text 'Permission', $detail -AppLogo $HelpIconPath

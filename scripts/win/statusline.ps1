# Statusline: model, directory, git branch, context %, cost, usage, weather
#
# EXECUTION: Runs ~300ms during token output only, NOT on terminal resize.

# ===== Icons & Constants =====
$ESC = [char]27
$showCost = $true

$iBolt     = [char]0xF0E7   # nf-fa-bolt
$iFolder   = [char]0xF07B   # nf-fa-folder
$iBranch   = [char]0xE0A0   # nf-pl-branch
$iZenmux   = [char]0xF080   # nf-fa-bar-chart
$iRefresh  = [char]0xF021   # nf-fa-refresh
$iUsd      = [char]0xF155   # nf-fa-usd
$iUp       = [char]0xF093   # nf-fa-upload
$iDown     = [char]0xF019   # nf-fa-download
$iCloud    = [char]0xF0C2   # nf-fa-cloud

$charFilled = ([char]0x2588).ToString()  # █
$charEmpty  = ([char]0x2591).ToString()  # ░

# ===== Helper Functions =====


function Format-Bar([double]$ratio, [int]$size, [string]$fillChar, [string]$emptyChar) {
  $filled = [math]::Round($ratio * $size)
  $fillChar * $filled + $emptyChar * ($size - $filled)
}

function Get-UsageColor([double]$rate) {
  $pct = $rate * 100
  if ($pct -ge 90) { return "$ESC[31m" }
  if ($pct -ge 70) { return "$ESC[33m" }
  return "$ESC[32m"
}

function Format-ResetTime([string]$endStr) {
  try {
    $dt = [datetime]::Parse($endStr).ToLocalTime()
    if ($dt.Date -eq [datetime]::Today) { return "$iRefresh $($dt.ToString('HH:mm'))" }
    return "$iRefresh $($dt.ToString('ddd HH:mm'))"
  } catch { return "" }
}

function Get-WeatherIcon([int]$code) {
  $u = [char]::ConvertFromUtf32
  if ($code -eq 100)                         { return $u.Invoke(0xF0599) } # sunny
  if ($code -eq 150)                         { return $u.Invoke(0xF0594) } # night
  if ($code -in 101,102,103)                 { return $u.Invoke(0xF0595) } # partly cloudy
  if ($code -in 151,152,153)                 { return $u.Invoke(0xF0F31) } # night partly cloudy
  if ($code -eq 104)                         { return $u.Invoke(0xF0590) } # cloudy
  if ($code -in 302,303,304)                 { return $u.Invoke(0xF067E) } # lightning rainy
  if ($code -in 313,404,405,406,407,456,457) { return $u.Invoke(0xF067F) } # snowy rainy
  if ($code -in 301,307,308,310,311,312,351) { return $u.Invoke(0xF0596) } # pouring
  if ($code -ge 300 -and $code -le 399)      { return $u.Invoke(0xF0597) } # rainy
  if ($code -ge 400 -and $code -le 499)      { return $u.Invoke(0xF0598) } # snowy
  if ($code -in 500,501,509,510,514,515)     { return $u.Invoke(0xF0591) } # fog
  if ($code -ge 500 -and $code -le 515)      { return $u.Invoke(0xF0F30) } # hazy
  if ($code -eq 900)                         { return $u.Invoke(0xF0F37) } # sunny alert
  return [char]0xF0C2                                                       # fallback
}

# ===== Parse Input =====
$inputJson = $input | Out-String | ConvertFrom-Json
$model     = $inputJson.model.display_name -replace '^[^/]+/', ''
$currentDir = Split-Path -Leaf $inputJson.workspace.current_dir
$currentSessionId = $inputJson.session_id.Substring(0, 8)

# ===== Git Branch =====
$gitBranch = ""
if (Test-Path .git) {
  try {
    $headContent = Get-Content .git/HEAD -ErrorAction Stop
    if ($headContent -match "ref: refs/heads/(.*)") {
      $branch = $matches[1]
      if ($branch.Length -gt 20) { $branch = $branch.Substring(0, 20) + [char]0x2026 }
      $gitBranch = " · $ESC[38;5;97m$iBranch $branch$ESC[0m"
    }
  } catch {}
}

# ===== Context Usage (cached to avoid 0% flicker) =====
$cacheFile = "$env:TEMP\claude_statusline_cache.txt"
$cachedData = if (Test-Path $cacheFile) { Get-Content $cacheFile } else { "" }
$cachedPercent, $cachedSessionId = $cachedData -split "\|"
if ($cachedSessionId -ne $currentSessionId) { $cachedPercent = "0" }

$displayPercent = $cachedPercent
$usage = $inputJson.context_window.current_usage
if ($usage -and $usage.PSObject.Properties.Count -gt 0) {
  $currentTokens = $usage.input_tokens + $usage.cache_creation_input_tokens + $usage.cache_read_input_tokens
  $contextSize = $inputJson.context_window.context_window_size
  if ($contextSize -gt 0 -and $currentTokens -gt 0) {
    $displayPercent = [math]::Round(($currentTokens * 100) / $contextSize, 0)
    "$displayPercent|$currentSessionId" | Out-File $cacheFile -Encoding UTF8
  }
}

# ===== Cost / Tokens =====
$inTokens  = $inputJson.context_window.total_input_tokens
$outTokens = $inputJson.context_window.total_output_tokens
$cost      = $inputJson.cost.total_cost_usd

if ($showCost) {
  $costStr = "$ESC[38;5;136m$iUsd " + [math]::Round($cost, 2) + "$ESC[0m"
}
else {
  $inFmt  = if ($inTokens  -ge 1MB) { [math]::Round($inTokens  / 1MB, 1).ToString() + "M" } else { [math]::Round($inTokens  / 1KB, 0).ToString() + "k" }
  $outFmt = if ($outTokens -ge 1MB) { [math]::Round($outTokens / 1MB, 1).ToString() + "M" } else { [math]::Round($outTokens / 1KB, 0).ToString() + "k" }
  $costStr = "$ESC[90m$iUp $ESC[0m$ESC[38;5;136m$inFmt$ESC[0m $ESC[90m$iDown $ESC[0m$ESC[38;5;136m$outFmt$ESC[0m"
}

# ===== Display: Progress Bar =====
$maxPercent = 30
$percentColor = if ($displayPercent -gt ($maxPercent * 0.8)) { "$ESC[33m" } else { "$ESC[32m" }
$bar = Format-Bar ([math]::Min($displayPercent / $maxPercent, 1.0)) 6 $charFilled $charEmpty
$progress = $percentColor + $bar + " " + $displayPercent + "%$ESC[0m"

# ===== Usage Providers =====
$zSegment = ""
$pluginRoot = (Get-Item "$PSScriptRoot\..\..").FullName
$cacheDir   = (Get-Item "$PSScriptRoot\..\..\..").FullName

# Load .env
$envFile = Join-Path $cacheDir ".env"
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match "^([^#][^=]*)=(.*)$") {
      [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
    }
  }
}

$usagesFile = Join-Path $pluginRoot "usages.json"

if (Test-Path $usagesFile) {
  $enabledProviders = ([System.Environment]::GetEnvironmentVariable("ENABLED_PROVIDER") -split ",") | ForEach-Object { $_.Trim().ToLower() }
  $usages = Get-Content $usagesFile | ConvertFrom-Json

  if ($enabledProviders -contains "zenmux") {
    $sessionId  = [System.Environment]::GetEnvironmentVariable($usages.zenmux.sessionIdEnv)
    $sessionSig = [System.Environment]::GetEnvironmentVariable($usages.zenmux.sessionSigEnv)

    if (-not ($sessionId -and $sessionSig)) {
      $zSegment = "$ESC[31m$iZenmux !cfg$ESC[0m"
    }
    else {
      $zCacheFile = "$env:TEMP\claude_zenmux_usage_cache.txt"
      $zNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
      $weekRate = $null; $hour5Rate = $null
      $weekEnd = $null; $h5End = $null

      if (Test-Path $zCacheFile) {
        $zParts = (Get-Content $zCacheFile) -split "\|"
        if ($zParts.Count -eq 5 -and ($zNow - [long]$zParts[4]) -lt 180) {
          $hour5Rate = [double]$zParts[0]; $h5End  = $zParts[1]
          $weekRate  = [double]$zParts[2]; $weekEnd = $zParts[3]
        }
      }

      if ($null -eq $weekRate) {
        try {
          $resp = Invoke-RestMethod `
            -Uri "https://zenmux.ai/api/subscription/get_current_usage" `
            -Headers @{ "Cookie" = "sessionId=$sessionId; sessionId.sig=$sessionSig" } `
            -TimeoutSec 3
          if ($resp.success) {
            $h5Data = $resp.data | Where-Object { $_.periodType -eq "hour_5" }
            $wData  = $resp.data | Where-Object { $_.periodType -eq "week" }
            $hour5Rate = $h5Data.usedRate; $h5End  = $h5Data.cycleEndTime
            $weekRate  = $wData.usedRate;  $weekEnd = $wData.cycleEndTime
            "$hour5Rate|$h5End|$weekRate|$weekEnd|$zNow" | Out-File $zCacheFile -Encoding UTF8
          } else {
            $zSegment = "$ESC[31m$iZenmux !auth$ESC[0m"
          }
        } catch {
          $zSegment = "$ESC[90m$iZenmux …$ESC[0m"
        }
      }

      if ($null -ne $weekRate -and $null -ne $hour5Rate) {
        $h5Pct  = [math]::Round($hour5Rate * 100)
        $wPct   = [math]::Round($weekRate  * 100)
        $h5Col  = Get-UsageColor $hour5Rate
        $wCol   = Get-UsageColor $weekRate
        $h5Time = Format-ResetTime $h5End
        $wTime  = Format-ResetTime $weekEnd
        $zSegment = "$iZenmux ${h5Col}${h5Pct}%$ESC[0m $ESC[90m$h5Time$ESC[0m / ${wCol}${wPct}%$ESC[0m $ESC[90m$wTime$ESC[0m"
      }
    }
  }
}

$usageSegment = if ($zSegment) { " · $zSegment" } else { "" }

# ===== Weather =====
$weatherSegment = ""
$weatherFile = Join-Path $pluginRoot "weather.json"

if (Test-Path $weatherFile) {
  $weatherEnabled = [System.Environment]::GetEnvironmentVariable("QWEATHER_ENABLED")
  if ($weatherEnabled -eq "true") {
    $wCfg  = Get-Content $weatherFile | ConvertFrom-Json
    $wHost = [System.Environment]::GetEnvironmentVariable($wCfg.hostEnv)
    $wLoc  = [System.Environment]::GetEnvironmentVariable($wCfg.locationEnv)
    $wKey  = [System.Environment]::GetEnvironmentVariable($wCfg.keyEnv)

    if (-not ($wHost -and $wLoc -and $wKey)) {
      $weatherSegment = " · $ESC[31m${iCloud} !cfg$ESC[0m"
    }
    else {
      $wCacheFile = "$env:TEMP\claude_weather_cache.txt"
      $wNow       = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
      $wTemp = $null; $wIcon = $null

      if (Test-Path $wCacheFile) {
        $wParts = (Get-Content $wCacheFile -Raw).Trim() -split '\|'
        if ($wParts.Count -eq 3 -and ($wNow - [long]$wParts[1]) -lt 600) {
          $wTemp = $wParts[0]; $wIcon = $wParts[2]
        }
      }

      if ($null -eq $wTemp) {
        try {
          $nowJob = $null
          $nowJob = Start-Job {
            param($h, $l, $hdr)
            Invoke-RestMethod -Uri "$h/v7/weather/now?location=$l&lang=en" -Headers $hdr -TimeoutSec 3
          } -ArgumentList $wHost, $wLoc, @{ "X-QW-Api-Key" = $wKey }

          $null = Wait-Job $nowJob -Timeout 4
          $nowResp = Receive-Job $nowJob -ErrorAction SilentlyContinue

          if ($nowResp.code -eq "200") {
            $wTemp = $nowResp.now.temp
            $wIcon = $nowResp.now.icon
            "$wTemp|$wNow|$wIcon" | Out-File $wCacheFile -Encoding UTF8 -NoNewline
          } else {
            $weatherSegment = " · $ESC[90m${iCloud} …$ESC[0m"
          }
        } catch {
          $weatherSegment = " · $ESC[90m${iCloud} …$ESC[0m"
        } finally {
          if ($nowJob) { Remove-Job $nowJob -Force -ErrorAction SilentlyContinue }
        }
      }

      if ($null -ne $wTemp) {
        $wIconChar = if ($wIcon) { Get-WeatherIcon([int]$wIcon) } else { $iCloud }
        $weatherSegment = " · $wIconChar $ESC[36m${wTemp}°$ESC[0m"
      }
    }
  }
}

# ===== Output =====
$line1 = "$ESC[36m$iBolt $model$ESC[0m · $ESC[34m$iFolder $currentDir$ESC[0m$gitBranch"
$line2 = "$progress$usageSegment · $costStr$weatherSegment"
[Console]::Write("$line1 · $line2")

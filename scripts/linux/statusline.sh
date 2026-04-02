#!/usr/bin/env bash
# Statusline: model, directory, git branch, context %, cost, usage, weather
ESC=$'\033'
SHOW_COST=true

# Nerd Font icons
i_bolt=$'\uf0e7'    # nf-fa-bolt
i_folder=$'\uf07b'  # nf-fa-folder
i_branch=$'\ue0a0'  # nf-pl-branch
i_zenmux=$'\uf080'  # nf-fa-bar-chart
i_refresh=$'\uf021' # nf-fa-refresh
i_usd=$'\uf155'     # nf-fa-usd
i_up=$'\uf093'      # nf-fa-upload
i_down=$'\uf019'    # nf-fa-download
i_cloud=$'\uf0c2'   # nf-fa-cloud

json=$(cat)
model=$(echo "$json" | jq -r '.model.display_name' | sed 's|^[^/]*/||')
current_dir=$(echo "$json" | jq -r '.workspace.current_dir' | xargs basename)
session_id=$(echo "$json" | jq -r '.session_id[:8]')

# Git branch
git_branch=""
if [ -d .git ]; then
  head=$(cat .git/HEAD 2>/dev/null)
  if [[ "$head" =~ ref:\ refs/heads/(.*) ]]; then
    _br="${BASH_REMATCH[1]}"
    (( ${#_br} > 20 )) && _br="${_br:0:20}…"
    git_branch=" · ${ESC}[38;5;97m${i_branch} ${_br}${ESC}[0m"
  fi
fi

# Cache for context percent
cache_file="/tmp/claude_statusline_cache.txt"
cached_percent="0"
cached_session=""
if [ -f "$cache_file" ]; then
  IFS='|' read -r cached_percent cached_session < "$cache_file"
fi
[ "$cached_session" != "$session_id" ] && cached_percent="0"

# Context usage
display_percent="$cached_percent"
input_tokens=$(echo "$json" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_creation=$(echo "$json" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$json" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
context_size=$(echo "$json" | jq -r '.context_window.context_window_size // 0')
current_tokens=$((input_tokens + cache_creation + cache_read))
if (( context_size > 0 && current_tokens > 0 )); then
  display_percent=$(( current_tokens * 100 / context_size ))
  echo "${display_percent}|${session_id}" > "$cache_file"
fi

# Cost
cost=$(echo "$json" | jq -r '.cost.total_cost_usd // 0')
in_tokens=$(echo "$json"  | jq -r '.context_window.total_input_tokens // 0')
out_tokens=$(echo "$json" | jq -r '.context_window.total_output_tokens // 0')

# Progress bar (█/░, 6 chars)
bar_size=6
max_percent=30
_capped=$(( display_percent > max_percent ? max_percent : display_percent ))
filled=$(( _capped * bar_size / max_percent ))
empty=$(( bar_size - filled ))
char_filled=$'\u2588'; char_empty=$'\u2591'
bar=$(printf "${char_filled}%.0s" $(seq 1 $filled 2>/dev/null))$(printf "${char_empty}%.0s" $(seq 1 $empty 2>/dev/null))
if (( display_percent > max_percent * 80 / 100 )); then
  percent_color="${ESC}[33m"
else
  percent_color="${ESC}[32m"
fi
progress="${percent_color}${bar} ${display_percent}%${ESC}[0m"

if $SHOW_COST; then
  cost_fmt=$(awk "BEGIN { printf \"%.2f\", $cost }")
  cost_str="${ESC}[38;5;136m${i_usd} ${cost_fmt}${ESC}[0m"
else
  fmt_tokens() {
    local n=$1
    if (( n >= 1048576 )); then awk "BEGIN { printf \"%.1fM\", $n/1048576 }"
    else awk "BEGIN { printf \"%dk\", int($n/1024) }"; fi
  }
  cost_str="${ESC}[90m${i_up} ${ESC}[0m${ESC}[38;5;136m$(fmt_tokens "$in_tokens")${ESC}[0m ${ESC}[90m${i_down} ${ESC}[0m${ESC}[38;5;136m$(fmt_tokens "$out_tokens")${ESC}[0m"
fi

# ===== Usage Providers =====
usage_segment=""
plugin_root="$(cd "$(dirname "$0")/../.." && pwd)"
cache_dir="$(cd "$(dirname "$0")/../../.." && pwd)"

# Load .env
_env_file="$cache_dir/.env"
if [ -f "$_env_file" ]; then
  set -a; source "$_env_file"; set +a
fi

usages_file="$plugin_root/usages.json"

format_reset_time() {
  local end_str="$1" end_ts today end_date
  end_ts=$(date -d "$end_str" +%s 2>/dev/null) || return
  today=$(date +%Y-%m-%d)
  end_date=$(date -d "@$end_ts" +%Y-%m-%d)
  if [ "$end_date" = "$today" ]; then
    echo "$i_refresh $(date -d "@$end_ts" +%H:%M)"
  else
    echo "$i_refresh $(LC_TIME=C date -d "@$end_ts" +"%a %H:%M")"
  fi
}

usage_color() {
  local pct; pct=$(awk "BEGIN { printf \"%d\", $1 * 100 }")
  (( pct >= 90 )) && echo "${ESC}[31m" && return
  (( pct >= 70 )) && echo "${ESC}[33m" && return
  echo "${ESC}[32m"
}

if [ -f "$usages_file" ]; then
  IFS=',' read -ra _providers <<< "${ENABLED_PROVIDER:-}"

  _zenmux_enabled=false
  for _p in "${_providers[@]}"; do
    [ "${_p// /}" = "zenmux" ] && _zenmux_enabled=true
  done

  if $_zenmux_enabled; then
    _sid_env=$(jq -r '.zenmux.sessionIdEnv' "$usages_file")
    _sig_env=$(jq -r '.zenmux.sessionSigEnv' "$usages_file")
    z_session_id="${!_sid_env}"
    z_session_sig="${!_sig_env}"

    if [ -z "$z_session_id" ] || [ -z "$z_session_sig" ]; then
      usage_segment=" · ${ESC}[31m${i_zenmux} !cfg${ESC}[0m"
    else
      z_cache_file="/tmp/claude_zenmux_usage_cache.txt"
      z_now=$(date -u +%s)
      week_rate=""; hour5_rate=""; week_end=""; h5_end=""

      if [ -f "$z_cache_file" ]; then
        IFS='|' read -r _ch _he _cw _we _cts < "$z_cache_file"
        if (( z_now - _cts < 180 )) && [ -n "$_he" ]; then
          hour5_rate="$_ch"; h5_end="$_he"; week_rate="$_cw"; week_end="$_we"
        fi
      fi

      if [ -z "$week_rate" ]; then
        _resp=$(curl -s --max-time 3 \
          "https://zenmux.ai/api/subscription/get_current_usage" \
          -H "Cookie: sessionId=${z_session_id}; sessionId.sig=${z_session_sig}" 2>/dev/null)
        if echo "$_resp" | jq -e '.success == true' > /dev/null 2>&1; then
          hour5_rate=$(echo "$_resp" | jq -r '.data[] | select(.periodType=="hour_5") | .usedRate')
          week_rate=$(echo "$_resp"  | jq -r '.data[] | select(.periodType=="week")   | .usedRate')
          h5_end=$(echo "$_resp"     | jq -r '.data[] | select(.periodType=="hour_5") | .cycleEndTime')
          week_end=$(echo "$_resp"   | jq -r '.data[] | select(.periodType=="week")   | .cycleEndTime')
          echo "${hour5_rate}|${h5_end}|${week_rate}|${week_end}|${z_now}" > "$z_cache_file"
        elif [ -n "$_resp" ]; then
          usage_segment=" · ${ESC}[31m${i_zenmux} !auth${ESC}[0m"
        else
          usage_segment=" · ${ESC}[90m${i_zenmux} …${ESC}[0m"
        fi
      fi

      if [ -n "$week_rate" ] && [ -n "$hour5_rate" ]; then
        h5_pct=$(awk "BEGIN { printf \"%d\", $hour5_rate * 100 }")
        w_pct=$(awk  "BEGIN { printf \"%d\", $week_rate  * 100 }")
        h5_col=$(usage_color "$hour5_rate")
        w_col=$(usage_color "$week_rate")
        h5_time=$(format_reset_time "$h5_end")
        w_time=$(format_reset_time "$week_end")
        usage_segment=" · ${i_zenmux} ${h5_col}${h5_pct}%${ESC}[0m ${ESC}[90m${h5_time}${ESC}[0m / ${w_col}${w_pct}%${ESC}[0m ${ESC}[90m${w_time}${ESC}[0m"
      fi
    fi
  fi
fi

# ===== Weather Icon Mapping =====
get_weather_icon() {
  case "${1:-0}" in
    100)                         printf $'\U000F0599' ;;  # sunny
    150)                         printf $'\U000F0594' ;;  # night
    101|102|103)                 printf $'\U000F0595' ;;  # partly cloudy
    151|152|153)                 printf $'\U000F0F31' ;;  # night partly cloudy
    104)                         printf $'\U000F0590' ;;  # cloudy
    302|303|304)                 printf $'\U000F067E' ;;  # lightning rainy
    313|404|405|406|407|456|457) printf $'\U000F067F' ;;  # snowy rainy
    301|307|308|310|311|312|351) printf $'\U000F0596' ;;  # pouring
    3[0-9][0-9])                 printf $'\U000F0597' ;;  # rainy
    4[0-9][0-9])                 printf $'\U000F0598' ;;  # snowy
    500|501|509|510|514|515)     printf $'\U000F0591' ;;  # fog
    50[2-8]|511|512|513)         printf $'\U000F0F30' ;;  # hazy
    900)                         printf $'\U000F0F37' ;;  # sunny alert
    *)                           printf '\uf0c2'      ;;  # fallback
  esac
}

# ===== Weather =====
weather_segment=""
weather_file="$plugin_root/weather.json"

if [ -f "$weather_file" ]; then
  if [ "${QWEATHER_ENABLED:-}" = "true" ]; then
    w_host_env=$(jq -r '.hostEnv'     "$weather_file")
    w_loc_env=$(jq -r  '.locationEnv' "$weather_file")
    w_key_env=$(jq -r  '.keyEnv'      "$weather_file")
    w_host="${!w_host_env}"; w_loc="${!w_loc_env}"; w_key="${!w_key_env}"

    if [ -z "$w_host" ] || [ -z "$w_loc" ] || [ -z "$w_key" ]; then
      weather_segment=" · ${ESC}[31m${i_cloud} !cfg${ESC}[0m"
    else
      w_cache_file="/tmp/claude_weather_cache.txt"
      w_now=$(date -u +%s)
      w_temp=""; w_icon=""

      if [ -f "$w_cache_file" ]; then
        IFS='|' read -r _wt _wts _wicon < "$w_cache_file"
        if (( w_now - _wts < 600 )) && [ -n "$_wt" ]; then
          w_temp="$_wt"; w_icon="$_wicon"
        fi
      fi

      if [ -z "$w_temp" ]; then
        _now_resp=$(curl -s --max-time 3 \
          "$w_host/v7/weather/now?location=$w_loc&lang=en" \
          -H "X-QW-Api-Key: $w_key" 2>/dev/null)
        _now_code=$(echo "$_now_resp" | jq -r '.code // empty' 2>/dev/null)

        if [ "$_now_code" = "200" ]; then
          w_temp=$(echo "$_now_resp" | jq -r '.now.temp')
          w_icon=$(echo "$_now_resp" | jq -r '.now.icon')
          printf '%s|%s|%s' "$w_temp" "$w_now" "$w_icon" > "$w_cache_file"
        else
          weather_segment=" · ${ESC}[90m${i_cloud} …${ESC}[0m"
        fi
      fi

      if [ -n "$w_temp" ]; then
        _wicon_char=$([ -n "$w_icon" ] && get_weather_icon "$w_icon" || printf '\uf0c2')
        weather_segment=" · ${_wicon_char} ${ESC}[36m${w_temp}°${ESC}[0m"
      fi
    fi
  fi
fi

# ===== Output =====
line1="${ESC}[36m${i_bolt} ${model}${ESC}[0m · ${ESC}[34m${i_folder} ${current_dir}${ESC}[0m${git_branch}"
line2="${progress}${usage_segment} · ${cost_str}${weather_segment}"
printf '%s · %s' "$line1" "$line2"

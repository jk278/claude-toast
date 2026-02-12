#!/usr/bin/env bash
# Statusline: model, directory, git branch, context %, calls, cost, duration
ESC=$'\033'
SHOW_COST=true

json=$(cat)
model=$(echo "$json" | jq -r '.model.display_name')
current_dir=$(echo "$json" | jq -r '.workspace.current_dir' | xargs basename)
session_id=$(echo "$json" | jq -r '.session_id[:8]')

# Git branch
git_branch=""
if [ -d .git ]; then
  head=$(cat .git/HEAD 2>/dev/null)
  if [[ "$head" =~ ref:\ refs/heads/(.*) ]]; then
    git_branch=" · ${ESC}[38;5;97m⎇ ${BASH_REMATCH[1]}${ESC}[0m"
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

# API calls from transcript
current_calls=0
transcript=$(echo "$json" | jq -r '.transcript_path // empty')
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  current_calls=$(jq -r 'select(.message.usage != null and .isSidechain != true and .isApiErrorMessage != true)' "$transcript" | jq -s 'length')
fi

# Cost or tokens
cost=$(echo "$json" | jq -r '.cost.total_cost_usd // 0')

# Duration
duration_ms=$(echo "$json" | jq -r '.cost.total_duration_ms // 0')
hours=$(awk "BEGIN { printf \"%.1f\", $duration_ms / 3600000 }")
time_str="${ESC}[90m${hours}h${ESC}[0m"

# Progress bar
bar_size=10
filled=$(( display_percent * bar_size / 100 ))
empty=$(( bar_size - filled ))
bar=$(printf '■%.0s' $(seq 1 $filled 2>/dev/null))$(printf '□%.0s' $(seq 1 $empty 2>/dev/null))
if (( display_percent > 80 )); then
  percent_color="${ESC}[33m"
else
  percent_color="${ESC}[32m"
fi
progress="${percent_color}${bar} ${display_percent}%${ESC}[0m"

calls="${ESC}[38;5;208m⬡ ${current_calls}c${ESC}[0m"

if $SHOW_COST; then
  cost_fmt=$(awk "BEGIN { printf \"%.2f\", $cost }")
  cost_str="${ESC}[38;5;136m\$${cost_fmt}${ESC}[0m"
fi

# Output
echo "${ESC}[36m⚡${model}${ESC}[0m · ${ESC}[34m□ ${current_dir}${ESC}[0m${git_branch} · ${progress} · ${calls} · ${cost_str} · ⧖ ${time_str}"

#!/usr/bin/env bash
# usage-statusline.sh — Claude Code statusLine badge for usage limits
#
# Receives JSON from Claude Code via stdin after each message.
# Outputs colored ANSI badges to stdout (shown in terminal statusline).
# Writes ~/.claude/.claude-usage-state.json for the menu bar plugin.
#
# Project: https://github.com/ChrisPiz/Claude-Code-Usage-Bar

set -euo pipefail

STATE_FILE="$HOME/.claude/.claude-usage-state.json"
JQ="/usr/bin/jq"

# ── Read stdin ──────────────────────────────────────────────────────────────
INPUT=$(cat)

[ -z "$INPUT" ] && exit 0

# ── Parse rate limits ────────────────────────────────────────────────────────
FIVE_H=$("$JQ" -r '.rate_limits.five_hour.used_percentage // empty' <<< "$INPUT" 2>/dev/null)
FIVE_H_RESET=$("$JQ" -r '.rate_limits.five_hour.resets_at // empty' <<< "$INPUT" 2>/dev/null)
SEVEN_D=$("$JQ" -r '.rate_limits.seven_day.used_percentage // empty' <<< "$INPUT" 2>/dev/null)
SEVEN_D_RESET=$("$JQ" -r '.rate_limits.seven_day.resets_at // empty' <<< "$INPUT" 2>/dev/null)
SEVEN_DS=$("$JQ" -r '.rate_limits.seven_day_sonnet.used_percentage // empty' <<< "$INPUT" 2>/dev/null)

# No usage data yet (first message of session) — stay silent
[ -z "$FIVE_H" ] && [ -z "$SEVEN_D" ] && exit 0

# ── ANSI color helper ────────────────────────────────────────────────────────
ansi_for_pct() {
  local pct="${1:-0}"
  if [ "$pct" -lt 70 ] 2>/dev/null; then
    printf '\033[38;5;82m'    # green
  elif [ "$pct" -lt 90 ] 2>/dev/null; then
    printf '\033[38;5;214m'   # orange
  else
    printf '\033[38;5;196m'   # red
  fi
}

RESET=$'\033[0m'

# ── Build usage badges ───────────────────────────────────────────────────────
usage_parts=()

if [ -n "$FIVE_H" ]; then
  c=$(ansi_for_pct "$FIVE_H")
  usage_parts+=("${c}5h:${FIVE_H}%${RESET}")
fi

if [ -n "$SEVEN_D" ]; then
  c=$(ansi_for_pct "$SEVEN_D")
  usage_parts+=("${c}7d:${SEVEN_D}%${RESET}")
fi

if [ -n "$SEVEN_DS" ]; then
  c=$(ansi_for_pct "$SEVEN_DS")
  usage_parts+=("${c}7d♦:${SEVEN_DS}%${RESET}")
fi

usage_text=$(IFS=' '; echo "${usage_parts[*]}")

# ── Caveman badge (optional, auto-detected) ──────────────────────────────────
caveman_text=""
caveman_flag="$HOME/.claude/.caveman-active"
if [ -f "$caveman_flag" ]; then
  caveman_mode=$(cat "$caveman_flag" 2>/dev/null)
  if [ "$caveman_mode" = "full" ] || [ -z "$caveman_mode" ]; then
    caveman_text=$'\033[38;5;172m[CAVEMAN]\033[0m'
  else
    caveman_suffix=$(echo "$caveman_mode" | tr '[:lower:]' '[:upper:]')
    caveman_text=$'\033[38;5;172m[CAVEMAN:'"${caveman_suffix}"$']\033[0m'
  fi
fi

# ── Emit statusline ──────────────────────────────────────────────────────────
if [ -n "$caveman_text" ] && [ -n "$usage_text" ]; then
  printf '%s  %s\n' "$caveman_text" "$usage_text"
elif [ -n "$usage_text" ]; then
  printf '%s\n' "$usage_text"
fi

# ── Write state file for menu bar plugin ────────────────────────────────────
NOW=$(date +%s)
"$JQ" -n \
  --argjson input "$INPUT" \
  --argjson ts "$NOW" \
  '{updated_at: $ts, rate_limits: $input.rate_limits}' \
  > "$STATE_FILE" 2>/dev/null || true

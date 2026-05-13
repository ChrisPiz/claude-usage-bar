#!/usr/bin/env bash
# claude-usage-bar.1m.sh — SwiftBar / xbar plugin for Claude Code usage
#
# Shows Claude Code Pro/Team plan consumption in the macOS menu bar.
# Reads state written by usage-statusline.sh (~/.claude/.claude-usage-state.json).
#
# Install locations:
#   SwiftBar: ~/Library/Application Support/SwiftBar/
#   xbar:     ~/Library/Application Support/xbar/plugins/
#
# Project: https://github.com/ChrisPiz/claude-usage-bar

STATE_FILE="$HOME/.claude/.claude-usage-state.json"
JQ="/usr/bin/jq"
STALE_THRESHOLD=21600  # 6 hours in seconds

# ── No state file yet ────────────────────────────────────────────────────────
if [ ! -f "$STATE_FILE" ]; then
  echo "⏳ Claude | color=gray"
  echo "---"
  echo "No usage data yet"
  echo "Send a message in Claude Code to populate | color=gray size=12"
  exit 0
fi

# ── Read state ───────────────────────────────────────────────────────────────
UPDATED_AT=$("$JQ" -r '.updated_at // 0' "$STATE_FILE" 2>/dev/null)
NOW=$(date +%s)
AGE=$(( NOW - UPDATED_AT ))

if [ "$AGE" -gt "$STALE_THRESHOLD" ]; then
  STALE=" (stale)"
else
  STALE=""
fi

# ── Extract values ───────────────────────────────────────────────────────────
FIVE_H=$("$JQ"  -r '.rate_limits.five_hour.used_percentage         // "?"' "$STATE_FILE" 2>/dev/null)
FIVE_H_RESET=$("$JQ" -r '.rate_limits.five_hour.resets_at          // 0'   "$STATE_FILE" 2>/dev/null)
SEVEN_D=$("$JQ" -r '.rate_limits.seven_day.used_percentage          // "?"' "$STATE_FILE" 2>/dev/null)
SEVEN_D_RESET=$("$JQ" -r '.rate_limits.seven_day.resets_at          // 0'   "$STATE_FILE" 2>/dev/null)
SEVEN_DS=$("$JQ" -r '.rate_limits.seven_day_sonnet.used_percentage  // "?"' "$STATE_FILE" 2>/dev/null)

# ── Color helpers ─────────────────────────────────────────────────────────────
menubar_color() {
  local pct="${1:-0}"
  [ "$pct" = "?" ] && echo "gray" && return
  if   [ "$pct" -lt 70 ] 2>/dev/null; then echo "green"
  elif [ "$pct" -lt 90 ] 2>/dev/null; then echo "orange"
  else echo "red"; fi
}

pct_emoji() {
  local pct="${1:-0}"
  [ "$pct" = "?" ] && echo "❓" && return
  if   [ "$pct" -lt 70 ] 2>/dev/null; then echo "🟢"
  elif [ "$pct" -lt 90 ] 2>/dev/null; then echo "🟠"
  else echo "🔴"; fi
}

# ── Dominant metric for title bar (highest usage = most constrained) ─────────
MAX_PCT="$FIVE_H"
if [ "$SEVEN_D" != "?" ] && [ "$SEVEN_D" -gt "${MAX_PCT:-0}" ] 2>/dev/null; then
  MAX_PCT="$SEVEN_D"
fi

TITLE_COLOR=$(menubar_color "$MAX_PCT")
TITLE_EMOJI=$(pct_emoji "$MAX_PCT")

# ── Format reset timestamps ───────────────────────────────────────────────────
fmt_reset() {
  local ts="$1"
  [ "$ts" = "0" ] || [ -z "$ts" ] && echo "unknown" && return
  date -r "$ts" "+%b %d %H:%M" 2>/dev/null || echo "unknown"
}

FIVE_H_RESET_FMT=$(fmt_reset "$FIVE_H_RESET")
SEVEN_D_RESET_FMT=$(fmt_reset "$SEVEN_D_RESET")
UPDATED_FMT=$(fmt_reset "$UPDATED_AT")

# ── Menu bar output ──────────────────────────────────────────────────────────
# Title line (visible in the menu bar itself)
echo "${TITLE_EMOJI} ${MAX_PCT}%${STALE} | color=${TITLE_COLOR}"

echo "---"
echo "Claude Code Usage | size=13"
echo "---"

# 5-hour session window
if [ "$FIVE_H" != "?" ]; then
  echo "⚡ Session (5h): ${FIVE_H}% | color=$(menubar_color "$FIVE_H")"
  echo "   Resets: ${FIVE_H_RESET_FMT} | size=11 color=gray"
fi

# 7-day all models
if [ "$SEVEN_D" != "?" ]; then
  echo "📅 Weekly (all): ${SEVEN_D}% | color=$(menubar_color "$SEVEN_D")"
  echo "   Resets: ${SEVEN_D_RESET_FMT} | size=11 color=gray"
fi

# 7-day Sonnet
if [ "$SEVEN_DS" != "?" ]; then
  echo "💎 Weekly (Sonnet): ${SEVEN_DS}% | color=$(menubar_color "$SEVEN_DS")"
  echo "   Resets: ${SEVEN_D_RESET_FMT} | size=11 color=gray"
fi

echo "---"
echo "Updated: ${UPDATED_FMT} | size=11 color=gray"
echo "---"
echo "Refresh | refresh=true"

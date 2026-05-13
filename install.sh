#!/usr/bin/env bash
# install.sh — claude-usage-bar installer
#
# Usage (from clone):  bash install.sh
# Usage (one-liner):   bash <(curl -s https://raw.githubusercontent.com/ChrisPiz/claude-usage-bar/main/install.sh)

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/ChrisPiz/claude-usage-bar/main/hooks"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DEST="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
JQ="/usr/bin/jq"

SWIFTBAR_DIR="$HOME/Library/Application Support/SwiftBar"
XBAR_DIR="$HOME/Library/Application Support/xbar/plugins"

# ── Resolve script location ──────────────────────────────────────────────────
# Works both from clone (local files available) and from curl pipe
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  LOCAL_HOOKS="$SCRIPT_DIR/hooks"
else
  LOCAL_HOOKS=""
fi

echo "claude-usage-bar installer"
echo ""

# ── Preflight checks ─────────────────────────────────────────────────────────
if ! command -v "$JQ" &>/dev/null && ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq"
  exit 1
fi
JQ=$(command -v jq)

if [ ! -f "$SETTINGS" ]; then
  echo "Error: ~/.claude/settings.json not found. Is Claude Code installed?"
  exit 1
fi

# ── Install hook scripts to ~/.claude/hooks/ ─────────────────────────────────
mkdir -p "$HOOKS_DEST"

install_script() {
  local name="$1"
  local dest="$HOOKS_DEST/$name"

  if [ -n "$LOCAL_HOOKS" ] && [ -f "$LOCAL_HOOKS/$name" ]; then
    cp "$LOCAL_HOOKS/$name" "$dest"
  else
    curl -fsSL "$REPO_RAW/$name" -o "$dest"
  fi
  chmod +x "$dest"
}

echo "Installing scripts to $HOOKS_DEST ..."
install_script "usage-statusline.sh"
install_script "claude-usage-bar.1m.sh"
echo "  ✓ usage-statusline.sh"
echo "  ✓ claude-usage-bar.1m.sh"

# ── Wire settings.json ───────────────────────────────────────────────────────
HOOK_PATH="$HOOKS_DEST/usage-statusline.sh"
HOOK_CMD="bash \"$HOOK_PATH\""

echo ""
echo "Configuring statusLine in settings.json ..."

CURRENT_CMD=$("$JQ" -r '.statusLine.command // .statusLine // empty' "$SETTINGS" 2>/dev/null || echo "")

if [ -z "$CURRENT_CMD" ]; then
  # No statusLine configured — install directly
  "$JQ" --arg cmd "$HOOK_CMD" \
    '. + {statusLine: {type: "command", command: $cmd}}' \
    "$SETTINGS" > /tmp/claude-settings.tmp && mv /tmp/claude-settings.tmp "$SETTINGS"
  echo "  ✓ statusLine configured"

elif echo "$CURRENT_CMD" | grep -q "usage-statusline.sh"; then
  # Already installed — update path in case directory changed
  "$JQ" --arg cmd "$HOOK_CMD" \
    '.statusLine.command = $cmd' \
    "$SETTINGS" > /tmp/claude-settings.tmp && mv /tmp/claude-settings.tmp "$SETTINGS"
  echo "  ✓ statusLine updated (already installed)"

elif echo "$CURRENT_CMD" | grep -q "caveman-statusline.sh"; then
  # Caveman statusLine detected — our script already includes the caveman badge
  "$JQ" --arg cmd "$HOOK_CMD" \
    '.statusLine = {type: "command", command: $cmd}' \
    "$SETTINGS" > /tmp/claude-settings.tmp && mv /tmp/claude-settings.tmp "$SETTINGS"
  echo "  ✓ Replaced caveman statusLine (usage-statusline.sh includes caveman badge)"

else
  # Custom statusLine — don't overwrite, show merge instructions
  echo "  ⚠  Custom statusLine detected — NOT overwritten."
  echo ""
  echo "  Add this to your existing statusline script to include usage badges:"
  echo ""
  echo "    # claude-usage-bar integration"
  echo "    source \"$HOOK_PATH\""
  echo ""
  echo "  Or see README for manual merge instructions."
fi

# ── Install menu bar plugin ───────────────────────────────────────────────────
PLUGIN_SRC="$HOOKS_DEST/claude-usage-bar.1m.sh"

echo ""
echo "Installing menu bar plugin ..."

if [ -d "$SWIFTBAR_DIR" ]; then
  cp "$PLUGIN_SRC" "$SWIFTBAR_DIR/claude-usage-bar.1m.sh"
  echo "  ✓ SwiftBar plugin installed → $SWIFTBAR_DIR"
elif [ -d "$XBAR_DIR" ]; then
  cp "$PLUGIN_SRC" "$XBAR_DIR/claude-usage-bar.1m.sh"
  echo "  ✓ xbar plugin installed → $XBAR_DIR"
else
  echo "  ℹ  SwiftBar/xbar not found — plugin not installed automatically."
  echo ""
  echo "  Install SwiftBar:  brew install --cask swiftbar"
  echo "  Then run:          cp \"$PLUGIN_SRC\" \"$SWIFTBAR_DIR/\""
  echo ""
  echo "  Install xbar:      brew install --cask xbar"
  echo "  Then run:          cp \"$PLUGIN_SRC\" \"$XBAR_DIR/\""
fi

echo ""
echo "Done! Send a message in Claude Code to see the usage badges."

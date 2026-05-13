# claude-usage-bar

Claude Code Pro/Team plan usage in your terminal statusline and macOS menu bar.

```
🟠 63% ← in your menu bar

5h:6%  7d:63%  7d♦:22% ← in your Claude Code terminal
```

---

## What it does

- **Terminal badge** — colored usage indicators in the Claude Code statusline after each message
- **Menu bar indicator** — live percentage in the macOS menu bar with a click-to-expand breakdown and reset times

Colors: 🟢 green `< 70%` · 🟠 orange `70–90%` · 🔴 red `≥ 90%`

---

## Requirements

- macOS
- [Claude Code](https://claude.ai/code) with a Pro or Team subscription
- `jq` — likely already installed (`which jq`), otherwise: `brew install jq`
- [SwiftBar](https://swiftbar.app) or [xbar](https://xbarapp.com) — for the menu bar indicator *(optional)*

---

## Quick install

```bash
bash <(curl -s https://raw.githubusercontent.com/ChrisPiz/claude-usage-bar/main/install.sh)
```

The installer:
1. Copies scripts to `~/.claude/hooks/`
2. Adds `statusLine` to `~/.claude/settings.json`
3. Installs the menu bar plugin if SwiftBar or xbar is found

Then send any message in Claude Code — the badges appear after the first response.

---

## Menu bar setup (if not auto-installed)

Install SwiftBar:
```bash
brew install --cask swiftbar
```

Copy the plugin:
```bash
cp ~/.claude/hooks/claude-usage-bar.1m.sh ~/Library/Application\ Support/SwiftBar/
```

Point SwiftBar to its plugins folder on first launch. The menu bar icon appears within 1 minute.

---

## How it works

```
Claude Code → JSON via stdin → usage-statusline.sh ──→ ANSI badge (terminal)
                                        │
                                        └──→ ~/.claude/.claude-usage-state.json
                                                          │
                                       claude-usage-bar.1m.sh ──→ menu bar
```

After each message, Claude Code passes usage data to the `statusLine` script. That script formats the terminal badge and writes a state file. The menu bar plugin reads that file every minute.

---

## Caveman compatibility

If you use the [caveman](https://github.com/superpowers/caveman) Claude Code plugin, the caveman mode badge is automatically included in the statusline — no extra configuration needed.

```
[CAVEMAN:ULTRA]  5h:6%  7d:63%
```

---

## Custom statusline integration

If you already have a custom `statusLine` script, the installer won't overwrite it. Add this snippet to your existing script:

```bash
# claude-usage-bar usage badges
USAGE_HOOK="$HOME/.claude/hooks/usage-statusline.sh"
if [ -f "$USAGE_HOOK" ]; then
  usage_out=$(cat | "$USAGE_HOOK")
  # Combine with your existing output
  printf '%s  %s\n' "$your_existing_output" "$usage_out"
fi
```

---

## Uninstall

```bash
bash ~/.claude/hooks/uninstall.sh
```

Or via curl:
```bash
bash <(curl -s https://raw.githubusercontent.com/ChrisPiz/claude-usage-bar/main/uninstall.sh)
```

---

## License

MIT

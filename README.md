Claude Code plan usage in your terminal statusline and macOS menu bar.

Independent project. Not affiliated with, endorsed by, or sponsored by Anthropic, Claude, or Claude Code.

![screenshot](docs/screenshot.png)

```
5h:17%  7d:63% ← in your Claude Code terminal
```

---

## What it does

- **Terminal badge** — colored usage indicators in the Claude Code statusline after each message
- **Menu bar app** — native macOS menu bar app, live percentage with click-to-expand breakdown and reset times

Colors: 🟢 green `< 70%` · 🟠 orange `70–90%` · 🔴 red `≥ 90%`

The menu bar icon auto-tints for light/dark mode and the interface uses your macOS system language.

---

## Requirements

- macOS 13+
- [Claude Code](https://claude.ai/code) with a Pro or Team subscription

---

## Install

### Download the DMG

Download `ClaudeUsageBar.dmg` from the [latest release](https://github.com/ChrisPiz/Claude-Code-Usage-Bar/releases/latest), open it, and drag `ClaudeUsageBar.app` to `Applications`.

Open the app once. On first launch it configures Claude Code automatically by adding this statusline command to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"/Applications/ClaudeUsageBar.app/Contents/MacOS/ClaudeUsageBar\" --statusline"
  }
}
```

Restart Claude Code, then send any message. The terminal badge appears after the first response, and the menu bar app updates from the same data.

If you already have a custom Claude Code `statusLine`, the app will not overwrite it.

Unsigned local builds may require right-click → Open. Public releases should be signed and notarized.

---

## Auto-start on login

Add the app to Login Items so it launches automatically:

**System Settings → General → Login Items → +** → select `/Applications/ClaudeUsageBar.app`

---

## How it works

```
Claude Code → JSON via stdin → ClaudeUsageBar --statusline ──→ ANSI badge (terminal)
                                                    │
                                                    └──→ ~/.claude/.claude-usage-state.json
                                                                      │
                                                   ClaudeUsageBar.app ──→ menu bar
```

After each message, Claude Code passes usage data to the app's `--statusline` mode. It formats the terminal badge and writes a state file. The menu bar app reads that file every 60 seconds.

---

## Caveman compatibility

If you use the [caveman](https://github.com/superpowers/caveman) Claude Code plugin, the caveman mode badge is automatically included in the statusline — no extra configuration needed.

```
[CAVEMAN:ULTRA]  5h:13%  7d:63%
```

---

## Custom statusline integration

If you already have a custom `statusLine` script, the app won't overwrite it. Add this snippet to your existing script:

```bash
# claude-usage-bar usage badges
USAGE_BAR="/Applications/ClaudeUsageBar.app/Contents/MacOS/ClaudeUsageBar"
if [ -x "$USAGE_BAR" ]; then
  usage_out=$(cat | "$USAGE_BAR" --statusline)
  printf '%s  %s\n' "$your_existing_output" "$usage_out"
fi
```

---

## Building a DMG

For maintainers:

```bash
bash build.sh
```

The build writes:

- `dist/ClaudeUsageBar.app`
- `dist/ClaudeUsageBar.dmg`

Set `CODE_SIGN_IDENTITY` to sign with a Developer ID certificate. Without it, the app is ad-hoc signed for local testing.

---

## Uninstall

Quit `ClaudeUsageBar`, delete it from `Applications`, and remove the `statusLine` entry from `~/.claude/settings.json`.

---

## License

MIT

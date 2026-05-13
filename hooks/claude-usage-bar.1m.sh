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
# ── Embedded menu bar icon (18px templateImage) ─────────────────────────────
ICON_B64="iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAKsGlDQ1BJQ0MgUHJvZmlsZQAASImVlwdUU+kSgP9700NCC0Q6oYYunQBSQmihSwcbIQkQCCEEgoDYkMUVWFFURLCiKyAKrgWQRUVEsS2KvS+IqKjrYgELKu8Ch7C777z3zptzJvNl7vzzz/zn/ufMBYCsxRGLhbAiAOmibEm4nxctNi6ehnsJIKAEyAALLDjcLDEzLCwIIDJj/y5jt5FoRG5YTub69+f/VZR4/CwuAFAYwom8LG46wscQHeOKJdkAoA4ifoOl2eJJvoawigQpEOGnk5w8zZ8mOXGK0aSpmMhwFsI0APAkDkeSDADJAvHTcrjJSB7SZA/WIp5AhHABwu7p6Rk8hDsQNkFixAhP5mck/iVP8t9yJspycjjJMp7uZUrw3oIssZCT938ex/+WdKF0Zg86oqQUiX84YpWRM3ualhEoY1FiSOgMC3hT8VOcIvWPmmFuFit+hrOEEewZ5nG8A2V5hCFBM5wk8JXFCLLZkTPMz/KJmGFJRrhs3yQJiznDHMlsDdK0KJk/hc+W5c9PiYyZ4RxBdIistrSIwNkYlswvkYbLeuGL/Lxm9/WVnUN61l96F7Bla7NTIv1l58CZrZ8vYs7mzIqV1cbje/vMxkTJ4sXZXrK9xMIwWTxf6CfzZ+VEyNZmIy/n7Now2RmmcgLCZhiwQAYQIioBNBCE/PMGIJufmz3ZCCtDnCcRJKdk05jIbePT2CKulQXN1trWEYDJuzv9arynTt1JiHpp1rdGDwC3vImJiY5ZXyByp46eBIB4f9ZHHwJA/hIAF7ZypZKcaR968gcDiEABqAB1oAMMgAmwBLbAEbgCT+ADAkAoiARxYDHgghSQjlS+FBSA1aAYlIINYAuoBrvAXlAPDoEjoBV0gDPgPLgMroFb4AHoB0PgFRgBY2AcgiAcRIYokDqkCxlB5pAtxIDcIR8oCAqH4qAEKBkSQVKoAFoDlUIVUDW0B2qAfoFOQGegi1AfdA8agIahd9AXGAWTYBVYGzaG58IMmAkHwpHwIjgZzoTz4SJ4PVwF18IH4Rb4DHwZvgX3w6/gURRAyaGoKD2UJYqBYqFCUfGoJJQEtQJVgqpE1aKaUO2oHtQNVD/qNeozGoumoGloS7Qr2h8dheaiM9Er0GXoanQ9ugXdjb6BHkCPoL9jyBgtjDnGBcPGxGKSMUsxxZhKzH7Mccw5zC3MEGYMi8VSsXSsE9YfG4dNxS7DlmF3YJuxndg+7CB2FIfDqePMcW64UBwHl40rxm3DHcSdxl3HDeE+4eXwunhbvC8+Hi/CF+Ir8Qfwp/DX8c/x4wRFghHBhRBK4BHyCOWEfYR2wlXCEGGcqESkE92IkcRU4mpiFbGJeI74kPheTk5OX85Zbr6cQG6VXJXcYbkLcgNyn0nKJDMSi7SQJCWtJ9WROkn3SO/JZLIx2ZMcT84mryc3kM+SH5M/yVPkreTZ8jz5lfI18i3y1+XfKBAUjBSYCosV8hUqFY4qXFV4rUhQNFZkKXIUVyjWKJ5QvKM4qkRRslEKVUpXKlM6oHRR6YUyTtlY2UeZp1ykvFf5rPIgBUUxoLAoXMoayj7KOcqQClaFrsJWSVUpVTmk0qsyoqqsaq8arZqrWqN6UrWfiqIaU9lUIbWceoR6m/pljvYc5hz+nHVzmuZcn/NRTVPNU42vVqLWrHZL7Ys6Td1HPU19o3qr+iMNtIaZxnyNpRo7Nc5pvNZU0XTV5GqWaB7RvK8Fa5lphWst09qrdUVrVFtH209brL1N+6z2ax2qjqdOqs5mnVM6w7oUXXddge5m3dO6L2mqNCZNSKuiddNG9LT0/PWkenv0evXG9en6UfqF+s36jwyIBgyDJIPNBl0GI4a6hsGGBYaNhveNCEYMoxSjrUY9Rh+N6cYxxmuNW41f0NXobHo+vZH+0IRs4mGSaVJrctMUa8owTTPdYXrNDDZzMEsxqzG7ag6bO5oLzHeY91lgLJwtRBa1FncsSZZMyxzLRssBK6pVkFWhVavVm7mGc+PnbpzbM/e7tYO10Hqf9QMbZZsAm0Kbdpt3tma2XNsa25t2ZDtfu5V2bXZv7c3t+fY77e86UByCHdY6dDl8c3RylDg2OQ47GTolOG13usNQYYQxyhgXnDHOXs4rnTucP7s4umS7HHH509XSNc31gOuLefR5/Hn75g266btx3Pa49bvT3BPcd7v3e+h5cDxqPZ54GnjyPPd7PmeaMlOZB5lvvKy9JF7HvT6yXFjLWZ3eKG8/7xLvXh9lnyifap/Hvvq+yb6NviN+Dn7L/Dr9Mf6B/hv977C12Vx2A3skwClgeUB3ICkwIrA68EmQWZAkqD0YDg4I3hT8MMQoRBTSGgpC2aGbQh+F0cMyw36dj50fNr9m/rNwm/CC8J4ISsSSiAMRY5FekeWRD6JMoqRRXdEK0QujG6I/xnjHVMT0x86NXR57OU4jThDXFo+Lj47fHz+6wGfBlgVDCx0WFi+8vYi+KHfRxcUai4WLTy5RWMJZcjQBkxCTcCDhKyeUU8sZTWQnbk8c4bK4W7mveJ68zbxhvhu/gv88yS2pIulFslvypuThFI+UypTXApagWvA21T91V+rHtNC0urQJYYywOR2fnpB+QqQsShN1Z+hk5Gb0ic3FxeL+TJfMLZkjkkDJ/iwoa1FWW7YKMiRdkZpIf5AO5Ljn1OR8Whq99GiuUq4o90qeWd66vOf5vvk/L0Mv4y7rKtArWF0wsJy5fM8KaEXiiq6VBiuLVg6t8ltVv5q4Om31b4XWhRWFH9bErGkv0i5aVTT4g98PjcXyxZLiO2td1+76Ef2j4MfedXbrtq37XsIruVRqXVpZ+rWMW3bpJ5ufqn6aWJ+0vrfcsXznBuwG0YbbGz021lcoVeRXDG4K3tSymba5ZPOHLUu2XKy0r9y1lbhVurW/KqiqbZvhtg3bvlanVN+q8app3q61fd32jzt4O67v9NzZtEt7V+muL7sFu+/u8dvTUmtcW7kXuzdn77N90ft6fmb83LBfY3/p/m91orr++vD67ganhoYDWgfKG+FGaePwwYUHrx3yPtTWZNm0p5naXHoYHJYefvlLwi+3jwQe6TrKONp0zOjY9uOU4yUtUEtey0hrSmt/W1xb34mAE13tru3Hf7X6ta5Dr6PmpOrJ8lPEU0WnJk7nnx7tFHe+PpN8ZrBrSdeDs7Fnb3bP7+49F3juwnnf82d7mD2nL7hd6LjocvHEJcal1suOl1uuOFw5/pvDb8d7HXtbrjpdbbvmfK29b17fqese18/c8L5x/ib75uVbIbf6bkfdvntn4Z3+u7y7L+4J7729n3N//MGqh5iHJY8UH1U+1npc+7vp7839jv0nB7wHrjyJePJgkDv46mnW069DRc/Izyqf6z5veGH7omPYd/jaywUvh16JX42/Lv5D6Y/tb0zeHPvT888rI7EjQ28lbyfelb1Xf1/3wf5D12jY6OOx9LHxjyWf1D/Vf2Z87vkS8+X5+NKvuK9V30y/tX8P/P5wIn1iQsyRcKZGARSicFISAO/qACDHAUBBZgjigunZekqg6e+BKQL/iafn7ylBJpcmxEyORaxOAA4jarwKyY3YyZEo0hPAdnYynZmDp2b2ScEiXy+7vSfp3qaIZeAfMj3P/6Xuf1owmdUe/NP+C3x1DVGzjtpmAAAAbGVYSWZNTQAqAAAACAAEARoABQAAAAEAAAA+ARsABQAAAAEAAABGASgAAwAAAAEAAgAAh2kABAAAAAEAAABOAAAAAAAAAJAAAAABAAAAkAAAAAEAAqACAAQAAAABAAAAJKADAAQAAAABAAAAJAAAAABAJAr6AAAACXBIWXMAABYlAAAWJQFJUiTwAAAEc0lEQVRYCbWWW4hWVRTHv9TsqkV0UaMky5xKXyzBIkJTxKTLS2EXoqcKiSKIIigqIuuhevAlSCiIKAoSowtCpQ5FqWVgGaQUxRCZlEZFZZldfj/ZC9ecOd9858xMC/7fXve9z157r/11Or1pAi5vgZ/KeEKPkJnYF/TwGZX5AaL/TXhomGznYvu9+F41jF9X07iulkOGaYfYg9wKfo+o6EK8GeaoIiwMZZuxyYLWVxKejHxDRReiOxS0M5ixHl30RyCX7bMuk2xLfpfW+PSh2wH2AXd6xHQBkX+DvKilNdl2JZ8pFfsM5Gz/FXlqxWeIaJJ5YPIQS6fzDLq8oP6Kz2HIfxWf3RWbZf6y2CLHH8jHVPwGiV7nL4ABJlwAMp2C8DOIhI6LkoPxYVuX9F6ALckWPi8ln1r2jErQAeR7Kp53VXw+SPY5ybYy6Z9N+liMu3V88qllPbzbQQTFuBbdcSViImN165cVm2PEXF10tyVd2H5D5+Ib0Ul4rQERHKOLOL9kcLLQO24t+luT/iz4i8D+pIuYG9G1JhucXxJJHP8EdwIPr6XKNrtydPRf4P2wbyo++q8GI6Y+IjeDPLH86+CKiv5t5FVF525uqNiN+xREF4cdGY0n7G5gI8sLG0B2x0In35/k0Mfo+3YOGDOaRab3QUzQdrScmfwHcR64HjwKXgNWYzloTN5Cd8uG1mZBu/H3Vjm5Zd0EuuV4F1vHG7EEzAX2Iq+4B7cb+YB6s9osqpevF+gdsNiJvwXTQCbfLf+Q/QjszuIHoO+uwj/CeDpoS/8QsAN8XPAhox/os3OQrNtXwFX2+pKR2C2PpfCsXAaiycIOpWppvFU+rMcCH76jy+h7FDgSfhK4D5wGhiNv5xtgALjDypK7ZAX2JuhjZVrTmUS8Aprslk1yf0NfSzgTNCYfwydB7j913Tgv9Hv854PF4GGwEdiTsk/mbZ496XA87gB7QASb1H8CbxbdgWQLnxiN8wYHTYS5EBhv1/fi6Gs5HwPD0pVYd4JI7rgR2CrcLWXPgzcu+1R5S7cI1JHneDao3vRBvicirQE5sVf/FmCC/OI/geyjq++L4PPCK9sEveLylvpa0JouJ8Lumhfj1p5aMnnw/GLtW4EleKrIKxmXFF67pVwGbHrK7ubtoDFNx9Mgg4VX9ToQZBvw4Glzx7xx0nqgLiZ7tcjq3KFJ4OmkexC+EU3B6zvgQXseWLpMLyA4icjbv7formGU7E+xi/o+rhK6F8QHr4K3/D1pfBcPb1osZnXymZH0lyT9iqS34c0vtqWM7ry5ngONFoXfILoYybfGJNtB/qO1vOi1nQ2CnKgfxEd42O3ykufxPaBtOmhFU/G2jAbvAX0gk+WISSdnA7xnLJcu95kJ2Nyt1rSOCCc08bya6A3FbrOso5tQxoK31Tm00bntLmQfWFgTOK7YnfDrGnuoXobR55NQjGb05s3qkmA2+vj6TV18VNur5gLbxv9Kc8geC1o7FjN1u+JNc/ua2/T8J3A/GACjov8A3GDlQZ7JzkcAAAAASUVORK5CYII="


# ── No state file yet ────────────────────────────────────────────────────────
if [ ! -f "$STATE_FILE" ]; then
  echo "— | templateImage=$ICON_B64"
  echo "---"
  echo "No usage data yet | color=gray size=12"
  echo "Send a message in Claude Code to populate | color=gray size=11"
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

# ── Dominant metric (highest = most constrained) ─────────────────────────────
MAX_PCT="$FIVE_H"
if [ "$SEVEN_D" != "?" ] && [ "$SEVEN_D" -gt "${MAX_PCT:-0}" ] 2>/dev/null; then
  MAX_PCT="$SEVEN_D"
fi

# ── Format reset timestamps ───────────────────────────────────────────────────
fmt_reset() {
  local ts="$1"
  [ "$ts" = "0" ] || [ -z "$ts" ] && echo "—" && return
  date -r "$ts" "+%b %d %H:%M" 2>/dev/null || echo "—"
}

FIVE_H_RESET_FMT=$(fmt_reset "$FIVE_H_RESET")
SEVEN_D_RESET_FMT=$(fmt_reset "$SEVEN_D_RESET")
UPDATED_FMT=$(fmt_reset "$UPDATED_AT")

# ── Menu bar output ──────────────────────────────────────────────────────────
# Title: plain text, no color, blends with system items
echo "${MAX_PCT}%${STALE} | templateImage=$ICON_B64"

echo "---"
echo "Claude Code | size=13 color=gray"
echo "---"

# 5-hour session window
if [ "$FIVE_H" != "?" ]; then
  echo "Session (5h)    ${FIVE_H}% | size=14 refresh=true"
  echo "Resets ${FIVE_H_RESET_FMT} | size=11 color=gray"
fi

# 7-day all models
if [ "$SEVEN_D" != "?" ]; then
  echo "Weekly (all)    ${SEVEN_D}% | size=14 refresh=true"
  echo "Resets ${SEVEN_D_RESET_FMT} | size=11 color=gray"
fi

# 7-day Sonnet
if [ "$SEVEN_DS" != "?" ]; then
  echo "Weekly (Sonnet) ${SEVEN_DS}% | size=14 refresh=true"
  echo "Resets ${SEVEN_D_RESET_FMT} | size=11 color=gray"
fi

echo "---"
echo "Updated ${UPDATED_FMT} | size=11 color=gray"
echo "---"
echo "Refresh | refresh=true"

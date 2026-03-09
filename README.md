# Claude Code Custom Status Line

A fully customizable status line for [Claude Code](https://claude.ai/code) that displays model name, current repo, context window usage (with a color-coded progress bar), token counts, and running session cost — all configurable via a single JSON settings file.

![Status line preview](https://i.imgur.com/placeholder.png)

```
claude-sonnet-4-6  📁 my-project  [█████░░░░░░░░░░]  34.7%  ↑45.2k ↓8.9k  $0.0823
```

---

## What it shows

| Component | Example | Description |
|-----------|---------|-------------|
| **Model** | `claude-sonnet-4-6` | Active Claude model name |
| **Repo** | `📁 my-project` | Current working directory (folder name or full path) |
| **Progress bar** | `[█████░░░░░░░░░░]` | Context window usage — green → yellow → red |
| **Context %** | `34.7%` | Exact percentage of context window used |
| **Tokens** | `↑45.2k ↓8.9k` | Cumulative input and output tokens for the session |
| **Cost** | `$0.0823` | Running session cost in USD |

---

## Installation

**1. Copy the script and settings file to your Claude config directory:**

```bash
cp statusline.py ~/.claude/statusline.py
cp statusline-settings.json ~/.claude/statusline-settings.json
chmod +x ~/.claude/statusline.py
```

**2. Add the `statusLine` entry to `~/.claude/settings.json`:**

```json
{
  "statusLine": {
    "type": "command",
    "command": "python3 ~/.claude/statusline.py"
  }
}
```

If `settings.json` already has other keys, just add the `statusLine` block alongside them.

**3. Start (or restart) Claude Code.** The status line appears at the bottom of the terminal and updates after each response.

### Requirements

- Python 3 (standard library only — no pip installs needed)
- Claude Code CLI

---

## Customization

All customization happens in `~/.claude/statusline-settings.json`. Changes take effect immediately on the next Claude Code response — no restart needed.

### Show / hide components

The `components` array controls which items appear and in what order. Remove any entry to hide it:

```json
{
  "components": ["model", "repo", "context_bar", "context_percent", "tokens", "cost"]
}
```

Or disable a component without removing it from the list:

```json
{
  "tokens": { "enabled": false }
}
```

### Colors

Every component accepts a `color` key. Available values:

```
black  red  green  yellow  blue  magenta  cyan  white
bright_black  bright_red  bright_green  bright_yellow
bright_blue   bright_magenta  bright_cyan  bright_white
none  (disables color)
```

Example — make the model name bright green and bold:

```json
{
  "model": { "color": "bright_green", "bold": true }
}
```

### Progress bar styles

```json
{
  "context_bar": {
    "style": "block"
  }
}
```

| Style | Preview |
|-------|---------|
| `"block"` (default) | `[█████░░░░░░░░░░]` |
| `"shade"` | `[▓▓▓▓▓░░░░░░░░░░]` |
| `"ascii"` | `[=====----------]` |
| `"thin"` | `[━━━━━╌╌╌╌╌╌╌╌╌╌]` |

You can also set custom characters:

```json
{
  "context_bar": {
    "filled_char": "▮",
    "empty_char":  "▯"
  }
}
```

### Bar color thresholds

The bar changes color based on how full the context window is:

```json
{
  "context_bar": {
    "low_threshold":  50,
    "high_threshold": 80,
    "color_low":    "green",
    "color_medium": "yellow",
    "color_high":   "red"
  }
}
```

### Token format

```json
{
  "tokens": {
    "format": "compact"
  }
}
```

| Format | Output |
|--------|--------|
| `"compact"` (default) | `↑45.2k ↓8.9k` |
| `"verbose"` | `in:45231 out:8902` |

### Other options

```json
{
  "separator": "  ",

  "repo": {
    "show_full_path": false,
    "prefix": "📁 "
  },

  "cost": {
    "decimal_places": 4,
    "prefix": "$"
  },

  "context_percent": {
    "decimal_places": 1
  }
}
```

---

## Full settings reference

```json
{
  "components": ["model", "repo", "context_bar", "context_percent", "tokens", "cost"],
  "separator": "  ",

  "model": {
    "enabled": true,
    "color": "cyan",
    "bold": true
  },

  "repo": {
    "enabled": true,
    "color": "bright_blue",
    "bold": false,
    "show_full_path": false,
    "prefix": "📁 "
  },

  "context_bar": {
    "enabled": true,
    "width": 15,
    "style": "block",
    "filled_char": "█",
    "empty_char": "░",
    "low_threshold": 50,
    "high_threshold": 80,
    "color_low": "green",
    "color_medium": "yellow",
    "color_high": "red",
    "brackets": true
  },

  "context_percent": {
    "enabled": true,
    "color": "white",
    "decimal_places": 1
  },

  "tokens": {
    "enabled": true,
    "color": "bright_black",
    "show_input": true,
    "show_output": true,
    "format": "compact"
  },

  "cost": {
    "enabled": true,
    "color": "magenta",
    "bold": false,
    "prefix": "$",
    "decimal_places": 4
  }
}
```

---

## Testing the script

You can test the script without running Claude Code by piping sample JSON:

```bash
echo '{
  "model": {"display_name": "claude-sonnet-4-6"},
  "cwd": "/Users/me/my-project",
  "context_window": {
    "used_percentage": 34.7,
    "total_input_tokens": 45231,
    "total_output_tokens": 8902
  },
  "cost": {"total_cost_usd": 0.0823}
}' | python3 ~/.claude/statusline.py
```

---

## How it works

Claude Code pipes a JSON object to the script on stdin after each response. The script reads it, loads your settings, renders each enabled component with ANSI color codes, and prints a single line to stdout — which Claude Code displays at the bottom of the terminal.

The JSON fields used:

| Field | Used for |
|-------|----------|
| `model.display_name` | Model name |
| `cwd` | Repo folder |
| `context_window.used_percentage` | Progress bar and percentage |
| `context_window.total_input_tokens` | Input token count |
| `context_window.total_output_tokens` | Output token count |
| `cost.total_cost_usd` | Session cost |

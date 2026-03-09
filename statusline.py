#!/usr/bin/env python3
"""
Claude Code status line script.
Reads JSON session data from stdin, renders a configurable status bar.

Settings file: ~/.claude/statusline-settings.json
"""

import json
import os
import sys

# ---------------------------------------------------------------------------
# ANSI helpers
# ---------------------------------------------------------------------------

ANSI = {
    "reset":          "\033[0m",
    "bold":           "\033[1m",
    "dim":            "\033[2m",
    # standard foreground
    "black":          "\033[30m",
    "red":            "\033[31m",
    "green":          "\033[32m",
    "yellow":         "\033[33m",
    "blue":           "\033[34m",
    "magenta":        "\033[35m",
    "cyan":           "\033[36m",
    "white":          "\033[37m",
    # bright foreground
    "bright_black":   "\033[90m",
    "bright_red":     "\033[91m",
    "bright_green":   "\033[92m",
    "bright_yellow":  "\033[93m",
    "bright_blue":    "\033[94m",
    "bright_magenta": "\033[95m",
    "bright_cyan":    "\033[96m",
    "bright_white":   "\033[97m",
}


def c(text: str, color: str = "", bold: bool = False) -> str:
    """Wrap text in ANSI color codes. color='' or 'none' means no color."""
    if not color or color == "none":
        return f"{ANSI['bold']}{text}{ANSI['reset']}" if bold else text
    code = ANSI.get(color, "")
    bold_code = ANSI["bold"] if bold else ""
    return f"{bold_code}{code}{text}{ANSI['reset']}"


# ---------------------------------------------------------------------------
# Default settings
# ---------------------------------------------------------------------------

DEFAULTS = {
    # Ordered list of components to display. Remove or reorder to customize.
    # Valid values: "model", "repo", "context_bar", "context_percent",
    #               "tokens", "cost"
    "components": ["model", "repo", "context_bar", "context_percent", "tokens", "cost"],

    # String inserted between each component
    "separator": "  ",

    # ---- Per-component config ----

    "model": {
        "enabled": True,
        # Any ANSI key from the list above, or "none" for no color
        "color": "cyan",
        "bold": True,
    },

    "repo": {
        "enabled": True,
        "color": "bright_blue",
        "bold": False,
        # True  → show full path, False → show only the folder name
        "show_full_path": False,
        "prefix": "📁 ",
    },

    "context_bar": {
        "enabled": True,
        # Number of characters wide the progress bar should be
        "width": 15,
        # "block"  → uses █ / ░
        # "shade"  → uses ▓ / ░
        # "ascii"  → uses = / -  (safe for all terminals)
        # "thin"   → uses ━ / ╌  (requires unicode)
        "style": "block",
        # Characters used for filled / empty sections (ignored when style != "block"/"shade")
        "filled_char": "█",
        "empty_char":  "░",
        # Color thresholds (percentage)
        "low_threshold":  50,
        "high_threshold": 80,
        # Colors applied based on which threshold the current value crosses
        "color_low":    "green",
        "color_medium": "yellow",
        "color_high":   "red",
        # Wrap bar in square brackets
        "brackets": True,
    },

    "context_percent": {
        "enabled": True,
        "color": "white",
        "decimal_places": 1,
    },

    "tokens": {
        "enabled": True,
        "color": "bright_black",
        # Show cumulative input / output token counts
        "show_input":  True,
        "show_output": True,
        # "compact"  → "↑12.3k ↓4.5k"
        # "verbose"  → "in:12345 out:4567"
        "format": "compact",
    },

    "cost": {
        "enabled": True,
        "color": "magenta",
        "bold": False,
        "prefix": "$",
        "decimal_places": 4,
    },
}


# ---------------------------------------------------------------------------
# Settings loader
# ---------------------------------------------------------------------------

def _deep_merge(base: dict, override: dict) -> dict:
    """Recursively merge override into a copy of base."""
    result = dict(base)
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = _deep_merge(result[k], v)
        else:
            result[k] = v
    return result


def load_settings() -> dict:
    path = os.path.expanduser("~/.claude/statusline-settings.json")
    if not os.path.exists(path):
        return DEFAULTS
    try:
        with open(path) as fh:
            user = json.load(fh)
        return _deep_merge(DEFAULTS, user)
    except Exception:
        return DEFAULTS


# ---------------------------------------------------------------------------
# Component renderers
# ---------------------------------------------------------------------------

def _pick_threshold_color(pct: float, cfg: dict) -> str:
    if pct >= cfg.get("high_threshold", 80):
        return cfg.get("color_high", "red")
    if pct >= cfg.get("low_threshold", 50):
        return cfg.get("color_medium", "yellow")
    return cfg.get("color_low", "green")


def _fmt_tokens(n: int, fmt: str) -> str:
    if fmt == "verbose":
        return str(n)
    # compact: abbreviate with k/m suffix
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}m"
    if n >= 1_000:
        return f"{n / 1_000:.1f}k"
    return str(n)


# --- model ---

def render_model(data: dict, cfg: dict) -> str | None:
    if not cfg.get("enabled", True):
        return None
    name = (data.get("model") or {}).get("display_name") or "?"
    return c(name, cfg.get("color", "cyan"), bold=cfg.get("bold", True))


# --- repo ---

def render_repo(data: dict, cfg: dict) -> str | None:
    if not cfg.get("enabled", True):
        return None
    cwd = (
        data.get("cwd")
        or (data.get("workspace") or {}).get("current_dir")
        or ""
    )
    if not cwd:
        return None
    label = cwd if cfg.get("show_full_path", False) else os.path.basename(cwd)
    prefix = cfg.get("prefix", "")
    return c(f"{prefix}{label}", cfg.get("color", "bright_blue"), bold=cfg.get("bold", False))


# --- context_bar ---

def render_context_bar(data: dict, cfg: dict) -> str | None:
    if not cfg.get("enabled", True):
        return None

    cw = data.get("context_window") or {}
    pct = float(cw.get("used_percentage") or 0)
    width = int(cfg.get("width", 15))
    style = cfg.get("style", "block")

    filled_count = round(pct * width / 100)
    empty_count  = width - filled_count

    if style == "ascii":
        filled_char, empty_char = "=", "-"
    elif style == "shade":
        filled_char, empty_char = "▓", "░"
    elif style == "thin":
        filled_char, empty_char = "━", "╌"
    else:  # block (default)
        filled_char = cfg.get("filled_char", "█")
        empty_char  = cfg.get("empty_char",  "░")

    bar_color   = _pick_threshold_color(pct, cfg)
    filled_part = c(filled_char * filled_count, bar_color)
    empty_part  = c(empty_char  * empty_count,  "bright_black")
    bar         = filled_part + empty_part

    if cfg.get("brackets", True):
        bar = f"[{bar}]"

    return bar


# --- context_percent ---

def render_context_percent(data: dict, cfg: dict) -> str | None:
    if not cfg.get("enabled", True):
        return None
    cw = data.get("context_window") or {}
    pct = float(cw.get("used_percentage") or 0)
    dec = int(cfg.get("decimal_places", 1))
    return c(f"{pct:.{dec}f}%", cfg.get("color", "white"))


# --- tokens ---

def render_tokens(data: dict, cfg: dict) -> str | None:
    if not cfg.get("enabled", True):
        return None
    cw  = data.get("context_window") or {}
    fmt = cfg.get("format", "compact")

    parts = []
    if cfg.get("show_input", True):
        n = int(cw.get("total_input_tokens") or 0)
        label = "in:" if fmt == "verbose" else "↑"
        parts.append(f"{label}{_fmt_tokens(n, fmt)}")
    if cfg.get("show_output", True):
        n = int(cw.get("total_output_tokens") or 0)
        label = "out:" if fmt == "verbose" else "↓"
        parts.append(f"{label}{_fmt_tokens(n, fmt)}")

    if not parts:
        return None
    return c(" ".join(parts), cfg.get("color", "bright_black"))


# --- cost ---

def render_cost(data: dict, cfg: dict) -> str | None:
    if not cfg.get("enabled", True):
        return None
    cost = float((data.get("cost") or {}).get("total_cost_usd") or 0)
    dec    = int(cfg.get("decimal_places", 4))
    prefix = cfg.get("prefix", "$")
    return c(f"{prefix}{cost:.{dec}f}", cfg.get("color", "magenta"), bold=cfg.get("bold", False))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

RENDERERS = {
    "model":           render_model,
    "repo":            render_repo,
    "context_bar":     render_context_bar,
    "context_percent": render_context_percent,
    "tokens":          render_tokens,
    "cost":            render_cost,
}


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        print("⚠ status line: bad JSON")
        return

    settings  = load_settings()
    order     = settings.get("components", list(RENDERERS.keys()))
    separator = settings.get("separator", "  ")

    parts = []
    for name in order:
        renderer = RENDERERS.get(name)
        if renderer is None:
            continue
        cfg = settings.get(name, {})
        # Top-level "enabled" can also be toggled inside the per-component block
        try:
            result = renderer(data, cfg)
        except Exception:
            result = None
        if result:
            parts.append(result)

    print(separator.join(parts))


if __name__ == "__main__":
    main()

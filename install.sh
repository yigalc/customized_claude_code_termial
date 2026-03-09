#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude Code Custom Status Line — Installer
# https://github.com/yigalc/customized_claude_code_termial
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/yigalc/customized_claude_code_termial/main"

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m';  BOLD='\033[1m'; DIM='\033[2m'
RESET='\033[0m'

# ─── Output helpers ───────────────────────────────────────────────────────────
info()    { echo -e "  ${CYAN}→${RESET} $*"; }
success() { echo -e "  ${GREEN}${BOLD}✓${RESET} $*"; }
warn()    { echo -e "  ${YELLOW}!${RESET} $*"; }
error()   { echo -e "\n  ${RED}${BOLD}✗ Error:${RESET} $*\n" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${BLUE}$*${RESET}"; echo -e "${DIM}$(printf '─%.0s' {1..60})${RESET}"; }

# ─── Help ─────────────────────────────────────────────────────────────────────
show_help() {
  echo ""
  echo -e "${BOLD}Usage:${RESET}  bash install.sh [OPTIONS]"
  echo ""
  echo -e "${BOLD}Options:${RESET}"
  echo -e "  ${BOLD}-l, --local${RESET}    Install into ./.claude/ (current project only)"
  echo -e "  ${BOLD}-g, --global${RESET}   Install into ~/.claude/ (all Claude Code sessions)"
  echo -e "  ${BOLD}-h, --help${RESET}     Show this help message"
  echo ""
  echo -e "${BOLD}Without flags:${RESET} the installer will ask you to choose."
  echo ""
}

# ─── Parse args ───────────────────────────────────────────────────────────────
INSTALL_MODE=""
for arg in "$@"; do
  case $arg in
    --global|-g) INSTALL_MODE="global" ;;
    --local|-l)  INSTALL_MODE="local"  ;;
    --help|-h)   show_help; exit 0     ;;
    *) error "Unknown option: $arg  (run with --help to see usage)" ;;
  esac
done

# ─── Banner ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}  ╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}  ║     Claude Code Custom Status Line Installer     ║${RESET}"
echo -e "${BOLD}${CYAN}  ╚══════════════════════════════════════════════════╝${RESET}"
echo ""

# ─── Pre-flight checks ────────────────────────────────────────────────────────
header "Checking requirements"
command -v python3 >/dev/null 2>&1 \
  && success "python3 found: $(python3 --version)" \
  || error "python3 is required but was not found. Please install Python 3."

if command -v curl >/dev/null 2>&1; then
  DOWNLOADER="curl"
  success "curl found"
elif command -v wget >/dev/null 2>&1; then
  DOWNLOADER="wget"
  success "wget found"
else
  error "curl or wget is required to download files."
fi

# ─── Download helper ──────────────────────────────────────────────────────────
download() {
  local url="$1" dest="$2"
  if [[ "$DOWNLOADER" == "curl" ]]; then
    curl -fsSL "$url" -o "$dest"
  else
    wget -q "$url" -O "$dest"
  fi
}

# ─── Choose install mode ──────────────────────────────────────────────────────
if [[ -z "$INSTALL_MODE" ]]; then
  header "Where do you want to install?"
  echo ""
  echo -e "  ${BOLD}1) Local${RESET}  — installs into ${BOLD}./.claude/${RESET} in the current directory"
  echo -e "           only affects Claude Code sessions opened in this folder"
  echo -e "           ${DIM}ideal for per-project customization or trying it out${RESET}"
  echo ""
  echo -e "  ${BOLD}2) Global${RESET} — installs into ${BOLD}~/.claude/${RESET}"
  echo -e "           applies to every Claude Code session for your user account"
  echo -e "           ${DIM}recommended once you're happy with the setup${RESET}"
  echo ""
  while true; do
    read -rp "  Enter 1 or 2: " choice
    case "$choice" in
      1) INSTALL_MODE="local";  break ;;
      2) INSTALL_MODE="global"; break ;;
      *) warn "Please enter 1 or 2." ;;
    esac
  done
fi

# ─── Resolve paths ────────────────────────────────────────────────────────────
if [[ "$INSTALL_MODE" == "global" ]]; then
  INSTALL_DIR="$HOME/.claude"
  SETTINGS_FILE="$HOME/.claude/settings.json"
  SCRIPT_CMD="python3 ~/.claude/statusline.py"
  SETTINGS_DISPLAY="~/.claude/statusline-settings.json"
else
  INSTALL_DIR="$(pwd)/.claude"
  SETTINGS_FILE="$(pwd)/.claude/settings.json"
  SCRIPT_CMD="python3 ${INSTALL_DIR}/statusline.py"
  SETTINGS_DISPLAY=".claude/statusline-settings.json"
fi

echo ""
info "Mode    : ${BOLD}$INSTALL_MODE${RESET}"
info "Install : ${BOLD}$INSTALL_DIR${RESET}"
info "Settings: ${BOLD}$SETTINGS_FILE${RESET}"

# ─── Create directory ─────────────────────────────────────────────────────────
header "Installing files"
mkdir -p "$INSTALL_DIR"
success "Directory ready: $INSTALL_DIR"

# ─── Download statusline.py ───────────────────────────────────────────────────
info "Downloading statusline.py ..."
download "$REPO_RAW/statusline.py" "$INSTALL_DIR/statusline.py"
chmod +x "$INSTALL_DIR/statusline.py"
success "statusline.py  (executable)"

# ─── Download statusline-settings.json (never overwrite user settings) ────────
SETTINGS_JSON="$INSTALL_DIR/statusline-settings.json"
if [[ -f "$SETTINGS_JSON" ]]; then
  warn "statusline-settings.json already exists — skipping to preserve your settings"
  warn "To reset to defaults: rm \"$SETTINGS_JSON\" and re-run the installer"
else
  info "Downloading statusline-settings.json ..."
  download "$REPO_RAW/statusline-settings.json" "$SETTINGS_JSON"
  success "statusline-settings.json"
fi

# ─── Patch settings.json ──────────────────────────────────────────────────────
header "Updating settings.json"

# Use env vars so special chars in paths don't break the python heredoc
result=$(SETTINGS_PATH="$SETTINGS_FILE" STATUS_CMD="$SCRIPT_CMD" python3 <<'PYEOF'
import json, os, shutil

path = os.environ["SETTINGS_PATH"]
cmd  = os.environ["STATUS_CMD"]

# Create file and parent dir if they don't exist
if not os.path.exists(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = {}
else:
    with open(path) as f:
        content = f.read().strip()
    data = json.loads(content) if content else {}

# Backup before touching
if os.path.exists(path):
    shutil.copy(path, path + ".bak")

if "statusLine" in data:
    print("EXISTS")
else:
    data["statusLine"] = {"type": "command", "command": cmd}
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("UPDATED")
PYEOF
)

case "$result" in
  UPDATED)
    success "statusLine entry added to settings.json"
    info "A backup was saved to ${SETTINGS_FILE}.bak"
    ;;
  EXISTS)
    warn "A statusLine entry already exists in settings.json — not overwritten"
    warn "To update it, set: \"command\": \"$SCRIPT_CMD\""
    ;;
  *)
    error "Unexpected error while updating settings.json"
    ;;
esac

# ─── Quick smoke-test ─────────────────────────────────────────────────────────
header "Smoke test"
TEST_OUTPUT=$(echo '{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"'"$INSTALL_DIR"'","context_window":{"used_percentage":25.0,"total_input_tokens":50000,"total_output_tokens":5000},"cost":{"total_cost_usd":0.042}}' \
  | python3 "$INSTALL_DIR/statusline.py" 2>&1) && STATUS=0 || STATUS=1

if [[ $STATUS -eq 0 ]]; then
  success "Script ran successfully. Preview:"
  echo ""
  echo -e "    $TEST_OUTPUT"
  echo ""
else
  warn "Smoke test failed. Output:"
  echo "    $TEST_OUTPUT"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
header "All done!"
echo ""
echo -e "  Restart Claude Code and the status line will appear at the bottom"
echo -e "  of your terminal. It updates automatically after each response."
echo ""

# ─── Configuration guide ──────────────────────────────────────────────────────
echo -e "${BOLD}${BLUE}  ╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${BLUE}  ║              Quick Configuration Guide           ║${RESET}"
echo -e "${BOLD}${BLUE}  ╚══════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  Your settings file:"
echo -e "  ${BOLD}${CYAN}$SETTINGS_JSON${RESET}"
echo ""
echo -e "  Changes take effect immediately — no restart needed."
echo ""

echo -e "  ${BOLD}◆ Show / hide components${RESET}"
echo -e "  ${DIM}Edit the \"components\" array to control what appears and in what order:${RESET}"
cat <<'GUIDE'
    "components": ["model", "repo", "context_bar", "context_percent", "tokens", "cost"]

    Remove any name to hide it, or set "enabled": false inside the block:
    "tokens": { "enabled": false }

GUIDE

echo -e "  ${BOLD}◆ Colors${RESET}"
echo -e "  ${DIM}Any component accepts a \"color\" key:${RESET}"
cat <<'GUIDE'
    "model": { "color": "bright_green", "bold": true }

    Available colors:
    red  green  yellow  blue  magenta  cyan  white  black
    bright_red  bright_green  bright_yellow  bright_blue
    bright_magenta  bright_cyan  bright_white  bright_black
    "none" → disables color for that component

GUIDE

echo -e "  ${BOLD}◆ Progress bar style${RESET}"
cat <<'GUIDE'
    "context_bar": { "style": "block" }  →  [█████░░░░░░░░░░]
    "context_bar": { "style": "shade" }  →  [▓▓▓▓▓░░░░░░░░░░]
    "context_bar": { "style": "ascii" }  →  [=====----------]  (safest for all terminals)
    "context_bar": { "style": "thin"  }  →  [━━━━━╌╌╌╌╌╌╌╌╌╌]

    Custom characters:
    "context_bar": { "filled_char": "▮", "empty_char": "▯" }

GUIDE

echo -e "  ${BOLD}◆ Bar color thresholds${RESET}"
cat <<'GUIDE'
    "context_bar": {
      "low_threshold":  50,   "color_low":    "green",
      "high_threshold": 80,   "color_high":   "red",
                              "color_medium":  "yellow"
    }

GUIDE

echo -e "  ${BOLD}◆ Token display format${RESET}"
cat <<'GUIDE'
    "tokens": { "format": "compact" }  →  ↑45.2k ↓8.9k
    "tokens": { "format": "verbose" }  →  in:45231 out:8902

GUIDE

echo -e "  ${BOLD}◆ Other useful options${RESET}"
cat <<'GUIDE'
    "separator": " │ "                     change the divider between items
    "repo":    { "show_full_path": true }  show full path instead of folder name
    "repo":    { "prefix": "» " }         change the icon/prefix
    "cost":    { "decimal_places": 2 }    fewer digits on cost
    "context_percent": { "decimal_places": 0 }  whole-number percentage

GUIDE

echo -e "  ${BOLD}◆ Test the script without opening Claude Code${RESET}"
echo ""
echo -e "  ${DIM}Paste this into your terminal:${RESET}"
echo ""
printf "  python3 %s/statusline.py <<'EOF'\n" "$INSTALL_DIR"
cat <<'GUIDE'
  {"model":{"display_name":"claude-sonnet-4-6"},"cwd":"/your/project",
   "context_window":{"used_percentage":60,"total_input_tokens":120000,"total_output_tokens":9000},
   "cost":{"total_cost_usd":0.45}}
  EOF
GUIDE

echo ""
echo -e "  ${DIM}Full docs and source: ${CYAN}https://github.com/yigalc/customized_claude_code_termial${RESET}"
echo ""

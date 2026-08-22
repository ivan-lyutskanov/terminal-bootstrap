#!/usr/bin/env bash
set -euo pipefail

# Absolute path to this clone. Everything the installer writes stays inside it,
# so there is nothing to copy into ~/.config and nothing to go stale in two
# places. Resolving from BASH_SOURCE means any clone location works.
TB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

if [ ! -f "$TB_ROOT/shell/init.sh" ]; then
    echo "This installer runs from a clone, not from a pipe." >&2
    echo "" >&2
    echo "  git clone --depth 1 https://github.com/ivan-lyutskanov/terminal-bootstrap.git ~/.terminal-bootstrap" >&2
    echo "  ~/.terminal-bootstrap/bootstrap.sh" >&2
    exit 1
fi

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${BLUE}==> Starting Dev Setup Bootstrap...${NC}"

# Helper function to check command existence
is_installed() {
    command -v "$1" &> /dev/null
}

# Determine shell RC file early (needed for brew PATH persistence)
SHELL_RC="$HOME/.zshrc"
[[ "$SHELL" == *"/bash"* ]] && SHELL_RC="$HOME/.bashrc"

# 1. Package Manager Setup
if ! is_installed brew; then
    echo -e "${BLUE}==> Installing Homebrew...${NC}"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # After install, detect brew binary and configure PATH for the running shell
    for BREW_BIN in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        if [ -x "$BREW_BIN" ]; then
            eval "$("$BREW_BIN" shellenv)"
            # Persist to shell RC so future sessions also find brew
            if ! grep -q 'brew shellenv' "$SHELL_RC" 2>/dev/null; then
                {
                    echo ''
                    echo '# Homebrew'
                    echo "eval \"\$($BREW_BIN shellenv)\""
                } >> "$SHELL_RC"
            fi
            break
        fi
    done
fi

# 2. Update Homebrew before installing tools
echo -e "${BLUE}==> Updating Homebrew...${NC}"
brew update

# 3. Core TUI Tools Installation
echo -e "${BLUE}==> Checking and installing TUI tools...${NC}"

FAILED_TOOLS=""
for tool in micro yazi lazygit atuin node herdr hunk opencode; do
    if is_installed "$tool"; then
        echo -e "${YELLOW}  - $tool is already installed. Skipping.${NC}"
        continue
    fi
    # Installed one at a time so a single unavailable formula does not abort
    # the rest of setup. Failures are collected and reported at the end.
    if brew install "$tool"; then
        echo -e "${GREEN}  - installed $tool${NC}"
    else
        echo -e "${YELLOW}  - FAILED to install $tool (continuing)${NC}"
        FAILED_TOOLS="$FAILED_TOOLS $tool"
    fi
done

# 4. Set Micro as Default Editor
if ! grep -q 'EDITOR="micro"' "$SHELL_RC" 2>/dev/null; then
    echo -e "${BLUE}==> Configuring Micro as default editor in $SHELL_RC...${NC}"
    {
      echo ''
      echo '# Custom Editor Settings'
      echo 'export EDITOR="micro"'
      echo 'export VISUAL="micro"'
      echo 'alias vim="micro"'
    } >> "$SHELL_RC"
    export EDITOR="micro"
    export VISUAL="micro"
fi

# 5. Atuin Directory-Scoped History Setup
mkdir -p "$HOME/.config/atuin"

# Only write config if it doesn't already exist (idempotent)
if [ ! -f "$HOME/.config/atuin/config.toml" ]; then
    cat << 'EOF' > "$HOME/.config/atuin/config.toml"
search_mode = "prefix"
filter_mode_shell_up_key_binding = "directory"
style = "compact"
inline_height = 20
EOF
fi

if ! grep -q "atuin init" "$SHELL_RC" 2>/dev/null; then
    echo -e "${BLUE}==> Wiring Atuin into shell environment...${NC}"
    # Directory scoping comes from filter_mode_shell_up_key_binding in config.toml.
    # Do NOT pass --disable-up-arrow and rebind manually: atuin's own init binds
    # ^[[A and ^[OA across the emacs, viins and vicmd keymaps. Overriding it with a
    # single bindkey loses application-mode arrows and every vi keymap binding.
    if [[ "$SHELL" == *"/bash"* ]]; then
        echo 'eval "$(atuin init bash)"' >> "$SHELL_RC"
    else
        echo 'eval "$(atuin init zsh)"' >> "$SHELL_RC"
    fi
fi

echo -e "${GREEN}==> Setup complete.${NC}"
if [ -n "$FAILED_TOOLS" ]; then
    echo -e "${YELLOW}    These tools failed to install:${FAILED_TOOLS}${NC}"
    echo -e "${YELLOW}    Re-run this script to retry them.${NC}"
fi
echo -e ""
echo -e "  Restart your shell, or: ${YELLOW}source $SHELL_RC${NC}"
echo -e "  Guide: ${YELLOW}$TB_ROOT/docs/GUIDE.md${NC}"
echo -e "  Repo:  ${YELLOW}https://github.com/ivan-lyutskanov/terminal-bootstrap${NC}"
echo -e ""

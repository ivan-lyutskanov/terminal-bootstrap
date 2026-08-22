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

# Determine shell RC file early (needed for the source-line append below).
# macOS bash reads .bash_profile for login shells and never sources .bashrc
# by default, so writing to .bashrc there would silently do nothing.
SHELL_RC="$HOME/.zshrc"
if [[ "$SHELL" == *"/bash"* ]]; then
    if [[ "$OSTYPE" == darwin* ]]; then
        SHELL_RC="$HOME/.bash_profile"
    else
        SHELL_RC="$HOME/.bashrc"
    fi
fi

# Homebrew on Linux needs these before its installer will succeed.
if [[ "$OSTYPE" != darwin* ]] && ! is_installed brew; then
    MISSING=""
    for dep in curl git file; do
        is_installed "$dep" || MISSING="$MISSING $dep"
    done
    if [ -n "$MISSING" ]; then
        echo "Homebrew on Linux needs these packages first:$MISSING" >&2
        echo "  Debian/Ubuntu: sudo apt-get install -y build-essential procps curl file git" >&2
        echo "  Fedora:        sudo dnf groupinstall -y 'Development Tools' && sudo dnf install -y procps-ng curl file git" >&2
        exit 1
    fi
fi

# 1. Package Manager Setup
if ! is_installed brew; then
    echo -e "${BLUE}==> Installing Homebrew...${NC}"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # After install, detect brew binary and configure PATH for the running shell
    for BREW_BIN in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        if [ -x "$BREW_BIN" ]; then
            eval "$("$BREW_BIN" shellenv)"
            break
        fi
    done
fi

# 2. Update Homebrew before installing tools
echo -e "${BLUE}==> Updating Homebrew...${NC}"
brew update

# 3. Core tool installation. Driven by the Brewfile, but installed one at a
# time: `brew bundle` aborts on first failure, which would skip the rest of setup.
echo -e "${BLUE}==> Installing tools from Brewfile...${NC}"

FAILED_TOOLS=""
# Input is read from fd 3, not stdin: `brew install` in the loop body would
# otherwise inherit the Brewfile as its own stdin, and if any install ever
# reads from stdin (a caveat, a prompt) it would silently consume the rest
# of the Brewfile and skip subsequent formulae. fd 3 leaves stdin pointing
# at the real terminal so a genuine prompt can still be answered by whoever
# is running this interactively.
# `|| [ -n "$line" ]` guards against a Brewfile without a trailing newline:
# `read` fails on that last, newline-less line but still populates $line, and
# without this the last formula would be silently dropped.
while IFS= read -r line <&3 || [ -n "$line" ]; do
    case "$line" in
        brew\ *) ;;
        *) continue ;;
    esac
    tool=$(printf '%s\n' "$line" | sed -n 's/^brew "\([^"]*\)".*/\1/p')
    [ -n "$tool" ] || continue

    if is_installed "$tool"; then
        echo -e "${YELLOW}  - $tool already installed${NC}"
    elif brew install "$tool"; then
        echo -e "${GREEN}  - installed $tool${NC}"
    else
        echo -e "${YELLOW}  - FAILED to install $tool (continuing)${NC}"
        FAILED_TOOLS="$FAILED_TOOLS $tool"
    fi
done 3< "$TB_ROOT/Brewfile"

# 4. Wire the shell configuration in with a single sourced line.
SOURCE_LINE="[ -f \"$TB_ROOT/shell/init.sh\" ] && . \"$TB_ROOT/shell/init.sh\""
if ! grep -qF "$SOURCE_LINE" "$SHELL_RC" 2>/dev/null; then
    echo -e "${BLUE}==> Adding terminal-bootstrap to $SHELL_RC...${NC}"
    {
        echo ''
        echo '# terminal-bootstrap'
        echo "$SOURCE_LINE"
    } >> "$SHELL_RC"
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

# 6. Review workflow: hunk-review-pane on PATH, plus agent skills.
echo -e "${BLUE}==> Installing review workflow...${NC}"

mkdir -p "$HOME/.local/bin"
ln -sfn "$TB_ROOT/bin/hunk-review-pane" "$HOME/.local/bin/hunk-review-pane"

SKILLS_DIR="$HOME/.config/opencode/skills"
mkdir -p "$SKILLS_DIR"
ln -sfn "$TB_ROOT/skills/hunk-review-pane" "$SKILLS_DIR/hunk-review-pane"

# hunk generates its own skill from source metadata, so symlink it rather than
# writing a copy that would drift on the next hunk release.
if is_installed hunk; then
    HUNK_SKILL="$(hunk skill path 2>/dev/null || true)"
    if [ -n "$HUNK_SKILL" ] && [ -f "$HUNK_SKILL" ]; then
        mkdir -p "$SKILLS_DIR/hunk-review"
        ln -sfn "$HUNK_SKILL" "$SKILLS_DIR/hunk-review/SKILL.md"
    fi
fi

# Let herdr track opencode's agent state in the pane UI.
if is_installed herdr && is_installed opencode; then
    herdr integration install opencode >/dev/null 2>&1 || true
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

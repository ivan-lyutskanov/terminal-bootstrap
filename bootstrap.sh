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

# 2. Update Homebrew before installing tools. Conditional, because the formula
# index moves slowly and a fetch is the slowest step here, and non-fatal, because
# under `set -e` a failed update (broken tap, flaky network) would abort the whole
# installer before a single formula was installed.
BREW_REPO="$(brew --repo 2>/dev/null || true)"
if [ -n "$BREW_REPO" ] && [ -n "$(find "$BREW_REPO/.git/FETCH_HEAD" -mtime -1 2>/dev/null)" ]; then
    echo -e "${YELLOW}==> Homebrew updated within the last day, skipping brew update${NC}"
else
    echo -e "${BLUE}==> Updating Homebrew...${NC}"
    brew update || echo -e "${YELLOW}  - brew update failed; continuing with the current formula index${NC}"
fi

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

# Only write config if it doesn't already exist: an existing atuin config is the
# user's, not ours. But someone upgrading from an older install already has one
# containing the wrong key, so say so at the end rather than silently doing nothing.
ATUIN_NEEDS_KEY=0
if [ ! -f "$HOME/.config/atuin/config.toml" ]; then
    cat << 'EOF' > "$HOME/.config/atuin/config.toml"
search_mode = "prefix"
filter_mode_shell_up_key_binding = "directory"
style = "compact"
inline_height = 20
EOF
elif ! grep -q 'filter_mode_shell_up_key_binding' "$HOME/.config/atuin/config.toml"; then
    ATUIN_NEEDS_KEY=1
fi

# 6. Review workflow: hunk-review-pane on PATH, plus agent skills.
echo -e "${BLUE}==> Installing review workflow...${NC}"

# `ln -sfn` swaps an existing symlink atomically, which is what a re-run needs.
# Against a real file or directory it does something else entirely: it links
# *inside* the destination, producing ~/.local/bin/hunk-review-pane/hunk-review-pane
# and leaving the stale copy in place, still shadowing us. So a non-symlink has to
# get out of the way -- moved to $3, never deleted: nothing here proves the thing
# in the way is a leftover of ours rather than something you wrote by hand. If the
# parking spot is taken too, touch neither and say so.
relink() {
    if [ -e "$2" ] && [ ! -L "$2" ]; then
        if [ -e "$3" ]; then
            echo -e "${YELLOW}  - $2 is in the way and $3 already exists; left both alone${NC}"
            return 0
        elif mv "$2" "$3" 2>/dev/null; then
            echo -e "${YELLOW}  - moved $2 aside to $3${NC}"
        else
            echo -e "${YELLOW}  - $2 is in the way and could not be moved; left it alone${NC}"
            return 0
        fi
    fi
    ln -sfn "$1" "$2"
}

mkdir -p "$HOME/.local/bin"
relink "$TB_ROOT/bin/hunk-review-pane" "$HOME/.local/bin/hunk-review-pane" \
       "$HOME/.local/bin/hunk-review-pane.disabled"

SKILLS_DIR="$HOME/.config/opencode/skills"
mkdir -p "$SKILLS_DIR"
# Parked one level above skills/, not beside it: opencode discovers a skill from
# skills/<name>/SKILL.md, so a hunk-review-pane.disabled/ left inside skills/ would
# still hold a live SKILL.md and come back as a duplicate. One level up is not scanned.
relink "$TB_ROOT/skills/hunk-review-pane" "$SKILLS_DIR/hunk-review-pane" \
       "$HOME/.config/opencode/hunk-review-pane.disabled"

# hunk generates its own skill from source metadata, so symlink it rather than
# writing a copy that would drift on the next hunk release.
HUNK_SKILL_MD="$SKILLS_DIR/hunk-review/SKILL.md"
HUNK_SKILL_LINKED=0
if is_installed hunk; then
    HUNK_SKILL="$(hunk skill path 2>/dev/null || true)"
    # `hunk skill path` resolves through the running binary, which brew keeps under
    # a versioned Cellar path. Linking that pins the skill to today's version and
    # dangles once `brew cleanup` removes it, so prefer the opt prefix, which brew
    # re-points on every upgrade.
    HUNK_OPT="$(brew --prefix hunk 2>/dev/null || true)"
    if [ -n "$HUNK_OPT" ] && [ -f "$HUNK_OPT/libexec/skills/hunk-review/SKILL.md" ]; then
        HUNK_SKILL="$HUNK_OPT/libexec/skills/hunk-review/SKILL.md"
    fi
    if [ -n "$HUNK_SKILL" ] && [ -f "$HUNK_SKILL" ]; then
        mkdir -p "$SKILLS_DIR/hunk-review"
        relink "$HUNK_SKILL" "$HUNK_SKILL_MD" "$HUNK_SKILL_MD.disabled"
        HUNK_SKILL_LINKED=1
    fi
fi

# An older version of this installer hand-wrote that SKILL.md, and its central rule
# is inverted: it tells the agent to drive hunk's TUI and stage with it, which hunk's
# own generated skill explicitly forbids. Whenever the symlink above did not land,
# that wrong file is still what the agent reads, so retire it. Renamed rather than
# deleted because nothing proves the file is ours -- skill discovery keys on the
# literal SKILL.md name, so a renamed file is inert but recoverable.
STALE_HUNK_SKILL=0
if [ "$HUNK_SKILL_LINKED" = 0 ] && [ -f "$HUNK_SKILL_MD" ] && [ ! -L "$HUNK_SKILL_MD" ]; then
    # Guarded, not bare: under `set -e` a failed mv would abort the installer here,
    # skipping the herdr step and the entire summary — including the notice below.
    if [ ! -e "$HUNK_SKILL_MD.disabled" ] && mv "$HUNK_SKILL_MD" "$HUNK_SKILL_MD.disabled" 2>/dev/null; then
        STALE_HUNK_SKILL=1
    else
        echo -e "${YELLOW}  - could not rename $HUNK_SKILL_MD; it may contain stale advice${NC}"
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
if [ "$STALE_HUNK_SKILL" = 1 ]; then
    echo -e "${YELLOW}    hunk's generated review skill could not be linked.${NC}"
    echo -e "${YELLOW}    An older install left a hand-written hunk-review skill whose staging${NC}"
    echo -e "${YELLOW}    advice contradicts hunk's own, so it was renamed out of the way:${NC}"
    echo -e "${YELLOW}      $HUNK_SKILL_MD.disabled${NC}"
    echo -e "${YELLOW}    Re-run this script once hunk installs to get the real skill.${NC}"
fi
if [ "$ATUIN_NEEDS_KEY" = 1 ]; then
    echo -e "${YELLOW}    Your existing ~/.config/atuin/config.toml was left untouched.${NC}"
    echo -e "${YELLOW}    Add  filter_mode_shell_up_key_binding = \"directory\"  to it for${NC}"
    echo -e "${YELLOW}    directory-scoped Up Arrow.${NC}"
fi
echo -e ""
echo -e "  Restart your shell, or: ${YELLOW}source $SHELL_RC${NC}"
echo -e "  Guide: ${YELLOW}$TB_ROOT/docs/GUIDE.md${NC}"
echo -e "  Repo:  ${YELLOW}https://github.com/ivan-lyutskanov/terminal-bootstrap${NC}"
echo -e ""

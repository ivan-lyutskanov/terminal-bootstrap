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

    # Formula name and binary name match for everything here except ripgrep,
    # which installs as `rg`. Without the mapping the check below never finds
    # it and brew gets re-invoked on every run.
    case "$tool" in
        ripgrep) bin="rg" ;;
        *)       bin="$tool" ;;
    esac

    if is_installed "$bin"; then
        echo -e "${YELLOW}  - $tool already installed${NC}"
    elif brew install "$tool"; then
        echo -e "${GREEN}  - installed $tool${NC}"
    else
        echo -e "${YELLOW}  - FAILED to install $tool (continuing)${NC}"
        FAILED_TOOLS="$FAILED_TOOLS $tool"
    fi
done 3< "$TB_ROOT/Brewfile"

# 4. Herdr skill for opencode, version-matched to the installed herdr.
#
# herdr ships its own skill (skills/herdr/SKILL.md in herdr's repo) that first
# landed in herdr 0.8.0, so 0.8.0 is a FLOOR for this step -- the only version
# mechanism in the installer: a floor, not a pin, with no upper bound. If the
# installed herdr is below it, upgrade it in place; if that still cannot reach the
# floor, skip the skill and report it loudly, the same refuse-and-report stance as
# the unverified-herdr-keys path below. The skill is fetched from the tag matching
# the installed binary, so the skill and the binary can never drift, and a re-run
# after a herdr upgrade re-fetches and converges. It is written as a managed file,
# not a symlink: the source lives in herdr's GitHub repo (nothing local to link),
# and a Cellar symlink dangles the moment `brew cleanup` removes the old path.
SKILLS_DIR="$HOME/.config/opencode/skills"
HERDR_SKILL_MD="$SKILLS_DIR/herdr/SKILL.md"
HERDR_FLOOR="0.8.0"
HERDR_VER=""
HERDR_SKILL_STATE=""    # empty when ok, otherwise a skip reason for the summary
HERDR_SKILL_RESULT=""   # current | installed | fetch-failed
HERDR_SKILL_URL=""
HERDR_UPGRADED_TO=""

# `herdr --version` prints "herdr X.Y.Z"; take the first dotted number so the
# label prefix never reaches the compare below.
herdr_version() {
    herdr --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1
}
# True when $1 is at least $2, comparing the numeric components of a dotted
# version and treating a missing component as 0 (so 0.8 == 0.8.0).
ver_at_least() {
    local -a a b
    IFS=. read -r -a a <<< "$1"
    IFS=. read -r -a b <<< "$2"
    local i x y
    for i in 0 1 2; do
        x=${a[i]:-0}; y=${b[i]:-0}
        x=${x%%[!0-9]*}; x=${x:-0}
        y=${y%%[!0-9]*}; y=${y:-0}
        if [ "$x" -gt "$y" ]; then
            return 0
        elif [ "$x" -lt "$y" ]; then
            return 1
        fi
    done
    return 0
}

if is_installed herdr; then
    HERDR_VER="$(herdr_version)"
    if [ -z "$HERDR_VER" ]; then
        HERDR_SKILL_STATE="unparseable-version"
    elif ver_at_least "$HERDR_VER" "$HERDR_FLOOR"; then
        :
    else
        echo -e "${YELLOW}==> herdr $HERDR_VER is below the $HERDR_FLOOR floor; upgrading herdr...${NC}"
        if brew upgrade herdr; then
            HERDR_NEW="$(herdr_version)"
            if [ -n "$HERDR_NEW" ] && ver_at_least "$HERDR_NEW" "$HERDR_FLOOR"; then
                HERDR_VER="$HERDR_NEW"
                HERDR_UPGRADED_TO="$HERDR_NEW"
            else
                HERDR_SKILL_STATE="floor-not-met"
            fi
        else
            HERDR_SKILL_STATE="upgrade-failed"
        fi
    fi
else
    HERDR_SKILL_STATE="herdr-missing"
fi

if [ -z "$HERDR_SKILL_STATE" ]; then
    # Reinstall the opencode integration after any upgrade: herdr's docs require
    # it, and it is what keeps opencode's agent state showing in the pane chrome.
    if is_installed opencode; then
        herdr integration install opencode >/dev/null 2>&1 || true
    fi

    # Fetch the skill from the tag matching the installed herdr, so the two can
    # never drift; a re-run after an upgrade re-fetches and converges on the new
    # tag.
    HERDR_SKILL_URL="https://github.com/herdrdev/herdr/raw/v${HERDR_VER}/skills/herdr/SKILL.md"
    HERDR_SKILL_TMP="$(mktemp "${TMPDIR:-/tmp}/tb-herdr-skill.XXXXXX")"
    if curl -fsSL "$HERDR_SKILL_URL" -o "$HERDR_SKILL_TMP" && [ -s "$HERDR_SKILL_TMP" ]; then
        # Stamp a managed header as a comment inside the frontmatter: the skill
        # still parses, and a re-run can tell this file is ours.
        TB_HERDR_VER="$HERDR_VER" awk '
            BEGIN { marker = "# terminal-bootstrap managed: herdr skill, fetched from skills/herdr/SKILL.md @ herdr v" ENVIRON["TB_HERDR_VER"] }
            NR==1 {
                if ($0 ~ /^---[ \t]*$/) { print; print marker } else { print marker; print }
                next
            }
            { print }
        ' "$HERDR_SKILL_TMP" > "${HERDR_SKILL_TMP}.managed"
        if [ -f "$HERDR_SKILL_MD" ] && cmp -s "${HERDR_SKILL_TMP}.managed" "$HERDR_SKILL_MD"; then
            HERDR_SKILL_RESULT="current"
            echo -e "${YELLOW}  - herdr skill already current${NC}"
        else
            mkdir -p "$SKILLS_DIR/herdr"
            cat "${HERDR_SKILL_TMP}.managed" > "$HERDR_SKILL_MD"
            HERDR_SKILL_RESULT="installed"
            echo -e "${BLUE}==> Installed herdr skill for opencode (herdr $HERDR_VER)${NC}"
        fi
    else
        # A failed fetch (network, or this tag has no skill) must not touch the
        # existing file: never leave a broken or half-written skill behind.
        HERDR_SKILL_RESULT="fetch-failed"
    fi
    rm -f "$HERDR_SKILL_TMP" "${HERDR_SKILL_TMP}.managed"
fi

# 5. Wire the shell configuration in with a single sourced line.
#
# Keyed on the `# terminal-bootstrap` marker rather than on the source line, because
# that line embeds this clone's absolute path and so only ever matches the clone it
# was written from. Re-running from a moved or second clone used to append a second
# block and leave both live: atuin initialised twice, and whichever clone sourced
# last silently won $EDITOR. Rewriting the marked block keeps exactly one, in the
# place it already occupies, and collapses duplicates an earlier run left behind.
#
# A marker followed by anything that is not a source line is left alone. Nothing
# proves such a line is ours, and this is the file that breaks every future shell
# if the guess is wrong.
SOURCE_LINE="[ -f \"$TB_ROOT/shell/init.sh\" ] && . \"$TB_ROOT/shell/init.sh\""
[ -f "$SHELL_RC" ] || : > "$SHELL_RC"

# Read the clone paths already wired in before rewriting, so the summary can say what
# moved rather than just that something did.
PREV_ROOTS="$(sed -n 's|^\[ -f "\(.*\)/shell/init\.sh" \] && \. .*$|\1|p' "$SHELL_RC" | sort -u)"

RC_TMP="$(mktemp "${TMPDIR:-/tmp}/tb-rc.XXXXXX")"

# First drop the three atuin lines an older version of this installer wrote by hand
# into the rc; shell/init.sh inits atuin properly without them, and these are the
# only rc lines this step will ever touch. A separate pass before the marker rewrite
# below keeps that concern out of the block-rewriting logic, whose getline reads the
# line under the marker and would otherwise print a legacy line back into the rc.
awk '
    /^[ \t]*eval "\$\(atuin init zsh --disable-up-arrow\)"[ \t]*$/ { next }
    /^[ \t]*bindkey "\^\[\[A" atuin-up-search-vicmd[ \t]*$/ { next }
    /^[ \t]*bindkey "\^\[\[A" atuin-up-search[ \t]*$/ { next }
    { print }
' "$SHELL_RC" > "$RC_TMP"

RC_NEW="$(mktemp "${TMPDIR:-/tmp}/tb-rc.XXXXXX")"
TB_SOURCE_LINE="$SOURCE_LINE" awk '
    BEGIN {
        marker = "# terminal-bootstrap"
        newsrc = ENVIRON["TB_SOURCE_LINE"]
        srcpat = "^\\[ -f \".*/shell/init\\.sh\" \\] && \\. \".*/shell/init\\.sh\"$"
    }
    /^[ \t]*#[ \t]*terminal-bootstrap[ \t]*$/ {
        if ((getline nextline) <= 0) { print; next }   # marker on the last line
        if (nextline !~ srcpat) { print; print nextline; next }
        if (seen++) next                               # duplicate block: drop it
        print marker
        print newsrc
        next
    }
    { print }
    END { if (!seen) { print ""; print marker; print newsrc } }
' "$RC_TMP" > "$RC_NEW"

if ! grep -qxF "$SOURCE_LINE" "$RC_NEW"; then
    echo -e "${YELLOW}==> Could not wire $SHELL_RC; left it unchanged${NC}" >&2
elif ! cmp -s "$SHELL_RC" "$RC_NEW"; then
    # Written through the existing file rather than moved over it: `mv` would leave
    # the rc owned by whoever ran this and readable only by them, which is mktemp's
    # 0600, not the mode the file had.
    cat "$RC_NEW" > "$SHELL_RC"
    if [ -z "$PREV_ROOTS" ]; then
        echo -e "${BLUE}==> Adding terminal-bootstrap to $SHELL_RC...${NC}"
    else
        echo -e "${BLUE}==> Updating terminal-bootstrap in $SHELL_RC...${NC}"
        printf '%s\n' "$PREV_ROOTS" | while IFS= read -r prev_root; do
            if [ -n "$prev_root" ] && [ "$prev_root" != "$TB_ROOT" ]; then
                echo -e "${YELLOW}  - was pointing at $prev_root${NC}"
            fi
        done
    fi
fi
rm -f "$RC_TMP" "$RC_NEW"

# 6. Atuin Directory-Scoped History Setup
ATUIN_CONFIG="$HOME/.config/atuin/config.toml"
mkdir -p "$(dirname "$ATUIN_CONFIG")"

# Only write config if it doesn't already exist: an existing atuin config is the
# user's, not ours, and is never overwritten whole. An existing config that still
# carries an older installer's bogus key gets exactly that one line fixed -- below.
ATUIN_NEEDS_KEY=0
ATUIN_KEY_FIXED=0
ATUIN_BOGUS_KEY=0
if [ ! -f "$ATUIN_CONFIG" ]; then
    cat << 'EOF' > "$ATUIN_CONFIG"
search_mode = "prefix"
filter_mode_shell_up_key_binding = "directory"
style = "compact"
inline_height = 20
EOF
else
    # An older version of this installer wrote `up_key_dir_scoped = true`, a key
    # atuin has no such setting for -- it is not in atuin's default-config, so
    # atuin silently ignores it. The real, working key is
    # filter_mode_shell_up_key_binding. Swap the bogus line for the real one, but
    # only when the real key is not already present: a config that already scopes
    # Up Arrow is left as the user's, and we touch only the one line we can prove
    # the old installer wrote.
    if grep -q '^[[:space:]]*up_key_dir_scoped = true[[:space:]]*$' "$ATUIN_CONFIG"; then
        if grep -q 'filter_mode_shell_up_key_binding' "$ATUIN_CONFIG"; then
            ATUIN_BOGUS_KEY=1
        else
            ATUIN_TMP="$(mktemp "${TMPDIR:-/tmp}/tb-atuin.XXXXXX")"
            sed 's/^[[:space:]]*up_key_dir_scoped = true[[:space:]]*$/filter_mode_shell_up_key_binding = "directory"/' \
                "$ATUIN_CONFIG" > "$ATUIN_TMP"
            # Prove the swap actually happened before it reaches the user's file:
            # bogus key gone, real key present. Otherwise leave the config alone.
            if ! grep -q 'up_key_dir_scoped' "$ATUIN_TMP" \
               && grep -q 'filter_mode_shell_up_key_binding' "$ATUIN_TMP"; then
                # Written through the existing file, not mv'd, to keep its owner and mode.
                cat "$ATUIN_TMP" > "$ATUIN_CONFIG"
                ATUIN_KEY_FIXED=1
            else
                ATUIN_BOGUS_KEY=1
            fi
            rm -f "$ATUIN_TMP"
        fi
    elif ! grep -q 'filter_mode_shell_up_key_binding' "$ATUIN_CONFIG"; then
        ATUIN_NEEDS_KEY=1
    fi
fi

# 7. herdr pane navigation: arrow keys as well as hjkl.
#
# Each action is written as a list so herdr's own prefix+h/j/k/l keeps working. A bare
# string would replace it, and this is meant to add a second way in rather than swap one
# set of keys for another. Nothing is displaced either way: no herdr default binds an
# arrow behind the prefix.
#
# Appending is only safe while the config has no [keys] table of its own. TOML rejects a
# second one, and herdr answers a parse error by falling back to defaults wholesale, so
# getting this wrong costs the user their whole herdr config rather than just this block.
# A config that already binds keys is left alone and reported at the end instead.
HERDR_KEYS_SKIPPED=""
if is_installed herdr; then
    HERDR_CONFIG="$HOME/.config/herdr/config.toml"
    mkdir -p "$(dirname "$HERDR_CONFIG")"
    [ -f "$HERDR_CONFIG" ] || : > "$HERDR_CONFIG"

    if grep -q '^# terminal-bootstrap herdr keys$' "$HERDR_CONFIG"; then
        echo -e "${YELLOW}  - herdr arrow-key pane focus already configured${NC}"
    elif grep -qE '^[[:space:]]*\[\[?[[:space:]]*keys' "$HERDR_CONFIG"; then
        HERDR_KEYS_SKIPPED="existing"
    else
        HERDR_TMP="$(mktemp "${TMPDIR:-/tmp}/tb-herdr.XXXXXX")"

        # What follows is validated against the candidate file rather than the installed
        # one, through HERDR_CONFIG_PATH. A herdr old enough to ignore that variable
        # would be reporting the *current* config clean while the candidate went unread,
        # so prove the redirect works by first handing it a file it has to reject.
        printf '[keys]\nfocus_pane_left = "not+a+key"\n' > "$HERDR_TMP"
        if HERDR_CONFIG_PATH="$HERDR_TMP" herdr config check >/dev/null 2>&1; then
            HERDR_KEYS_SKIPPED="unverified"
        else
            cat "$HERDR_CONFIG" > "$HERDR_TMP"
            # Without this, a config whose last line has no trailing newline gets the
            # [keys] header spliced onto the end of it.
            if [ -s "$HERDR_TMP" ] && [ -n "$(tail -c 1 "$HERDR_TMP")" ]; then
                printf '\n' >> "$HERDR_TMP"
            fi
            cat >> "$HERDR_TMP" << 'HERDR_KEYS'

# terminal-bootstrap herdr keys
[keys]
focus_pane_left  = ["prefix+h", "prefix+left"]
focus_pane_down  = ["prefix+j", "prefix+down"]
focus_pane_up    = ["prefix+k", "prefix+up"]
focus_pane_right = ["prefix+l", "prefix+right"]
HERDR_KEYS

            # herdr validates its own config, which is also how this finds out whether
            # the installed version accepts a list of bindings per action at all.
            # Refusing a file it rejects is what keeps an older herdr from answering
            # this block by discarding the rest of the user's settings.
            if HERDR_CONFIG_PATH="$HERDR_TMP" herdr config check >/dev/null 2>&1; then
                echo -e "${BLUE}==> Adding arrow-key pane navigation to herdr...${NC}"
                cat "$HERDR_TMP" > "$HERDR_CONFIG"
                # Reaches a running server without a restart. With none running there is
                # nothing to reload, hence non-fatal.
                herdr server reload-config >/dev/null 2>&1 || true
            else
                HERDR_KEYS_SKIPPED="unverified"
            fi
        fi
        rm -f "$HERDR_TMP"
    fi
fi

echo -e "${GREEN}==> Setup complete.${NC}"
if [ -n "$FAILED_TOOLS" ]; then
    echo -e "${YELLOW}    These tools failed to install:${FAILED_TOOLS}${NC}"
    echo -e "${YELLOW}    Re-run this script to retry them.${NC}"
fi
case "$HERDR_SKILL_STATE" in
    unparseable-version)
        echo -e "${YELLOW}    Could not read the installed herdr version, so the herdr skill for${NC}"
        echo -e "${YELLOW}    opencode was not installed. Check herdr and re-run this script.${NC}"
        ;;
    upgrade-failed)
        echo -e "${YELLOW}    herdr was below the $HERDR_FLOOR floor and \`brew upgrade herdr\` failed,${NC}"
        echo -e "${YELLOW}    so the herdr skill for opencode was not installed. Upgrade herdr and${NC}"
        echo -e "${YELLOW}    re-run this script.${NC}"
        ;;
    floor-not-met)
        echo -e "${YELLOW}    herdr is still below the $HERDR_FLOOR floor after the upgrade attempt, so${NC}"
        echo -e "${YELLOW}    the herdr skill for opencode was not installed. Re-run once a newer${NC}"
        echo -e "${YELLOW}    herdr is available.${NC}"
        ;;
    herdr-missing)
        echo -e "${YELLOW}    herdr is not installed, so the herdr skill for opencode was skipped.${NC}"
        echo -e "${YELLOW}    Install herdr and re-run this script.${NC}"
        ;;
esac
if [ "$HERDR_SKILL_RESULT" = "fetch-failed" ]; then
    echo -e "${YELLOW}    Could not fetch the herdr skill (${HERDR_SKILL_URL}). Any existing${NC}"
    echo -e "${YELLOW}    skill was left untouched; re-run this script once the network allows.${NC}"
fi
if [ -n "$HERDR_UPGRADED_TO" ]; then
    echo -e "${YELLOW}    herdr was upgraded to $HERDR_UPGRADED_TO. Restart the herdr server to${NC}"
    echo -e "${YELLOW}    activate it: the running server keeps the old binary in memory until${NC}"
    echo -e "${YELLOW}    you restart it.${NC}"
fi
if [ "$ATUIN_KEY_FIXED" = 1 ]; then
    echo -e "${YELLOW}    Your atuin config carried the old installer's bogus key; the real${NC}"
    echo -e "${YELLOW}    directory-scoping key was set in its place.${NC}"
fi
if [ "$ATUIN_BOGUS_KEY" = 1 ]; then
    echo -e "${YELLOW}    Your atuin config already scopes Up Arrow correctly. It also still has an${NC}"
    echo -e "${YELLOW}    old installer's bogus key (up_key_dir_scoped); atuin ignores it, so you may${NC}"
    echo -e "${YELLOW}    delete that line.${NC}"
fi
if [ "$ATUIN_NEEDS_KEY" = 1 ]; then
    echo -e "${YELLOW}    Your existing ~/.config/atuin/config.toml was left untouched.${NC}"
    echo -e "${YELLOW}    Add  filter_mode_shell_up_key_binding = \"directory\"  to it for${NC}"
    echo -e "${YELLOW}    directory-scoped Up Arrow.${NC}"
fi
case "$HERDR_KEYS_SKIPPED" in
    existing)
        echo -e "${YELLOW}    Your ~/.config/herdr/config.toml already binds keys, so it was left${NC}"
        echo -e "${YELLOW}    untouched. For arrow keys beside hjkl, add to its [keys] table:${NC}"
        echo -e "${YELLOW}      focus_pane_left  = [\"prefix+h\", \"prefix+left\"]${NC}"
        echo -e "${YELLOW}      focus_pane_down  = [\"prefix+j\", \"prefix+down\"]${NC}"
        echo -e "${YELLOW}      focus_pane_up    = [\"prefix+k\", \"prefix+up\"]${NC}"
        echo -e "${YELLOW}      focus_pane_right = [\"prefix+l\", \"prefix+right\"]${NC}"
        ;;
    unverified)
        echo -e "${YELLOW}    This herdr would not confirm the arrow-key pane bindings, so${NC}"
        echo -e "${YELLOW}    ~/.config/herdr/config.toml was left untouched. Pane focus stays on${NC}"
        echo -e "${YELLOW}    Ctrl+b then h/j/k/l; upgrading herdr and re-running picks them up.${NC}"
        ;;
esac
echo -e ""
echo -e "  Restart your shell, or: ${YELLOW}source $SHELL_RC${NC}"
echo -e "  Guide: ${YELLOW}$TB_ROOT/docs/GUIDE.md${NC}"
echo -e "  Repo:  ${YELLOW}https://github.com/ivan-lyutskanov/terminal-bootstrap${NC}"
echo -e ""

# shellcheck shell=bash
# terminal-bootstrap shell configuration.
#
# Sourced from your shell rc by bootstrap.sh. Edit this file, not your rc —
# it is version controlled, so `git pull` updates your config and deleting the
# single source line from your rc uninstalls it.

# Homebrew. Checked in order: Apple Silicon, Intel macOS, Linuxbrew.
for _tb_brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [ -x "$_tb_brew" ]; then
        eval "$("$_tb_brew" shellenv)"
        break
    fi
done
unset _tb_brew

# Editor. yazi and lazygit both open $EDITOR, which is what makes the bundle
# feel like one tool rather than four.
export EDITOR="micro"
export VISUAL="micro"
alias vim="micro"

# Atuin. Directory scoping is configured in ~/.config/atuin/config.toml via
# filter_mode_shell_up_key_binding. Do NOT add --disable-up-arrow plus a manual
# bindkey here: atuin's own init binds ^[[A and ^[OA across the emacs, viins and
# vicmd keymaps, and overriding it with one bindkey loses application-mode
# arrows and every vi binding.
if command -v atuin >/dev/null 2>&1; then
    if [ -n "${ZSH_VERSION:-}" ]; then
        eval "$(atuin init zsh)"
    elif [ -n "${BASH_VERSION:-}" ]; then
        eval "$(atuin init bash)"
    fi
fi

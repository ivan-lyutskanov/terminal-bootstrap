# Terminal Environment Bootstrap

A reliable bootstrap script to quickly replicate a terminal-native, keyboard-driven development workstation on macOS or Linux.

## 🛠️ What Gets Installed & Configured

| Tool | Description | Configuration / Customization |
| :--- | :--- | :--- |
| **[Micro](https://micro-editor.github.io/)** | Modern terminal text editor | Set as `$EDITOR` and `$VISUAL`, aliased to `vim` |
| **[Yazi](https://github.com/sxyazi/yazi)** | Blazing fast TUI file manager | Native installation |
| **[LazyGit](https://github.com/jesseduffield/lazygit)** | Terminal UI for Git commands | Native installation |
| **[Atuin](https://github.com/atuinsh/atuin)** | Magical shell history | `Up Arrow` bound strictly to **directory-scoped** history search |
| **[Hunk](https://github.com/modem-dev/hunk)** | Interactive diff & patch tool | Compiled & installed via Rust toolchain |
| **[Herdr](https://github.com/herdrdev/herdr)** | Markdown TUI reader / workflow orchestrator | Auto-launches onboarding cheatsheet post-install |
| **[OpenCode](https://github.com/opencode-ai/opencode)** | AI Coding Agent | Provisioned with custom `hunk` review skill |

---

## 🚀 Quick Start

Run the following command in your terminal to clone and bootstrap your new machine:

```bash
git clone https://github.com/ivan-lyutskanov/terminal-bootstrap.git
cd terminal-bootstrap
chmod +x bootstrap.sh
./bootstrap.sh
```

Or execute it directly via curl:

```bash
curl -fsSL https://raw.githubusercontent.com/ivan-lyutskanov/terminal-bootstrap/master/bootstrap.sh | bash
```

---

## ⚙️ How It Works

1. **Reliability Check:** Checks whether tools (`brew`, `micro`, `yazi`, `lazygit`, `atuin`, `node`, `opencode`, `hunk`, `herdr`) are already installed on the system before attempting installation.
2. **Environment Export:** Configures `~/.zshrc` or `~/.bashrc` with `export EDITOR="micro"` and binds the up-arrow key for Atuin directory-scoped search.
3. **OpenCode Skill Setup:** Provisions `~/.config/opencode/skills/hunk_review.md` instructing OpenCode to use `hunk` for granular diff inspection and interactive staging.
4. **Onboarding Launch:** Writes a cheatsheet to `~/.config/herdr/onboarding.md` and opens it in Herdr, providing instructions on setting up API key access tokens via macOS Keychain or Linux Secret Tool.

---

## 🔑 Post-Installation: Keychain Setup for AI Tokens

To keep your API keys secure without hardcoding them in your shell:

### macOS
```bash
# Add your provider key(s) to Keychain - pick yours:
security add-generic-password -a "$USER" -s "ANTHROPIC_API_KEY" -w "$ANTHROPIC_API_KEY"
security add-generic-password -a "$USER" -s "OPENAI_API_KEY" -w "$OPENAI_API_KEY"
security add-generic-password -a "$USER" -s "GOOGLE_API_KEY" -w "$GOOGLE_API_KEY"

# Add to your shell rc - uncomment the providers you use:
echo '# API Keys from Keychain' >> ~/.zshrc
echo 'export ANTHROPIC_API_KEY=$(security find-generic-password -a "$USER" -s "ANTHROPIC_API_KEY" -w)' >> ~/.zshrc
# echo 'export OPENAI_API_KEY=$(security find-generic-password -a "$USER" -s "OPENAI_API_KEY" -w)' >> ~/.zshrc
# echo 'export GOOGLE_API_KEY=$(security find-generic-password -a "$USER" -s "GOOGLE_API_KEY" -w)' >> ~/.zshrc
```

### Linux (`libsecret` / `secret-tool`)
```bash
# Store your provider key(s):
secret-tool store --name="Anthropic Key" service anthropic username "$USER"
secret-tool store --name="OpenAI Key" service openai username "$USER"
secret-tool store --name="Google Key" service google username "$USER"

# Add to your shell rc:
echo '# API Keys from secret-tool' >> ~/.zshrc
echo 'export ANTHROPIC_API_KEY=$(secret-tool lookup service anthropic username "$USER")' >> ~/.zshrc
# echo 'export OPENAI_API_KEY=$(secret-tool lookup service openai username "$USER")' >> ~/.zshrc
# echo 'export GOOGLE_API_KEY=$(secret-tool lookup service google username "$USER")' >> ~/.zshrc

Your OpenCode config will automatically pick up whichever key(s) you've configured.
```

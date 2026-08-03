# Terminal Environment Bootstrap

An idempotent bootstrap script to quickly replicate a terminal-native, keyboard-driven development workstation on macOS or Linux.

## 🛠️ What Gets Installed & Configured

| Tool | Description | Configuration / Customization |
| :--- | :--- | :--- |
| **[Micro](https://micro-editor.github.io/)** | Modern terminal text editor | Set as `$EDITOR` and `$VISUAL`, aliased to `vim` |
| **[Yazi](https://github.com/sxyazi/yazi)** | Blazing fast TUI file manager | Native installation |
| **[LazyGit](https://github.com/jesseduffield/lazygit)** | Terminal UI for Git commands | Native installation |
| **[Atuin](https://github.com/atuinsh/atuin)** | Magical shell history | `Up Arrow` bound strictly to **directory-scoped** history search |
| **[Hunk](https://github.com/modem-dev/hunk)** | Interactive diff & patch tool | Compiled & installed via Rust toolchain |
| **[Herdr](https://github.com/your-org/herdr)** | Markdown TUI reader / workflow orchestrator | Auto-launches onboarding cheatsheet post-install |
| **[OpenCode](https://github.com/opencode-ai/opencode)** | AI Coding Agent | Provisioned with custom `hunk` review skill |

---

## 🚀 Quick Start

Run the following command in your terminal to clone and bootstrap your new machine:

```bash
git clone https://github.com/your-username/dotfiles-bootstrap.git
cd dotfiles-bootstrap
chmod +x bootstrap.sh
./bootstrap.sh
```

Or execute it directly via curl:

```bash
curl -fsSL https://raw.githubusercontent.com/your-username/dotfiles-bootstrap/main/bootstrap.sh | bash
```

---

## ⚙️ How It Works

1. **Idempotence Check:** Checks whether tools (`brew`, `micro`, `yazi`, `lazygit`, `atuin`, `node`, `opencode`, `hunk`, `herdr`) are already installed on the system before attempting installation.
2. **Environment Export:** Configures `~/.zshrc` or `~/.bashrc` with `export EDITOR="micro"` and binds the up-arrow key for Atuin directory-scoped search.
3. **OpenCode Skill Setup:** Provisions `~/.config/opencode/skills/hunk_review.md` instructing OpenCode to use `hunk` for granular diff inspection and interactive staging.
4. **Onboarding Launch:** Writes a cheatsheet to `~/.config/herdr/onboarding.md` and opens it in Herdr, providing instructions on setting up API key access tokens via macOS Keychain or Linux Secret Tool.

---

## 🔑 Post-Installation: Keychain Setup for AI Tokens

To keep your AI provider API keys safe without hardcoding them in plain text:

### macOS
```bash
# Save your key into Apple Keychain
security add-generic-password -a "$USER" -s "OPENAI_API_KEY" -w "your-actual-api-key"

# Append retrieval to ~/.zshrc
echo 'export OPENAI_API_KEY=$(security find-generic-password -a "$USER" -s "OPENAI_API_KEY" -w)' >> ~/.zshrc
```

### Linux (`libsecret` / `secret-tool`)
```bash
# Store key
secret-tool store --name="OpenAI Key" service openai username "$USER"

# Append retrieval to ~/.bashrc or ~/.zshrc
echo 'export OPENAI_API_KEY=$(secret-tool lookup service openai username "$USER")' >> ~/.zshrc
```

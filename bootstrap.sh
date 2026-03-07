#!/bin/bash
set -e

# Sister's Mac Bootstrap Script
# Generated from sister-setup.md selections
# Run: chmod +x bootstrap.sh && ./bootstrap.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=========================================="
echo "  Mac Setup - Bootstrap Script"
echo "=========================================="
echo ""

# ── 1. Homebrew ──────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    echo ">> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo ">> Homebrew already installed"
fi

# ── 2. Brew packages (CLI tools, apps, fonts) ───────────────
echo ""
echo ">> Installing Homebrew packages..."
brew bundle --file="$SCRIPT_DIR/Brewfile"

# ── 3. Create folder structure ───────────────────────────────
echo ""
echo ">> Creating folder structure..."
mkdir -p ~/docs
mkdir -p ~/code
echo "   Created ~/docs (Obsidian vault)"
echo "   Created ~/code (Code projects)"

# ── 4. ZSH config ───────────────────────────────────────────
echo ""
echo ">> Configuring ZSH..."

# Backup existing .zshrc
if [ -f ~/.zshrc ] && [ ! -L ~/.zshrc ]; then
    echo "   Backing up existing .zshrc to .zshrc.backup"
    mv ~/.zshrc ~/.zshrc.backup
fi

# Install .zshrc
cat > ~/.zshrc << 'ZSHRC'
# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# npm global packages
export PATH="$HOME/.npm-global/bin:$PATH"

# VS Code CLI
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

# Editor
export EDITOR="code --wait"

# Antidote (ZSH plugin manager)
source $(brew --prefix)/opt/antidote/share/antidote/antidote.zsh
antidote load ~/.zsh_plugins.txt

# Zoxide (smart cd)
eval "$(zoxide init zsh)"

# Starship prompt
eval "$(starship init zsh)"

# Navigation aliases
alias ..="cd .."
alias ...="cd ../.."
alias cx="cd ~/code"

# Git aliases
alias gs="git status"
alias gc="git commit"
alias gp="git push"
alias glog="git log --oneline --graph --decorate -20"
alias ga="git add"
alias gd="git diff"
alias gl="git pull"

# ls alias
alias ls="ls -lah --color=auto"

# Reload shell
alias reload="source ~/.zshrc"

# Claude Code launcher (shows last session summary, runs in dangerous mode)
clauded() {
    local latest=$(ls -t docs/*.EndOfSessionSummary.md 2>/dev/null | head -1)
    if [ -n "$latest" ]; then
        echo "Last session: $latest"
    fi
    claude --dangerously-skip-permissions "$@"
}
ZSHRC

echo "   Installed .zshrc"

# Install ZSH plugins list
cp "$SCRIPT_DIR/zsh_plugins.txt" ~/.zsh_plugins.txt
echo "   Installed .zsh_plugins.txt"

# ── 5. Starship config ──────────────────────────────────────
echo ""
echo ">> Configuring Starship prompt..."
mkdir -p ~/.config
cp "$SCRIPT_DIR/starship.toml" ~/.config/starship.toml
echo "   Installed starship.toml"

# ── 6. VS Code settings & keybindings ───────────────────────
echo ""
echo ">> Configuring VS Code..."
VSCODE_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$VSCODE_DIR"

cp "$SCRIPT_DIR/vscode/settings.json" "$VSCODE_DIR/settings.json"
cp "$SCRIPT_DIR/vscode/keybindings.json" "$VSCODE_DIR/keybindings.json"
echo "   Installed settings.json and keybindings.json"

# ── 7. VS Code extensions ───────────────────────────────────
echo ""
echo ">> Installing VS Code extensions..."

# Ensure 'code' CLI is in PATH (Homebrew cask doesn't add it automatically)
VSCODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
if ! command -v code &>/dev/null && [ -f "$VSCODE_BIN" ]; then
    export PATH="$PATH:$(dirname "$VSCODE_BIN")"
fi

if command -v code &>/dev/null; then
    code --install-extension anthropics.claude-code 2>/dev/null || true
    code --install-extension github.vscode-github-actions 2>/dev/null || true
    code --install-extension harryhopkinson.vim-theme 2>/dev/null || true
    echo "   Installed Claude Code, GitHub Actions, and Vim Theme extensions"
    # Terminal Activity extension (custom) - download latest from GitHub
    echo "   Downloading Terminal Activity extension..."
    TAM_VSIX="/tmp/tam.vsix"
    if curl -sL -o "$TAM_VSIX" "$(gh release view --repo kilo9alfa/TAM --json assets --jq '.assets[0].url')" 2>/dev/null; then
        code --install-extension "$TAM_VSIX" 2>/dev/null || true
        rm -f "$TAM_VSIX"
        echo "   Installed Terminal Activity extension"
    else
        echo "   [skip] Could not download Terminal Activity extension"
    fi
else
    echo "   [skip] VS Code CLI not found - open VS Code first, then re-run"
fi

# ── 8. Claude Code ──────────────────────────────────────────
echo ""
echo ">> Installing Claude Code CLI..."
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
export PATH="$HOME/.npm-global/bin:$PATH"
npm install -g @anthropic-ai/claude-code
echo "   Installed Claude Code (run 'claude' in terminal to start)"

# ── 9. Claude Code config ────────────────────────────────────
echo ""
echo ">> Configuring Claude Code..."
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "input=$(cat); cwd=$(echo \"$input\" | jq -r '.workspace.current_dir'); dir=$(basename \"$cwd\"); model_full=$(echo \"$input\" | jq -r '.model.display_name'); model_short=$(echo \"$model_full\" | sed -E 's/Claude ([0-9.]+) (Sonnet|Opus|Haiku).*/\\2 \\1/'); used_pct=$(echo \"$input\" | jq -r '.context_window.used_percentage // empty'); printf '\\033[34m~/%s\\033[0m' \"$dir\"; [ -n \"$model_short\" ] && printf ' \\033[32m[%s]\\033[0m' \"$model_short\"; [ -n \"$used_pct\" ] && printf ' \\033[35m[ctx:%s%%]\\033[0m' \"$used_pct\"; echo"
  },
  "alwaysThinkingEnabled": true,
  "skipDangerousModePermissionPrompt": true
}
EOF
echo "   Installed ~/.claude/settings.json"

# ── 10. GitHub CLI auth (optional) ────────────────────────────
echo ""
echo ">> GitHub authentication..."
if ! gh auth status &>/dev/null 2>&1; then
    echo "   [skip] Not logged in to GitHub. This is optional."
    echo "   To log in later, run: gh auth login"
else
    echo "   Already authenticated with GitHub"
fi

# ── 11. Obsidian plugins ────────────────────────────────────
echo ""
echo ">> Setting up Obsidian vault at ~/docs..."
OBSIDIAN_DIR="$HOME/docs/.obsidian"
mkdir -p "$OBSIDIAN_DIR/plugins"
mkdir -p "$OBSIDIAN_DIR/themes"

# Install Minimal theme
if [ -d "$SCRIPT_DIR/obsidian/themes/Minimal" ]; then
    cp -r "$SCRIPT_DIR/obsidian/themes/Minimal" "$OBSIDIAN_DIR/themes/"
    echo "   Installed Minimal theme"
fi

# Community plugins list
cat > "$OBSIDIAN_DIR/community-plugins.json" << 'EOF'
[
    "table-editor-obsidian",
    "folder-notes",
    "obsidian-collapse-all-plugin",
    "editing-toolbar",
    "recent-files-obsidian",
    "copy-as-html",
    "obsidian-shellcommands",
    "chatmd-custom"
]
EOF
echo "   Created community-plugins.json"
echo "   NOTE: Open Obsidian, go to Settings > Community Plugins > Browse"
echo "   and install each plugin listed above. Then enable them."

# Copy plugin folders if available
if [ -d "$SCRIPT_DIR/obsidian/plugins" ]; then
    for plugin_dir in "$SCRIPT_DIR/obsidian/plugins"/*/; do
        if [ -d "$plugin_dir" ]; then
            plugin_name=$(basename "$plugin_dir")
            cp -r "$plugin_dir" "$OBSIDIAN_DIR/plugins/"
            echo "   Copied plugin: $plugin_name"
        fi
    done
fi

# ── 12. Karabiner ───────────────────────────────────────────
echo ""
echo ">> Karabiner Elements installed via Homebrew"
echo "   Open Karabiner and configure key remappings manually"

# ── Done ─────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Open a new terminal tab to load the new shell config"
echo "  2. Open VS Code - settings and keybindings are ready"
echo "  3. Open Obsidian - set ~/docs as your vault"
echo "     Then go to Settings > Community Plugins > Browse and install:"
echo "       - Table Editor (table-editor-obsidian)"
echo "       - Folder Notes (folder-notes)"
echo "       - Collapse All (obsidian-collapse-all-plugin)"
echo "       - Editing Toolbar (editing-toolbar)"
echo "       - Recent Files (recent-files-obsidian)"
echo "       - Copy as HTML (copy-as-html)"
echo "       - Shell Commands (obsidian-shellcommands)"
echo "     The chatmd-custom plugin and Minimal theme are already installed."
echo "     Go to Settings > Appearance > Themes and select 'Minimal'."
echo "  4. Run 'claude' in VS Code terminal to start Claude Code"
echo "     (first run will ask you to log in to Anthropic)"
echo "  5. Configure Karabiner Elements for key remappings"
echo ""

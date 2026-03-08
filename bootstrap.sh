#!/bin/bash

# Sister's Mac Bootstrap Script
# Run: ./bootstrap.sh
# Safe to re-run — overwrites configs, skips already-installed packages.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=========================================="
echo "  Mac Setup - Bootstrap Script"
echo "=========================================="
echo ""

# ── 1. Homebrew ──────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    echo ">> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
echo ">> Homebrew ready"

# ── 2. npm global prefix (avoids permission errors) ──────────
echo ""
echo ">> Configuring npm..."
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
export PATH="$HOME/.npm-global/bin:$PATH"
echo "   npm global prefix set to ~/.npm-global"

# ── 3. Write .zshrc (do this early so it exists even if later steps fail)
echo ""
echo ">> Writing .zshrc..."
if [ -f ~/.zshrc ] && [ ! -L ~/.zshrc ]; then
    cp ~/.zshrc ~/.zshrc.backup
    echo "   Backed up existing .zshrc"
fi

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
if [ -f $(brew --prefix)/opt/antidote/share/antidote/antidote.zsh ]; then
    source $(brew --prefix)/opt/antidote/share/antidote/antidote.zsh
    [ -f ~/.zsh_plugins.txt ] && antidote load ~/.zsh_plugins.txt
fi

# Zoxide (smart cd)
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# Starship prompt
command -v starship &>/dev/null && eval "$(starship init zsh)"

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

# Claude Code launcher
clauded() {
    local latest=$(ls -t docs/*.EndOfSessionSummary.md 2>/dev/null | head -1)
    if [ -n "$latest" ]; then
        echo "Last session: $latest"
    fi
    claude --dangerously-skip-permissions "$@"
}
ZSHRC

echo "   Installed .zshrc"

# ── 4. Brew packages ─────────────────────────────────────────
echo ""
echo ">> Installing Homebrew packages..."
brew bundle --file="$SCRIPT_DIR/Brewfile" || echo "   [warn] Some packages may have failed"

# ── 5. Folder structure ──────────────────────────────────────
echo ""
echo ">> Creating folder structure..."
mkdir -p ~/docs ~/code
echo "   Created ~/docs and ~/code"

# ── 6. ZSH plugins ──────────────────────────────────────────
cp "$SCRIPT_DIR/zsh_plugins.txt" ~/.zsh_plugins.txt
echo "   Installed .zsh_plugins.txt"

# ── 7. Starship config ──────────────────────────────────────
echo ""
echo ">> Configuring Starship prompt..."
mkdir -p ~/.config
cp "$SCRIPT_DIR/starship.toml" ~/.config/starship.toml
echo "   Installed starship.toml"

# ── 8. VS Code settings ─────────────────────────────────────
echo ""
echo ">> Configuring VS Code..."
VSCODE_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$VSCODE_DIR"
cp "$SCRIPT_DIR/vscode/settings.json" "$VSCODE_DIR/settings.json"
cp "$SCRIPT_DIR/vscode/keybindings.json" "$VSCODE_DIR/keybindings.json"
echo "   Installed settings.json and keybindings.json"

# ── 9. VS Code extensions ───────────────────────────────────
echo ""
echo ">> Installing VS Code extensions..."

# Ensure 'code' CLI is in PATH
VSCODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
export PATH="$PATH:$VSCODE_BIN"

if command -v code &>/dev/null; then
    code --install-extension anthropic.claude-code 2>/dev/null && echo "   Installed Claude Code extension" || echo "   [warn] Claude Code extension failed"
    code --install-extension github.vscode-github-actions 2>/dev/null && echo "   Installed GitHub Actions extension" || echo "   [warn] GitHub Actions extension failed"
    code --install-extension harryhopkinson.vim-theme 2>/dev/null && echo "   Installed Vim Theme extension" || echo "   [warn] Vim Theme extension failed"

    # Terminal Activity extension (TAM) - download from public GitHub release
    echo "   Downloading TAM extension..."
    TAM_URL="https://github.com/kilo9alfa/TAM/releases/latest/download/tam-terminal-activity-management-0.1.0.vsix"
    TAM_VSIX="/tmp/tam.vsix"
    if curl -sL -o "$TAM_VSIX" "$TAM_URL" && [ -s "$TAM_VSIX" ]; then
        code --install-extension "$TAM_VSIX" 2>/dev/null && echo "   Installed TAM extension" || echo "   [warn] TAM extension failed"
        rm -f "$TAM_VSIX"
    else
        echo "   [skip] Could not download TAM extension"
    fi
else
    echo "   [skip] VS Code not found — install it, then re-run this script"
fi

# ── 10. Claude Code CLI ─────────────────────────────────────
echo ""
echo ">> Installing Claude Code CLI..."
if command -v claude &>/dev/null; then
    echo "   Claude Code already installed ($(claude --version 2>/dev/null))"
else
    npm install -g @anthropic-ai/claude-code && echo "   Installed Claude Code CLI" || echo "   [ERROR] Claude Code install failed"
fi

# ── 11. Claude Code config ───────────────────────────────────
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

# ── 12. Obsidian vault ───────────────────────────────────────
echo ""
echo ">> Setting up Obsidian vault at ~/docs..."
OBSIDIAN_DIR="$HOME/docs/.obsidian"
mkdir -p "$OBSIDIAN_DIR/plugins" "$OBSIDIAN_DIR/themes"

if [ -d "$SCRIPT_DIR/obsidian/themes/Minimal" ]; then
    cp -r "$SCRIPT_DIR/obsidian/themes/Minimal" "$OBSIDIAN_DIR/themes/"
    echo "   Installed Minimal theme"
fi

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

if [ -d "$SCRIPT_DIR/obsidian/plugins" ]; then
    for plugin_dir in "$SCRIPT_DIR/obsidian/plugins"/*/; do
        if [ -d "$plugin_dir" ]; then
            plugin_name=$(basename "$plugin_dir")
            cp -r "$plugin_dir" "$OBSIDIAN_DIR/plugins/"
            echo "   Copied plugin: $plugin_name"
        fi
    done
fi

# ── 13. Verify installation ─────────────────────────────────
echo ""
echo "=========================================="
echo "  Verification"
echo "=========================================="
echo ""
ok=0; fail=0
check() {
    if "$@" &>/dev/null; then
        echo "  [OK] $1"
        ((ok++))
    else
        echo "  [FAIL] $1"
        ((fail++))
    fi
}
check brew --version
check node --version
check code --version
check claude --version
check starship --version
[ -f ~/.zshrc ] && echo "  [OK] ~/.zshrc exists" && ((ok++)) || { echo "  [FAIL] ~/.zshrc missing"; ((fail++)); }
[ -f ~/.config/starship.toml ] && echo "  [OK] starship.toml exists" && ((ok++)) || { echo "  [FAIL] starship.toml missing"; ((fail++)); }

echo ""
echo "  $ok passed, $fail failed"

# ── Done ─────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Open a NEW terminal tab (to load shell config)"
echo "  2. Open VS Code — settings and extensions are ready"
echo "  3. Open Obsidian — set ~/docs as your vault"
echo "     Go to Settings > Community Plugins > Browse and install the plugins."
echo "     Select 'Minimal' theme in Settings > Appearance."
echo "  4. Run 'claude' in terminal to start Claude Code"
echo "     (first run will ask you to log in to Anthropic)"
echo ""

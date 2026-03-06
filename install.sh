#!/bin/bash
set -e

# One-line installer:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/kilo9alfa/mac-setup/main/install.sh)"

echo "=========================================="
echo "  Mac Setup - Installer"
echo "=========================================="
echo ""

# Install Homebrew if needed
if ! command -v brew &>/dev/null; then
    echo ">> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo ">> Homebrew already installed"
fi

# Install git if needed
if ! command -v git &>/dev/null; then
    echo ">> Installing git..."
    brew install git
fi

# Clone the setup repo
SETUP_DIR="$HOME/code/mac-setup"
if [ -d "$SETUP_DIR" ]; then
    echo ">> Setup repo already cloned at $SETUP_DIR, pulling latest..."
    git -C "$SETUP_DIR" pull
else
    echo ">> Cloning setup repo..."
    mkdir -p ~/code
    git clone https://github.com/kilo9alfa/mac-setup.git "$SETUP_DIR"
fi

# Run bootstrap
echo ""
exec "$SETUP_DIR/bootstrap.sh"

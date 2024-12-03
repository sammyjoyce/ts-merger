#!/bin/bash

set -e

# Get the latest release URL
REPO="sammyjoyce/ts-merger"
LATEST_RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS" in
    "darwin")
        case "$ARCH" in
            "x86_64") BINARY="fuze-macos-x64" ;;
            "arm64") BINARY="fuze-macos-arm64" ;;
            *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
        esac
        ;;
    "linux")
        case "$ARCH" in
            "x86_64") BINARY="fuze-linux-x64" ;;
            *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
        esac
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

# Create installation directory
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

# Download binary
echo "Downloading latest release of fuze..."
DOWNLOAD_URL=$(curl -s $LATEST_RELEASE_URL | grep "browser_download_url.*$BINARY" | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Could not find download URL for $BINARY"
    exit 1
fi

# Download and install
curl -L "$DOWNLOAD_URL" -o "$INSTALL_DIR/fuze"
chmod +x "$INSTALL_DIR/fuze"

echo "Successfully installed fuze to $INSTALL_DIR/fuze"

# Check if directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "NOTE: Add $INSTALL_DIR to your PATH to use fuze from anywhere"
    echo "You can do this by adding this line to your shell's config file:"
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
fi

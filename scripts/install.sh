#!/bin/bash
set -e

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=linux;;
    Darwin*)    MACHINE=macos;;
    *)          echo "Unsupported operating system: ${OS}"; exit 1;;
esac

# Detect architecture
ARCH="$(uname -m)"
case "${ARCH}" in
    x86_64*)    ARCH=x64;;
    arm64*)     ARCH=arm64;;
    *)          echo "Unsupported architecture: ${ARCH}"; exit 1;;
esac

# Get the latest release URL
LATEST_RELEASE_URL="https://github.com/sammyjoyce/fuze/releases/latest/download/fuze-${MACHINE}-${ARCH}"

# Installation directory
INSTALL_DIR="/usr/local/bin"
[ ! -d "$INSTALL_DIR" ] && sudo mkdir -p "$INSTALL_DIR"

echo "Downloading fuze..."
if command -v curl > /dev/null; then
    sudo curl -L -o "${INSTALL_DIR}/fuze" "${LATEST_RELEASE_URL}"
elif command -v wget > /dev/null; then
    sudo wget -O "${INSTALL_DIR}/fuze" "${LATEST_RELEASE_URL}"
else
    echo "Error: curl or wget is required"
    exit 1
fi

# Make executable
sudo chmod +x "${INSTALL_DIR}/fuze"

echo "fuze has been installed to ${INSTALL_DIR}/fuze"
echo "Run 'fuze --help' to get started"

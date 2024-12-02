#!/bin/bash
set -e

# Source repository information if get-repo-info.sh exists in the same directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/get-repo-info.sh" ]; then
    source "$SCRIPT_DIR/get-repo-info.sh"
fi

# Fallback to environment variables if available
GITHUB_OWNER=${GITHUB_OWNER:-${GITHUB_REPOSITORY_OWNER}}
GITHUB_REPO=${GITHUB_REPO:-${GITHUB_EVENT_REPOSITORY_NAME}}
GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-"$GITHUB_OWNER/$GITHUB_REPO"}

# Validate repository information
if [ -z "$GITHUB_REPOSITORY" ]; then
    echo "Error: Could not determine GitHub repository information"
    exit 1
fi

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "${OS}" in
    "darwin")
        MACHINE=macos
        ;;
    "linux")
        MACHINE=linux
        ;;
    *)
        echo "Unsupported operating system: ${OS}"
        exit 1
        ;;
esac

# Detect architecture
ARCH=$(uname -m)
case "${ARCH}" in
    "x86_64")
        ARCH=x64
        ;;
    "arm64")
        ARCH=arm64
        ;;
    *)
        echo "Unsupported architecture: ${ARCH}"
        exit 1
        ;;
esac

# Get the latest nightly release info
API_URL="https://api.github.com/repos/${GITHUB_REPOSITORY}/releases"
if command -v curl > /dev/null; then
    RELEASES=$(curl -s "$API_URL")
elif command -v wget > /dev/null; then
    RELEASES=$(wget -qO- "$API_URL")
else
    echo "Error: curl or wget is required"
    exit 1
fi

# Find the latest nightly release
LATEST_NIGHTLY_TAG=$(echo "$RELEASES" | grep -o '"tag_name": "nightly-[^"]*"' | head -n 1 | cut -d'"' -f4)
if [ -z "$LATEST_NIGHTLY_TAG" ]; then
    echo "Error: No nightly release found"
    exit 1
fi

# Get the download URL for the latest nightly release
case "${MACHINE}" in
    "macos")
        case "${ARCH}" in
            "x64") BINARY="${GITHUB_REPO}-${MACHINE}-${ARCH}-nightly-${LATEST_NIGHTLY_TAG#nightly-}" ;;
            "arm64") BINARY="${GITHUB_REPO}-${MACHINE}-${ARCH}-nightly-${LATEST_NIGHTLY_TAG#nightly-}" ;;
            *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
        esac
        ;;
    "linux")
        case "${ARCH}" in
            "x64") BINARY="${GITHUB_REPO}-${MACHINE}-${ARCH}-nightly-${LATEST_NIGHTLY_TAG#nightly-}" ;;
            *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
        esac
        ;;
    *)
        echo "Unsupported operating system: ${OS}"
        exit 1
        ;;
esac

DOWNLOAD_URL=$(echo "$RELEASES" | grep -m 1 "browser_download_url.*$BINARY" | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Could not find download URL for $BINARY"
    exit 1
fi

# Installation directory
INSTALL_DIR="/usr/local/bin"
[ ! -d "$INSTALL_DIR" ] && sudo mkdir -p "$INSTALL_DIR"

echo "Downloading ${GITHUB_REPO} nightly build ${LATEST_NIGHTLY_TAG}..."
if command -v curl > /dev/null; then
    sudo curl -L -o "${INSTALL_DIR}/${GITHUB_REPO}" "${DOWNLOAD_URL}"
elif command -v wget > /dev/null; then
    sudo wget -O "${INSTALL_DIR}/${GITHUB_REPO}" "${DOWNLOAD_URL}"
fi

# Make executable
sudo chmod +x "${INSTALL_DIR}/${GITHUB_REPO}"

echo "${GITHUB_REPO} nightly build has been installed to ${INSTALL_DIR}/${GITHUB_REPO}"
echo "Run '${GITHUB_REPO} --help' to get started"

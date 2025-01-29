#!/usr/bin/env bash

# Exit on error and undefined variables
set -o errexit
set -o nounset

# Configuration
STORAGE_DIR="/home/ubuntu/chrome"  # Changed from /home/bitnami to /home/ubuntu
CHROME_DEB="google-chrome-stable_current_amd64.deb"
CHROME_URL="https://dl.google.com/linux/direct/${CHROME_DEB}"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Create storage directory if it doesn't exist
if [[ ! -d "${STORAGE_DIR}" ]]; then
    log "Creating Chrome directory at ${STORAGE_DIR}"
    mkdir -p "${STORAGE_DIR}"
fi

# Install Chrome if not already present
if [[ ! -d "${STORAGE_DIR}/google-chrome" ]]; then
    log "Downloading Chrome"
    cd "${STORAGE_DIR}"
    
    # Install dependencies (Ubuntu-specific)
    log "Installing dependencies"
    sudo apt-get update
    sudo apt-get install -y wget libnss3 libgconf-2-4
    
    # Download Chrome
    if ! wget -q -P ./ "${CHROME_URL}"; then
        log "ERROR: Failed to download Chrome"
        exit 1
    fi
    
    # Extract Chrome
    if ! ar x "./${CHROME_DEB}"; then
        log "ERROR: Failed to extract .deb package"
        exit 1
    fi
    
    if ! tar -xf data.tar.xz -C "${STORAGE_DIR}"; then
        log "ERROR: Failed to extract Chrome files"
        exit 1
    fi
    
    # Cleanup
    log "Cleaning up installation files"
    rm -f "./${CHROME_DEB}" "data.tar.xz" "debian-binary" "control.tar.gz" "control.tar.xz"
else
    log "Using existing Chrome installation from cache"
fi

# Add Chrome to PATH if not already present
CHROME_BIN="/home/ubuntu/chrome/opt/google/chrome"  # Changed path to match ubuntu user
if [[ ":$PATH:" != *":${CHROME_BIN}:"* ]]; then
    log "Adding Chrome to PATH"
    export PATH="${PATH}:${CHROME_BIN}"
fi

log "Chrome installation complete"

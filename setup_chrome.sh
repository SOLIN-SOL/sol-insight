#!/usr/bin/env bash

# Exit on error and undefined variables
set -o errexit
set -o nounset

# Configuration
STORAGE_DIR="/home/ubuntu/chrome"
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
    
    # Install dependencies (Ubuntu 24.04 specific with t64 suffix)
    log "Installing dependencies"
    sudo apt-get update
    sudo apt-get install -y wget libnss3 fonts-liberation \
        libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 libatspi2.0-0t64 \
        libcairo2 libcups2t64 libdbus-1-3 libdrm2 libexpat1 \
        libgbm1 libglib2.0-0t64 libnspr4 libpango-1.0-0 \
        libx11-6 libxcb1 libxcomposite1 libxdamage1 \
        libxext6 libxfixes3 libxrandr2 libxshmfence1 x11-utils \
        xdg-utils libgtk-3-0t64
    
    # Download Chrome with retry
    log "Downloading Chrome package"
    for i in {1..3}; do
        if wget --no-verbose --show-progress "${CHROME_URL}"; then
            break
        fi
        log "Download attempt $i failed, retrying..."
        sleep 2
    done

    # Verify the package is complete
    if ! dpkg-deb -I "${CHROME_DEB}" >/dev/null 2>&1; then
        log "ERROR: Downloaded package is corrupted"
        rm -f "${CHROME_DEB}"
        exit 1
    fi

    # Install using dpkg instead of manual extraction
    log "Installing Chrome package"
    sudo dpkg -i "${CHROME_DEB}" || {
        log "Installing missing dependencies"
        sudo apt-get -f install -y
        sudo dpkg -i "${CHROME_DEB}"
    }
    
    # Cleanup
    log "Cleaning up installation files"
    rm -f "${CHROME_DEB}"
else
    log "Using existing Chrome installation from cache"
fi

# Add Chrome to PATH if not already present
CHROME_BIN="/usr/bin/google-chrome"
if [[ ":$PATH:" != *":${dirname $CHROME_BIN}:"* ]]; then
    log "Adding Chrome to PATH"
    export PATH="${PATH}:$(dirname ${CHROME_BIN})"
fi

log "Chrome installation complete"

# Verify installation
if command -v google-chrome >/dev/null 2>&1; then
    log "Chrome installation verified successfully"
    google-chrome --version
else
    log "ERROR: Chrome installation could not be verified"
    exit 1
fi

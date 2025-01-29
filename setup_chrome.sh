#!/usr/bin/env bash

# Exit on error and undefined variables
set -o errexit
set -o nounset

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log "Please run this script as root or with sudo"
    exit 1
fi

# Configure swap
setup_swap() {
    log "Setting up swap space..."
    
    # Check if swap already exists
    if [ "$(swapon --show | wc -l)" -gt 0 ]; then
        log "Swap space already exists"
        return 0
    fi
    
    # Create and configure 2GB swap file
    log "Creating 2GB swap file..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    # Make swap permanent
    if ! grep -q "/swapfile none swap sw 0 0" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
    
    # Optimize swap settings for better performance
    echo "vm.swappiness=60" > /etc/sysctl.d/99-swap.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.d/99-swap.conf
    sysctl -p /etc/sysctl.d/99-swap.conf
    
    log "Swap setup complete"
    free -h
}

# Install Chrome and required dependencies
install_chrome() {
    log "Installing Chrome and dependencies..."
    
    # Update package list
    apt-get update
    
    # Install required dependencies
    apt-get install -y wget curl unzip xvfb libnss3 libgbm1 \
        libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 libatspi2.0-0t64 \
        libcairo2 libcups2t64 libdbus-1-3 libdrm2 libexpat1 \
        libgbm1 libglib2.0-0t64 libnspr4 libpango-1.0-0 \
        libx11-6 libxcb1 libxcomposite1 libxdamage1 \
        libxext6 libxfixes3 libxrandr2 libxshmfence1 x11-utils \
        xdg-utils libgtk-3-0t64 fonts-liberation
    
    # Download and install Chrome
    log "Downloading Chrome..."
    wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    
    # Try to install Chrome with increased memory limits
    log "Installing Chrome..."
    export TMPDIR=/var/tmp  # Use larger temp directory
    dpkg -i /tmp/chrome.deb || {
        apt-get -f install -y
        dpkg -i /tmp/chrome.deb
    }
    
    # Clean up
    rm -f /tmp/chrome.deb
    
    # Create Chrome wrapper script with memory management flags
    cat > /usr/local/bin/chrome-wrapper <<EOF
#!/bin/bash
exec google-chrome --headless --disable-gpu --no-sandbox --disable-dev-shm-usage \
    --disable-extensions --remote-debugging-port=9222 \
    --disable-software-rasterizer --disable-gpu-sandbox \
    --memory-pressure-off --disable-background-networking \
    --single-process "\$@"
EOF
    chmod +x /usr/local/bin/chrome-wrapper
}

# Main execution
log "Starting Chrome setup with memory management"
setup_swap
install_chrome
log "Installation complete"

# Verify installation
if command -v google-chrome >/dev/null 2>&1; then
    log "Chrome installation verified successfully"
    google-chrome --version
    log "You can now use 'chrome-wrapper' command for Selenium automation"
else
    log "ERROR: Chrome installation could not be verified"
    exit 1
fi

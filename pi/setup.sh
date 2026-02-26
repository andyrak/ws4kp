#!/bin/bash
# WeatherStar 4000+ Raspberry Pi Setup Script
# Configures WiFi, zip code, installs dependencies, and sets up kiosk mode.
# Run on a fresh Raspberry Pi OS Lite installation.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_USER="${SUDO_USER:-pi}"
HOME_DIR=$(eval echo "~$SERVICE_USER")
MUSIC_DIR="$HOME_DIR/music"

echo "============================================"
echo "  WeatherStar 4000+ Raspberry Pi Setup"
echo "============================================"
echo

# --- WiFi Configuration ---
echo "--- WiFi Configuration ---"
echo

# Check if already connected
if ping -c 1 -W 3 api.weather.gov &>/dev/null; then
    echo "Internet connection detected."
    read -rp "Skip WiFi setup? [Y/n]: " SKIP_WIFI
    SKIP_WIFI="${SKIP_WIFI:-Y}"
else
    SKIP_WIFI="n"
fi

if [[ "${SKIP_WIFI,,}" == "n" ]]; then
    read -rp "WiFi SSID: " WIFI_SSID
    read -rsp "WiFi Password: " WIFI_PASS
    echo

    if [ -z "$WIFI_SSID" ]; then
        echo "Error: SSID cannot be empty."
        exit 1
    fi

    # Use nmcli if available (Pi OS Bookworm+), otherwise use wpa_supplicant
    if command -v nmcli &>/dev/null; then
        echo "Connecting to WiFi via NetworkManager..."
        sudo nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASS" || {
            echo "Failed to connect. Check your credentials."
            exit 1
        }
    else
        echo "Configuring wpa_supplicant..."
        WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
        sudo bash -c "cat >> $WPA_CONF" <<WPAEOF

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASS"
    key_mgmt=WPA-PSK
}
WPAEOF
        sudo wpa_cli -i wlan0 reconfigure
        echo "Waiting for connection..."
        sleep 5
    fi

    # Verify connection
    if ! ping -c 1 -W 5 api.weather.gov &>/dev/null; then
        echo "Warning: Cannot reach api.weather.gov. Check WiFi credentials."
        echo "You can re-run this script after fixing connectivity."
    else
        echo "Connected successfully!"
    fi
fi

echo

# --- Zip Code ---
echo "--- Location Configuration ---"
echo

EXISTING_ZIP=""
ENV_FILE="$APP_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    EXISTING_ZIP=$(grep -oP '^KIOSK_ZIPCODE=\K.*' "$ENV_FILE" 2>/dev/null || true)
fi

if [ -n "$EXISTING_ZIP" ]; then
    read -rp "Current zip code is $EXISTING_ZIP. Enter new zip code (or press Enter to keep): " ZIPCODE
    ZIPCODE="${ZIPCODE:-$EXISTING_ZIP}"
else
    read -rp "Enter your zip code: " ZIPCODE
fi

if [ -z "$ZIPCODE" ]; then
    echo "Error: Zip code is required."
    exit 1
fi

echo "Location set to: $ZIPCODE"
echo

# --- Install System Dependencies ---
echo "--- Installing System Dependencies ---"
echo

sudo apt-get update -qq

# Node.js - check if already installed and recent enough
NODE_INSTALLED=false
if command -v node &>/dev/null; then
    NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_VERSION" -ge 18 ]; then
        NODE_INSTALLED=true
        echo "Node.js $(node -v) already installed."
    fi
fi

if [ "$NODE_INSTALLED" = false ]; then
    echo "Installing Node.js 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Chromium and X server for kiosk mode
echo "Installing Chromium and X server..."
sudo apt-get install -y --no-install-recommends \
    chromium-browser \
    xserver-xorg \
    x11-xserver-utils \
    xinit \
    openbox \
    unclutter

echo

# --- Install App Dependencies ---
echo "--- Installing Application ---"
echo

cd "$APP_DIR"
npm ci --omit=dev --ignore-scripts 2>/dev/null || npm install --omit=dev

# Build CSS if not already present
if [ ! -f "$APP_DIR/server/styles/main.css" ]; then
    echo "Note: Pre-built CSS not found. If styles look broken, build CSS on a dev machine first."
fi

echo

# --- Create Music Directory ---
echo "--- Setting Up Audio ---"
echo

mkdir -p "$MUSIC_DIR"
chown "$SERVICE_USER:$SERVICE_USER" "$MUSIC_DIR"

MUSIC_COUNT=$(find "$MUSIC_DIR" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.ogg" -o -name "*.m4a" -o -name "*.wav" -o -name "*.aac" -o -name "*.flac" \) 2>/dev/null | wc -l)
if [ "$MUSIC_COUNT" -gt 0 ]; then
    echo "Found $MUSIC_COUNT audio file(s) in $MUSIC_DIR"
else
    echo "No music files found. Place .mp3/.ogg/.m4a/.wav files in: $MUSIC_DIR"
fi

echo

# --- Write .env File ---
echo "--- Writing Configuration ---"
echo

cat > "$ENV_FILE" <<ENVEOF
WS4KP_PORT=8080
KIOSK_MODE=1
KIOSK_ZIPCODE=$ZIPCODE
AUDIO_DIR=$MUSIC_DIR
ENVEOF

chown "$SERVICE_USER:$SERVICE_USER" "$ENV_FILE"
echo "Configuration written to $ENV_FILE"
echo

# --- Install Kiosk Launcher ---
echo "--- Setting Up Kiosk Mode ---"
echo

# Copy kiosk launch script
KIOSK_SCRIPT="$HOME_DIR/.ws4kp-kiosk.sh"
cp "$SCRIPT_DIR/kiosk.sh" "$KIOSK_SCRIPT"
chmod +x "$KIOSK_SCRIPT"
chown "$SERVICE_USER:$SERVICE_USER" "$KIOSK_SCRIPT"

# Install systemd services
echo "Installing systemd services..."

# App server service
sudo cp "$SCRIPT_DIR/ws4kp.service" /etc/systemd/system/ws4kp.service
sudo sed -i "s|__APP_DIR__|$APP_DIR|g" /etc/systemd/system/ws4kp.service
sudo sed -i "s|__USER__|$SERVICE_USER|g" /etc/systemd/system/ws4kp.service

# Kiosk display service
sudo cp "$SCRIPT_DIR/ws4kp-kiosk.service" /etc/systemd/system/ws4kp-kiosk.service
sudo sed -i "s|__KIOSK_SCRIPT__|$KIOSK_SCRIPT|g" /etc/systemd/system/ws4kp-kiosk.service
sudo sed -i "s|__USER__|$SERVICE_USER|g" /etc/systemd/system/ws4kp-kiosk.service

sudo systemctl daemon-reload
sudo systemctl enable ws4kp.service
sudo systemctl enable ws4kp-kiosk.service

echo "Services installed and enabled."
echo

# --- Configure Auto-Login ---
echo "--- Configuring Auto-Login ---"
echo

# Set up auto-login on tty1
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo bash -c "cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf" <<LOGINEOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $SERVICE_USER --noclear %I \$TERM
LOGINEOF

echo "Auto-login configured for user: $SERVICE_USER"
echo

# --- GPU Memory Split ---
echo "--- Optimizing for Display ---"
echo

# Allocate more GPU memory for Chromium rendering
if ! grep -q "^gpu_mem=" /boot/config.txt 2>/dev/null && ! grep -q "^gpu_mem=" /boot/firmware/config.txt 2>/dev/null; then
    CONFIG_TXT="/boot/config.txt"
    [ -f "/boot/firmware/config.txt" ] && CONFIG_TXT="/boot/firmware/config.txt"
    echo "gpu_mem=128" | sudo tee -a "$CONFIG_TXT" >/dev/null
    echo "GPU memory set to 128MB."
else
    echo "GPU memory already configured."
fi

echo
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo
echo "  Location: $ZIPCODE"
echo "  Music:    $MUSIC_DIR"
echo "  App:      http://localhost:8080"
echo
echo "  To add music, copy files to: $MUSIC_DIR"
echo "  To change zip code, edit: $ENV_FILE"
echo "  Then restart: sudo systemctl restart ws4kp"
echo
echo "  Reboot now to start the weather display."
read -rp "  Reboot now? [Y/n]: " DO_REBOOT
DO_REBOOT="${DO_REBOOT:-Y}"
if [[ "${DO_REBOOT,,}" != "n" ]]; then
    sudo reboot
fi

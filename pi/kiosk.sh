#!/bin/bash
# WeatherStar 4000+ Kiosk Mode Launcher
# Launches Chromium in fullscreen kiosk mode pointing at the local server.
# Called by ws4kp-kiosk.service after the app server is running.

WS4KP_PORT="${WS4KP_PORT:-8080}"
URL="http://localhost:${WS4KP_PORT}"

# Wait for the server to be ready
echo "Waiting for WeatherStar 4000+ server..."
for i in $(seq 1 30); do
    if curl -s -o /dev/null "$URL" 2>/dev/null; then
        echo "Server is ready."
        break
    fi
    sleep 1
done

# Disable screen blanking and power management
xset s off
xset s noblank
xset -dpms

# Hide the mouse cursor after 3 seconds of inactivity
unclutter -idle 3 -root &

# Clear Chromium crash flags to prevent "restore session" dialogs
CHROMIUM_DIR="$HOME/.config/chromium"
if [ -d "$CHROMIUM_DIR/Default" ]; then
    sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' \
        "$CHROMIUM_DIR/Default/Preferences" 2>/dev/null || true
    sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' \
        "$CHROMIUM_DIR/Default/Preferences" 2>/dev/null || true
fi

# Launch Chromium in kiosk mode with Pi-optimized flags
exec chromium-browser \
    --kiosk "$URL" \
    --noerrdialogs \
    --disable-infobars \
    --disable-translate \
    --no-first-run \
    --disable-features=TranslateUI \
    --check-for-update-interval=31536000 \
    --disable-pinch \
    --overscroll-history-navigation=0 \
    --autoplay-policy=no-user-gesture-required \
    --disable-session-crashed-bubble \
    --disable-component-update \
    --disable-background-networking \
    --disable-sync \
    --disable-default-apps \
    --disable-extensions \
    --disable-hang-monitor \
    --disable-popup-blocking \
    --disable-prompt-on-repost \
    --disable-client-side-phishing-detection \
    --disable-ipc-flooding-protection \
    --password-store=basic \
    --use-mock-keychain \
    --enable-features=OverlayScrollbar

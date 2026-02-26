# WeatherStar 4000+ on Raspberry Pi

Turn a Raspberry Pi 4 (or newer) into a dedicated retro weather display.

## What You Need

- Raspberry Pi 4 (2GB+ RAM) or newer
- MicroSD card (8GB+)
- HDMI display
- WiFi connection
- Raspberry Pi OS Lite (Bookworm or later) flashed to the SD card

## Quick Start

1. Flash **Raspberry Pi OS Lite (64-bit)** to your SD card using [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Boot the Pi and log in (default user: `pi`)
3. Clone and run setup:

```bash
git clone https://github.com/andyrak/ws4kp.git
cd ws4kp
sudo bash pi/setup.sh
```

The setup script will:
- Ask for your **WiFi credentials** (if not already connected)
- Ask for your **zip code**
- Install Node.js, Chromium, and X server
- Configure the app to auto-start in fullscreen kiosk mode on boot
- Set up local music playback

4. Reboot when prompted. The weather display will start automatically.

## Adding Music

Place `.mp3`, `.ogg`, `.m4a`, `.wav`, `.aac`, or `.flac` files in:

```
/home/pi/music/
```

The app will detect and shuffle-play them automatically. Music files are not included in the repo for copyright reasons.

You can copy files via USB drive:
```bash
sudo mount /dev/sda1 /mnt
cp /mnt/*.mp3 ~/music/
sudo umount /mnt
```

Or via SCP from another computer:
```bash
scp ~/my-music/*.mp3 pi@<pi-ip>:~/music/
```

Restart the app after adding music:
```bash
sudo systemctl restart ws4kp
```

## Changing Configuration

Edit the config file:
```bash
nano ~/ws4kp/.env
```

Available settings:
| Variable | Default | Description |
|----------|---------|-------------|
| `WS4KP_PORT` | `8080` | Server port |
| `KIOSK_MODE` | `1` | Enable kiosk auto-start (`1` = on, `0` = off) |
| `KIOSK_ZIPCODE` | *(set during setup)* | Location for weather data |
| `AUDIO_DIR` | `/home/pi/music` | Local music directory |

After editing, restart:
```bash
sudo systemctl restart ws4kp
```

## Managing the Services

```bash
# Check status
sudo systemctl status ws4kp
sudo systemctl status ws4kp-kiosk

# Restart the weather server
sudo systemctl restart ws4kp

# Restart the kiosk display
sudo systemctl restart ws4kp-kiosk

# Stop everything
sudo systemctl stop ws4kp-kiosk ws4kp

# View logs
journalctl -u ws4kp -f
journalctl -u ws4kp-kiosk -f
```

## Re-running Setup

To change WiFi or zip code, re-run the setup script:
```bash
cd ~/ws4kp
sudo bash pi/setup.sh
```

## Resource Usage

On a Raspberry Pi 4 (2GB), expect approximately:
- **RAM**: ~150-200MB total (Node.js server + Chromium)
- **CPU**: Low idle usage, brief spikes during weather data refresh
- **Disk**: ~200MB for the app + dependencies
- **Network**: Periodic requests to api.weather.gov (requires internet)

## Troubleshooting

**Black screen on boot**: Check that the server is running with `sudo systemctl status ws4kp`. The kiosk waits up to 30 seconds for the server.

**No weather data**: Verify WiFi with `ping api.weather.gov`. Re-run setup to reconfigure WiFi.

**No audio**: Ensure files are in `/home/pi/music/` and are a supported format. Check with `ls ~/music/`.

**Display too small/large**: The app auto-scales to fill the screen. If the resolution is wrong, adjust with `raspi-config` > Display Options.

**Exit kiosk mode temporarily**: Press `Alt+F4` to close Chromium, or SSH in from another machine.

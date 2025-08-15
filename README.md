Here’s the new `README.md` I’ve prepared based on everything we learned, including Wi-Fi setup, screen-blanking prevention, and the working Lorex stream test commands:

---

# Raspberry Pi IP Camera Viewer

This project runs on the smallest Raspberry Pi with HDMI output (e.g., Raspberry Pi Zero 2 W) and connects to local Wi-Fi to automatically discover and view RTSP video streams from IP cameras. It provides a web portal for selecting cameras and adjusting behavior.

---

## Features

* Works with small Raspberry Pi boards (Zero 2 W recommended for Wi-Fi + HDMI)
* Scans network for IP cameras via ONVIF WS-Discovery
* Web portal for configuring camera selection
* Fullscreen video display on HDMI output
* Automatic directory creation for required folders (`static/`, etc.)
* Command-line test scripts to verify RTSP stream access
* Supports Lorex/Dahua `cam/realmonitor` RTSP paths
* Avoids OS sleep/screen blanking for continuous viewing

---

## Requirements

**Hardware**

* Raspberry Pi Zero 2 W (or larger Pi with HDMI)
* HDMI display
* USB power supply

**Software**

* Raspberry Pi OS Lite or Full
* Python 3.9+
* `ffmpeg` (provides `ffprobe` and `ffplay`)
* `mpv` (for efficient video playback)
* `nmap` (for scanning RTSP paths)
* Required Python packages from `pyproject.toml` (install with `uv sync` or `pip install .`)

---

## First-Run Setup

The program will automatically create missing directories like `static/` on first run.
If `wsdiscovery` or other dependencies are missing, install them with:

```bash
uv sync
```

---

## Wi-Fi Setup on Raspberry Pi OS

```bash
sudo raspi-config
```

1. Go to **System Options → Wireless LAN**
2. Enter your SSID and password
3. Reboot

Or edit `/etc/wpa_supplicant/wpa_supplicant.conf`:

```bash
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="YourSSID"
    psk="YourPassword"
}
```

---

## Prevent Screen Blanking

Disable HDMI power saving so the video display remains on:

```bash
# Disable screen blanking in console mode
sudo raspi-config
# Go to: Display Options → Screen Blanking → Disable

# Or edit /boot/config.txt
sudo nano /boot/config.txt
```

Add:

```
consoleblank=0
```

For LXDE desktop:

```bash
# Disable screensaver
lxsession-default-apps
```

---

## Testing RTSP Access from Command Line

Before integrating into the program, verify camera stream access.

### 1. Export environment variables

```bash
export IP=192.168.86.2       # Camera IP
export USER=admin            # Camera username
export PASS='lorexadmin'     # Camera password
```

### 2. URL-encode the password (if it has special chars)

```bash
CAM_PASS_ENC=$(python3 - <<'PY' "$PASS"
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1]))
PY
)
```

### 3. Test common Lorex/Dahua RTSP paths

```bash
for sp in \
  "cam/realmonitor?channel=1&subtype=0" \
  "cam/realmonitor?channel=1&subtype=1" \
  "cam/realmonitor?channel=1&subtype=2"
do
  URL="rtsp://${USER}:${CAM_PASS_ENC}@${IP}:554/${sp}"
  echo "Testing: $URL"
  CODEC=$(ffprobe -rtsp_transport tcp -v error -select_streams v:0 \
          -show_entries stream=codec_name -of csv=p=0 "$URL" 2>/dev/null)
  [ -n "$CODEC" ] && echo "✔ WORKS [$CODEC] -> $URL" && break
done
```

### 4. Play the working stream full-screen

```bash
STREAM_PATH='cam/realmonitor?channel=1&subtype=1'
mpv --no-config --vo=drm --gpu-context=drm --fs --no-osd-bar --profile=low-latency --hwdec=auto-safe \
  "rtsp://${USER}:${PASS}@${IP}:554/${STREAM_PATH}"
```

---

## Web Portal

The Flask-based web portal runs on port `5000` by default and allows you to:

* View discovered cameras
* Select active camera
* Adjust stream settings

Start the service:

```bash
uv run python app.py
```

Then open in a browser:

```
http://<pi-ip>:5000
```

---

## Notes

* First run automatically creates missing directories like `static/`.
* Works best on wired or stable Wi-Fi connections for HD streams.
* Some cameras require you to enable RTSP in their web settings.

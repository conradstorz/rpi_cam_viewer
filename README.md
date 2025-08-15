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
* `tcpdump`, `netcat-openbsd`, `git`
* - Python with `uv` for dependency management
* Required Python packages from `pyproject.toml` (install with `uv sync`)

> The app auto-creates required directories (e.g., `static/`) on first run.

---

## Safe Install & Run (Use normal user; `sudo` only when required)

It is assumed from here on out that you are accessing the Pi Zero via ssh.
The following commands are to be applied to the Pi Zero operating system.

### 1) Update system & tools (**sudo needed**)
```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y mpv ffmpeg nmap tcpdump netcat-openbsd git
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.profile
````

# Disable screen blanking in console mode
sudo raspi-config
# Go to: Display Options → Screen Blanking → Disable

### 2) Create project location (**sudo here**, then normal user)

```bash
sudo mkdir -p /opt/camviewer
sudo chown $USER:$USER /opt/camviewer
cd /opt/camviewer
```

### 3) Clone your repo (normal user)

```bash
git clone https://github.com/conradstorz/rpi_cam_viewer.git .
```

### 4) Install Python deps with `uv` (normal user)

```bash
uv sync
```

> From here on, run commands as **your normal user** unless the step explicitly says `sudo`.

---

## Camera Discovery & Command-Line Testing

### Export your camera credentials (normal user)

```bash
# These settings are for a known camera for testing your setup
export IP=192.168.86.2  (your camera will be different)
export USER='admin'
export PASS='admin' (if needed)
# NOTE: Modern Lorex cameras require password be updated on first access. If your
# camera does the same behaviour then it would be neccessary to manually login 
# to the camera from a web browser and make the change to the password.
```

### URL-encode the password (if it has special chars)

```bash
CAM_PASS_ENC=$(python3 - <<'PY' "$PASS"
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1]))
PY
)
```

### Try Lorex/Dahua RTSP paths (main/sub/third)

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

> Tip: On the Zero 2 W, prefer **H.264** substream (usually `subtype=1`).

---

## Run Full-Screen (Headless, no desktop)

```bash
STREAM_PATH='cam/realmonitor?channel=1&subtype=1'   # set to your working path
mpv --no-config --vo=drm --gpu-context=drm --fs --no-osd-bar \
    --profile=low-latency --hwdec=auto-safe \
    "rtsp://${USER}:${PASS}@${IP}:554/${STREAM_PATH}"
```

This uses KMS/DRM to render direct to HDMI from the console. Warnings about VT switching over SSH are harmless.

---

## Web Portal

Start the portal (normal user):

```bash
uv run uvicorn camviewer.main:app --host 0.0.0.0 --port 8080
```

Open `http://<pi-ip>:8080`, **Edit** your camera, paste the working RTSP URL, **Save**, then **Set Active**.

---

## Systemd Services (optional, auto-start on boot)

### Web & Player services (**sudo needed**)

```bash
sudo cp scripts/camviewer-*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable camviewer-web camviewer-player
sudo systemctl start camviewer-web camviewer-player
```

The player service is configured to use **KMS/DRM** and will auto-reconnect streams.

---

## Prevent Screen Blanking & Keep Wi-Fi Stable

### Disable console blanking

Temporary (until reboot):

```bash
sudo sh -c 'setterm -blank 0 -powerdown 0 -powersave off </dev/tty1 >/dev/tty1'
```

Persistent:

* Append `consoleblank=0` to `/boot/cmdline.txt`
* Or add the `setterm` line to `/etc/rc.local` before `exit 0`

### Disable Wi-Fi power save

```bash
sudo iw dev wlan0 set power_save off
```

Make persistent by adding the same command to `/etc/rc.local`.

---

## Troubleshooting

* **RTSP works in CLI but not full-screen** → ensure you’re using `--vo=drm --gpu-context=drm` and an **H.264 substream**.
* **Discovery finds nothing** → enable **ONVIF** in the camera UI, ensure Pi & camera are on the **same non-guest SSID**, disable AP/client isolation, allow multicast.
* **Choppy video** → use substream (`subtype=1`), move AP closer, consider Ethernet, disable Wi-Fi power save.
* **Logs** → `journalctl -u camviewer-player -n 200 -f`

---

## Default Config Paths

The app uses the first existing path:

1. `/etc/camviewer/config.yaml`
2. `/var/lib/camviewer/config.yaml`
3. `./config.yaml` (dev)

---

### Example Working Lorex URL (substream)

```
rtsp://admin:lorexadmin@192.168.86.2:554/cam/realmonitor?channel=1&subtype=1
```

EOF

````

## 3) Add the quick test script
```bash
mkdir -p scripts
cat > scripts/test_camera.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${IP:?export IP=...}"
: "${USER:?export USER=...}"
: "${PASS:?export PASS=...}"

CAM_PASS_ENC=$(python3 - <<'PY' "$PASS"
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1]))
PY
)

paths=(
  "cam/realmonitor?channel=1&subtype=0"
  "cam/realmonitor?channel=1&subtype=1"
  "cam/realmonitor?channel=1&subtype=2"
  "Streaming/Channels/101"
)

for sp in "${paths[@]}"; do
  URL="rtsp://${USER}:${CAM_PASS_ENC}@${IP}:554/${sp}"
  echo "Testing: $URL"
  CODEC=$(ffprobe -rtsp_transport tcp -v error -select_streams v:0 \
          -show_entries stream=codec_name -of csv=p=0 "$URL" 2>/dev/null || true)
  if [ -n "$CODEC" ]; then
    echo "✔ WORKS [$CODEC] -> $URL"
    echo "To play full-screen:"
    echo "  STREAM_PATH='${sp}' mpv --no-config --vo=drm --gpu-context=drm --fs --no-osd-bar --profile=low-latency --hwdec=auto-safe \"rtsp://${USER}:${PASS}@${IP}:554/${sp}\""
    exit 0
  fi
done

echo "No working RTSP path found in the quick list. Try other vendor-specific paths or nmap rtsp-url-brute." >&2
exit 1
EOF
chmod +x scripts/test_camera.sh
````

## 4) Ensure `static/` exists and is tracked

```bash
mkdir -p static
[ -f static/.gitkeep ] || touch static/.gitkeep
```

## 5) (If needed) fix dependency & harden player flags

* Ensure `pyproject.toml` uses the correct package name:

```bash
grep -n "wsdiscovery" -n pyproject.toml || sed -i 's/ws-discovery/wsdiscovery/' pyproject.toml
```

* Update the player to KMS/DRM flags (recommended for headless HDMI). In `camviewer/player.py`, replace the `cmd = [...]` with:

```python
cmd = [
    "mpv",
    "--no-config",
    "--vo=drm", "--gpu-context=drm",
    "--fs", "--no-osd-bar", "--profile=low-latency",
    "--hwdec=auto-safe",
    rtsp_url,
]
```

## 6) Commit and push

```bash
git add README.md scripts/test_camera.sh static/.gitkeep pyproject.toml camviewer/player.py
git commit -m "Docs: safer install/run; add test script; track static; use wsdiscovery; KMS/DRM player flags"
git push
```

## 7) Make a ZIP if you would like an option other than cloning from github. (two options)

### A) From your working tree (includes everything there)

```bash
cd ..
zip -r rpi_cam_viewer_$(date +%Y%m%d_%H%M%S).zip rpi_cam_viewer
```

### B) From Git (exactly what’s committed on HEAD)

```bash
cd /opt/rpi_cam_viewer
git archive --format=zip -o ../rpi_cam_viewer_HEAD.zip HEAD
```


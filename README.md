# CamViewer (Pi Zero 2 W friendly)

A tiny Raspberry Pi app that discovers ONVIF/RTSP cameras, lets you pick one in a web portal, and plays it fullscreen on HDMI.

## Quick start (on the Pi)

```bash
sudo apt update
sudo apt install -y git mpv python3-pip

# Optional: install uv (recommended)
curl -LsSf https://astral.sh/uv/install.sh | sh
# re-login or source ~/.profile so `uv` is on PATH

# Unzip this project somewhere, then:
cd /opt/camviewer
uv sync
uv run uvicorn camviewer.main:app --host 0.0.0.0 --port 8080
# Browse to http://<pi-ip>:8080
```

### Systemd services
```bash
sudo cp scripts/camviewer-*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable camviewer-web camviewer-player
sudo systemctl start camviewer-web camviewer-player
```

### Default config path
- `/etc/camviewer/config.yaml` (preferred), or
- `/var/lib/camviewer/config.yaml`, or
- `./config.yaml` (dev)

Edit via the web portal or by hand.

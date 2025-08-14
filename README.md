# CamViewer (Pi Zero 2 W friendly)

A tiny Raspberry Pi app that discovers ONVIF/RTSP cameras, lets you pick one in a web portal, and plays it fullscreen on HDMI.

## 1) Prepare your Raspberry Pi

* Use **Raspberry Pi Imager** to flash Raspberry Pi OS (Lite recommended) to a microSD.
* In Imager’s “OS Customisation”:

  * Set hostname and user/password
  * Enable Wi-Fi and SSH
* Connect mini-HDMI → HDMI to your display and boot.
* SSH in (or use a local keyboard/monitor).

## 2) Update base system and install tools

```bash
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y git mpv
```

## 3) Install `uv` (recommended workflow)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# Re-login or:
source ~/.profile
```

## 4) Clone from GitHub

> Replace the URL with your repository URL.

```bash
cd /opt
sudo git clone https://github.com/<your-user>/<your-repo>.git camviewer
sudo chown -R $USER:$USER camviewer
cd camviewer
```

## 5) Install dependencies

```bash
uv sync
```

## 6) Run the web portal

```bash
uv run uvicorn camviewer.main:app --host 0.0.0.0 --port 8080
```

Visit `http://<pi-ip>:8080` to discover ONVIF cameras, set RTSP URLs, and choose the active camera.

## 7) (Optional) Enable systemd services

```bash
sudo cp scripts/camviewer-*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable camviewer-web camviewer-player
sudo systemctl start camviewer-web camviewer-player
```

## 8) Configuration

CamViewer reads the first existing file from this list (in order):

* `/etc/camviewer/config.yaml` (preferred)
* `/var/lib/camviewer/config.yaml`
* `./config.yaml` (dev)

You can edit the config via the web portal or directly with a text editor.

---

### Notes

* **Player** uses `mpv` in fullscreen with low-latency settings and auto-restarts on failure.
* **Discovery** uses WS-Discovery to find ONVIF devices; you can manually paste RTSP URLs if needed.
* **Security**: Run on a trusted LAN or add auth/reverse proxy in front of the web portal.



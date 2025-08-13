from .webapp import app  # uvicorn target
from .config import load_config
from .player import play_forever

def active_rtsp():
    cfg = load_config()
    if not cfg.active_camera:
        return None
    cam = next((c for c in cfg.cameras if c.name == cfg.active_camera and c.enabled), None)
    if not cam:
        return None
    return cam.rtsp_url

def run_player_loop():
    play_forever(active_rtsp)

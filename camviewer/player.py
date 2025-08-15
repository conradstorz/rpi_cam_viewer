# player.py
import subprocess, time
from loguru import logger
from pathlib import Path
from .bootstrap import ensure_runtime_environment

def run_fullscreen(rtsp_url: str):
    cmd = [
        "mpv", "--fs", "--no-osd-bar", "--profile=low-latency",
        "--really-quiet", "--no-config",
        rtsp_url
    ]
    return subprocess.call(cmd)

def play_forever(get_url_callable, retry_delay=3):
    runtime = ensure_runtime_environment()
    log_path = Path(runtime["log_dir"]) / "camviewer-player.log"
    logger.add(str(log_path), rotation="1 MB", backtrace=False, diagnose=False, enqueue=True)
    while True:
        url = get_url_callable()
        if not url:
            logger.warning("No active camera RTSP URL configured. Sleeping...")
            time.sleep(5)
            continue
        logger.info(f"Starting player: {url}")
        rc = run_fullscreen(url)
        logger.warning(f"Player exited (rc={rc}). Restarting in {retry_delay}s...")
        time.sleep(retry_delay)

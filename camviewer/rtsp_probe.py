import subprocess, shlex

def rtsp_playable(rtsp_url: str, timeout_s: int = 4) -> bool:
    # Use mpv’s probe: try opening 1 frame then quit quietly
    cmd = f"mpv --no-terminal --frames=1 --timeout={timeout_s} --no-config {shlex.quote(rtsp_url)}"
    try:
        res = subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=timeout_s+2)
        return res.returncode == 0
    except Exception:
        return False

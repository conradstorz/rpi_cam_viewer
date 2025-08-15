"""
camviewer.bootstrap
-------------------
One-time and per-boot sanity checks that make the app resilient.

We *create* required directories if missing and pick writable paths
for logs/config to avoid crashing on first run.
"""

from __future__ import annotations
from pathlib import Path
import os

# Preferred locations, in order. We'll use the first that exists OR is creatable.
CONFIG_DIR_CANDIDATES = [Path("/etc/camviewer"), Path("/var/lib/camviewer"), Path.cwd()]
LOG_DIR_CANDIDATES    = [Path("/var/log/camviewer"), Path.cwd() / "logs"]
STATIC_DIR            = Path(__file__).resolve().parent.parent / "static"  # project-local

def _mkdir(p: Path) -> bool:
    try:
        p.mkdir(parents=True, exist_ok=True)
        return True
    except Exception:
        return False

def pick_writable_dir(candidates: list[Path]) -> Path:
    for d in candidates:
        if d.exists() and os.access(d, os.W_OK):
            return d
        # Try to create it if it doesn't exist
        if not d.exists() and _mkdir(d) and os.access(d, os.W_OK):
            return d
    # Fallback to CWD
    fallback = Path.cwd()
    _mkdir(fallback)
    return fallback

def ensure_runtime_environment() -> dict[str, Path]:
    """
    Ensures that all required directories exist and returns chosen paths.
    - Creates a local 'static/' so FastAPI StaticFiles doesn't fail.
    - Picks/creates a writable config dir and log dir.
    """
    # Ensure project-local static/ exists (FastAPI mount safety)
    _mkdir(STATIC_DIR)

    config_dir = pick_writable_dir(CONFIG_DIR_CANDIDATES)
    log_dir    = pick_writable_dir(LOG_DIR_CANDIDATES)

    # Common files we might want later
    (log_dir / ".keep").touch(exist_ok=True)

    return {"config_dir": config_dir, "log_dir": log_dir, "static_dir": STATIC_DIR}

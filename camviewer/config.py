from pathlib import Path
from pydantic import BaseModel, Field
from typing import List, Optional
import yaml
from .bootstrap import ensure_runtime_environment

CONFIG_PATHS = [
    Path("/etc/camviewer/config.yaml"),
    Path("/var/lib/camviewer/config.yaml"),
    Path("./config.yaml"),
]

class Camera(BaseModel):
    name: str
    host: str
    onvif_xaddr: Optional[str] = None
    rtsp_url: Optional[str] = None
    username: Optional[str] = None
    password: Optional[str] = None
    enabled: bool = True

class AppConfig(BaseModel):
    active_camera: Optional[str] = None
    cameras: List[Camera] = Field(default_factory=list)

def load_config() -> AppConfig:
    for p in CONFIG_PATHS:
        if p.exists():
            with p.open("r") as f:
                data = yaml.safe_load(f) or {}
            return AppConfig(**data)
    return AppConfig()

def save_config(cfg: AppConfig) -> Path:
    # Prefer a writable path determined at runtime; fall back to existing logic
    runtime = ensure_runtime_environment()
    preferred = Path(runtime["config_dir"]) / "config.yaml"
    target = preferred
    # If somehow that failed, keep old behavior as a last resort:
    if not target.parent.exists():
        target = next((p for p in CONFIG_PATHS if p.parent.exists()), CONFIG_PATHS[-1])
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("w") as f:
        yaml.safe_dump(cfg.model_dump(), f, sort_keys=False)
    return target

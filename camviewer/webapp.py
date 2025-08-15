from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from jinja2 import Environment, PackageLoader, select_autoescape
from .config import load_config, save_config, Camera
from .discovery import discover_onvif
from .rtsp_probe import rtsp_playable
from .bootstrap import ensure_runtime_environment

runtime = ensure_runtime_environment()
env = Environment(loader=PackageLoader("camviewer", "templates"), autoescape=select_autoescape())
app = FastAPI()
# Always safe to mount because bootstrap created the dir
app.mount("/static", StaticFiles(directory=str(runtime["static_dir"])), name="static")

@app.get("/", response_class=HTMLResponse)
def home(request: Request):
    cfg = load_config()
    tmpl = env.get_template("home.html")
    return tmpl.render(cfg=cfg, request=request)

@app.post("/discover")
def do_discover():
    found = discover_onvif()
    cfg = load_config()
    # Merge new devices (simple heuristic by xaddr host)
    seen_hosts = {c.host for c in cfg.cameras}
    for dev in found:
        host = dev.address.split("//")[-1].split("/")[0] if dev.address else dev.epr
        if host and host not in seen_hosts:
            cfg.cameras.append(Camera(name=host, host=host))
            seen_hosts.add(host)
    save_config(cfg)
    return RedirectResponse("/", status_code=303)

@app.post("/set-active")
def set_active(name: str = Form(...)):
    cfg = load_config()
    if any(c.name == name for c in cfg.cameras):
        cfg.active_camera = name
        save_config(cfg)
    return RedirectResponse("/", status_code=303)

@app.get("/edit", response_class=HTMLResponse)
def edit(name: str):
    cfg = load_config()
    cam = next((c for c in cfg.cameras if c.name == name), None)
    tmpl = env.get_template("edit.html")
    return tmpl.render(cam=cam)

@app.post("/save")
def save(
    name: str = Form(...),
    host: str = Form(""),
    rtsp_url: str = Form(""),
    username: str = Form(""),
    password: str = Form(""),
    enabled: str = Form("on"),
):
    cfg = load_config()
    for i, c in enumerate(cfg.cameras):
        if c.name == name:
            cfg.cameras[i] = Camera(
                name=name, host=host or name, rtsp_url=rtsp_url or None,
                username=username or None, password=password or None,
                enabled=(enabled == "on")
            )
            break
    save_config(cfg)
    return RedirectResponse("/", status_code=303)

@app.post("/test")
def test(rtsp_url: str = Form(...)):
    ok = rtsp_playable(rtsp_url)
    where = "/?test=ok" if ok else "/?test=fail"
    return RedirectResponse(where, status_code=303)

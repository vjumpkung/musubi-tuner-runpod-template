# musubi-tuner RunPod template

CUDA 12.8 RunPod image for musubi-tuner with two browser services:

- **Musubi GUI:** React frontend and FastAPI backend on port `8000`
- **Jupyter Lab:** notebooks and terminal access on port `8888`
- **TensorBoard-compatible port:** `6006` remains exposed for training workflows

The frontend is compiled during the Docker build and served by FastAPI, so the
GUI and `/api` share one origin. FastAPI runs with exactly one worker because
its in-process queue runner must not execute a training job more than once.

## Build

```bash
docker build -t musubi-tuner-runpod .
```

The build follows the current `main` branches of musubi-tuner and both GUI
repositories. Reproducible builds can select a release, tag, or branch:

```bash
docker build \
  --build-arg MUSUBI_TUNER_REF=v0.3.4 \
  --build-arg GUI_BACKEND_REF=main \
  --build-arg GUI_FRONTEND_REF=main \
  -t musubi-tuner-runpod .
```

## Run locally

```bash
docker run --rm --gpus all \
  -p 8000:8000 \
  -p 8888:8888 \
  -v musubi-notebooks:/notebooks \
  musubi-tuner-runpod
```

Open `http://localhost:8000` for the GUI and `http://localhost:8888` for
Jupyter. In RunPod, add HTTP service ports `8000` and `8888` to the template.

## Runtime layout

- `/notebooks/musubi-tuner` — trainer source used by GUI jobs
- `/notebooks/.musubi-gui` — GUI database, managed datasets, and job logs
- `/notebooks/musubi-gui.log` — FastAPI/GUI service log
- `/notebooks/jupyter.log` — Jupyter service log

Client-supplied paths are confined to `/notebooks`. This matches the GUI's
default `./musubi-tuner`, model, output, and logging paths.

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `MUSUBI_GUI_PORT` | `8000` | GUI/API listening port |
| `JUPYTER_PORT` | `8888` | Jupyter listening port |
| `MUSUBI_UPDATE_ON_START` | `1` | Refresh musubi-tuner and helper scripts when the pod starts |
| `MUSUBI_CONFIGURE_DNS` | `1` | Use Google DNS inside the container; set to `0` to keep platform DNS |
| `MUSUBI_GUI_DATA_ROOT` | `/notebooks/.musubi-gui` | Persistent GUI state |
| `MUSUBI_GUI_WORKSPACE_ROOT` | `/notebooks` | Allowed root for GUI paths |
| `MUSUBI_GUI_PASSWORD` | random | Password for the GUI, its API, the MCP endpoint, and JupyterLab. When unset, a random password is generated and printed in the container log |

If a startup refresh cannot reach GitHub, the container logs a warning and
continues with the versions included in the image.

## Password and MCP

The GUI, its API, the MCP endpoint, and JupyterLab share one password. If
`MUSUBI_GUI_PASSWORD` is unset or blank, the first start generates a random
password and saves it in `/notebooks/.musubi-gui/gui_password`. Every start
prints it in the container log; on RunPod, open the pod and select **Logs**:

```text
[musubi-template] Password for the GUI and JupyterLab: <password> (set MUSUBI_GUI_PASSWORD to choose your own)
```

To choose your own password, set `MUSUBI_GUI_PASSWORD` in the template's
**Environment Variables** before deploying. A password you set is never
printed. To generate a new random password, delete
`/notebooks/.musubi-gui/gui_password` and restart the pod. Changing the
password signs out existing GUI sessions.

The GUI's sidebar has a **Log out** button, and sessions last 7 days. Wrong
passwords are throttled to about one attempt per second.

The GUI also serves an MCP endpoint at `/mcp` on the same port, which lets an
AI client such as Claude Code check the system, start downloads, manage dataset
configs, and queue and monitor training jobs. Through the RunPod proxy, connect
to `https://<POD_ID>-8000.proxy.runpod.net/mcp` with the password as a Bearer
token:

```bash
claude mcp add --transport http musubi-tuner-gui https://<POD_ID>-8000.proxy.runpod.net/mcp --header "Authorization: Bearer <password>"
```

The MCP endpoint cannot delete data or upload files. See the
[backend README](https://github.com/vjumpkung/musubi-tuner-gui-backend#mcp-server)
for the tool list.

JupyterLab on port `8888` asks for the same password in its **Password or
token** box. Jupyter is a terminal on the pod, so anyone with the password can
read every file and environment variable on it; do not share it.

The login page, realtime updates, and MCP endpoint come from the GUI
repositories' `main` branches, which the Dockerfile clones at build time.
Rebuild the image to pick them up.

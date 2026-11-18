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
| `MUSUBI_GUI_PASSWORD` | unset | Password for the GUI, its API, and the MCP endpoint. When unset, there is no login |

If a startup refresh cannot reach GitHub, the container logs a warning and
continues with the versions included in the image.

## Password and MCP

The GUI shows a login page and protects its API and MCP endpoint only when
`MUSUBI_GUI_PASSWORD` is set. It is unset by default, so anyone who has the
port `8000` URL can use the GUI. For a RunPod pod, set a long random value in
the template's **Environment Variables** before deploying. The GUI's sidebar
then has a **Log out** button, and sessions last 7 days. Wrong passwords are
throttled to about one attempt per second.

```bash
MUSUBI_GUI_PASSWORD=<long random password>
```

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

JupyterLab on port `8888` is unchanged and still has no token or password.
Because it is a terminal on the pod, anyone who can open the Jupyter URL can
also read the pod's environment variables, including `MUSUBI_GUI_PASSWORD`, so
do not share that link.

The login page, realtime updates, and MCP endpoint come from the GUI
repositories' `main` branches, which the Dockerfile clones at build time.
Rebuild the image to pick them up.

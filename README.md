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

If a startup refresh cannot reach GitHub, the container logs a warning and
continues with the versions included in the image.

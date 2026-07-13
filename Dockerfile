# syntax=docker/dockerfile:1.7

# Build the React application first. Vite writes its production output into
# the sibling backend repository's web/ directory.
FROM node:24-bookworm-slim AS gui-builder

ARG GUI_BACKEND_REPOSITORY="https://github.com/vjumpkung/musubi-tuner-gui-backend.git"
ARG GUI_BACKEND_REF="main"
ARG GUI_FRONTEND_REPOSITORY="https://github.com/vjumpkung/musubi-tuner-gui-frontend.git"
ARG GUI_FRONTEND_REF="main"
ARG PNPM_VERSION="10.24.0"

RUN apt-get update && \
    apt-get install --yes --no-install-recommends ca-certificates git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git clone --depth 1 --branch "${GUI_BACKEND_REF}" \
        "${GUI_BACKEND_REPOSITORY}" musubi-tuner-gui-backend && \
    git clone --depth 1 --branch "${GUI_FRONTEND_REF}" \
        "${GUI_FRONTEND_REPOSITORY}" musubi-tuner-gui-frontend

WORKDIR /build/musubi-tuner-gui-frontend
RUN npm install --global "pnpm@${PNPM_VERSION}" && \
    pnpm install --frozen-lockfile && \
    pnpm build && \
    test -f /build/musubi-tuner-gui-backend/web/index.html && \
    mv /build/musubi-tuner-gui-backend/web /build/musubi-tuner-gui-web && \
    rm -rf /build/musubi-tuner-gui-backend/.git \
        /build/musubi-tuner-gui-frontend/node_modules


FROM nvidia/cuda:12.8.1-base-ubuntu24.04 AS runtime

ARG PYTHON_VERSION="3.12"
ARG TORCH_VERSION="2.11.0"
ARG TORCHVISION_VERSION="0.26.0"
ARG TORCHAUDIO_VERSION="2.11.0"
ARG XFORMERS_VERSION="0.0.35"
ARG MUSUBI_TUNER_REPOSITORY="https://github.com/kohya-ss/musubi-tuner.git"
ARG MUSUBI_TUNER_REF="main"
ARG MUSUBI_HELPERS_REPOSITORY="https://github.com/vjumpkung/vjump-runpod-notebooks-and-script.git"
ARG MUSUBI_HELPERS_REF="main"

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
    UV_LINK_MODE=copy \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin \
    MUSUBI_GUI_BACKEND_ROOT=/opt/musubi-tuner-gui-backend \
    MUSUBI_GUI_DATA_ROOT=/notebooks/.musubi-gui \
    MUSUBI_GUI_SCRIPTS_DIR=/notebooks \
    MUSUBI_GUI_WORKSPACE_ROOT=/notebooks \
    MUSUBI_GUI_WEB_DIR=/opt/musubi-tuner-gui-backend/web \
    MUSUBI_GUI_PORT=8000 \
    JUPYTER_PORT=8888

RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
        aria2 \
        bash \
        build-essential \
        ca-certificates \
        curl \
        ffmpeg \
        git \
        git-lfs \
        libgl1 \
        libglib2.0-0 \
        libstdc++6 \
        tini \
        wget && \
    git lfs install --system && \
    rm -rf /var/lib/apt/lists/*

# Copy a versioned uv binary instead of executing a mutable remote installer.
COPY --from=ghcr.io/astral-sh/uv:0.11.28 /uv /uvx /usr/local/bin/

RUN uv python install "${PYTHON_VERSION}" && \
    uv venv /opt/venv --python "${PYTHON_VERSION}" && \
    python --version && \
    uv --version

WORKDIR /notebooks
RUN git clone --depth 1 --branch "${MUSUBI_TUNER_REF}" \
        "${MUSUBI_TUNER_REPOSITORY}" musubi-tuner

WORKDIR /notebooks/musubi-tuner
RUN uv pip install \
        "torch==${TORCH_VERSION}" \
        "torchvision==${TORCHVISION_VERSION}" \
        "torchaudio==${TORCHAUDIO_VERSION}" \
        "xformers==${XFORMERS_VERSION}" \
        --index-url https://download.pytorch.org/whl/cu128 && \
    uv pip install \
        "https://github.com/Comfy-Org/wheels/releases/download/sageattention-latest/sageattention-2.2.0+cu128torch2.11-cp312-cp312-manylinux_2_34_x86_64.manylinux_2_35_x86_64.whl" && \
    uv pip install \
        jupyterlab \
        jupyter-archive \
        nbformat \
        jupyterlab-git \
        ipywidgets \
        ipykernel \
        ipython \
        pickleshare \
        requests \
        python-dotenv \
        nvitop \
        gdown \
        setuptools \
        "numpy<2" && \
    uv pip install -e .

# Install the backend before adding the generated web/ directory. Older backend
# refs relied on automatic package discovery, which treats web/ as a second
# top-level Python package and rejects the editable install.
COPY --from=gui-builder /build/musubi-tuner-gui-backend /opt/musubi-tuner-gui-backend
RUN uv pip install -e /opt/musubi-tuner-gui-backend && \
    uv cache clean
COPY --from=gui-builder /build/musubi-tuner-gui-web /opt/musubi-tuner-gui-backend/web
RUN test -f "${MUSUBI_GUI_WEB_DIR}/index.html"

# Keep the notebook and helper files available in the shared GUI workspace.
COPY . /notebooks/
RUN git clone --depth 1 --branch "${MUSUBI_HELPERS_REF}" \
        "${MUSUBI_HELPERS_REPOSITORY}" /tmp/musubi-helpers && \
    find /tmp/musubi-helpers/musubi_tuner -maxdepth 1 -type f \
        \( -name '*.sh' -o -name '*.ipynb' \) \
        -exec cp -f {} /notebooks/ \; && \
    rm -rf /tmp/musubi-helpers && \
    chmod +x /notebooks/*.sh

WORKDIR /notebooks

EXPOSE 8000 8888 6006

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl --fail --silent --show-error "http://127.0.0.1:${MUSUBI_GUI_PORT}/" > /dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/notebooks/start.sh"]

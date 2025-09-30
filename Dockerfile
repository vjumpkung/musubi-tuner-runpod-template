# Stage 1: Base image with common dependencies
FROM nvidia/cuda:12.8.1-base-ubuntu24.04 AS base

ARG PYTHON_VERSION="3.12"
ARG CONTAINER_TIMEZONE=UTC 

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# create notebooks dir
RUN mkdir -p /notebooks /notebooks/program/

# Install basic tools and dependencies first
RUN ln -snf /usr/share/zoneinfo/$CONTAINER_TIMEZONE /etc/localtime && echo $CONTAINER_TIMEZONE > /etc/timezone
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    build-essential \
    aria2 \
    git \
    git-lfs \
    curl \
    wget \
    gcc \
    g++ \
    bash \
    libgl1 \
    software-properties-common \
    ffmpeg \
    libstdc++6 \
    ca-certificates && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install uv first (before Python)
ADD https://astral.sh/uv/install.sh /uv-installer.sh
RUN sh /uv-installer.sh && rm /uv-installer.sh
ENV PATH="/root/.local/bin/:$PATH"

# Use uv to install Python 3.12
RUN uv python install ${PYTHON_VERSION}

# Create a virtual environment and activate it globally
RUN uv venv /opt/venv --python=${PYTHON_VERSION}
ENV PATH="/opt/venv/bin:$PATH"
ENV VIRTUAL_ENV=/opt/venv

# Set up Python symlinks to make it available system-wide (pointing to venv)
RUN ln -sf /opt/venv/bin/python /usr/bin/python && \
    ln -sf /opt/venv/bin/python /usr/bin/python3

# Verify Python installation
RUN python --version && python3 --version

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

WORKDIR /notebooks

RUN git clone https://github.com/kohya-ss/musubi-tuner.git

WORKDIR /notebooks/musubi-tuner/

# JupyterLab and other python packages

RUN uv pip install torch==2.8.0 torchvision torchaudio xformers --index-url https://download.pytorch.org/whl/cu128
RUN uv pip install jupyterlab jupyter-archive nbformat \
    jupyterlab-git ipywidgets ipykernel ipython pickleshare \
    requests python-dotenv nvitop gdown sageattention setuptools "numpy<2" && \
    uv pip install -e . && \
    uv cache clean

WORKDIR /notebooks

EXPOSE 8888 6006
CMD ["jupyter", "lab", "--allow-root", "--ip=0.0.0.0", "--no-browser", \
    "--ServerApp.trust_xheaders=True", "--ServerApp.disable_check_xsrf=False", \
    "--ServerApp.allow_remote_access=True", "--ServerApp.allow_origin='*'", \
    "--ServerApp.allow_credentials=True", "--FileContentsManager.delete_to_trash=False", \
    "--FileContentsManager.always_delete_dir=True", "--FileContentsManager.preferred_dir=/notebooks", \
    "--ContentsManager.allow_hidden=True", "--LabServerApp.copy_absolute_path=True", \
    "--ServerApp.token=''", "--ServerApp.password=''"]

RUN chmod +x /start.sh

CMD ["/start.sh"]

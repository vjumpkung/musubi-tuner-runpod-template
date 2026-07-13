#!/usr/bin/env bash

set -Euo pipefail

JUPYTER_PID=""
GUI_PID=""

log() {
    printf '[musubi-template] %s\n' "$*"
}

configure_dns() {
    if [[ "${MUSUBI_CONFIGURE_DNS:-1}" != "1" ]]; then
        return
    fi

    log "Configuring DNS settings"
    if ! cp /etc/resolv.conf /etc/resolv.conf.backup ||
        ! printf 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n' >/etc/resolv.conf; then
        log "Warning: DNS configuration could not be changed; continuing"
    fi
}

refresh_runtime_assets() {
    local helpers_dir

    if [[ "${MUSUBI_UPDATE_ON_START:-1}" != "1" ]]; then
        log "Skipping startup updates (MUSUBI_UPDATE_ON_START=${MUSUBI_UPDATE_ON_START:-0})"
        return
    fi

    log "Updating musubi-tuner"
    if git -C /notebooks/musubi-tuner symbolic-ref --quiet HEAD >/dev/null 2>&1; then
        if ! git -C /notebooks/musubi-tuner pull --ff-only ||
            ! uv pip install -e /notebooks/musubi-tuner; then
            log "Warning: musubi-tuner update failed; using the version included in the image"
        fi
    else
        log "Skipping musubi-tuner pull because the image was built from a tag"
    fi

    log "Updating helper scripts"
    helpers_dir=$(mktemp -d)
    if git clone --quiet --depth 1 --branch main \
        https://github.com/vjumpkung/vjump-runpod-notebooks-and-script.git \
        "${helpers_dir}/repository"; then
        find "${helpers_dir}/repository/musubi_tuner" -maxdepth 1 -type f \
            \( -name '*.sh' -o -name '*.ipynb' \) \
            -exec cp -f {} /notebooks/ \;
        chmod +x /notebooks/*.sh
    else
        log "Warning: helper update failed; using the versions included in the image"
    fi
    rm -rf "${helpers_dir}"
}

export_env_vars() {
    local environment_file=/etc/rp_environment
    local name value

    log "Saving RunPod and service environment variables for interactive shells"
    : >"${environment_file}"
    while IFS='=' read -r name value; do
        printf 'export %s=%q\n' "${name}" "${value}" >>"${environment_file}"
    done < <(printenv | grep -E '^(RUNPOD_|PATH=|MUSUBI_GUI_|JUPYTER_PORT=)' || true)

    if ! grep -Fqx 'source /etc/rp_environment' /root/.bashrc 2>/dev/null; then
        printf '%s\n' 'source /etc/rp_environment' >>/root/.bashrc
    fi
}

start_jupyter() {
    log "Starting Jupyter Lab on port ${JUPYTER_PORT:-8888}"
    cd /notebooks
    jupyter lab \
        --allow-root \
        --ip=0.0.0.0 \
        --port="${JUPYTER_PORT:-8888}" \
        --no-browser \
        --ServerApp.trust_xheaders=True \
        --ServerApp.disable_check_xsrf=False \
        --ServerApp.allow_remote_access=True \
        --ServerApp.allow_origin='*' \
        --ServerApp.allow_credentials=True \
        --FileContentsManager.delete_to_trash=False \
        --FileContentsManager.always_delete_dir=True \
        --FileContentsManager.preferred_dir=/notebooks \
        --ContentsManager.allow_hidden=True \
        --LabServerApp.copy_absolute_path=True \
        --ServerApp.token='' \
        --ServerApp.password='' \
        > /notebooks/jupyter.log 2>&1 &
    JUPYTER_PID=$!
}

start_gui() {
    local backend_root="${MUSUBI_GUI_BACKEND_ROOT:-/opt/musubi-tuner-gui-backend}"
    local port="${MUSUBI_GUI_PORT:-8000}"

    log "Starting musubi-tuner GUI on port ${port}"
    cd "${backend_root}"
    uvicorn app.main:app \
        --host 0.0.0.0 \
        --port "${port}" \
        --workers 1 \
        > /notebooks/musubi-gui.log 2>&1 &
    GUI_PID=$!
}

shutdown() {
    local status=$?
    trap - EXIT INT TERM
    log "Stopping services"

    if [[ -n "${GUI_PID}" ]] && kill -0 "${GUI_PID}" 2>/dev/null; then
        kill -TERM "${GUI_PID}" 2>/dev/null || true
    fi
    if [[ -n "${JUPYTER_PID}" ]] && kill -0 "${JUPYTER_PID}" 2>/dev/null; then
        kill -TERM "${JUPYTER_PID}" 2>/dev/null || true
    fi
    wait 2>/dev/null || true
    exit "${status}"
}

trap shutdown EXIT INT TERM

log "Pod started"
configure_dns
refresh_runtime_assets
export_env_vars
start_gui
start_jupyter

log "Services are ready: GUI :${MUSUBI_GUI_PORT:-8000}, Jupyter :${JUPYTER_PORT:-8888}"

# Exit the container if either primary service fails. The EXIT trap stops the
# remaining service and lets the platform restart an unhealthy pod.
wait -n "${GUI_PID}" "${JUPYTER_PID}"

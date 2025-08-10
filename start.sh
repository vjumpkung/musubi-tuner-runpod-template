#!/bin/bash

# Function to configure DNS settings
configure_dns() {
    echo "Configuring DNS settings..."
    # Backup the current resolv.conf
    cp /etc/resolv.conf /etc/resolv.conf.backup
    # Use Google's public DNS servers
    echo "nameserver 8.8.8.8
nameserver 8.8.4.4" >/etc/resolv.conf
    echo "DNS configuration updated."
}

# Function to start Jupyter Lab
start_jupyter() {
    echo "Starting Jupyter Lab..."
    cd /notebooks/ &&
        nohup jupyter lab \
            --allow-root \
            --ip=0.0.0.0 \
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
            --ServerApp.password='' &>./jupyter.log &
    echo "Jupyter Lab started."
}

# Function to export environment variables
export_env_vars() {
    echo "Exporting environment variables..."
    printenv | grep -E '^RUNPOD_|^PATH=|^_=' | awk -F= '{ print "export " $1 "=\"" $2 "\"" }' >>/etc/rp_environment
    echo 'source /etc/rp_environment' >>~/.bashrc
    echo "Environment variables exported."
}

update_musubi_tuner() {
    cd /notebooks/musubi-tuner && git pull --ff-only && cd ..
}

run_custom_script() {
    cd /notebooks
    curl -s https://raw.githubusercontent.com/vjumpkung/vjump-runpod-notebooks-and-script/refs/heads/main/musubi_tuner/custom_script.sh -sSf | bash -s -- -y
}

# Main execution sequence
echo "Pod Started"
configure_dns
update_musubi_tuner
run_custom_script
start_jupyter
export_env_vars
echo "Start script(s) finished, pod is ready to use."
sleep infinity
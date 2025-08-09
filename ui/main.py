import os
import shlex
import subprocess
import sys
import zipfile

import ipywidgets as widgets
import torch
from IPython.display import display

platform_id = "OTHER"

if "RUNPOD_POD_ID" in os.environ.keys():
    platform_id = "RUNPOD"
elif "PAPERSPACE_FQDN" in os.environ.keys():
    platform_id = "PAPERSPACE"


class Envs:
    def __init__(self):
        self.CIVITAI_TOKEN = ""
        self.HUGGINGFACE_TOKEN = ""


envs = Envs()


def setup():

    if not torch.cuda.is_available():
        warn = widgets.HTML(
            '<h3 style="width: 500px;">CUDA not found please recreate pod</h3>'
        )
        headers = widgets.HBox([warn])
        display(headers)
    else:
        warn = widgets.HTML('<h3 style="width: 500px;">found CUDA :)</h3>')
        headers = widgets.HBox([warn])
        display(headers)

    settings = []
    input_list = [
        ("CIVITAI_TOKEN", "CivitAI API Key", "Paste your API key here", ""),
        ("HUGGINGFACE_TOKEN", "Huggingface API Key", "Paste your API key here", ""),
    ]

    save_button = widgets.Button(description="Save", button_style="primary")
    output = widgets.Output()

    for key, input_label, placeholder, input_value in input_list:
        label = widgets.Label(input_label, layout=widgets.Layout(width="100px"))
        textfield = widgets.Text(
            placeholder=placeholder,
            value=input_value,
            layout=widgets.Layout(width="400px"),
        )
        settings.append((key, textfield))
        row = [label, textfield]
        print("")
        display(widgets.HBox(row))

    def on_save(button):
        output.clear_output()
        with output:
            for key, textInput in settings:
                if key == "CIVITAI_TOKEN":
                    envs.CIVITAI_TOKEN = textInput.value
                elif key == "HUGGINGFACE_TOKEN":
                    envs.HUGGINGFACE_TOKEN = textInput.value
            print("\nSaved ✔")

    save_button.on_click(on_save)
    display(save_button, output)


def download(name: str, url: str, type: str):

    destination = ""
    filename = ""

    if type in ["sd15", "sdxl"]:
        destination = "./model/stable_diffusion_ckpt/"
    elif type in ["flux", "sd3"]:
        destination = "./model/unet/"
    elif type == "clip":
        destination = "./model/clip/"
    elif type == "vae":
        destination = "./model/vae/"
    elif type == "custom_model":
        destination = "./model/custom_model/"
    elif type == "dataset":
        destination = "./lora_training/dataset/"

    print(f"Starting download: {name}")

    if envs.CIVITAI_TOKEN != "" and "civitai" in url:
        if "?" in url:
            url += f"&token={envs.CIVITAI_TOKEN}"
        else:
            url += f"?token={envs.CIVITAI_TOKEN}"

    command = f"aria2c --console-log-level=error -c -x 16 -s 16 -k 1M {url} --dir={destination} --download-result=hide"

    if envs.HUGGINGFACE_TOKEN != "" and "huggingface" in url:
        command += f' --header="Authorization: Bearer {envs.HUGGINGFACE_TOKEN}"'

    if "huggingface" in url:
        filename = url.split("/")[-1]
        command += f" -o {filename}"

    if "civitai" in url:
        command += " --content-disposition=true"

    if "drive.google.com" in url:
        command = (
            f"python ./ui/google_drive_download.py --path {destination} --url {url}"
        )
    process_success = True
    with subprocess.Popen(
        shlex.split(command),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    ) as sp:
        print("\033[?25l", end="")
        for line in sp.stdout:
            if line.startswith("[#"):
                text = "Download progress {}".format(line.strip("\n"))
                print("\r" + " " * 100 + "\r" + text, end="", flush=True)
                prev_line = text
            elif line.startswith("[COMPLETED]"):
                if prev_line != "":
                    print("", flush=True)
            else:
                print(line.strip(), flush=True)
        print("\033[?25h")

        # Check the return code of the process
        return_code = sp.wait()
        if return_code != 0:
            process_success = False

    if process_success:
        if zipfile.is_zipfile(os.path.join(destination, filename)):
            with zipfile.ZipFile(os.path.join(destination, filename), "r") as zip_ref:
                zip_ref.extractall(destination)
        print(f"Download completed: {name}")
        return 0
    else:
        print(f"Download failed: {name}")
        return sys.exit(1)


def completed_message():
    completed = widgets.Button(
        description="Completed", button_style="success", icon="check"
    )
    print("\n")
    display(completed)


def download_dataset():
    models_header = widgets.HTML(
        '<h3 style="width: 500px;">Download Dataset จาก Google Drive หรือ Huggingface</h3>'
    )
    headers = widgets.HBox([models_header])
    display(headers)
    textinputlayout = widgets.Layout(width="400px", height="40px")
    dataset_url = widgets.Text(
        value="",
        placeholder="วาง Link Huggingface หรือ Google Drive",
        disabled=False,
        layout=textinputlayout,
    )
    textWidget = widgets.HBox([widgets.Label("Dataset URL:"), dataset_url])
    display(textWidget)

    download_button = widgets.Button(description="Download", button_style="primary")
    output = widgets.Output()

    def on_press(button):
        with output:
            output.clear_output()
            try:
                if dataset_url.value != "":
                    download("Dataset", dataset_url.value, "dataset")
                completed_message()

            except KeyboardInterrupt:
                print("\n\n--Download Model interrupted--")

    download_button.on_click(on_press)

    display(download_button, output)

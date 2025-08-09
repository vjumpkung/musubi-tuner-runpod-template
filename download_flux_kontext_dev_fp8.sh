#!/bin/bash

# Flux Kontext Model Download Script
# Downloads Flux Kontext and related models using aria2c

echo "Starting Flux Kontext model downloads..."

# Create directories for organized storage
mkdir -p diffusion_models
mkdir -p text_encoders
mkdir -p vae

# Download Flux Kontext main model
echo "Downloading Flux1 Kontext Dev FP8 model..."
aria2c \
  --continue=true \
  --max-connection-per-server=16 \
  --split=16 \
  --min-split-size=1M \
  --max-concurrent-downloads=1 \
  --file-allocation=none \
  --summary-interval=10 \
  --dir=./diffusion_models \
  --out=flux1-kontext-dev-fp8-e4m3fn.safetensors \
  "https://huggingface.co/6chan/flux1-kontext-dev-fp8/resolve/main/flux1-kontext-dev-fp8-e4m3fn.safetensors"

# Download CLIP-L text encoder
echo "Downloading CLIP-L text encoder..."
aria2c \
  --continue=true \
  --max-connection-per-server=16 \
  --split=16 \
  --min-split-size=1M \
  --max-concurrent-downloads=1 \
  --file-allocation=none \
  --summary-interval=10 \
  --dir=./text_encoders \
  --out=clip_l.safetensors \
  "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"

# Download T5-XXL FP8 text encoder
echo "Downloading T5-XXL FP8 text encoder..."
aria2c \
  --continue=true \
  --max-connection-per-server=16 \
  --split=16 \
  --min-split-size=1M \
  --max-concurrent-downloads=1 \
  --file-allocation=none \
  --summary-interval=10 \
  --dir=./text_encoders \
  --out=t5xxl_fp8_e4m3fn.safetensors \
  "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors"

# Download VAE autoencoder
echo "Downloading Flux VAE autoencoder..."
aria2c \
  --continue=true \
  --max-connection-per-server=16 \
  --split=16 \
  --min-split-size=1M \
  --max-concurrent-downloads=1 \
  --file-allocation=none \
  --summary-interval=10 \
  --dir=./vae \
  --out=ae.safetensors \
  "https://huggingface.co/lovis93/testllm/resolve/ed9cf1af7465cebca4649157f118e331cf2a084f/ae.safetensors"

echo "All downloads completed!"
echo ""
echo "Files downloaded to:"
echo "  - diffusion_models/flux1-kontext-dev-fp8-e4m3fn.safetensors"
echo "  - text_encoders/clip_l.safetensors"
echo "  - text_encoders/t5xxl_fp8_e4m3fn.safetensors"
echo "  - vae/ae.safetensors"
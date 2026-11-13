#!/usr/bin/env bash
# run-docker.sh - builds the MAS ISO on Ubuntu (or any Linux) using Docker.
# Usage, from inside this folder:   bash run-docker.sh
# The ISO appears in the "out" folder.
set -e
cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker (asks for your password)..."
  sudo apt update
  sudo apt install -y docker.io
fi

sudo docker run --rm --privileged -v "$PWD":/mas -w /mas archlinux:latest \
  bash -c "pacman -Syu --noconfirm --needed archiso && bash build-mas.sh"

echo
echo "Finished. Look in the 'out' folder for the .iso file."

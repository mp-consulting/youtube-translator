#!/bin/bash
set -e

echo "==> Updating apt packages..."
sudo apt-get update

echo "==> Installing pipx..."
sudo apt-get install -y pipx

echo "==> Installing yt-dlp..."
pipx install yt-dlp
pipx ensurepath

echo "==> Installing Ruby dependencies..."
bundle install

echo "==> Verifying installations..."
ruby --version
yt-dlp --version

echo "==> Setup complete!"

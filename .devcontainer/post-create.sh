#!/bin/bash
set -e

echo "==> Updating apt packages..."
sudo apt-get update

echo "==> Installing ffmpeg and python3-pip..."
sudo apt-get install -y ffmpeg python3-pip

echo "==> Installing yt-dlp..."
pip3 install --user yt-dlp

echo "==> Installing Ruby dependencies..."
bundle install

echo "==> Verifying installations..."
ruby --version
yt-dlp --version

echo "==> Setup complete!"

#!/bin/bash
# PiCarD step 1/2: HARDWARE layer — camera, Hailo NPU (AI HAT+ 2), I2C, base packages.
# Safe on a freshly flashed SD card; needs no repos cloned yet.
#
# Usage (on the Pi, as your normal user, NOT root):
#   bash start_step1.sh
# or directly:
#   curl -L https://raw.githubusercontent.com/STEM-PLUS-HK/picard/main/start_step1.sh | bash
set -e

if [ "$EUID" -eq 0 ]; then
    echo "Run as your normal user, not root."
    exit 1
fi

echo "==> [1/3] apt packages (git, python, I2C tools, camera, Hailo NPU driver)"
sudo apt update
sudo apt install -y \
    git \
    python3-pip python3-pil python3-smbus python3-venv \
    i2c-tools \
    python3-picamera2 rpicam-apps \
    hailo-all

echo "==> [2/3] enable I2C"
sudo raspi-config nonint do_i2c 0

echo "==> [3/3] hardware checks (informational — NPU may need the reboot first)"
rpicam-hello --list-cameras 2>/dev/null || echo "WARN: no camera detected (check ribbon cable, both ends)"
hailortcli fw-control identify > /dev/null 2>&1 \
    && echo "OK:   Hailo NPU detected" \
    || echo "WARN: Hailo NPU not answering yet — normal before the first reboot"

echo
read -p "Reboot now to activate I2C + Hailo driver? [y/N] " ans
if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
    sudo reboot
else
    echo "Remember to: sudo reboot   then run start_step2.sh"
fi

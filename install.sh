#!/bin/bash
# PiCarD one-shot installer: OLED display service + JupyterLab service (Raspberry Pi 5)
# Run as the normal user (e.g. admin), NOT as root:
#   cd ~/picard && ./install.sh
set -e

if [ "$EUID" -eq 0 ]; then
    echo "Do not run as root. Run as your normal user; sudo is used where needed."
    exit 1
fi

PICARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIRACER_DIR="$HOME/PiRacer"
VENV="$PIRACER_DIR/.venv"

echo "==> [1/6] apt packages (incl. Hailo NPU driver for AI HAT+ 2)"
sudo apt update
sudo apt install -y python3-pip python3-pil python3-smbus python3-venv i2c-tools hailo-all

echo "==> [2/6] enable I2C (reboot required if this changes the setting)"
sudo raspi-config nonint do_i2c 0

echo "==> [3/6] install picard python package"
pip3 install "$PICARD_DIR" --break-system-packages

echo "==> [4/6] OLED display service"
sudo tee /etc/systemd/system/picard-oled.service > /dev/null <<EOF
[Unit]
Description=PiCard OLED Display
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PICARD_DIR
ExecStart=/usr/bin/python3 $PICARD_DIR/oled_display.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "==> [5/6] Jupyter venv at $VENV"
mkdir -p "$PIRACER_DIR"
python3 -m venv --system-site-packages "$VENV"
"$VENV/bin/pip" install --upgrade pip
"$VENV/bin/pip" install jupyterlab ipykernel ipywidgets
# ponytail: PyPI aarch64 torch wheels are CPU-only, no CUDA cleanup needed on Pi
"$VENV/bin/pip" install torch torchvision

echo "==> [6/6] Jupyter service (passwordless, LAN only!)"
sudo tee /etc/systemd/system/pidemo-jupyter.service > /dev/null <<EOF
[Unit]
Description=PiRacer JupyterLab
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PIRACER_DIR
Environment=HOME=$HOME
Environment=PYTHONUNBUFFERED=1
Environment=PATH=$VENV/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$VENV/bin/jupyter-lab --ip=0.0.0.0 --port=8888 --no-browser --ServerApp.root_dir=$PIRACER_DIR --IdentityProvider.token='' --PasswordIdentityProvider.hashed_password=''
Restart=on-failure
RestartSec=5
KillSignal=SIGINT
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now picard-oled.service
sudo systemctl enable --now pidemo-jupyter.service

echo
echo "Install complete. Verify with:  $PICARD_DIR/test.sh"
echo "If I2C was just enabled, reboot first:  sudo reboot"

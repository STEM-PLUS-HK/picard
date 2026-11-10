#!/bin/bash
# PiCarD step 2/2: SOFTWARE layer — clone GitHub repos, install package + services.
# Run AFTER start_step1.sh (and its reboot).
#
# Usage (on the Pi, as your normal user, NOT root):
#   bash start_step2.sh
# or directly:
#   curl -L https://raw.githubusercontent.com/STEM-PLUS-HK/picard/main/start_step2.sh | bash
set -e

PICARD_REPO="https://github.com/STEM-PLUS-HK/picard.git"
PIRACER_REPO="https://github.com/STEM-PLUS-HK/PiRacer_YOLO.git"

if [ "$EUID" -eq 0 ]; then
    echo "Run as your normal user, not root."
    exit 1
fi

echo "==> [1/2] clone repos (public: anonymous HTTPS, no login)"
clone_or_pull() {
    if [ -d "$2/.git" ]; then
        echo "    $2 already exists, pulling latest"
        git -C "$2" pull --ff-only
    else
        git clone "$1" "$2"
    fi
}
clone_or_pull "$PIRACER_REPO" "$HOME/PiRacer"   # target folder MUST be ~/PiRacer (install.sh expects it)
clone_or_pull "$PICARD_REPO"  "$HOME/picard"

echo "==> [2/2] install picard package + OLED/Jupyter services"
bash "$HOME/picard/install.sh"

echo
echo "Model files are NOT in git — copy them into ~/PiRacer, e.g.:"
echo "  scp best_steering_model_xy.pth admin@<pi-ip>:~/PiRacer/"
echo "  scp -r best_hailo_model admin@<pi-ip>:~/PiRacer/"
echo
echo "Verify everything with:  ~/picard/test.sh"

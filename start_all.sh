#!/bin/bash
# PiCarD + PiRacer full bootstrap: step 1 (hardware) -> reboot -> step 2 (software).
#
# Usage on a freshly flashed Pi 5 (as normal user, NOT root):
#   curl -L https://raw.githubusercontent.com/STEM-PLUS-HK/picard/main/start_all.sh | bash
# or after cloning:
#   bash ~/picard/start_all.sh
set -e

BASE="https://raw.githubusercontent.com/STEM-PLUS-HK/picard/main"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_step() {
    if [ -f "$DIR/$1" ]; then
        bash "$DIR/$1"          # local copy (repo cloned)
    else
        curl -fsSL "$BASE/$1" | bash   # curl|bash bootstrap, nothing cloned yet
    fi
}

run_step start_step1.sh

echo
echo "Step 1 done. If you rebooted, log back in, then finish with:"
echo "  bash $DIR/start_step2.sh"
echo "or:"
echo "  curl -fsSL $BASE/start_step2.sh | bash"

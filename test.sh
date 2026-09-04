#!/bin/bash
# PiCarD sanity checks: I2C devices, services, Jupyter HTTP, python imports
#   cd ~/picard && ./test.sh
pass=0; fail=0
ok()  { echo "PASS  $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1"; fail=$((fail+1)); }
warn(){ echo "WARN  $1"; }

echo "--- I2C devices (bus 1) ---"
map=$(i2cdetect -y 1 2>/dev/null)
if [ -z "$map" ]; then
    bad "i2cdetect failed (I2C enabled? run: sudo raspi-config nonint do_i2c 0)"
else
    echo "$map" | grep -q "3c" && ok "OLED at 0x3c"        || bad "OLED not found at 0x3c"
    echo "$map" | grep -q " 40" && ok "PCA9685 at 0x40"    || bad "PCA9685 not found at 0x40"
fi

echo "--- systemd services ---"
for svc in picard-oled pidemo-jupyter; do
    systemctl is-enabled --quiet "$svc" && ok "$svc enabled" || bad "$svc not enabled"
    systemctl is-active  --quiet "$svc" && ok "$svc active"  || bad "$svc not active (logs: journalctl -u $svc -b)"
done

echo "--- Jupyter HTTP ---"
curl -sf -o /dev/null --max-time 5 http://127.0.0.1:8888/lab \
    && ok "JupyterLab responding on :8888 (open http://$(hostname -I | awk '{print $1}'):8888/lab)" \
    || bad "JupyterLab not responding on :8888"

echo "--- python imports ---"
python3 -c "import robot" 2>/dev/null \
    && ok "robot package (PiRacer servo/motor)" \
    || bad "robot package (run: pip3 install ~/picard --break-system-packages)"
python3 -c "import oled_display, adafruit_ssd1306" 2>/dev/null \
    && ok "oled_display module" \
    || bad "oled_display module"

echo "--- NPU (optional) ---"
hailortcli fw-control identify > /dev/null 2>&1 \
    && ok "Hailo NPU detected" \
    || warn "Hailo NPU not detected (NPU column will show '--'; try: sudo apt install hailo-all)"

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

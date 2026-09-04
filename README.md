# PiCard

OLED stats display + PCA9685 servo/motor (ESC) control for the Raspberry Pi 5 (with AI HAT+ 2).

## Tech Stack

- Raspberry Pi 5, I2C bus 1
- SSD1306 128×32 OLED (`0x3c`) via `adafruit-circuitpython-ssd1306` / Blinka
- PCA9685 16-channel PWM driver (`0x40`) via `smbus` — steering servo (ch 0) + ESC motor (ch 1), 50 Hz
- Hailo-10H (AI HAT+ 2) temperature via `hailo_platform` (optional; NPU column shows `--` without it)

## Architecture

```
picard/
├── oled_display.py     # stats display loop: IP / CPU NPU RAM DSK, 2 s refresh
├── robot/
│   ├── pca9685.py      # I2C PWM driver (duty cycle per channel)
│   ├── motor.py        # Motor (2-pin H-bridge) and Servo (pulse-width) classes
│   └── piracer.py      # PiRacer: steering + throttle traits, ~/piracer_conf.json calibration
└── setup.py
```

`PiRacer.steering` / `PiRacer.throttle` are `-1.0 … 1.0`. Steering pulse = 1000–2000 µs.
The ESC is driven like a servo: `0` = neutral, positive = forward, negative = reverse.
Calibration lives in `~/piracer_conf.json` (created on first run — edit duty cycles there, not in code).

## Quick install (one shot)

Fresh SD card → fully working system:

```bash
# 1. clone BOTH repos first (git can't clone into ~/PiRacer after the venv exists)
git clone <PiRacer-repo> ~/PiRacer
git clone <this-repo> ~/picard

# 2. run the installer as your normal user, NOT root
cd ~/picard
./install.sh

# 3. reboot (I2C + Hailo driver need it)
sudo reboot

# 4. sanity-check everything
~/picard/test.sh

# 5. copy model files (not in git) into ~/PiRacer:
#    best_steering_model_xy.pth, best_hailo_model/best.hef + metadata.yaml
```

JupyterLab: `http://<pi-ip>:8888/lab` (passwordless — trusted LAN only).

## Manual install

```bash
sudo apt update
sudo apt install python3-pip python3-pil python3-smbus i2c-tools
sudo raspi-config nonint do_i2c 0   # enable I2C, reboot if needed

git clone <this-repo> ~/picard
cd ~/picard
pip3 install . --break-system-packages   # or: pip install . inside a venv
```

Verify wiring (`3c` = OLED, `40` = PCA9685):

```bash
i2cdetect -y 1
```

## Wiring (PCA9685 → Pi 5)

| PCA9685 | Pi 5 |
|---|---|
| VCC (logic) | Pin 1 (3.3V) |
| GND | Pin 6 (GND) |
| SDA | Pin 3 |
| SCL | Pin 5 |
| V+ (servo power) | External 5–6V — **not** from the Pi |
| Servo signal | Channel 0 |
| ESC signal | Channel 1 |

## Motor / Servo quickstart

Wheels off the ground. The ESC needs neutral (`0`) for ~2 s to arm.

```python
from robot import PiRacer
import time

car = PiRacer(bus=1)
try:
    car.steering = 0.5; time.sleep(1)
    car.steering = 0
    car.throttle = 0; time.sleep(2)   # arm ESC
    car.throttle = 0.15; time.sleep(1)
finally:
    car.stop()
```

Steering reversed? Call `car.servo.reverse_output()` once, or flip the alphas in `~/piracer_conf.json`.

## OLED display service (auto-start on boot)

Test manually first: `python3 ~/picard/oled_display.py` (Ctrl+C to stop).

```bash
sudo nano /etc/systemd/system/picard-oled.service
```

```ini
[Unit]
Description=PiCard OLED Display
After=network.target

[Service]
Type=simple
User=admin
WorkingDirectory=/home/admin/picard
ExecStart=/usr/bin/python3 /home/admin/picard/oled_display.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now picard-oled.service
sudo reboot   # verify it survives boot
```

## JupyterLab service (auto-start on boot)

Venv lives at `~/PiRacer/.venv` (`--system-site-packages`, so it sees apt/pip system packages):

```bash
mkdir -p ~/PiRacer
python3 -m venv --system-site-packages ~/PiRacer/.venv
~/PiRacer/.venv/bin/pip install --upgrade pip
~/PiRacer/.venv/bin/pip install jupyterlab ipykernel ipywidgets torch torchvision
```

(On aarch64, PyPI `torch` wheels are already CPU-only — no CUDA cleanup needed.)

```bash
sudo nano /etc/systemd/system/pidemo-jupyter.service
```

```ini
[Unit]
Description=PiRacer JupyterLab
After=network.target

[Service]
Type=simple
User=admin
WorkingDirectory=/home/admin/PiRacer
Environment=HOME=/home/admin
Environment=PYTHONUNBUFFERED=1
Environment=PATH=/home/admin/PiRacer/.venv/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/admin/PiRacer/.venv/bin/jupyter-lab --ip=0.0.0.0 --port=8888 --no-browser --ServerApp.root_dir=/home/admin/PiRacer --IdentityProvider.token='' --PasswordIdentityProvider.hashed_password=''
Restart=on-failure
RestartSec=5
KillSignal=SIGINT
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now pidemo-jupyter.service
systemctl status pidemo-jupyter.service --no-pager
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `FileNotFoundError: '.lgd-nfy-3'` in service logs | `WorkingDirectory` missing — lgpio writes pipe files to CWD, `/` is not writable |
| No `3c`/`40` in `i2cdetect` | Enable I2C (`raspi-config`), check SDA=Pin 3 / SCL=Pin 5 |
| NPU shows `--` | `sudo apt install hailo-all`, reboot; check `hailortcli fw-control identify` |
| Service dead after reboot | `sudo systemctl enable picard-oled.service`; logs: `journalctl -u picard-oled.service -b` |

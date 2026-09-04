import os
import subprocess
import time

COL = 26  # 4 columns x 26px = 104px, fits 128px width
HEADERS = ["CPU", "NPU", "RAM", "DSK"]

_npu_device = None


def get_ip():
    try:
        ips = subprocess.check_output(["hostname", "-I"]).decode().split()
        return ips[0] if ips else "not available"
    except Exception:
        return "not available"


def get_cpu():
    try:
        load1 = float(open("/proc/loadavg").read().split()[0])
        return f"{min(int(load1 * 100 / 4), 99):2d}%"
    except Exception:
        return "--"


def get_npu():
    # ponytail: holds the device open across reads; recreates it if the read fails
    global _npu_device
    try:
        from hailo_platform import Device
        if _npu_device is None:
            _npu_device = Device()
        temp = _npu_device.control.get_chip_temperature().ts0_temperature
        return f"{int(temp):2d}C"
    except Exception:
        _npu_device = None
        return "--"


def get_ram():
    try:
        with open("/proc/meminfo") as f:
            lines = f.readlines()
        total = int(lines[0].split()[1])
        avail = int(lines[2].split()[1])  # MemAvailable
        return f"{int((total - avail) / total * 100):2d}%"
    except Exception:
        return "--"


def get_disk():
    try:
        st = os.statvfs("/")
        return f"{int((st.f_blocks - st.f_bfree) / st.f_blocks * 100):2d}%"
    except Exception:
        return "--"


def main():
    from board import SCL, SDA
    import busio
    from PIL import Image, ImageDraw, ImageFont
    import adafruit_ssd1306

    i2c = busio.I2C(SCL, SDA)
    oled = adafruit_ssd1306.SSD1306_I2C(128, 32, i2c)
    oled.fill(0)
    oled.show()

    image = Image.new("1", (oled.width, oled.height))
    draw = ImageDraw.Draw(image)

    # ponytail: size 9 truetype renders distinct 6/8 glyphs; fallback keeps it working anywhere
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 9)
    except Exception:
        font = ImageFont.load_default()

    while True:
        draw.rectangle((0, 0, oled.width, oled.height), outline=0, fill=0)

        # Row 1: IP address
        draw.text((4, 0), f"IP: {get_ip()}", font=font, fill=255)

        # Row 2: headers
        for i, header in enumerate(HEADERS):
            draw.text((i * COL + 4, 11), header, font=font, fill=255)

        # Row 3: values
        values = [get_cpu(), get_npu(), get_ram(), get_disk()]
        for i, value in enumerate(values):
            draw.text((i * COL + 4, 22), value, font=font, fill=255)

        oled.image(image)
        oled.show()
        time.sleep(2)


if __name__ == "__main__":
    main()

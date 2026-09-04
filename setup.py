from setuptools import setup

setup(
    name="picard",
    version="0.1.0",
    description="PiCarD: OLED stats display + PCA9685 servo/motor (ESC) control for Raspberry Pi 5",
    py_modules=["oled_display"],
    packages=["robot"],
    install_requires=[
        "traitlets",
        "pillow",
        "smbus2",
        "adafruit-blinka",
        "adafruit-circuitpython-ssd1306",
    ],
    python_requires=">=3.9",
)

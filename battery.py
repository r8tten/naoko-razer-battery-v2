#!/usr/bin/env python3

import os
import dbus
from openrazer.client import DeviceManager

CACHE = os.path.expanduser("~/.cache/razer-battery")
DESIRED_POLL_RATE = 1000

def save_battery(value):
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)

    with open(CACHE, "w") as f:
        f.write(str(value))


def load_battery():
    try:
        with open(CACHE, "r") as f:
            return f.read().strip()
    except FileNotFoundError:
        return ""


try:
    dm = DeviceManager()

    battery = None
    charging = False
    dpi = None
    poll_rate = None
    firmware = None
    driver = None

    for device in dm.devices:
        if "DeathAdder" in device.name:
            power = dbus.Interface(
                device._dbus,
                "razer.device.power"
            )

            battery = round(power.getBattery())
            charging = power.isCharging()

            dpi_value = device.dpi
            if isinstance(dpi_value, (tuple, list)) and len(dpi_value) >= 1:
                dpi = dpi_value[0]
            elif dpi_value is not None:
                dpi = dpi_value

            poll_rate = device.poll_rate

            if poll_rate is not None and poll_rate != DESIRED_POLL_RATE:
                try:
                    device.poll_rate = DESIRED_POLL_RATE
                    poll_rate = DESIRED_POLL_RATE
                except Exception:
                    pass

            firmware = device.firmware_version
            driver = device.driver_version

            break

    # DeathAdder reports fake 0% while asleep.
    if battery == 0:
        cached = load_battery()

        if cached:
            battery = int(cached)
        else:
            battery = None

    elif battery is not None:
        save_battery(battery)

    if battery is not None:
        print(
            f"{battery}|"
            f"{1 if charging else 0}|"
            f"{dpi if dpi is not None else ''}|"
            f"{poll_rate if poll_rate is not None else ''}|"
            f"{firmware if firmware is not None else ''}|"
            f"{driver if driver is not None else ''}"
        )
    else:
        print("")

except Exception:
    print("")

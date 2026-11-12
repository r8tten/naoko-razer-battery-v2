# Razer Battery V2

A bar widget for the Omarchy shell (Quickshell) that shows the battery level of a
**Razer DeathAdder V2 Pro**, plus DPI, polling rate, firmware and driver version.

<!-- Drop a screenshot into screenshots/panel.png, then uncomment:
![Razer Battery V2 panel](screenshots/panel.png)
-->

## Features

- Battery percentage and charging/wireless state as the panel's focal point, with a
  level bar underneath.
- 2×2 stat grid: DPI, polling rate, firmware, driver. Each cell hides itself when
  the device does not report a value.
- A "Mouse not connected" empty state instead of a column of `Unavailable` rows.
- Bar icon with a ten-band battery glyph matching Omarchy's own battery widget,
  a hover tooltip (`50%`, `50% · charging`), the accent colour from the original
  plugin, and a red icon below 20%.
- Desktop notification when the mouse reaches full charge, once per charge cycle.
- Follows the bar's font family, font scale, spacing scale and theme colours.
- Panel closes with `Esc`, the close button, or a click outside.

## Requirements

- Omarchy running the Omarchy shell (Quickshell).
- OpenRazer, with the daemon running:

  ```bash
  sudo systemctl enable --now openrazer-daemon   # or the user service
  ```

  Arch packages used here: `openrazer-daemon`, `openrazer-driver-dkms`,
  `python-openrazer`, `python-dbus`.
- A Nerd Font for the battery/mouse glyphs (the Omarchy default font is fine).

OpenRazer must currently be able to see the mouse. Check with:

```bash
python3 -c 'from openrazer.client import DeviceManager; print([d.name for d in DeviceManager().devices])'
```

## Install

```bash
git clone https://github.com/r8tten/naoko-razer-battery-v2.git ~/Projects/naoko-razer-battery-v2
cp -r ~/Projects/naoko-razer-battery-v2 ~/.config/omarchy/plugins/naoko.razer-battery-v2
```

Then open the bar settings, add the **Razer Battery V2** widget, and place it where
you want it. The plugin is disabled until you do — cloning it alone changes nothing
on screen.

The directory name `naoko.razer-battery-v2` matches the plugin id in
`manifest.json`; keep it that way if you install by hand.

To update later:

```bash
git -C ~/Projects/naoko-razer-battery-v2 pull
cp -r ~/Projects/naoko-razer-battery-v2 ~/.config/omarchy/plugins/naoko.razer-battery-v2
```

## Behaviour worth knowing

- **It forces a 1000 Hz polling rate.** `battery.py` sets `device.poll_rate = 1000`
  on every run if it differs, overriding whatever OpenRazer/Polychromatic has
  configured. Remove the `DESIRED_POLL_RATE` block in `battery.py` if you would
  rather keep your own setting.
- **It polls every 7 seconds**, by running `battery.py` and reading one `|`-separated
  line from stdout.
- **It matches any device whose name contains "DeathAdder"**, not just the V2 Pro.
- **Sleeping mice report 0%.** When the reported level is `0`, the last good value is
  read from `~/.cache/razer-battery` and shown instead, so the percentage can be
  stale while the mouse is idle. This is deliberate: the alternative is the icon
  randomly dropping to 0%.
- **Notifications** use `notify-send` and fire once per charge cycle (the latch
  resets when the mouse stops charging).

## Uninstall

Disable/remove the widget in the bar settings, then:

```bash
rm -rf ~/.config/omarchy/plugins/naoko.razer-battery-v2
```

## License

MIT — see [LICENSE](LICENSE).

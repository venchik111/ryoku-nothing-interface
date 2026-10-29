# Lockscreen checks

From the repository root:

```sh
python3 -m unittest discover -s lockscreen/tests -p 'test_*.py' -v
```

The suite checks player selection, metadata consistency, missing playerctl,
timeouts, invalid durations, package paths, byte sizes, SHA-256 digests and
installation into a temporary directory.

With a Qt 6 QML runtime installed, it also loads the actual theme and data
component offscreen under six locales. It checks translated labels, localized
dates, password focus, login-error reset and that playback controls target the
displayed player even when the selected player changes between clicks.

The QML fixtures replace SDDM and Quickshell I/O with inert test doubles. They
do not authenticate, lock the screen, connect to a live wallpaper socket or
control real media players. QML checks are skipped when Qt is unavailable;
Ryoku's installed translation catalogue is used when present.

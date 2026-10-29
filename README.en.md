# Nothing Interface for Ryoku

**Charcoal surfaces. Dot-matrix clock. Island bar.** An unofficial [Ryoku](https://ryoku.dev) theme inspired by Nothing OS. [Русский README](README.md).

The theme leaves your wallpaper unchanged. An [optional set of six AI-generated 16:9 wallpapers](wallpapers/README.md) is available separately in this repository. These are unofficial adaptations of the phone-sized Connected Collection artwork, not official Nothing desktop wallpapers. Proprietary Nothing font files are not bundled.

## Screenshots

![Nothing Interface desktop at 1920 × 1080 with the island bar, widgets and Spotify album art](assets/screenshots/desktop-1920x1080.png)

Captured on the Ryoku desktop with Spotify playing. Song lyrics were hidden for the screenshot only.

![Rendered preview of the Nothing Interface lock screen using the current wallpaper, live status and Spotify track](assets/screenshots/lockscreen-preview-1920x1080.png)

The lock screen image is a QML render with the current wallpaper and status data; it was captured without locking the session.

## What you get

- A three-island QS Bar, a four-dot launcher mark and monochrome status icons.
- A large QML-drawn dot clock and date, plus analog clock, battery, screen-time and media widgets.
- A lock screen with the current Ryogami wallpaper, live widgets, media playback control and Ryoku password authentication.
- An optional circular audio widget. Red is reserved for the analog second hand and critical battery alerts.
- A fixed charcoal and grey palette that does not follow or replace your wallpaper.

| Analog clock | Battery | Screen time |
| :---: | :---: | :---: |
| <img src="plugins/nothing-analog-clock/assets/preview-widget.png" width="180" alt="Analog clock"> | <img src="plugins/nothing-dashboard/assets/preview-widget.png" width="180" alt="Battery tile"> | <img src="plugins/nothing-screen-time/assets/preview-widget.png" width="180" alt="Screen time"> |

| Media | Optional audio | Bar status |
| :---: | :---: | :---: |
| <img src="plugins/nothing-media/assets/preview-widget.png" width="180" alt="Schematic media tile without playback data"> | <img src="plugins/nothing-audio/assets/preview-widget.png" width="180" alt="Audio widget"> | <img src="plugins/nothing-status/assets/preview-widget.png" width="180" alt="Bar status"> |

## Install

Built with **Ryoku 0.75.3**. The four QML overrides may need updates with future Ryoku versions. Individual plugin manifests list their local command dependencies.

```bash
git clone https://github.com/venchik111/ryoku-nothing-interface.git
cd ryoku-nothing-interface
for name in nothing-analog-clock nothing-dashboard nothing-media nothing-screen-time; do
  ryoku plugin add "plugins/$name" --yes
done
ryoku plugin add plugins/nothing-status --bar --yes
ryoku-hub rice import "$PWD/theme"
ryoku-hub rice apply nothing-interface
ryoku-shell dock hide
```

Save your current Ryoku rice before applying the new one. The optional audio widget can be installed with `ryoku plugin add plugins/nothing-audio --yes`.

For the custom clock and launcher appearance, back up any existing `~/.config/ryoku/user_edits` directory, then copy `theme/user_edits/.` into it and run `ryoku reload`. These are user overlays; do not edit Ryoku's shipped files. If you already customized the same four QML files, preserve your changes before copying.

Place the plugins through **Ryoku Hub → Widgets**. [`theme/layout-example.json`](theme/layout-example.json) records a 1920 × 1080 reference layout and is not imported automatically. Set outer window gaps to **8** in **Ryoku Hub → Window Manager** if you want the same tight spacing. Adjust the islands in **QS Bar Settings → Bars / Layout / Community**. Restore a missing built-in bar clock with `ryoku-shell bar move clock --section center --index 0`.

The reference layout uses a 120 pixel cell and a 16 pixel gap in logical coordinates on a 1920 × 1080 display at 1.5 scale. Square tiles are 256 × 256, screen time is 256 × 120, and the rectangular media tile is 392 × 256.

Install the lock screen separately:

```bash
mkdir -p "$HOME/.local/share/qylock/themes"
cp -a lockscreen/nothing-interface "$HOME/.local/share/qylock/themes/"
ryoku-hub lock set nothing-interface
```

Select or restore a lock screen in **Ryoku Hub → Lockscreen**. This theme subscribes to Ryogami's wallpaper updates, including changes made while the session is locked. The lock screen's clock, battery, daily screen time and MPRIS media information refresh in place.

For an SDDM sign-in screen that retains the wallpaper across reboots, run `bash lockscreen/install-greeter.sh`. The installer requests system authorization and enables a user service that saves the latest background outside the home directory. The sign-in screen includes installed session selection, suspend, shutdown and restart; shutdown and restart require confirmation. See [installation and verification details](lockscreen/README.md).

The media tile reads local MPRIS metadata and Ryoku's lyrics feed. It fills the cover area with the player's album art when available, falling back to the geometric disc otherwise. Qt may fetch a remote artwork URL supplied by the player. Screen time comes from Ryoku's own daily counter.

## Fonts, wallpaper and license

The main font is **Noto Sans**; large dotted digits are drawn in QML. Optional NType 82 files can be obtained from the [Nothing community brand reference](https://nothing.wiki/nothing/brand_reference). Nothing's original font files and phone wallpapers are not redistributed here. You can add the [optional AI-generated widescreen wallpapers](wallpapers/README.md) to Ryoku's wallpaper picker. [Nothing's Launcher Beta post](https://nothing.community/d/617-a-glimpse-of-nothing-os-nothing-launcher-beta-is-here) links to a different original wallpaper pack.

This is an independent fan project, unaffiliated with Nothing Technology Limited. Original plugins, preset and documentation are [MIT licensed](LICENSE). The QML adaptations retain their upstream Ryoku licenses. The optional AI-generated wallpapers are based on third-party artwork and **are not covered by the repository's MIT license**; see [NOTICE.md](NOTICE.md) for attribution. Nothing trademarks and original artwork belong to their respective owners.

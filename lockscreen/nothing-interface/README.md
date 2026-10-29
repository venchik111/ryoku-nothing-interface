# Nothing Interface lockscreen

Nothing OS inspired lockscreen for Ryoku, with live wallpaper, battery,
screen time and MPRIS media. Labels and dates follow the system locale using
Ryoku's translation catalogue at `/usr/share/ryoku/i18n`; missing labels fall
back to English. The media button controls the player shown in the card.

Install from the repository root:

```sh
mkdir -p "$HOME/.local/share/qylock/themes"
cp -a lockscreen/nothing-interface "$HOME/.local/share/qylock/themes/"
ryoku-hub lock set nothing-interface
```

Select or restore the theme in **Ryoku Hub → Lockscreen**. The theme uses
Ryoku's existing authentication mechanism and requires `python3` and `playerctl`
for its local data helpers. Quickshell-specific code is loaded only during
in-session locking. It does not bundle wallpapers or Nothing fonts.

Version 0.2.0 also supports a persistent SDDM background, session selection and
confirmed shutdown/reboot controls. To enable background synchronization, run
`bash lockscreen/install-greeter.sh` from the source repository as your desktop
user. It requests system authorization and requires `python-pillow`. See
`../README.md` for the greeter setup and `../nothing-greeter-wallpaper.service`
for the user service; those setup files remain outside this theme package.

The package manifest lists files relative to this directory. After changing a
listed file, update its byte size and SHA-256 digest. Developer checks are
documented in `../tests/README.md` in the source repository.

Source: https://github.com/venchik111/ryoku-nothing-interface

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/yoke-menubar-dark.svg">
    <img src="assets/yoke-menubar.svg" alt="Yoke: a gamepad with fried eggs for sticks" width="168">
  </picture>
</p>

<h1 align="center">Yoke</h1>

<p align="center">Drive your Mac from a game controller.</p>

A macOS menu-bar app. The left stick moves the pointer, the right stick scrolls, a shoulder button holds your dictation key, and the plus pad switches desktops.

## Install

Download the DMG from [Releases](https://github.com/chatur-dev/yoke/releases/latest), open it, and drag Yoke to Applications. Needs macOS 14 or later.

Or build it yourself with the Xcode command line tools:

```sh
git clone https://github.com/chatur-dev/yoke.git
cd yoke
make install
```

Connect a controller, click the Yoke icon in the menu bar, and allow Accessibility when asked.

## Controls

| Control | Does |
| --- | --- |
| Left stick | Pointer |
| Right stick | Scroll. Flick sideways for browser back and forward. |
| LT | Slow, precise pointer while held |
| RB | Talk. Holds the dictation key (Fn by default). |
| LB | Option |
| A / B | Left click / right click |
| X | Enter |
| Y | Focus the text field |
| Plus left / right | Previous / next desktop |
| Plus up / down | Next full-screen space / next desktop |
| Back | Delete mode. Push the right stick to erase. |
| Start | Suspend or resume |

Every button can be reassigned from the menu. The menu also has a screen magnifier (1.5×, 2×, 3×), speed sliders, button calibration, and launch at login.

## Dictation

Yoke only holds a key. Set push-to-talk in Wispr Flow, Hex, or any other dictation app to Fn, then hold RB and talk.

## Notes

- Desktop switching and the magnifier use private macOS APIs and may break on a system update.
- Yoke does not grab the controller. Press Start to suspend before playing a game.

## License

[MIT](LICENSE)

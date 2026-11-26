<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/yoke-menubar-dark.svg">
    <img src="assets/yoke-menubar.svg" alt="Yoke: a gamepad with fried eggs for sticks" width="168">
  </picture>
</p>

<h1 align="center">Yoke</h1>

<p align="center">Drive your Mac from a game controller. Pointer, scroll, dictation, and desktops, from the couch or the bed.</p>

Yoke is a macOS menu-bar app. The left stick flies the pointer, the right stick scrolls like a trackpad, a shoulder button holds your dictation key, and the plus pad moves between desktops. It stays out of the Dock.

Any controller macOS can see works, over Bluetooth or USB. It was built around an Evo Fox.

## Controls

These are the defaults. Every button can be reassigned from the menu.

| Control | Does |
| --- | --- |
| Left stick | Pointer. Speed follows how far you push. |
| Right stick | Scroll. A hard sideways flick goes back or forward in the browser. |
| LT | Precision. Slows the pointer while held. |
| RB | Talk. Holds the dictation key until you let go. |
| LB | Option, while held |
| A / Cross | Left click. Hold to drag. |
| B / Circle | Right click |
| X / Square | Enter |
| Y / Triangle | Focus the text field in the front app |
| L3 / R3 | Left click / right click |
| Plus left / right | Previous / next desktop on the display under the pointer |
| Plus up | Next full-screen space |
| Plus down | Next ordinary desktop |
| Back / Select | Delete mode |
| Start | Suspend. The pad goes back to being a pad. |
| ML / MR | Command while held / paste, on pads that report these as buttons |

Press Start again to drive. Quitting, disconnecting, or suspending releases every key and mouse button Yoke is holding, so nothing gets stuck down.

### Delete mode

Press Back, then push the scroll stick to erase. A light push takes characters, a hard push takes words, then the whole line. Hold LT to go one character at a time. Press Back again to leave. The menu-bar icon changes while it is on.

## The menu

Click the icon in the menu bar.

- **Magnifier.** Zooms the display the pointer is on to 1.5×, 2×, or 3×, and the view follows the pointer. Off puts it back, and so does quitting.
- **Driving.** The same as Start: turn the pad off without quitting.
- **Pointer speed and scroll speed**, with separate invert toggles.
- **Talk key.** Which key RB holds.
- **Buttons.** Reassign any control, or run Calibrate buttons if the face buttons come up in the wrong order.
- **Launch at login.**

## Dictation

Yoke does not transcribe anything. Talk holds a key, and your dictation app does the rest. It works with Wispr Flow, Hex, or anything else with a push-to-talk shortcut.

1. In your dictation app, set push-to-talk to Fn.
2. Hold RB and talk. Let go to stop.

If your app will not take Fn, switch the Talk key in the Yoke menu to Right Option or Control + Option, and set the same shortcut there.

## Install

Yoke builds from source. You need macOS 14 or later and Xcode or the Xcode command line tools.

```sh
git clone https://github.com/chatur-dev/yoke.git
cd yoke
make install
```

That builds `dist/Yoke.app`, copies it to `/Applications`, and opens it. Then:

1. Connect the controller. For Bluetooth, pair it in System Settings → Bluetooth.
2. Click the Yoke icon in the menu bar and allow Accessibility when asked. Without it the stick does nothing, and the menu says so.
3. If the pad connects but never moves anything, allow Yoke under Input Monitoring and reconnect the pad.

A rebuild can make macOS ask for Accessibility again. The build script signs with your development identity when you have one, which keeps the grant.

## Controllers

Xbox, DualSense, and Switch pads usually arrive as a standard gamepad. Cheaper pads, the Evo Fox included, often arrive as a generic HID device. Yoke reads the HID path first, because it keeps working while the app sits in the background.

If A and B are swapped, choose Calibrate buttons in the menu. It asks for each button once and remembers the order.

Yoke does not take the controller exclusively, so a game still sees it. Suspend with Start before you play, or the pointer will move too.

## Good to know

- Moving desktops and the magnifier use private macOS window-server calls, because there is no public way to do either. They were written against macOS 27 and a system update can break them.
- Yoke is not sandboxed. A sandboxed app cannot post pointer events or read the gamepad.
- Nothing you type and no controller input is written to disk.
- The mapping lives in `~/Library/Application Support/Yoke/profile.json`. Delete it to go back to the defaults.

## Development

```sh
swift test   # the mapping engine
make app     # build without installing
```

`Sources/YokeCore` is the mapping engine and has no AppKit in it. `macos/` is the menu-bar app. The defaults are `Profile.bed` in `Sources/YokeCore/Model.swift`.

## License

[MIT](LICENSE)

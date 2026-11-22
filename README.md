# Yoke

A menu-bar app that flies the Mac pointer from a game controller. Hold a shoulder and it holds the dictation key. The app stays out of the Dock.

Any Bluetooth pad works. An Evo Fox is the one this was built around. The same Mac app runs on the MacBook and a Mac mini. Linux (Nomadji / Omarchy) is next and is not in this tree yet.

## From the bed

| Control | Does |
| --- | --- |
| Left stick | Pointer. Speed follows how far you push, not a fixed crawl. |
| Left trigger | Precision. Full stick becomes a slow stick while held. |
| Right stick | Scroll |
| Right trigger | Talk. Holds Right Option until you let go. |
| Left bumper | Option |
| Right bumper | Fn |
| A / Cross | Left click. Hold to drag. |
| B / Circle | Right click |
| X / Square | Middle click |
| Y / Triangle | Mission Control |
| D-pad | Arrow keys |
| Back | Spotlight |
| Start | Suspend. The pad goes back to being a pad. |

Start again to drive. Quitting, disconnecting, or suspending releases every key Yoke is holding, so Option cannot get stuck down.

## Wispr or Hex

Wispr will not take a bare F13. A modifier on its own is allowed, and macOS will actually deliver Right Option. Fn is Wispr's own default, but a synthetic Fn is often swallowed, so it is a preset rather than the one Yoke starts on.

1. Open the Flow menu-bar icon, then Shortcuts.
2. Set Push to talk to Right Option.
3. Hold the right trigger and talk. Release to stop.

Hex gets the same shortcut. The Talk menu in Yoke can switch to Fn, Control+Option, or Option+F13 if you would rather match a shortcut you already have.

## Install

Pair the controller in System Settings → Bluetooth first. Evo Fox pads usually want their Bluetooth mode, not the 2.4 GHz dongle mode, though the dongle is still a HID pad and should show up.

```sh
make install
```

That builds `dist/Yoke.app`, copies it to `/Applications`, and opens it. The icon is a game controller in the menu bar. Click it.

Grant Accessibility when asked. Without it the stick does nothing, and the popover says so. If a generic pad connects but never moves, allow Yoke under Input Monitoring and reconnect the pad.

`make app` only builds. `swift test` runs the mapping tests.

Each ad-hoc rebuild can make macOS ask for Accessibility again. The build script signs with your development identity when you have one, which keeps that grant.

## A pad macOS does not understand

Xbox, DualSense, and Switch pads usually arrive as a standard gamepad. An Evo Fox often arrives as a generic HID pad instead. Yoke reads that path first, because it keeps working while the app is in the background.

If A and B are swapped, open Yoke and choose Calibrate buttons. It asks for each face button once and remembers the order. If the stick is backwards, Invert stick is next to that.

Yoke does not grab the controller exclusively. A game still sees it. Suspend with Start before you play, or the pointer will move too.

## Profile

The mapping lives in `~/Library/Application Support/Yoke/profile.json`. The bed defaults are `Profile.bed` in `Sources/YokeCore/Model.swift`.

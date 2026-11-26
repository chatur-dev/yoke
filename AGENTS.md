# Yoke

Menu-bar app that flies the Mac pointer from a game controller. Dictation is a held keyboard shortcut for Wispr Flow or Hex, not speech recognition.

## Layout

- `Sources/YokeCore` is the mapping engine. No AppKit. `swift test` covers it.
- `macos/` is the agent app: IOHID first (works in the background, which is how an Evo Fox shows up), GameController as fallback, CGEvent for the pointer and keys.
- `LSUIElement` is on. It must not appear in the Dock.

## Checks

On a Mac:

```sh
swift test
make app
```

Do not sandbox the app. Sandbox blocks the pointer injection and the gamepad. Do not log keystrokes or controller state to disk.

## Dictation

The default hold is Fn, posted as a modifier flag only: a Fn key-down makes macOS draw the volume meter. Right Option and Control + Option are presets in the Talk menu. Disconnect, suspend, and quit must release every held key and mouse button.

## Releases

`make dmg` builds a universal DMG. `make release` also tags `v<version>` from `macos/Info.plist` and uploads it. Only the operator publishes.

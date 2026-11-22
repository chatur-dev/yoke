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

Wispr rejects a bare function key. The default hold is Right Option, posted as a real modifier. Fn is a preset, not the default, because macOS often swallows a synthetic Fn. Disconnect, suspend, and quit must release every held key and mouse button.

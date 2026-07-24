# KeyLock

A simple little macOS menu bar utility that locks the keyboard so you can clean it
without random nonsense happening. Mouse and trackpad are unaffected.

## Usage

- Click the keyboard icon in the menu bar, then **Lock Keyboard**.
- While locked, the icon changes to a filled padlock and all key presses,
  modifier keys, and media keys are swallowed.
- Click the padlock icon, then **Unlock Keyboard** when you're done.

The first time you lock, macOS will ask you to grant Accessibility access
(System Settings > Privacy & Security > Accessibility). That permission is
required to intercept keystrokes. Enable KeyLock there, then lock again.

## Building

```bash
./build.sh
```

Produces `KeyLock.app` in this directory. Open it with `open KeyLock.app`.

To have it start at login: System Settings > General > Login Items > add KeyLock.app.

## How it works

Single-file Swift app (`Sources/main.swift`). When lock mode is entered, it installs a
session-level `CGEventTap` for keyDown/keyUp/flagsChanged/system-defined
events and drops them. Mouse events are ignored. If the app quits or
crashes while locked, the tap dies with the process and the keyboard
immediately works again. 

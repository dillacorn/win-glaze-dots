# WGDot v4.6.5

Improves launcher responsiveness and brings the managed GlazeWM keybinds closer to the Awtarchy experience without taking over native Windows shortcuts.

## Install and update

- [Install](https://github.com/dillacorn/win-glaze-dots/blob/main/INSTALL.md)
- [Update](https://github.com/dillacorn/win-glaze-dots/blob/main/UPDATE.md)

## Changes

- Reduced WGDot launcher cold-start overhead and moved icon loading off the first visible frame.
- Fixed `Super+D` so the launcher no longer leaves Windows Start/Search open after activation.
- Restored Vesktop workspace-3 routing and expanded Awtarchy-style workspace, tiling, terminal, RawAccel, and H/J/K/L resize shortcuts across Normal and Work profiles.
- Kept `Super+Ctrl+Arrow` available to native Windows virtual desktops.
- Kept persistent Floating Windows mode as an intentional bar/Quick Settings control only; VM `Super+Alt+F` still toggles the active window floating.

## Validation

- PR #85 passed WGDot PowerShell 7, Windows PowerShell 5.1, YASB/desktop schema, and native-bootstrap validation.
- The maintainer runtime-tested the responsive `Super+D` launcher behavior and Vesktop workspace routing before merge.

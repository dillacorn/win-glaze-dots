# Qalc calculator on Windows

Win-Glaze-Dots uses **Qalculate!** (`Qalculate.Qalculate`) for native Qalc CLI calculations. Windows intentionally uses the native calculator UI, not Awtarchy's custom bottom-input frontend. A custom calculator-specific `wgdot.exe` runtime is not required.

- `Alt+Shift+C` and left/right `Super+Shift+C` open independent Windows Terminal windows. The Super bindings also work in `noalt` mode.
- `qalc.exe -s "autocalc on"` enables calculate-as-you-type results. The native Qalc prompt and calculation history follow Qalc's normal top-to-bottom layout; the input is **not** fixed at the bottom.
- The terminal title is `Qalc`, the requested terminal dimensions are 46 columns by 22 rows, and GlazeWM floats and centers only terminals with that title.
- No Python, PowerShell runtime scripts, `.cmd` helper scripts, or new WGDot calculator frontend are used. Windows Terminal inherits the user's configured theme.

The managed GlazeWM command references the default **64-bit WinGet/MSI installation** path, `%ProgramFiles%\\Qalculate\\qalc.exe`. Qalculate must be installed in that path or the command must be adjusted locally to its actual CLI location. Windows package ID: `Qalculate.Qalculate`.

This replacement does not uninstall a previously installed SpeedCrunch or remove its settings. The retired SpeedCrunch catalog entry is removed from newly managed software selections, not used as an uninstall request.

# Qalc calculator on Windows

Win-Glaze-Dots uses **Qalculate!** (`Qalculate.Qalculate`) as the actual calculation engine. The installed `qalc.exe` CLI does the mathematics; the narrow C# console frontend in WGDot supplies Awtarchy-style layout and keyboard navigation.

- `Alt+Shift+C` or either `Super+Shift+C` opens a **new, independent** Windows Terminal window. `Super+Shift+C` also works in `noalt` mode.
- The dedicated window is titled **Qalc**, sized to 46 columns by 22 rows, and floated/centered by GlazeWM. Terminal DPI and font scaling determine its pixel dimensions.
- Type directly at the bottom. The live result appears above the input after a short debounce, before Enter; committed expression/result pairs stack upward, newest at the bottom. Older complete pairs are clipped above the reserved header.
- Left/Right/Home/End move in the input; Up/Down browse this window's calculations; Enter commits; Backspace/Delete edit; Ctrl+A/E move start/end; Ctrl+U clears input; Ctrl+L clears history; Escape or Ctrl+C/D closes this calculator.
- The active Windows Terminal color/profile settings are inherited; no terminal settings are changed. Each window has its own history and evaluation process.

WGDot finds the Qalc CLI through registered Windows App Paths, PATH, recognized Qalculate install directories and uninstall-registry install locations. It does not assume one fixed Program Files location. If Qalc is absent, choose **Qalculate!** in `wgdot software` or install with `winget install --id Qalculate.Qalculate --exact --source winget`. The supported WinGet manifest is published by Microsoft, and Qalculate's Windows installer includes the CLI.

**Migration:** Removing SpeedCrunch from the WGDot catalog does not uninstall a previously installed copy and does not touch SpeedCrunch application data. Any historical WGDot software selection is preserved/handled by existing manifest reconciliation rather than converted into an uninstall request.

**Testing unreleased changes:** Use `wgdot git-review --branch feat/qalc-bottom-windows --revision <40-character-commit-SHA>` before `git-update`; the latter replaces the managed GlazeWM configuration with backup protection and updates the native runtime for that exact branch revision. The Qalc package must be installed separately if this machine does not already have it. Test both Normal and Work profiles as appropriate.

The `--terse --time 1500 -- <expression>` Qalc CLI contract and the real window behavior must be verified on Windows; source-level tests do not prove installed CLI responsiveness or Windows Terminal/GlazeWM focus under DPI scaling.

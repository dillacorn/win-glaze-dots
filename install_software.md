# Package Management with WinGet

WGDot's interactive software selector is the preferred installation path. Packages are grouped by category instead of shown as one giant list.

Installation setup now treats `Q`/Esc as **back one setup screen**. Repeated back presses cannot silently dump the user out of the installer: backing out past the first setup screen opens an explicit quit confirmation, and only `Y` quits. `N`, Enter, or beginning to navigate with the arrow/page keys keeps the installer open and preserves the in-progress selections.


The default selection is intentionally conservative for public use. Only the WGDot desktop stack, broadly useful defaults, and practical dependencies are enabled by default; personal applications are opt-in.

## privacy.sexy behavior

privacy.sexy remains optional. WGDot installs/updates only from the official upstream release, detects when the installer already started the desktop app so it does not launch a duplicate window, and waits for that app instance to close before continuing. WGDot does not disable antivirus or add antivirus exclusions around privacy.sexy execution. Upstream 0.13.8 does not expose a supported unattended CLI/API for selecting a recommendation level, generating the resulting script, and executing it.

## Automatic time and time zone

WGDot defaults **Sync Windows time + detect time zone automatically** ON. This is an administrator-level Windows setting because automatic time-zone detection is system-wide. WGDot enables the normal Windows Time service path, enables the Auto Time Zone Updater, and enables Windows Location services using Microsoft's documented registry settings. It then starts the built-in services when possible, requests an immediate `w32tm /resync /rediscover`, and reports the current Windows time zone.

No third-party geolocation or IP-location service is used. Windows itself determines the time zone from Location services. A domain/MDM policy, disabled location provider, unavailable network, or VPN/location mismatch can still prevent or delay correct detection. Deselecting the tweak restores the pre-WGDot registry settings; it does not intentionally roll the current clock or selected time zone backward.

## Taskbar Widgets compatibility

WGDot normally hides the Windows 11 Widgets button through the current-user `TaskbarDa` setting. Some Windows builds protect that specific value even when other taskbar values remain writable. If Windows rejects only `TaskbarDa`, WGDot discards the untouched value's rollback snapshot and uses Microsoft's machine-level Widgets policy `SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests=0` inside the existing elevated setup batch. The pre-WGDot policy state is snapshotted for rollback.

## Automated acceptance audit

For broad maintainer testing without filling a VM or repeatedly mutating the live profile, run:

```powershell
wgdot acceptance-audit
```

This command refreshes the WGDot runtime before dispatch, then runs the isolated native mutation/rollback suite under a temporary `WGDOT_TEST_ROOT`, resolves the current managed-config plan without applying it, validates persisted browser option IDs, runs the complete no-install software catalog/source audit, enumerates GPU state read-only, and verifies refresh coverage for normal maintenance commands.

It does **not** install software, change Windows tweaks, apply managed dots, modify browser profiles, or launch DDU. Human acceptance is still required for actual global hotkeys, Firefox/Brave extension approval/consumption, one real managed-dots apply/rollback cycle, and any intentionally tested DDU reboot flow.

## Software catalog audit

The native maintenance menu includes **Audit all software (no install)**. This checks every package in the WGDot manifest, including optional applications, without installing or downloading installer payloads. The audit performs exact-ID WinGet metadata lookups, validates any known post-install action names, and checks declared official GitHub fallback repositories for a matching latest-release asset.

The audit does not request UAC, modify the registry, launch applications, install/upgrade packages, or consume meaningful VM disk space. It is intended for broad catalog validation on a small test VM. Packages with a verified official fallback are counted as alternate-source coverage rather than a failure. RustDesk uses its official GitHub releases directly because its historical WinGet package is not currently available. Raw Accel uses its official release ZIP and MicLockTray uses its official standalone release executable; both remain opt-in. FileZilla is intentionally treated as an official-page package because it is not available from the WinGet community source; WGDot validates its publisher download page without downloading the installer. A passing audit does not prove that a third-party installer itself will execute correctly or that app-specific runtime integration works after installation.

Direct command:

```powershell
wgdot software-audit
```

Direct user-facing WGDot commands perform the same runtime refresh check as plain `wgdot` before dispatch. You do not need to run plain `wgdot` first to refresh before using `wgdot software-audit`.

## Elevation behavior

WGDot keeps the interactive software selector unelevated. After the user reviews and approves the software selection, WGDot preflights the selected WinGet packages, collects any explicitly approved upgrades, and groups missing installs plus administrator-only setup into one internal elevated worker. On a normal unelevated run, this means one UAC approval for the software batch instead of one elevation prompt per installer.

Preflight reads the installed WinGet package state once, then performs exact-ID source validation only for selected packages that are actually missing. Silent WinGet checks run with interactivity disabled and a 30-second timeout; if WinGet itself stops responding, WGDot reports the package/check and stops before launching a partial elevated install batch instead of hanging forever.

Firefox's Windows extension-policy registry mutation and registry-heavy Windows setup tweaks are handled inside the same bounded elevated worker when needed. Raw Accel's upstream kernel-driver installer also runs there after its official release ZIP is safely extracted; WGDot verifies the driver service/file state and leaves the required restart to the user. Betterfox profile changes, Brave/Mullvad browser interaction, Flow Launcher/EarTrumpet application configuration, browser launches, MicLockTray's standalone portable install/launch, and other user-level post-install launches stay in the normal unelevated WGDot process. WGDot does not require Windows sudo and does not disable or weaken UAC.


## Default ON

- **Git** — `Git.Git`
- **Windows Terminal** — `Microsoft.WindowsTerminal`
- **AltSnap** — `AltSnap.AltSnap`
- **Visual C++ Redistributable** — `Microsoft.VCRedist.2015+.x64`
- **YASB** — `AmN.yasb`
- **Flameshot** — `Flameshot.Flameshot`
- **Flow Launcher** — `Flow-Launcher.Flow-Launcher`

  WGDot tries the exact WinGet package first. If that WinGet install stalls for 180 seconds or fails, WGDot terminates the stuck WinGet attempt and may fall back only to the official `Flow-Launcher/Flow.Launcher` latest release asset `Flow-Launcher-Setup.exe`.
- **EarTrumpet** — `File-New-Project.EarTrumpet`
- **Micro** — `zyedidia.micro`
- **Yazi** — `sxyazi.yazi`
- **qimgv** — `easymodo.qimgv`
- **mpv.net** — `mpv.net`
- **Firefox** — `Mozilla.Firefox`
- **7-Zip** — `7zip.7zip`
- **FFmpeg** — `Gyan.FFmpeg`
- **jq** — `jqlang.jq`
- **Poppler** — `oschwartz10612.Poppler`
- **fd** — `sharkdp.fd`
- **ripgrep** — `BurntSushi.ripgrep.MSVC`
- **fzf** — `junegunn.fzf`
- **zoxide** — `ajeetdsouza.zoxide`
- **ImageMagick** — `ImageMagick.ImageMagick`
- **GlazeWM** — `glzr-io.glazewm`
- **JetBrains Mono Nerd Font** — `DEVCOM.JetBrainsMonoNerdFont`
- **Open-Shell** — `Open-Shell.Open-Shell-Menu`

## Optional packages by category

### CLI / Yazi helpers

- **Fastfetch** — `Fastfetch-cli.Fastfetch`
- **Cava** — `karlstav.cava`
- **btop4win** — `aristocratos.btop4win`

### Browsers

- **Brave** — `Brave.Brave`
- **Mullvad Browser** — `MullvadVPN.MullvadBrowser`

When the **Browsers** category is open, highlight Firefox, Brave, or Mullvad Browser and press **E** to review that browser's extensions/options. Browser-option choices are remembered separately from the package checkboxes.

Firefox is the managed path. Fresh WGDot selections default to Betterfox plus CanvasBlocker, ClearURLs, Ctrl+Number to switch tabs, LocalCDN, Return YouTube Dislike, SponsorBlock, and full uBlock Origin. Dark Reader and ScrollAnywhere are optional and default OFF. Signed Firefox add-ons are requested through Mozilla's supported Windows policy mechanism.

Betterfox is installed only into a dedicated `Profiles/wgdot.betterfox` Firefox profile. Existing profiles are preserved and relevant Firefox metadata is backed up. WGDot asks before changing the Firefox default profile.

Brave uses its built-in Shields privacy/blocking features, so WGDot does not stack extra privacy blockers by default. Return YouTube Dislike and SponsorBlock default ON; Dark Reader and ScrollAnywhere default OFF and use their official Chrome Web Store pages with normal **Add to Brave** approval. Full uBlock Origin is still supported by Brave through `brave://settings/extensions/v2`; WGDot exposes that as an optional default-OFF Brave setting because Shields already covers the normal blocking role. ClearURLs is omitted because Brave disables the current Manifest V2 build, CanvasBlocker has no official Chromium build, LocalCDN's Chromium store publication is not the upstream-supported path, and Ctrl+1..9 tab switching is already native.

Mullvad Browser is intentionally left untouched. WGDot does not install extensions, Betterfox, `user.js`, or preference tweaks into it. Use it as shipped to preserve its anti-fingerprinting profile, preferably with a VPN.

### Editors

- **Notepad++** — `Notepad++.Notepad++`

### General utilities

- **SpeedCrunch** — `SpeedCrunch.SpeedCrunch`
- **Everything** — `voidtools.Everything`
- **MicLockTray** — `dillacorn.MicLockTray` — official standalone GitHub release, optional and default OFF

### System / diagnostics

- **Display Driver Uninstaller** — `Wagnardsoft.DisplayDriverUninstaller`
- **PowerToys** — `Microsoft.PowerToys`
- **System Informer** — `WinsiderSS.SystemInformer`
- **HWMonitor** — `CPUID.HWMonitor`
- **Ventoy** — `Ventoy.Ventoy`
- **CCleaner** — `Piriform.CCleaner`
- **WizTree** — `AntibodySoftware.WizTree`
- **CPU-Z** — `CPUID.CPU-Z`
- **GPU-Z** — `TechPowerUp.GPU-Z`
- **Windhawk** — `RamenSoftware.Windhawk`

### Networking / remote

- **LocalSend** — `LocalSend.LocalSend`
- **RustDesk** — `RustDesk.RustDesk`
- **qBittorrent** — `qBittorrent.qBittorrent`
- **WinSCP** — `WinSCP.WinSCP`
- **FileZilla** — `TimKosse.FileZilla.Client`
- **WireGuard** — `WireGuard.WireGuard`
- **Tailscale** — `Tailscale.Tailscale`

### Communication

- **Vesktop (Vencord)** — `Vencord.Vesktop`

### Media

- **FLAC** — `Xiph.FLAC`
- **Feishin** — `jeffvli.Feishin`
- **OBS Studio** — `OBSProject.OBSStudio`
- **Okular** — `KDE.Okular`
- **yt-dlp** — `yt-dlp.yt-dlp`
- **DistroAV** — `DistroAV.DistroAV`

### Creative

- **Krita** — `KDE.Krita`
- **Shotcut** — `Meltytech.Shotcut`
- **GIMP** — `GIMP.GIMP`
- **ScreenToGif** — `NickeManarin.ScreenToGif`

### 3D printing

- **OrcaSlicer** — `SoftFever.OrcaSlicer`
- **PrusaSlicer** — `Prusa3D.PrusaSlicer`
- **Cura** — `Ultimaker.Cura`

### Gaming

- **Steam** — `Valve.Steam`
- **itch.io** — `ItchIo.Itch`
- **GOG Galaxy** — `GOG.Galaxy`
- **Prism Launcher** — `PrismLauncher.PrismLauncher`
- **r2modman** — `ebkr.r2modman`
- **Epic Games Launcher** — `EpicGames.EpicGamesLauncher`
- **Raw Accel** — `RawAccelOfficial.RawAccel` — official release ZIP/driver installer, optional and default OFF; restart Windows after installation
- **Moonlight** — `MoonlightGameStreamingProject.Moonlight`
- **Sunshine** — `LizardByte.Sunshine`

### Security

- **KeePassXC** — `KeePassXCTeam.KeePassXC`

### Development

- **Make** — `GnuWin32.Make`
- **MSYS2** — `MSYS2.MSYS2`
- **cURL** — `cURL.cURL`

### Virtualization

- **QEMU** — `SoftwareFreedomConservancy.QEMU`
- **QEMU Guest Agent** — `SoftwareFreedomConservancy.QEMUGuestAgent`

### Work

- **Microsoft Teams** — `Microsoft.Teams`

## Notes

- Open-Shell is enabled by default and WGDot starts it after a successful first install.
- Micro is the preferred text editor. Notepad++ remains available only as an opt-in editor.
- qimgv and mpv.net are default media applications.
- Vesktop (`Vencord.Vesktop`) is the offered Discord-family client; Discord itself is not cataloged.
- OrcaSlicer, PrusaSlicer, and Cura are all optional and default OFF.
- WireGuard is available under Networking / remote and defaults OFF.
- Steam, itch.io, GOG Galaxy, Prism Launcher, r2modman, and Epic Games Launcher are all optional and default OFF.
- Signal, Bitwarden, Betaflight Configurator, PDF-XChange Editor, Spotify, Process Explorer, and Double Commander are intentionally not offered.
- Deselecting an installed package does not uninstall it.
- WGDot never runs `winget upgrade --all`; upgrade checks are opt-in and each selected package requires approval.


## GPU drivers

WGDot has a separate GPU driver maintenance workflow in the main menu.

- Detects present AMD, NVIDIA, and Intel display adapters from PCI hardware IDs.
- Reports the active display-driver provider/version and recommends the matching vendor tooling when a vendor driver is missing.
- Supports AMD Auto-Detect, NVIDIA App, and Intel Driver & Support Assistant from vendor-owned download endpoints. AMD downloads include AMD.com's required support-page referrer, and downloaded executables are checked before launch so an HTML error page is never executed as an installer.
- Detects possible stale/mismatched display-driver vendors without treating legitimate hybrid Intel+NVIDIA / Intel+AMD systems as errors.
- Offers a guarded DDU clean reinstall/refresh path that stages Safe Mode only after explicit confirmation.
- DDU cleanup state survives the reboot. WGDot removes forced Safe Mode before DDU launches and remembers which vendor driver must be reinstalled afterward.
- DDU remains available as `Wagnardsoft.DisplayDriverUninstaller`, but WGDot does not run it automatically.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$runtimePath = Join-Path $repoRoot "wgdot\wgdot.ps1"
$manifestPath = Join-Path $repoRoot "wgdot\manifest.json"
$launcherPath = Join-Path $repoRoot "wgdot\wgdot.cmd"
$manualPath = Join-Path $repoRoot "MANUAL_POWERSHELL.md"
$nativeBootstrapPath = Join-Path $repoRoot "wgdot\\bootstrap.cmd"
$nativeSourcePath = Join-Path $repoRoot "wgdot\\wgdot-native.cs"

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -ne $Actual) { throw "ASSERTION FAILED: $Message. Expected '$Expected', got '$Actual'." }
}

Assert-True (Test-Path -LiteralPath $runtimePath -PathType Leaf) "runtime exists"
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) "manifest exists"
Assert-True (Test-Path -LiteralPath $launcherPath -PathType Leaf) "launcher exists"
Assert-True (Test-Path -LiteralPath $nativeBootstrapPath -PathType Leaf) "native bootstrap exists"
$nativeBootstrapText = Get-Content -LiteralPath $nativeBootstrapPath -Raw
Assert-True ($nativeBootstrapText -match 'System\.Windows\.Forms\.dll') "native bootstrap references WinForms for the WGDot power overlay"
Assert-True ($nativeBootstrapText -match 'System\.Drawing\.dll') "native bootstrap references System.Drawing for the WGDot power overlay"
Assert-True (Test-Path -LiteralPath $nativeSourcePath -PathType Leaf) "native bootstrap source exists"

$env:WGDOT_TEST_MODE = "1"
. $runtimePath

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-Equal 1 ([int]$manifest.schemaVersion) "manifest schema"
Assert-Equal "dillacorn/win-glaze-dots" ([string]$manifest.runtime.repository) "repository identity"

$componentIds = @($manifest.components | ForEach-Object { [string]$_.id })
Assert-True ($componentIds -contains "glazewm") "GlazeWM component exists"
Assert-True ($componentIds -contains "yasb") "YASB component exists"
Assert-True ($componentIds -contains "cursor") "cursor component exists"
Assert-True ($componentIds -contains "yazi") "Yazi component exists"

$yasb = $manifest.components | Where-Object { $_.id -eq "yasb" } | Select-Object -First 1
Assert-True (@($yasb.postActions | Where-Object { $_.type -eq "ensure-yasb-theme" }).Count -eq 1) "YASB component has exactly one theme-generation post-action"
$cursorComponent = $manifest.components | Where-Object { $_.id -eq "cursor" } | Select-Object -First 1
Assert-True (@($cursorComponent.postActions | Where-Object { $_.type -eq "ensure-cursor-theme" }).Count -eq 1) "cursor component has exactly one cursor post-action"

$glaze = $manifest.components | Where-Object { $_.id -eq "glazewm" } | Select-Object -First 1
Assert-True (@($glaze.postActions | Where-Object { $_.type -eq "ensure-desktop-worker" }).Count -eq 1) "GlazeWM apply starts the WGDot desktop worker immediately"
Assert-Equal "UserProfile/.glzr/glazewm/config.yaml" ([string]$glaze.files[0].sourceByGlazeProfile.normal) "normal GlazeWM source"
Assert-Equal "UserProfile/.glzr/glazewm/custom_work_config.yaml" ([string]$glaze.files[0].sourceByGlazeProfile.work) "work GlazeWM source"
Assert-Equal "%USERPROFILE%\.glzr\glazewm\config.yaml" ([string]$glaze.files[0].destination) "GlazeWM variants share destination"

$seenFiles = @{}
foreach ($component in $manifest.components) {
    foreach ($file in $component.files) {
        Assert-True (-not $seenFiles.ContainsKey([string]$file.id)) "managed file IDs are unique: $($file.id)"
        $seenFiles[[string]$file.id] = $true
        $dest = [string]$file.destination
        Assert-True (($dest -like '%USERPROFILE%\*') -or ($dest -like '%APPDATA%\*') -or ($dest -like '%LOCALAPPDATA%\*')) "destination stays in approved user-local roots: $dest"

        if ($file.PSObject.Properties.Name -contains "source") {
            $source = Join-Path $repoRoot (([string]$file.source) -replace '/', '\')
            Assert-True (Test-Path -LiteralPath $source -PathType Leaf) "source exists: $($file.source)"
        }
        if ($file.PSObject.Properties.Name -contains "sourceByGlazeProfile") {
            foreach ($name in @("normal", "work")) {
                $rel = [string]$file.sourceByGlazeProfile.$name
                $source = Join-Path $repoRoot ($rel -replace '/', '\')
                Assert-True (Test-Path -LiteralPath $source -PathType Leaf) "profile source exists: $rel"
            }
        }
    }
}

$packageIds = @{}
foreach ($package in $manifest.packages) {
    $id = [string]$package.id
    Assert-True ($id -match '^[A-Za-z0-9][A-Za-z0-9+._-]*(\.[A-Za-z0-9+._-]+)+$') "package ID shape: $id"
    Assert-True (-not $packageIds.ContainsKey($id.ToLowerInvariant())) "package IDs are unique: $id"
    $packageIds[$id.ToLowerInvariant()] = $true
}
Assert-True ($packageIds.ContainsKey("easymodo.qimgv")) "correct qimgv ID is cataloged"
Assert-True ($packageIds.ContainsKey("wagnardsoft.displaydriveruninstaller")) "correct DDU ID is cataloged"
Assert-True ($packageIds.ContainsKey("xiph.flac")) "correct FLAC ID is cataloged"
Assert-True ($packageIds.ContainsKey("itchio.itch")) "correct itch ID is cataloged"
Assert-True (-not $packageIds.ContainsKey("microsoft.sysinternals.processexplorer")) "Process Explorer is not offered; System Informer is the preferred process manager"
Assert-True (-not $packageIds.ContainsKey("alexx2000.doublecommander")) "Double Commander is not offered by WGDot"
Assert-True ($packageIds.ContainsKey("mozilla.firefox")) "Firefox is cataloged"
Assert-True ($packageIds.ContainsKey("vencord.vesktop")) "Vesktop is cataloged"
Assert-True ($packageIds.ContainsKey("softfever.orcaslicer")) "OrcaSlicer is cataloged"
Assert-True ($packageIds.ContainsKey("prusa3d.prusaslicer")) "PrusaSlicer is cataloged"
Assert-True ($packageIds.ContainsKey("wireguard.wireguard")) "WireGuard is cataloged"
Assert-True ($packageIds.ContainsKey("wagnardsoft.displaydriveruninstaller")) "DDU is cataloged for GPU maintenance"
Assert-True (-not $packageIds.ContainsKey("spotify.spotify")) "Spotify is not offered by WGDot"
Assert-True ($packageIds.ContainsKey("rustdesk.rustdesk")) "RustDesk is cataloged"
Assert-True ($packageIds.ContainsKey("rawaccelofficial.rawaccel")) "Raw Accel is cataloged"
Assert-True ($packageIds.ContainsKey("dillacorn.miclocktray")) "MicLockTray is cataloged"
Assert-True (-not $packageIds.ContainsKey("discord.discord")) "Discord is not offered; Vesktop is the Discord-family option"
Assert-True (-not $packageIds.ContainsKey("openwhispersystems.signal")) "Signal is not offered by WGDot"
Assert-True (-not $packageIds.ContainsKey("bitwarden.bitwarden")) "Bitwarden is not offered by WGDot"
Assert-True (-not $packageIds.ContainsKey("betaflight.betaflight-configurator")) "Betaflight Configurator is not offered by WGDot"
Assert-True (-not $packageIds.ContainsKey("trackersoftware.pdf-xchangeeditor")) "PDF-XChange Editor is not offered by WGDot"

function Get-ManifestPackage {
    param([string]$Id)
    return $manifest.packages | Where-Object { [string]$_.id -eq $Id } | Select-Object -First 1
}

$rawAccelPackage = Get-ManifestPackage -Id "RawAccelOfficial.RawAccel"
Assert-True ($null -ne $rawAccelPackage) "Raw Accel package exists"
Assert-Equal "official-github-archive-driver" ([string]$rawAccelPackage.installMode) "Raw Accel uses the official GitHub archive-driver path"
Assert-Equal "RawAccelOfficial/rawaccel" ([string]$rawAccelPackage.fallbackGitHubRepo) "Raw Accel source is the official upstream repository"
Assert-Equal "installer.exe" ([string]$rawAccelPackage.archiveInstaller) "Raw Accel uses the upstream driver installer"
Assert-Equal "rawaccel" ([string]$rawAccelPackage.installedService) "Raw Accel installation verifies the kernel-driver service"
Assert-Equal "rawaccel.sys" ([string]$rawAccelPackage.driverFileName) "Raw Accel installation verifies the installed driver file"

$micLockTrayPackage = Get-ManifestPackage -Id "dillacorn.MicLockTray"
Assert-True ($null -ne $micLockTrayPackage) "MicLockTray package exists"
Assert-Equal "official-github-portable" ([string]$micLockTrayPackage.installMode) "MicLockTray uses the unelevated official GitHub portable path"
Assert-Equal "dillacorn/MicLockTray" ([string]$micLockTrayPackage.fallbackGitHubRepo) "MicLockTray source is the official repository"
Assert-Equal "MicLockTray.exe" ([string]$micLockTrayPackage.installedFile) "MicLockTray installs the published standalone executable"
Assert-Equal $true ([bool]$micLockTrayPackage.launchAfterInstall) "MicLockTray launches after its user-level portable install"

$startupExpectations = @{
    "glzr-io.glazewm" = "glazewm"
    "AltSnap.AltSnap" = "altsnap"
    "File-New-Project.EarTrumpet" = "eartrumpet"
    "dillacorn.MicLockTray" = "miclocktray"
}
foreach ($entry in $startupExpectations.GetEnumerator()) {
    $package = Get-ManifestPackage -Id $entry.Key
    Assert-True ($null -ne $package) "startup package exists: $($entry.Key)"
    Assert-Equal $entry.Value ([string]$package.startupHandler) "$($entry.Key) has the expected WGDot startup handler"
    Assert-Equal $true ([bool]$package.startupDefault) "$($entry.Key) defaults to startup when selected"
}

$expectedDefaultOnPackages = @(
    "Git.Git",
    "Microsoft.WindowsTerminal",
    "AltSnap.AltSnap",
    "Microsoft.VCRedist.2015+.x64",
    "AmN.yasb",
    "Flameshot.Flameshot",
    "File-New-Project.EarTrumpet",
    "zyedidia.micro",
    "sxyazi.yazi",
    "easymodo.qimgv",
    "mpv.net",
    "Mozilla.Firefox",
    "7zip.7zip",
    "Gyan.FFmpeg",
    "jqlang.jq",
    "oschwartz10612.Poppler",
    "sharkdp.fd",
    "BurntSushi.ripgrep.MSVC",
    "junegunn.fzf",
    "ajeetdsouza.zoxide",
    "ImageMagick.ImageMagick",
    "glzr-io.glazewm",
    "DEVCOM.JetBrainsMonoNerdFont",
    "Open-Shell.Open-Shell-Menu"
)

foreach ($package in $manifest.packages) {
    $id = [string]$package.id
    $shouldDefaultOn = $expectedDefaultOnPackages -contains $id
    Assert-Equal $shouldDefaultOn ([bool]$package.defaultNormal) "$id Normal default follows conservative public baseline"
    Assert-Equal $shouldDefaultOn ([bool]$package.defaultWork) "$id Work default follows conservative public baseline"
}

function Get-BrowserDefinition {
    param([string]$PackageId)
    return $manifest.browserOptions |
        Where-Object { [string]$_.packageId -eq $PackageId } |
        Select-Object -First 1
}

Assert-Equal 3 @($manifest.browserOptions).Count "exactly the supported WGDot browsers have browser-specific definitions"

$firefoxBrowser = Get-BrowserDefinition -PackageId "Mozilla.Firefox"
Assert-True ($null -ne $firefoxBrowser) "Firefox browser options exist"
Assert-Equal "firefox-managed" ([string]$firefoxBrowser.mode) "Firefox uses managed signed-addon setup"
$firefoxOptionIds = @($firefoxBrowser.options | ForEach-Object { [string]$_.id })
$firefoxDefaultOn = @(
    "betterfox",
    "duckduckgo-no-ai",
    "canvasblocker",
    "clearurls",
    "ctrl-number",
    "localcdn",
    "return-youtube-dislike",
    "sponsorblock",
    "ublock-origin"
)
$firefoxDefaultOff = @("dark-reader", "scroll-anywhere")
foreach ($id in $firefoxDefaultOn) {
    Assert-True ($firefoxOptionIds -contains $id) "Firefox option exists: $id"
    $option = $firefoxBrowser.options | Where-Object { [string]$_.id -eq $id } | Select-Object -First 1
    Assert-True ([bool]$option.defaultNormal) "Firefox $id defaults on for Normal"
    Assert-True ([bool]$option.defaultWork) "Firefox $id defaults on for Work"
}
foreach ($id in $firefoxDefaultOff) {
    Assert-True ($firefoxOptionIds -contains $id) "Firefox option exists: $id"
    $option = $firefoxBrowser.options | Where-Object { [string]$_.id -eq $id } | Select-Object -First 1
    Assert-True (-not [bool]$option.defaultNormal) "Firefox $id defaults off for Normal"
    Assert-True (-not [bool]$option.defaultWork) "Firefox $id defaults off for Work"
}
Assert-Equal 11 $firefoxOptionIds.Count "Firefox exposes only the researched WGDot option set"
$betterfox = $firefoxBrowser.options | Where-Object { [string]$_.id -eq "betterfox" } | Select-Object -First 1
Assert-Equal "https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js" ([string]$betterfox.sourceUrl) "Betterfox uses official upstream user.js"
$duckDuckGoNoAi = $firefoxBrowser.options | Where-Object { [string]$_.id -eq "duckduckgo-no-ai" } | Select-Object -First 1
Assert-Equal "https://addons.mozilla.org/firefox/downloads/latest/duckduckgo-no-ai-search/latest.xpi" ([string]$duckDuckGoNoAi.installUrl) "Firefox DuckDuckGo No-AI uses DuckDuckGo's signed AMO extension"
foreach ($option in @($firefoxBrowser.options | Where-Object { [string]$_.kind -eq "firefox-extension" })) {
    Assert-True (([string]$option.installUrl) -match '^https://addons\.mozilla\.org/firefox/downloads/latest/.+/latest\.xpi$') "Firefox extension uses signed AMO latest XPI: $($option.id)"
}

$braveBrowser = Get-BrowserDefinition -PackageId "Brave.Brave"
Assert-True ($null -ne $braveBrowser) "Brave browser options exist"
Assert-Equal "guided-chrome-web-store" ([string]$braveBrowser.mode) "Brave uses browser-approved Chrome Web Store setup"
$braveOptionIds = @($braveBrowser.options | ForEach-Object { [string]$_.id })
Assert-Equal 5 $braveOptionIds.Count "Brave exposes only researched supported add-ons/features"
foreach ($id in @("return-youtube-dislike", "sponsorblock")) {
    $option = $braveBrowser.options | Where-Object { [string]$_.id -eq $id } | Select-Object -First 1
    Assert-True ([bool]$option.defaultNormal) "Brave $id defaults on"
    Assert-True ([bool]$option.defaultWork) "Brave $id defaults on for Work"
}
foreach ($id in @("dark-reader", "scroll-anywhere")) {
    $option = $braveBrowser.options | Where-Object { [string]$_.id -eq $id } | Select-Object -First 1
    Assert-True (-not [bool]$option.defaultNormal) "Brave $id defaults off"
    Assert-True (-not [bool]$option.defaultWork) "Brave $id defaults off for Work"
}
$braveUbo = $braveBrowser.options | Where-Object { [string]$_.id -eq "ublock-origin" } | Select-Object -First 1
Assert-True ($null -ne $braveUbo) "Brave exposes its supported full uBlock Origin path"
Assert-Equal "brave-mv2-settings" ([string]$braveUbo.kind) "Brave uBlock Origin uses Brave-hosted Manifest V2 settings"
Assert-Equal "brave://settings/extensions/v2" ([string]$braveUbo.settingsUrl) "Brave uBlock Origin points to Brave's supported Manifest V2 page"
Assert-True (-not [bool]$braveUbo.defaultNormal) "Brave full uBlock Origin defaults off to avoid stacking with Shields"
Assert-True (-not [bool]$braveUbo.defaultWork) "Brave full uBlock Origin defaults off for Work"
foreach ($id in @("clearurls", "canvasblocker", "localcdn", "ctrl-number")) {
    Assert-True (-not ($braveOptionIds -contains $id)) "Brave omits redundant/unsupported option: $id"
}
foreach ($option in @($braveBrowser.options | Where-Object { [string]$_.kind -eq "chrome-web-store" })) {
    Assert-True (([string]$option.storeUrl) -match '^https://chromewebstore\.google\.com/detail/') "Brave option uses official Chrome Web Store: $($option.id)"
}

$mullvadBrowser = Get-BrowserDefinition -PackageId "MullvadVPN.MullvadBrowser"
Assert-True ($null -ne $mullvadBrowser) "Mullvad Browser definition exists"
Assert-Equal "preserve-upstream" ([string]$mullvadBrowser.mode) "Mullvad Browser is preserve-upstream only"
Assert-Equal 0 @($mullvadBrowser.options).Count "Mullvad Browser cannot receive WGDot extensions or custom settings"
Assert-True (([string]$mullvadBrowser.notice) -match 'exactly as shipped') "Mullvad Browser UI recommends upstream configuration"
Assert-True (([string]$mullvadBrowser.notice) -match 'VPN') "Mullvad Browser UI recommends VPN use"

$openShell = Get-ManifestPackage -Id "Open-Shell.Open-Shell-Menu"
Assert-Equal "launch-open-shell" ([string]$openShell.postInstallAction) "Open-Shell launches after first install"

$rustDesk = Get-ManifestPackage -Id "RustDesk.RustDesk"
Assert-Equal "rustdesk/rustdesk" ([string]$rustDesk.fallbackGitHubRepo) "RustDesk approved fallback repository"

$tweakIds = @($manifest.tweaks | ForEach-Object { [string]$_.id })
foreach ($id in @(
    "micro-text-defaults",
    "flow-launcher-alt-p",
    "eartrumpet-mixer-alt-v",
    "disable-windows-shell-hotkeys",
    "clean-taskbar-items",
    "disable-printscreen-snipping",
    "disable-enhanced-pointer-precision",
    "communications-do-nothing",
    "disable-snap-assist",
    "automatic-time-and-timezone",
    "disable-remote-assistance",
    "enable-windows-sudo",
    "reduce-visual-effects",
    "classic-context-menu",
    "oops-all-links-cursor",
    "privacy-sexy"
)) {
    Assert-True ($tweakIds -contains $id) "Windows tweak exists: $id"
}

foreach ($id in @(
    "classic-context-menu",
    "oops-all-links-cursor",
    "privacy-sexy",
    "disable-remote-assistance",
    "enable-windows-sudo",
    "reduce-visual-effects",
    "disable-windows-shell-hotkeys",
    "flow-launcher-alt-p"
)) {
    $t = $manifest.tweaks | Where-Object { $_.id -eq $id } | Select-Object -First 1
    Assert-True (-not [bool]$t.defaultNormal) "$id defaults off"
}


foreach ($id in @("eartrumpet-mixer-alt-v", "automatic-time-and-timezone")) {
    $tweak = $manifest.tweaks | Where-Object { $_.id -eq $id } | Select-Object -First 1
    Assert-True ([bool]$tweak.defaultNormal) "$id defaults on for Normal"
    Assert-True ([bool]$tweak.defaultWork) "$id defaults on for Work"
}

$runtimeText = Get-Content -LiteralPath $runtimePath -Raw
$launcherText = Get-Content -LiteralPath $launcherPath -Raw
$manualText = Get-Content -LiteralPath $manualPath -Raw
$nativeBootstrapText = Get-Content -LiteralPath $nativeBootstrapPath -Raw
$nativeSourceText = Get-Content -LiteralPath $nativeSourcePath -Raw
Assert-True ($runtimeText -notmatch '(?i)-ExecutionPolicy\s+Bypass') "runtime does not bypass execution policy"
Assert-True ($runtimeText -match 'browserOptions = \[pscustomobject\]\$browserOptions') "PowerShell fallback persists browser option state on fresh/reconfigure selection"
Assert-True ($runtimeText -match 'New-WgdotInstallationSelection -Manifest \$manifest -Existing \$existingInstallation') "PowerShell reset path preserves existing browser option selections"
Assert-True ($launcherText -notmatch '(?i)-ExecutionPolicy\s+(Bypass|Unrestricted)') "launcher does not override execution policy"
Assert-True ($launcherText -notmatch '(?i)Set-ExecutionPolicy') "launcher does not change execution policy"
Assert-True ($launcherText -match 'Get-ExecutionPolicy') "launcher checks effective execution policy"
Assert-True ($launcherText -match '(?i)Restricted') "launcher handles Restricted policy"
Assert-True ($launcherText -match '(?i)AllSigned') "launcher handles AllSigned policy"
Assert-True ($manualText -notmatch '(?i)-ExecutionPolicy\s+Bypass') "manual path does not bypass execution policy"
Assert-True ($manualText -match 'theme\.css') "paste-only manual workflow generates YASB theme.css"
Assert-True ($manualText -match 'theme\.json') "paste-only manual workflow preserves YASB theme state"
Assert-True ($manualText -match 'Microsoft\.WindowsTerminal_8wekyb3d8bbwe') "paste-only manual workflow synchronizes Windows Terminal"
Assert-True ($manualText -match 'terminalSynced') "paste-only manual workflow records Terminal theme synchronization state"
Assert-True ($manualText -match 'appearance\.css') "paste-only manual workflow generates YASB appearance.css"
Assert-True ($manualText -match 'yasb-appearance\.json') "paste-only manual workflow preserves YASB appearance state"
Assert-True ($manualText -match 'Microsoft\.WinGet\.Client') "paste-only manual workflow can bootstrap missing WinGet from Microsoft's module"
Assert-True ($manualText -match 'Repair-WinGetPackageManager -Force -Latest') "paste-only manual workflow uses Microsoft's current WinGet repair command"
Assert-True ($manualText -match 'WGDot\.\*') "paste-only manual workflow documents disabling WGDot-owned startup values"
foreach ($themeId in @("carbon-night", "catppuccin-frappe", "crimson-red", "electric-blue", "gruvbox", "iron-forge", "obsidian-night", "pink", "pipboy")) {
    Assert-True ($manualText.Contains($themeId)) "paste-only manual workflow includes YASB theme palette: $themeId"
}

$manualManagedBlock = [regex]::Match(
    $manualText,
    '(?s)## Apply managed files from the latest stable WGDot release.*?```powershell\r?\n(.*?)\r?\n```'
)
Assert-True $manualManagedBlock.Success "paste-only managed-files PowerShell block can be extracted"
[scriptblock]::Create($manualManagedBlock.Groups[1].Value) | Out-Null
Assert-True ($nativeBootstrapText -notmatch '(?i)Set-ExecutionPolicy|-ExecutionPolicy\s+(Bypass|Unrestricted)') "native bootstrap does not change or bypass execution policy"
Assert-True ($nativeSourceText -notmatch '(?i)Set-ExecutionPolicy|-ExecutionPolicy\s+(Bypass|Unrestricted)') "native bootstrap source does not change or bypass execution policy"
Assert-True ($nativeSourceText -match 'WmSettingChange') "native installer broadcasts environment changes"
Assert-True ($nativeSourceText -match '"git-review"') "native runtime exposes Git review command"
Assert-True ($nativeSourceText -match '"git-update"') "native runtime exposes explicit Git update command"
Assert-True ($nativeSourceText -match '"git-reset"') "native runtime exposes explicit Git reset command"
Assert-True ($nativeSourceText -match 'GitManagedFromArgs\("update"') "Git update uses the shared exact-revision Git-testing path"
Assert-True ($nativeSourceText -match 'GitManagedFromArgs\("reset"') "Git reset uses the shared exact-revision Git-testing path"
Assert-True ($nativeSourceText -match 'Select remote branch') "native Git UI exposes selectable remote branches"
Assert-True ($nativeSourceText -match 'Use selected branch head') "native Git UI defaults to branch head without commit typing"
Assert-True ($nativeSourceText -match 'ReadMultiChoice') "native runtime contains keyboard multi-select UI"
Assert-True ($nativeSourceText -match 'SoftwareReconcile') "native runtime includes software reconciliation"
Assert-True ($nativeSourceText -match 'SoftwareManager') "native runtime exposes a software/startup management surface"
Assert-True ($nativeSourceText -match 'StartupManager') "native runtime exposes individual startup management"
Assert-True ($nativeSourceText -match '(?s)SpecialFolder\.ApplicationData.*?AltSnap.*?AltSnap\.exe') "AltSnap startup resolver covers its normal per-user AppData install path"
Assert-True ($nativeSourceText -match 'GlazeWM \+ YASB') "startup manager presents the GlazeWM/YASB session as one login unit"
Assert-True ($nativeSourceText -notmatch 'startupHandler.*yasb') "YASB is not registered as a duplicate Windows startup application"
Assert-True ($nativeSourceText -match 'SoftwareUninstallManager') "native runtime exposes explicit individual uninstall management"
foreach ($command in @("software-reconcile", "software-uninstall", "startup", "startup-disable-all")) {
    Assert-True ($nativeSourceText -match ('String\.Equals\(command, "' + [regex]::Escape($command) + '"')) "direct $command command participates in runtime auto-refresh"
}
Assert-True ($nativeSourceText -match 'Disable all WGDot-managed startup') "software manager exposes a non-uninstall startup back-out path"
Assert-True ($nativeSourceText -match 'Software\\Microsoft\\Windows\\CurrentVersion\\Run') "startup manager uses per-user Windows startup registration"
Assert-True ($nativeSourceText -match '"WGDot\." \+ handler') "startup entries are namespaced to WGDot ownership"
Assert-True ($nativeSourceText -match 'ApplyStartupDefaultsForSelection') "software reconciliation applies remembered/default WGDot startup policy"
Assert-True ($nativeSourceText -match 'uninstall --id ') "standard catalog applications use exact WinGet uninstall"
Assert-True ($nativeSourceText -match 'Uninstall exactly these applications\?') "software removal requires a dedicated confirmation"
Assert-True ($nativeSourceText -match 'selection\.Packages\.RemoveAll') "successfully uninstalled software is removed from WGDot desired state"
Assert-True ($nativeSourceText -match 'Install/reconcile this software selection\? \[y/N\]') "software mutation requires confirmation"
Assert-True ($nativeSourceText -match 'if \(command == "software-elevated"\) return SoftwareElevatedFromArgs') "native runtime exposes the internal elevated software worker command"
Assert-True ($nativeSourceText -match 'RunElevatedSelfWithExitCode\("software-elevated --plan "') "software reconciliation elevates one WGDot worker rather than each package"
Assert-True ([regex]::Matches($nativeSourceText, 'RunElevatedSelfWithExitCode\("software-elevated --plan "').Count -eq 1) "software reconciliation contains one batch elevation handoff"
Assert-True ($nativeSourceText -match 'WGDot will request administrator approval once for this software batch') "software UI explains the single elevation request"
Assert-True ($nativeSourceText -match 'Elevated software plans must stay inside the WGDot state directory') "elevated software plan path is constrained to WGDot state"
Assert-True ($nativeSourceText -match 'sourceRevision') "elevated software worker checks the selected source revision"
Assert-True ($nativeSourceText -match 'TweakNeedsAdministrator') "software batching separates administrator-only tweaks from normal user-level tweaks"
Assert-True ($nativeSourceText -match 'WingetPreflightTimeoutMs = 30000') "WinGet preflight has a finite timeout"
Assert-True ($nativeSourceText -match 'EnsureWingetAvailable') "native runtime can bootstrap required WinGet automatically"
Assert-True ($nativeSourceText -match 'Microsoft\.WinGet\.Client') "WinGet bootstrap uses Microsoft's supported PowerShell module"
Assert-True ($nativeSourceText -match 'Repair-WinGetPackageManager -Force -Latest') "WinGet bootstrap uses Microsoft's current repair/bootstrap command"
Assert-True ($nativeSourceText -match 'Add-AppxPackage -RegisterByFamilyName') "WinGet bootstrap requests current-user App Installer registration"
Assert-True ($nativeBootstrapText -match '"%OUT%" ensure-winget') "native bootstrap enforces WinGet as a WGDot prerequisite"
Assert-True ($nativeSourceText -match 'Reading installed WinGet package state') "software reconciliation snapshots installed packages once before per-package network validation"
Assert-True ($nativeSourceText -match 'RunWithTimeout') "native process runner supports bounded preflight calls"
Assert-True ($nativeSourceText -match 'BeginOutputReadLine') "captured stdout is drained asynchronously"
Assert-True ($nativeSourceText -match 'BeginErrorReadLine') "captured stderr is drained asynchronously"
Assert-True ($nativeSourceText -match 'Process timeout self-test failed') "native self-test exercises timeout handling"
Assert-True ($nativeSourceText -match '--disable-interactivity') "WinGet reconciliation suppresses WinGet CLI prompts"
Assert-True ($nativeSourceText -match 'RunInteractiveWithTimeout') "actual WinGet install phase is bounded"
Assert-True ($nativeSourceText -match 'taskkill\.exe') "timed-out WinGet install attempts terminate the stuck process tree"
Assert-True ($nativeSourceText -match 'trying the approved official GitHub fallback') "WinGet install timeout/failure can fall back to an approved official GitHub release"
Assert-True ($nativeSourceText -match 'GetWingetInstallTimeoutMs') "package-specific WinGet install timeout is manifest-driven"
$flowPackage = @($manifest.packages | Where-Object { $_.id -eq 'Flow-Launcher.Flow-Launcher' })[0]
Assert-True ($null -ne $flowPackage) "Flow Launcher package exists"
Assert-Equal ([string]$flowPackage.fallbackGitHubRepo) 'Flow-Launcher/Flow.Launcher' "Flow Launcher fallback is restricted to the official upstream repository"
Assert-Equal ([string]$flowPackage.fallbackAssetRegex) '^Flow-Launcher-Setup\.exe$' "Flow Launcher fallback accepts only the official setup asset"
Assert-Equal ([int]$flowPackage.wingetInstallTimeoutSeconds) 180 "Flow Launcher WinGet attempt times out before indefinite stalls"
Assert-True ($nativeSourceText -match 'TweakRunsInElevatedBatch') "registry-heavy setup tweaks are grouped into the one elevated software worker"
Assert-True ($nativeSourceText -match 'clean-taskbar-items') "taskbar cleanup is eligible for elevated batching"
Assert-True ($nativeSourceText -match 'FirefoxExtensionInstallPolicyNeedsMutation') "Firefox extension policy is preflighted before deciding whether elevation is needed"
Assert-True ($nativeSourceText -match 'firefoxPolicyConfigured') "Firefox extension policy state is passed through the bounded elevated software plan"
Assert-True ($nativeSourceText -match 'ApplyBrowserConfiguration\(manifest, selection, false\)') "user-level browser pass does not rewrite protected Firefox policy"
Assert-True ($nativeSourceText -match 'Firefox extension policy failed in elevated setup') "elevated Firefox policy failures are labeled instead of surfacing as an anonymous browser error"
Assert-True ($nativeSourceText -match 'Windows denied normal-user access for tweak') "later tweak operations retry access-denied registry work through explicit elevation"
Assert-True ($nativeSourceText -match 'ApplyTweak\(id, enabled == "1", true\);') "direct apply-tweak commands permit UAC fallback on access denied"
Assert-True ($nativeSourceText -match 'String\.Equals\(command, "apply-tweak", StringComparison\.OrdinalIgnoreCase\)') "direct apply-tweak commands participate in runtime auto-refresh"
Assert-True ($nativeSourceText -match 'Elevated tweak batching self-test failed') "native self-test covers elevated tweak classification"
Assert-True ($nativeSourceText -match 'ConfirmQuitInstallationSelection') "installation selection has an explicit quit guard"
Assert-True ($nativeSourceText -match 'Quit the installer and discard the current selection changes\?') "quit guard clearly asks before discarding installation choices"
Assert-True ($nativeSourceText -match 'Up/Down: keep configuring and return to the current menu') "arrow navigation cancels an accidental quit request"
Assert-True ($nativeSourceText -match 'Deliberately ignore repeated Q/Esc presses') "repeated back keys cannot confirm quitting"
Assert-True ($nativeSourceText -match 'Installation quit confirmation self-test failed') "native self-test covers Y/N and arrow-key quit behavior"
Assert-True ($nativeSourceText -match 'WaitForProcessToAppear\("privacy\.sexy", 3000\)') "privacy.sexy installer auto-launch is detected before WGDot launches another copy"
Assert-True ($nativeSourceText -match 'WGDot will not launch a second copy') "privacy.sexy duplicate-launch prevention is explicit"
Assert-True ($nativeSourceText -match 'WaitForProcessToExit\("privacy\.sexy"\)') "WGDot waits for privacy.sexy to close before continuing"
Assert-True ($nativeSourceText -match 'or disable antivirus') "privacy.sexy integration does not weaken antivirus protection"
Assert-True ($nativeSourceText -match 'result\["failureDetails"\] = failureDetails') "elevated worker returns human-readable failure details"
Assert-True ($nativeSourceText -match 'Failure details:') "software reconciliation prints exact failure details in the main WGDot window"
Assert-True ($nativeSourceText -match 'Administrator tweak') "elevated tweak failures identify the exact tweak and reason"
Assert-True ($nativeSourceText -match 'Firefox extension policy:') "Firefox policy failures remain identifiable after the elevated window closes"
Assert-True ($nativeSourceText -match 'OpenRegistryKeyForValueWrite') "registry writes open existing keys before attempting to create them"
Assert-True ($nativeSourceText -match 'RegistryRights\.QueryValues \| RegistryRights\.SetValue') "existing registry keys request only value query/write rights"
Assert-True ($nativeSourceText -match 'Registry access denied:') "registry failures identify the exact hive/path/value"
Assert-True ($nativeSourceText -match 'DiscardRegistryOriginalSnapshot') "failed TaskbarDa writes do not leave a false rollback snapshot"
Assert-True ($nativeSourceText -match 'AllowNewsAndInterests') "protected TaskbarDa falls back to the documented Widgets policy"
Assert-True ($nativeSourceText -match 'using the supported Widgets policy fallback') "Widgets fallback is visible during reconciliation"
Assert-True ($nativeSourceText -match 'automatic-time-and-timezone') "native runtime manages automatic time/time-zone setup"
Assert-True ($nativeSourceText -match 'Services\\tzautoupdate') "automatic time-zone setup manages the Windows Auto Time Zone service"
Assert-True ($nativeSourceText -match 'CapabilityAccessManager\\ConsentStore\\location') "automatic time-zone setup enables Windows Location services"
Assert-True ($nativeSourceText -match '"Allow", RegistryValueKind\.String') "automatic time-zone setup uses Microsoft\'s Location Allow value"
Assert-True ($nativeSourceText -match 'w32tm\.exe') "automatic time setup invokes Windows Time"
Assert-True ($nativeSourceText -match '/resync /rediscover') "automatic time setup requests an immediate rediscovery/resync"
Assert-True ($nativeSourceText -match 'tzutil\.exe') "automatic time-zone setup reports the current Windows time zone"
Assert-True ($nativeSourceText -match 'Registry snapshot discard self-test failed') "native self-test covers failed-write snapshot cleanup"
Assert-True ($nativeSourceText -match 'Audit all software \(no install\)') "maintenance menu exposes full software audit"
Assert-True ($nativeSourceText -match 'if \(command == "software-audit"\) return SoftwareCatalogAudit') "software audit has a direct native command"
Assert-True ($nativeSourceText -match 'This audit does not install, upgrade, download installers, launch apps') "software audit clearly states its non-mutating scope"
Assert-True ($nativeSourceText -match 'ResolveGitHubReleasePackageAsset') "software audit and fallback installer share one official GitHub asset resolver"
Assert-True ($nativeSourceText -match 'Installer execution and application-specific runtime behavior still require an installed app') "software audit documents its runtime-testing limit"
Assert-True ($nativeSourceText -match 'IsOfficialPagePackage') "software reconcile supports packages intentionally unavailable through WinGet"
Assert-True ($nativeSourceText -match 'ProbeOfficialHttpsPage') "software audit validates official manual download pages without installer downloads"
Assert-True ($nativeSourceText -match 'Packages using alternate official source:') "audit distinguishes valid alternate-source packages from failures"
Assert-True ($nativeSourceText -match 'Manual official-source applications:') "reconcile explains manual official-source packages"
$fileZillaPackage = @($manifest.packages | Where-Object { $_.id -eq 'TimKosse.FileZilla.Client' })[0]
Assert-True ($null -ne $fileZillaPackage) "FileZilla catalog entry exists"
Assert-Equal ([string]$fileZillaPackage.installMode) 'official-page' "FileZilla no longer pretends its removed WinGet package is installable"
Assert-Equal ([string]$fileZillaPackage.officialPageUrl) 'https://filezilla-project.org/download.php?type=client' "FileZilla points only to its official download page"
Assert-True ($nativeSourceText -match 'String\.Equals\(command, "software-audit"') "software-audit refreshes the runtime before dispatch"
Assert-True ($nativeSourceText -match 'IsOfficialGitHubPackage') "catalog supports packages whose primary source is official GitHub"
Assert-True ($nativeSourceText -match 'official-github-portable') "catalog supports standalone user-level GitHub executables"
Assert-True ($nativeSourceText -match 'official-github-archive-driver') "catalog supports official GitHub driver archives"
Assert-True ($nativeSourceText -match 'ExtractZipToDirectorySafe') "archive installs reject unsafe extraction paths"
Assert-True ($nativeSourceText -match 'RunInteractiveInDirectory') "driver archive installers run from their release directory"
Assert-True ($nativeSourceText -match 'Refusing to install a user-level portable package inside the elevated worker') "portable applications are kept out of the elevated worker"
Assert-True ($nativeSourceText -match 'official GitHub OK') "audit reports official GitHub packages without a false WinGet-missing warning"
Assert-True ($nativeSourceText -match 'Official GitHub source selected') "reconcile skips dead WinGet lookup for official GitHub packages"
$rustDeskPackage = @($manifest.packages | Where-Object { $_.id -eq 'RustDesk.RustDesk' })[0]
Assert-True ($null -ne $rustDeskPackage) "RustDesk catalog entry exists"
Assert-Equal ([string]$rustDeskPackage.installMode) 'official-github' "RustDesk uses its verified official GitHub source instead of a missing WinGet ID"
Assert-Equal ([string]$rustDeskPackage.fallbackGitHubRepo) 'rustdesk/rustdesk' "RustDesk official GitHub source remains publisher-owned"
Assert-True ($nativeSourceText -match 'const string Version = "native-preview-60"') "native runtime version tracks current WGDot maintenance changes"
Assert-True ($nativeSourceText -match 'if \(command == "theme"\) return ThemeManagerFromArgs') "native runtime exposes direct YASB theme selection"
Assert-True ($nativeSourceText -match 'String\.Equals\(command, "theme"') "theme command refreshes the WGDot runtime before dispatch"
Assert-True ($nativeSourceText -match 'BuildYasbThemeCss') "native runtime generates a variable-only YASB theme override"
Assert-True ($nativeSourceText -match 'ApplyWindowsTerminalTheme') "theme selection synchronizes Windows Terminal"
Assert-True ($nativeSourceText -match 'Windows Terminal theme synchronization self-test failed') "isolated native self-test exercises Terminal theme synchronization"
Assert-True ($nativeSourceText -match 'GlazeWM was not reloaded') "theme application explicitly preserves GlazeWM state"
Assert-True ($nativeSourceText -match 'catppuccin-frappe') "Awtarchy theme palette catalog is carried into WGDot"
Assert-True ($nativeSourceText -match 'YASB theme CSS generation self-test failed') "isolated native self-test exercises real theme CSS writes"
Assert-True ($nativeSourceText -match '(?s)requiredRefreshCommands.*?"theme"') "acceptance audit itself requires theme runtime auto-refresh"
Assert-True ($nativeSourceText -match '(?s)requiredRefreshCommands.*?"cursor"') "acceptance audit requires cursor runtime auto-refresh"
Assert-True ($nativeSourceText -match 'File\.AppendAllText\(cssPath, Environment\.NewLine') "theme apply guarantees YASB receives an imported-stylesheet modified event"
Assert-True ($nativeSourceText -match 'if \(command == "acceptance-audit"\) return AcceptanceAudit') "native runtime exposes automated acceptance audit"
Assert-True ($nativeSourceText -match 'String\.Equals\(command, "acceptance-audit"') "acceptance audit refreshes runtime before dispatch"
Assert-True ($nativeSourceText -match 'Automated acceptance audit \(safe\)') "development menu exposes safe acceptance audit"
Assert-True ($nativeSourceText -match 'Development / testing - maintainer tools') "maintenance UI isolates maintainer-only diagnostics"
Assert-True ($nativeSourceText -match 'ShowDevelopmentMenu') "main maintenance menu exposes the development section"
Assert-True ($nativeSourceText -match 'RunIsolatedMaintenanceSelfTest') "acceptance audit runs mutation tests in an isolated child runtime"
Assert-True ($nativeSourceText -match 'SoftwareCatalogAudit\(false\)') "acceptance audit includes the full noninteractive software catalog audit"
Assert-True ($nativeSourceText -match 'ValidateBrowserSelectionState') "acceptance audit validates persisted browser option state"
Assert-True ($nativeSourceText -match 'GPU inventory \(read-only\)') "acceptance audit includes read-only GPU enumeration"
Assert-True ($nativeSourceText -match 'Still requires real Windows interaction') "acceptance audit labels the remaining manual-only scope"
Assert-True ($nativeSourceText -notmatch '(?i)sudo(?:\.exe)?\s+winget') "software batching does not depend on Windows sudo"
Assert-True ($nativeSourceText -notmatch '(?i)winget(?:\.exe)?\s+upgrade\s+--all') "native runtime never upgrades all WinGet packages"
Assert-True ($nativeSourceText -match '\.wgdot\.backup') "native runtime uses identifiable adjacent backup names"
Assert-True ($nativeSourceText -match 'REMOVED-UPSTREAM') "native runtime preserves upstream-removal planning"
Assert-True ($nativeSourceText -match 'merge-file') "native runtime includes three-way merge support"
Assert-True ($nativeSourceText -match 'BackupManager') "native runtime includes backup manager"
Assert-True ($nativeSourceText -match 'releases/latest') "native runtime resolves published stable releases"
Assert-True ($nativeSourceText -match 'TryRefreshRuntimeAndRun\(args, out refreshedExitCode\)') "normal WGDot commands check for runtime refresh before dispatch"
Assert-True ($nativeSourceText -match 'ShouldAutoRefreshRuntime') "runtime refresh policy is centralized"
Assert-True ($nativeSourceText -match 'BuildCommandLine\(originalArgs\)') "refreshed runtime preserves the requested WGDot command"
Assert-True ($nativeSourceText -match 'wgdot-next-') "native runtime stages a replacement executable safely"
Assert-True ($nativeSourceText -match 'ScheduleStagedRuntimeInstall') "staged runtime installs itself after the requested operation exits"
Assert-True ($nativeSourceText -match 'CreateRuntimeSwapHelper') "native runtime defers replacing the running executable"
Assert-True ($nativeSourceText -match 'PrepareRawRevisionSource') "native runtime can acquire exact managed sources from raw.githubusercontent.com"
Assert-True ($nativeSourceText -match 'WGDOT_FORCE_RAW_SOURCE') "CI can force the restricted-network raw source path"
Assert-True ($nativeSourceText -match 'source-self-test') "native runtime exposes an internal exact-source validation command"
Assert-True ($nativeSourceText -match '(?s)string recordedRevision = GetString\(bootstrap, "sourceRevision"\);.*?explicitRefTesting.*?Regex\.IsMatch\(recordedRevision.*?\? recordedRevision\.ToLowerInvariant\(\).*?: ResolveBranchHeadViaApi\(sourceRef\)') "explicit exact bootstrap revisions stay pinned without requiring a branch-head API lookup"
Assert-True ($nativeSourceText -match 'runtime-refresh\.log') "blocked API refresh checks are recorded without killing the installed runtime"
Assert-True ($nativeSourceText -match 'CopyRuntimeWithRetry') "runtime install retries replacement across transient executable locks"
Assert-True ($nativeSourceText -match 'runtime-swap-stop') "runtime self-refresh stops WGDot-owned workers before replacing the installed executable"
Assert-True ($nativeSourceText -match 'runtime-swap-restore') "runtime self-refresh restores WGDot-owned workers after replacement"
Assert-True ($nativeSourceText -match 'wgdot-worker-state-') "runtime self-refresh persists transient worker state outside the installed executable"
Assert-True ($nativeSourceText -match 'IsRuntimeSwapInternalCommand') "runtime-swap internals cannot recursively schedule another staged replacement"
Assert-True ($nativeSourceText -match 'idleInhibitorWasActive = NamedMutexExists\(IdleInhibitorMutexName\)') "runtime install preserves active idle inhibitor state"
Assert-True ($nativeSourceText -match 'mouseModeHookWasActive = NamedMutexExists\(MouseModeMutexName\)') "runtime install preserves active mouse-mode worker state"
Assert-True ($nativeSourceText -match 'superLTestHookWasActive = NamedMutexExists\(SuperLTestMutexName\)') "runtime install preserves active Super+L test hook state"
Assert-True ($nativeSourceText -match 'Runtime replacement helper self-test failed') "native self-test exercises runtime replacement helper"
Assert-True ($nativeSourceText -match '"mark-runtime"') "runtime revision is recorded by the successfully swapped executable"
Assert-True ($nativeSourceText -match 'WGDOT_SKIP_RUNTIME_REFRESH') "staged runtime avoids recursive refresh while running the requested operation"
Assert-True ($nativeSourceText -match '"maintenance-self-test"') "native runtime exposes isolated maintenance self-test"
Assert-True ($nativeSourceText -match 'ensure-yasb-theme') "native runtime supports generated YASB theme post-action"
Assert-True ((Get-Command Get-WgdotYasbThemeCss -ErrorAction SilentlyContinue) -ne $null) "PowerShell fallback exposes YASB theme CSS generator"
Assert-True ((Get-Command Set-WgdotYasbTheme -ErrorAction SilentlyContinue) -ne $null) "PowerShell fallback exposes YASB theme writer"
Assert-True ((Get-Command Set-WgdotWindowsTerminalTheme -ErrorAction SilentlyContinue) -ne $null) "PowerShell fallback exposes Windows Terminal theme writer"
Assert-True ((Get-Command Get-WgdotYasbThemeManualPowerShell -ErrorAction SilentlyContinue) -ne $null) "PowerShell fallback can emit standalone theme recovery commands"
Assert-True ((Get-Command Get-WgdotWindowsTerminalThemeManualPowerShell -ErrorAction SilentlyContinue) -ne $null) "PowerShell fallback can emit standalone Terminal theme recovery commands"

$expectedThemeRows = @(
    "carbon-night|Carbon Night|#353535|#d0d0d0|#404040|#4a4a4a|#2b2b2b|#ff5555|#1a1a1a|#6a9955|#ff5555|#5c5c5c",
    "catppuccin-frappe|Catppuccin Frappe|#303446|#c6d0f5|#414559|#535970|#383c4d|#e78284|#232634|#a6d189|#ef9f76|#a5adce",
    "crimson-red|Crimson Red|#1e1e2e|#f38ba8|#352630|#5a3442|#292330|#f38ba8|#1e1e2e|#fab387|#f38ba8|#9f8994",
    "electric-blue|Electric Blue|#1e1e2e|#89b4fa|#293448|#34445e|#252938|#f38ba8|#1e1e2e|#a6e3a1|#fab387|#8993a8",
    "gruvbox|Gruvbox|#282828|#ebdbb2|#4a423c|#665c4e|#3c3836|#b16286|#fbf1c7|#98971a|#cc241d|#a89984",
    "iron-forge|Iron Forge|#0f1113|#bcd2d2|#1f2328|#242a32|#0d0f12|#a31717|#ffffff|#1f6f6f|#a31717|#6a7b86",
    "obsidian-night|Obsidian Night|#0f0f0f|#cdd6f4|#1e1e2e|#313244|#1a1a1a|#ff5555|#1e1e2e|#6a9955|#ff5555|#4b4b4b",
    "pink|Pink|#D297A1|#2E2E2E|#B77F91|#C0AFC0|#C0AFC0|#B04155|#FFFFFF|#D3D3D3|#B04155|#7A7A7A",
    "pipboy|Pip-Boy|#050805|#a4ff47|#1f301f|#1b281b|#101810|#263826|#050805|#a4ff47|#3c1b1b|#2a3d2a"
)
$actualThemes = @(Get-WgdotYasbThemes)
Assert-Equal 9 $actualThemes.Count "PowerShell fallback theme count"
$actualThemeRows = @($actualThemes | ForEach-Object {
    @(
        [string]$_.id, [string]$_.label, [string]$_.background, [string]$_.foreground,
        [string]$_.hover, [string]$_.focus, [string]$_.active, [string]$_.urgent,
        [string]$_.dark, [string]$_.charging, [string]$_.critical, [string]$_.muted
    ) -join "|"
})
foreach ($row in $expectedThemeRows) {
    Assert-True ($actualThemeRows -contains $row) "PowerShell fallback palette matches current Awtarchy: $row"
}
Assert-True ($nativeSourceText -match 'WGDOT_TEST_ROOT') "native maintenance self-test redirects state away from normal WGDot state"

$themeTestRoot = Join-Path $env:TEMP ("wgdot-ps-theme-test-" + [guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Path $themeTestRoot -Force | Out-Null
    $themeCssPath = Join-Path $themeTestRoot "theme.css"
    $themeStatePath = Join-Path $themeTestRoot "theme.json"
    $terminalSettingsPath = Join-Path $themeTestRoot "settings.json"
    '{"profiles":{"defaults":{}},"schemes":[{"name":"External"}],"themes":[{"name":"External UI"}],"theme":"External UI"}' |
        Set-Content -LiteralPath $terminalSettingsPath -Encoding UTF8
    Set-WgdotYasbTheme -Id "electric-blue" -CssPath $themeCssPath -StatePath $themeStatePath -TerminalSettingsPath $terminalSettingsPath

    Assert-True (Test-Path -LiteralPath $themeCssPath -PathType Leaf) "PowerShell fallback writes YASB theme.css"
    Assert-True (Test-Path -LiteralPath $themeStatePath -PathType Leaf) "PowerShell fallback writes YASB theme state"
    $themeCss = Get-Content -LiteralPath $themeCssPath -Raw
    $themeState = Get-Content -LiteralPath $themeStatePath -Raw | ConvertFrom-Json
    Assert-True ($themeCss -match '--background: #1e1e2e;') "PowerShell fallback theme has Electric Blue background"
    Assert-True ($themeCss -match '--foreground: #89b4fa;') "PowerShell fallback theme has Electric Blue foreground"
    Assert-True ($themeCss -match '--subtle-hover: rgba\(137, 180, 250, 20\);') "PowerShell fallback derives Awtarchy subtle-hover alpha"
    Assert-Equal "electric-blue" ([string]$themeState.id) "PowerShell fallback preserves theme id in state"
    Assert-Equal $true ([bool]$themeState.terminalSynced) "PowerShell fallback records successful Terminal synchronization"
    Assert-Equal $false ([bool]$themeState.glazewmReloaded) "PowerShell fallback records that GlazeWM was not reloaded"
    $terminalSettings = Get-Content -LiteralPath $terminalSettingsPath -Raw | ConvertFrom-Json
    Assert-Equal "WGDot Electric Blue UI" ([string]$terminalSettings.theme) "PowerShell fallback selects the WGDot Terminal UI theme"
    Assert-True (@($terminalSettings.schemes | Where-Object { $_.name -eq "External" }).Count -eq 1) "PowerShell fallback preserves unrelated Terminal schemes"
    Assert-True (@($terminalSettings.schemes | Where-Object { $_.name -eq "WGDot Electric Blue" }).Count -eq 1) "PowerShell fallback writes the selected WGDot Terminal scheme"

    $manualThemeLines = @(Get-WgdotYasbThemeManualPowerShell -Id "electric-blue")
    $manualThemeText = $manualThemeLines -join [Environment]::NewLine
    Assert-True ($manualThemeText -match 'theme\.css') "generated manual recovery includes theme.css"
    Assert-True ($manualThemeText -match 'theme\.json') "generated manual recovery includes theme state"
    Assert-True ($manualThemeText -match 'electric-blue') "generated manual recovery preserves selected theme id"
    Assert-True ($manualThemeText -match 'terminalSettingsPath') "generated manual recovery includes Windows Terminal settings"
    Assert-True ($manualThemeText -match 'terminalSynced') "generated manual recovery records Terminal synchronization state"
    Assert-True ($manualThemeText -match 'WGDot Electric Blue') "generated manual recovery includes the selected Terminal scheme"
    Assert-True ($manualThemeText -match 'glazewmReloaded = \$false') "generated manual recovery never reloads GlazeWM"
    [scriptblock]::Create($manualThemeText) | Out-Null
} finally {
    if (Test-Path -LiteralPath $themeTestRoot) { Remove-Item -LiteralPath $themeTestRoot -Recurse -Force }
}
Assert-True ($nativeSourceText -match 'TweakManager') "native runtime includes Windows tweak manager"
Assert-True ($nativeSourceText -match 'ApplyMicroTextDefaults') "native runtime manages Micro text associations"
Assert-True ($nativeSourceText -match 'ReadPackageChoicesByCategory') "software selector is grouped by category"
Assert-True ($nativeSourceText -match 'PackageCategoryLabel') "software selector has friendly category labels"
Assert-True ($nativeSourceText -match 'E: extensions/options') "Browser category advertises E for nested browser options"
Assert-True ($nativeSourceText -match 'IsBrowserOptionsKey\(ConsoleKey\.E\)') "E opens browser-specific options"
Assert-True ($nativeSourceText -match 'ReadBrowserOptionChoices') "browser-specific options use a nested keyboard checklist"
Assert-True ($nativeSourceText -match 'if \(edited == null\) edited = choices;') "Q/Esc back preserves browser-option checkbox changes"
Assert-True ($nativeSourceText -match 'default-OFF Firefox options such as Dark Reader') "nested Firefox option persistence regression is documented in code"
Assert-True ($nativeSourceText -match 'BrowserOptionsConfigured') "browser selection migration state is explicit"
Assert-True ($nativeSourceText -match 'Software\\Policies\\Mozilla\\Firefox\\Extensions\\Install') "Firefox uses Mozilla Extensions.Install Windows policy"
Assert-True ($nativeSourceText -match 'Profiles/wgdot\.betterfox') "Betterfox uses a dedicated WGDot Firefox profile"
Assert-True ($nativeSourceText -match 'Make the WGDot Betterfox profile the Firefox default\? \[y/N\]') "Betterfox default-profile change requires explicit review"
Assert-True ($nativeSourceText -match 'Firefox default profile changed outside WGDot') "Betterfox rollback preserves newer user default-profile changes"
Assert-True ($nativeSourceText -match 'manual Add to Brave approval') "Brave Chrome Web Store setup requires browser/user approval"
Assert-True ($nativeSourceText -match 'brave://settings/extensions/v2') "Brave full uBlock Origin uses Brave's supported Manifest V2 settings page"
Assert-True ($nativeSourceText -match 'braveGuidedReviewedOptions') "Brave guided extension pages are remembered instead of reopening every reconcile"
Assert-True ($nativeSourceText -match 'Close Firefox before WGDot creates the dedicated Betterfox profile') "Betterfox profile metadata is not rewritten while Firefox is running"
Assert-True ($nativeSourceText -match 'defaultProfileReviewed') "Betterfox remembers a reviewed default-profile choice"
Assert-True ($nativeSourceText -match 'Browser selection persistence self-test failed') "native self-test covers persisted browser selections"
Assert-True ($nativeSourceText -match 'Firefox default-profile rollback self-test failed') "native self-test isolates Betterfox default-profile rollback"
Assert-True ($nativeSourceText -match 'key == ConsoleKey\.Escape \|\| key == ConsoleKey\.Q') "Q and Escape share the global back-key behavior"
Assert-True ($nativeSourceText -match 'Q/Esc: back') "keyboard UI advertises Q and Escape as back keys"
Assert-True ($nativeSourceText -match 'launch-open-shell') "native runtime starts Open-Shell after installation"
Assert-True ($nativeSourceText -match 'ApplyFlowLauncherAltP') "native runtime manages Flow Launcher Alt+P"
Assert-True ($nativeSourceText -match 'command == "quick-launch"') "native runtime exposes the YASB Quick Launch bridge"
Assert-True ($nativeSourceText -match '(?s)static int OpenYasbQuickLaunch\(\).*?PostThreadMessage.*?new UIntPtr\(1\)') "YASB Quick Launch dispatches directly to hotkey ID 1 without synthetic keys"
Assert-True ($nativeSourceText -match 'OpenFlowLauncher') "native runtime exposes the Flow Launcher bar helper"
Assert-True ($nativeSourceText -match 'command == "flow-open"') "Flow Launcher helper command is dispatchable"
Assert-True ($nativeSourceText -match 'ApplyEarTrumpetMixerAltV') "native runtime manages EarTrumpet Alt+V"
Assert-True ($nativeSourceText -match 'OpenEarTrumpetMixer') "native runtime exposes the EarTrumpet bar helper"
Assert-True ($nativeSourceText -match 'keybd_event\(VkMenu') "EarTrumpet helper triggers its configured Alt+V mixer hotkey"
Assert-True ($nativeSourceText -match 'command == "clipboard-history"') "native runtime exposes Windows Clipboard History"
Assert-True ($nativeSourceText -match 'ApplyWindowsShellHotkeysPolicy') "native runtime implements reversible selective Windows hotkey filtering"
Assert-True ($nativeSourceText -match 'MigrateLegacyWindowsShellHotkeys') "native runtime migrates WGDot-owned legacy NoWinKeys state"
Assert-True ($nativeSourceText -match '(?s)MigrateLegacyWindowsShellHotkeys\(bool allowElevation\).*?if \(!IsAdministrator\(\)\).*?RunElevatedSelf\("migrate-legacy-hotkeys"\)') "legacy NoWinKeys migration elevates before opening the protected policy key for write"
Assert-True ($nativeSourceText -match 'DiscardRegistryOriginalSnapshot\(id, "HKCU", legacyPath, legacyName\)') "legacy NoWinKeys ownership is retired after migration"
Assert-True ([bool](@(($manifest.components | Where-Object { $_.id -eq "glazewm" }).postActions | Where-Object { $_.type -eq "migrate-legacy-windows-hotkeys" }).Count -eq 1)) "managed GlazeWM updates run the legacy hotkey migration"
Assert-True ($nativeSourceText -match '"DisabledHotkeys"') "native runtime uses selective Explorer DisabledHotkeys instead of blanket NoWinKeys"
Assert-True ($nativeSourceText -match '"ABCDEFGHIJKLMOPQRSTUWXYZ0123456789"') "selective shell filter preserves native Win+V and Win+N"
Assert-True ($nativeSourceText -match 'RestoreRegistryOriginals\(id\)') "Windows hotkey tweak participates in registry rollback"
Assert-True ($nativeSourceText -match 'command == "glazewm-pause-status"') "native runtime exposes GlazeWM paused state"
Assert-True ($nativeSourceText -match 'command == "glazewm-pause-toggle"') "native runtime exposes real GlazeWM pause toggle"
Assert-True ($nativeSourceText -match 'command == "theme-toggle"') "native runtime exposes the single-instance theme selector"
Assert-True ($nativeSourceText -match 'command == "power-menu"') "native runtime exposes the WGDot power overlay"
Assert-True ($nativeSourceText -match 'System\.Windows\.Forms\.Application\.Run') "power overlay uses a native WinForms event loop"
Assert-True ($nativeSourceText -match 'LockWorkStation') "power overlay uses Windows lock API"
Assert-True ($nativeSourceText -match 'SetSuspendState') "power overlay uses Windows sleep API"
Assert-True ($nativeSourceText -match 'ApplicationDataManager\.CreateForPackageFamily') "EarTrumpet AppX settings use Windows packaged LocalSettings"
Assert-True ($nativeSourceText -match '40459File-New-Project\.EarTrumpet_725pr5jq8wr8a') "EarTrumpet package family is explicit"
Assert-True ($nativeSourceText -match 'ApplyClassicContextMenu') "native runtime manages classic context menu"
Assert-True ($nativeSourceText -match 'DeleteRegistryKeyIfOriginallyAbsentAndEmpty') "native tweak rollback prunes only WGDot-created empty registry keys"
Assert-True ($nativeSourceText -notmatch 'DeleteSubKeyTree\(clsid') "classic context-menu rollback does not delete unknown pre-WGDot CLSID state"
Assert-True ($nativeSourceText -match 'base64-bytes') "registry rollback preserves binary and REG_NONE values losslessly"
Assert-True ($nativeSourceText -match 'RegistryKeyWasAbsentInSnapshot') "registry rollback tracks pre-WGDot key existence"
Assert-True ($nativeSourceText -match 'ApplyOopsCursor') "native runtime keeps Oops cursor support"
Assert-True ($nativeSourceText -match 'BibataCursorAssets') "native runtime exposes Awtarchy Bibata cursor variants"
Assert-True ($nativeSourceText -match 'ful1e5/Bibata_Cursor') "Bibata cursor assets resolve only from the official upstream repository"
Assert-True ($nativeSourceText -match 'ExtractZipToDirectorySafe\(zipPath, extractRoot\)') "Bibata cursor extraction uses the safe archive extractor"
Assert-True ($nativeSourceText -match 'if \(command == "cursor"\) return CursorManagerFromArgs') "native runtime exposes cursor selection"
Assert-True ($nativeSourceText -match 'undergroundwires/privacy\.sexy/releases/latest') "privacy.sexy uses official latest GitHub release"
Assert-True ($nativeSourceText -match 'privacy\.sexy download did not return a valid Windows executable') "privacy.sexy installer payload is validated before execution"
Assert-True ($nativeSourceText -match 'GAC_MSIL') "EarTrumpet helper can find framework facades on normal Windows without developer reference assemblies"
Assert-True ($nativeSourceText -match 'System\.Runtime\.WindowsRuntime') "EarTrumpet helper includes Windows Runtime interop fallback"
Assert-True ($nativeSourceText -match 'SetupDiGetClassDevs') "native runtime detects present display adapters through SetupAPI"
Assert-True ($nativeSourceText -match 'VEN_1002') "GPU detection recognizes AMD PCI vendor IDs"
Assert-True ($nativeSourceText -match 'VEN_10DE') "GPU detection recognizes NVIDIA PCI vendor IDs"
Assert-True ($nativeSourceText -match 'VEN_8086') "GPU detection recognizes Intel PCI vendor IDs"
Assert-True ($nativeSourceText -match 'Wagnardsoft\.DisplayDriverUninstaller') "GPU maintenance uses the exact DDU WinGet package"
Assert-True ($nativeSourceText -match '\*WGDotGpuSafeModeResume') "DDU workflow registers a Safe Mode-capable RunOnce handoff"
Assert-True ($nativeSourceText -match '/set \{current\} safeboot minimal') "DDU workflow explicitly stages Safe Mode"
Assert-True ($nativeSourceText -match '/deletevalue \{current\} safeboot') "DDU workflow removes forced Safe Mode before launching DDU"
Assert-True ($nativeSourceText -match 'drivers\.amd\.com') "AMD installer resolver is restricted to the official AMD driver host"
Assert-True ($nativeSourceText -match 'HttpRequestHeader\.Referer') "AMD installer download sends AMD's required support-page referrer"
Assert-True ($nativeSourceText -match 'minimalsetup\|installer') "AMD resolver targets the current official auto-detect web installer shape"
Assert-True ($nativeSourceText -match 'DownloadVendorPageText') "GPU installer resolver has a bounded curl/browser fallback for vendor page changes"
Assert-True ($nativeSourceText -match '\\u002F') "GPU resolver normalizes JSON-unicode escaped vendor download URLs"
Assert-True ($nativeSourceText -match 'No third-party fallback was used') "invalid GPU payloads fail closed instead of opening an unverified fallback"
Assert-True ($nativeSourceText -match 'foreach \(string vendor in physical\.OrderBy\(GpuVendorLabel\)\)') "GPU maintenance automatically runs the vendor assistant for every detected physical GPU vendor"
Assert-True ($nativeSourceText -match 'us\.download\.nvidia\.com') "NVIDIA installer resolver is restricted to NVIDIA's official download host"
Assert-True ($nativeSourceText -match 'dsadata\.intel\.com') "Intel installer uses Intel's official Driver & Support Assistant endpoint"
Assert-True ($nativeSourceText -match 'GPU DRIVER ACTION REQUIRED') "pending GPU cleanup is surfaced on the next WGDot run"
Assert-True ($nativeSourceText -match 'Review only\. No files, backups, baselines, or selection state were changed\.') "native Git review is explicitly non-mutating"
Assert-True ($nativeSourceText -match 'HKCU\\\\Environment|OpenSubKey\("Environment"|CreateSubKey\("Environment"') "native installer persists user PATH"
Assert-True ($nativeBootstrapText -notmatch '(?i)powershell(?:\.exe)?') "native bootstrap does not invoke PowerShell"
Assert-True ($nativeBootstrapText -match 'raw\.githubusercontent\.com/dillacorn/win-glaze-dots') "native bootstrap can acquire source from GitHub"
Assert-True ($nativeBootstrapText -match '(?i)--revision') "native bootstrap supports exact revision testing"
Assert-True ($nativeBootstrapText -match '(?i)--ref') "native bootstrap supports explicit ref testing"
Assert-True ($nativeBootstrapText -match 'WGDOT_SOURCE_EXPLICIT') "native bootstrap records explicit ref-testing intent"
Assert-True ($nativeSourceText -match 'sourceExplicit') "native runtime preserves explicit ref-testing state"
Assert-True ($nativeSourceText -match 'explicitRefTesting') "native runtime can use explicit main as the maintainer config source"
Assert-True ($nativeBootstrapText -match '(?i)curl\.exe') "native bootstrap has a location-independent download path"
Assert-True ($runtimeText -notmatch '(?i)winget\s+upgrade\s+--all') "runtime never upgrades all WinGet packages"
Assert-True ($manualText -notmatch '(?i)winget\s+upgrade\s+--all') "manual path never upgrades all WinGet packages"
Assert-True ($runtimeText -notmatch '(?i)rmdir\s+/s') "runtime does not use destructive CMD directory removal"

$yasbConfigText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.config\yasb\config.yaml") -Raw
Assert-True ($yasbConfigText -match 'context_menu:\s*false') "YASB blank-bar context menu is disabled while Alt+Ctrl+B keeps coordinated auto-hide"
Assert-True ($yasbConfigText -match 'run_cmd:\s*"wgdot idle-inhibitor-status"') "YASB bar polls the WGDot idle inhibitor"
Assert-True ($yasbConfigText -match 'label:\s*"\{data\[icon\]\}"') "YASB idle inhibitor renders JSON-decoded eye state"
Assert-True ($yasbConfigText -match 'return_format:\s*"json"') "YASB idle inhibitor uses JSON to preserve Nerd Font glyphs"
Assert-True ($yasbConfigText -match 'exec wgdotw idle-inhibitor-toggle') "YASB bar toggles the WGDot idle inhibitor without a console flash"
Assert-True ($yasbConfigText -match 'glazewm_tiling_direction') "YASB exposes GlazeWM tiling direction"
Assert-True ($yasbConfigText -match 'GlazewmTilingDirectionWidget') "YASB uses its native GlazeWM tiling-direction widget"

$flameshotConfigText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\AppData\Roaming\flameshot\flameshot.ini") -Raw
Assert-True ($flameshotConfigText -match '(?m)^captureActiveMonitor=true') "Flameshot defaults to capturing the active monitor without monitor selection"

Assert-True ($nativeSourceText -match 'WaitForWindowsModifierRelease') "synthetic mixer hotkeys can wait for physical Super release"
Assert-True ($nativeSourceText -match 'command == "idle-inhibitor-status"') "native runtime exposes idle-inhibitor status"
Assert-True ($nativeSourceText -match 'command == "idle-inhibitor-toggle"') "native runtime exposes idle-inhibitor toggle"
Assert-True ($nativeSourceText -match 'SetThreadExecutionState') "idle inhibitor uses the native Windows execution-state API"
Assert-True ($nativeSourceText -match 'EsContinuous \| EsSystemRequired \| EsDisplayRequired') "idle inhibitor blocks system and display idle timeout while active"
Assert-True ($nativeSourceText -match 'command == "desktop-worker"') "native runtime exposes the persistent desktop worker"
Assert-True ($nativeSourceText -match 'String.Equals\(type, "ensure-desktop-worker"') "managed GlazeWM apply can activate the desktop worker without a reboot"
Assert-True ($nativeSourceText -match 'AddClipboardFormatListener') "WGDot clipboard history listens for native clipboard updates"
Assert-True ($nativeSourceText -match 'class ClipboardHistoryForm') "WGDot owns a native clipboard history window instead of Win+V"
Assert-True ($nativeSourceText -match 'Clipboard\.ContainsImage') "WGDot clipboard history captures image content"
Assert-True ($nativeSourceText -match 'Clipboard\.ContainsText') "WGDot clipboard history captures text content"
Assert-True ($nativeSourceText -match 'UpdateClipboardHistoryText') "WGDot clipboard text can be edited and saved"
Assert-True ($nativeSourceText -match 'DeleteClipboardHistoryEntry') "WGDot clipboard entries can be deleted individually"
Assert-True ($nativeSourceText -match 'ClearClipboardHistory') "WGDot clipboard history can be cleared"
Assert-True ($nativeSourceText -notmatch '(?s)OpenWindowsClipboardHistory\(\).*?SendKeyChord\(VkLwin, VkV\)') "WGDot clipboard history no longer depends on native Win+V"
Assert-True ($nativeSourceText -match 'command == "flameshot-gui"') "native runtime exposes a robust Flameshot launcher"
Assert-True ($nativeSourceText -match 'FindFlameshotExe') "Flameshot launcher resolves the installed executable"
Assert-True ($nativeSourceText -match 'command == "display-settings"') "native runtime exposes Windows display settings"
Assert-True ($nativeSourceText -match 'command == "rawaccel-open"') "native runtime exposes the RawAccel GUI toggle"
Assert-True ($nativeSourceText -match 'ResolveRawAccelExe') "RawAccel GUI resolves managed, running, PATH, standard portable, and remembered locations"
Assert-True ($nativeSourceText -match 'OpenFileDialog') "RawAccel can ask for rawaccel.exe once when portable discovery cannot find it"
Assert-True ($nativeSourceText -match 'Process\.GetProcessesByName\("rawaccel"\)') "RawAccel toggle detects an already-running GUI"
Assert-True ($nativeSourceText -match 'command == "bar-autohide-toggle"') "native runtime exposes coordinated YASB/GlazeWM auto-hide"
Assert-True ($nativeSourceText -match 'command == "window-audit"') "native runtime exposes visible-window process auditing"
Assert-True ($nativeSourceText -match 'command == "mouse-mode-toggle"') "native runtime exposes the scoped mouse-mode toggle"
Assert-True ($nativeSourceText -match 'command == "mouse-mode-disable"') "native runtime exposes an unconditional mouse-mode escape"
Assert-True ($nativeSourceText -match 'NamedMutexExists\(MouseModeMutexName\)') "mouse-mode state trusts the scoped hook mutex before GlazeWM query fallback"
Assert-True ($nativeSourceText -match 'command == "mouse-mode-hook"') "native runtime exposes the scoped mouse hook worker"
Assert-True ($nativeSourceText -match 'command == "glazewm-binding-mode-toggle"') "native runtime exposes NoAlt/VM quick-setting toggles"
Assert-True ($nativeSourceText -match 'SendInput') "desktop shortcut bridges use Win32 SendInput"
Assert-True ($nativeSourceText -match 'public MOUSEINPUT mouse') "Win32 INPUT union includes MOUSEINPUT so x64 SendInput uses the native 40-byte layout"
Assert-True ($nativeSourceText -match 'public HARDWAREINPUT hardware') "Win32 INPUT union includes HARDWAREINPUT for native union sizing"
Assert-True ($nativeSourceText -match 'expectedInputSize = IntPtr.Size == 8 \? 40 : 28') "native self-test validates Win32 INPUT size on x64 and x86"
Assert-True ($nativeSourceText -match 'TryGetActiveGlazeWmBindingMode') "binding-mode Quick Settings still use live GlazeWM state when the query succeeds"
Assert-True ($nativeSourceText -match 'ReadTrackedGlazeBindingMode') "binding-mode Quick Settings fall back to WGDot tracked state when GlazeWM query IPC fails"
Assert-True ($nativeSourceText -match 'command == "glazewm-binding-mode-set"') "native runtime exposes deterministic binding-mode transitions for keyboard shortcuts"
Assert-True ($nativeSourceText -match 'PostThreadMessage') "Quick Launch dispatches directly to YASB's hotkey listener"
$quickLaunchBlock = [regex]::Match($nativeSourceText, '(?ms)^    static int OpenYasbQuickLaunch\(\)\r?\n    \{.*?^    \}').Value
Assert-True ($quickLaunchBlock -match 'new UIntPtr\(1\)') "Quick Launch posts YASB hotkey ID 1 directly"
Assert-True ($quickLaunchBlock -notmatch 'GlazeWmPauseToggle|SendKeyChord|Thread\.Sleep|WaitForLauncherModifierRelease') "Quick Launch never pauses GlazeWM or waits on synthetic-key timing"
Assert-True ($nativeSourceText -match 'EnsureHiddenLauncher') "native runtime installs the GUI-subsystem wgdotw helper"
Assert-True ($nativeSourceText -match '/target:winexe') "wgdotw is compiled without a console window"
Assert-True (@($yasb.postActions | Where-Object { $_.type -eq "ensure-hidden-launcher" }).Count -eq 1) "YASB apply ensures wgdotw exists"
Assert-True ($nativeSourceText -match 'ReadableTerminalColor') "Windows Terminal ANSI colors are contrast-checked"
Assert-True ($nativeSourceText -match 'command == "yasb-running-apps-toggle"') "native runtime exposes the running-app visibility toggle"
Assert-True ($nativeSourceText -match 'command == "yasb-running-apps-shade-toggle"') "native runtime exposes the themed running-app shading toggle"
Assert-True ($nativeSourceText -match 'AppearanceStatePath') "YASB appearance state is persisted separately from managed styles"
Assert-True ($nativeSourceText -match 'BuildYasbAppearanceCss') "YASB appearance toggles generate a live imported stylesheet"
Assert-True ($nativeSourceText -match 'command == "super-l-test"') "native runtime exposes the isolated Super+L test controller"
Assert-True ($nativeSourceText -match 'command == "super-l-hook"') "native runtime exposes the hidden Super+L test hook worker"
Assert-True ($nativeSourceText -match 'SetWindowsHookExKeyboard') "Super+L test uses a scoped low-level keyboard hook"
Assert-True ($nativeSourceText -match 'focus --direction right') "Super+L test sends focus-right to GlazeWM"
Assert-True ($nativeSourceText -match 'SuperLTestStopEventName') "Super+L test hook has an explicit stop signal"
Assert-True ($nativeSourceText -match 'String\.Equals\(command, "super-l-test"') "Super+L test controller participates in runtime auto-refresh"
Assert-True ($nativeSourceText -match 'SetWindowsHookEx') "mouse mode installs a Windows low-level mouse hook only while active"
Assert-True ($nativeSourceText -match 'UnhookWindowsHookEx') "mouse mode always removes its low-level hook"
Assert-True ($nativeSourceText -match 'GlazeWmBindingModeActive\("mouse"\)') "mouse hook lifetime follows the real GlazeWM mouse binding mode"
Assert-True ($nativeSourceText -match 'WmNcLButtonDown') "mouse move/resize uses Windows native interactive move-size messages"
Assert-True ($nativeSourceText -match 'toggle-floating') "mouse middle-click delegates floating state to GlazeWM"
$autoRefreshBlock = [regex]::Match($nativeSourceText, '(?ms)^    static bool ShouldAutoRefreshRuntime\(string command\)\r?\n    \{.*?^    \}').Value
Assert-True ($autoRefreshBlock -notmatch 'mouse-mode-toggle') "mouse-mode hotkey skips remote runtime-refresh checks for immediate response"
Assert-True ($autoRefreshBlock -notmatch 'mouse-mode-disable') "mouse-mode escape skips remote runtime-refresh checks for immediate response"
Assert-True ($autoRefreshBlock -notmatch 'bar-autohide-toggle') "bar auto-hide hotkey skips remote runtime-refresh checks for immediate response"
Assert-True ($autoRefreshBlock -match 'window-audit') "window audit command participates in runtime auto-refresh"
Assert-True ($nativeSourceText -match 'yasbc\.exe", "reload -s"') "bar auto-hide reloads YASB after changing native auto-hide state"
Assert-True ($nativeSourceText -match 'glazewm\.exe", "command wm-reload-config"') "bar auto-hide reloads GlazeWM after changing the 5/35 px gap"
Assert-True ($nativeSourceText -match 'GetWindowThreadProcessId') "window audit resolves process IDs from real top-level windows"
Assert-True ($nativeSourceText -match 'IsWindowVisible') "window audit filters to visible top-level windows"
Assert-True ($nativeSourceText -match 'CenterWindowOnMonitor') "theme picker can move to the focused monitor"

$terminalSettingsPath = Join-Path $repoRoot "UserProfile\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$terminalSettings = Get-Content -LiteralPath $terminalSettingsPath -Raw | ConvertFrom-Json
Assert-Equal $true ([bool]$terminalSettings.copyOnSelect) "Windows Terminal copies selected text automatically"
Assert-True (@($terminalSettings.keybindings | Where-Object { $_.id -eq "Terminal.CopyToClipboard" -and $_.keys -eq "ctrl+shift+c" }).Count -eq 1) "Windows Terminal keeps Ctrl+Shift+C copy"

$glazeNormalText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.glzr\glazewm\config.yaml") -Raw
$glazeWorkText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.glzr\glazewm\custom_work_config.yaml") -Raw
Assert-True ($glazeNormalText -match 'bindings:\s*\["lwin\+shift\+m",\s*"rwin\+shift\+m"\]') "Normal profile keeps Raw Accel on Super+Shift+M"
Assert-True ($glazeNormalText -notmatch 'bindings:\s*\["alt\+shift\+m",\s*"lwin\+shift\+m",\s*"rwin\+shift\+m"\]') "Normal profile does not capture Alt+Shift+M for Raw Accel"
Assert-True ($glazeNormalText -match 'bindings:\s*\["alt\+ctrl\+shift\+m"\]') "Normal scripts menu remains on Alt+Ctrl+Shift+M"
Assert-True ($glazeNormalText -match 'window_process:\s*\{ regex: "\^rawaccel') "Raw Accel launches floating and centered in Normal profile"
Assert-True ($glazeNormalText -match 'desktop-worker') "Normal profile starts the WGDot clipboard/lone-Super desktop worker"
Assert-True ($glazeWorkText -match 'desktop-worker') "Work profile starts the WGDot clipboard/lone-Super desktop worker"
Assert-True ($glazeNormalText -match 'bindings:\s*\["alt\+shift\+c"\]') "Normal profile keeps Awtarchy Alt+Shift+C SpeedCrunch"
Assert-True ($glazeNormalText -match 'bindings:\s*\["lwin\+shift\+c",\s*"rwin\+shift\+c"\]') "Normal profile keeps Awtarchy Super+Shift+C SpeedCrunch"
Assert-True ($glazeNormalText -match '(?ms)cursor_jump:\s*\r?\n\s+enabled:\s*true') "Normal profile enables cursor jump by default"
Assert-True ($glazeNormalText -notmatch '(?ms)- name: "1"\r?\n\s+display_name: "1: Flame"\r?\n\s+keep_alive:\s*true') "normal GlazeWM workspace 1 is not pinned alive"
Assert-True ($glazeNormalText -match '(?s)wgdot\.exe quick-launch''\]\s*\r?\n\s*bindings:\s*\["alt\+p",\s*"lwin\+d",\s*"rwin\+d"\]') "Normal profile keeps Alt+P and Super+D on YASB Quick Launch"
Assert-True ($glazeNormalText -notmatch 'wgdot\.exe flow-open') "Normal profile keeps Flow Launcher out of managed launcher bindings"
Assert-True ($glazeWorkText -match '(?s)wgdot\.exe flow-open''\]\s*\r?\n\s*bindings:\s*\["alt\+p"\]') "Work profile routes Alt+P to Flow Launcher"
Assert-True ($glazeWorkText -match '(?s)wgdot\.exe quick-launch''\]\s*\r?\n\s*bindings:\s*\["lwin\+d",\s*"rwin\+d"\]') "Work profile keeps Super+D on YASB Quick Launch"
Assert-True ($glazeWorkText -notmatch 'bindings:\s*\["alt\+p",\s*"lwin\+d",\s*"rwin\+d"\]') "Work profile no longer aliases Alt+P and Super+D to the same launcher"
foreach ($text in @($glazeNormalText, $glazeWorkText)) {
    $globalMarker = [Environment]::NewLine + "keybindings:" + [Environment]::NewLine
    $globalIndex = $text.LastIndexOf($globalMarker)
    $flameshotIndex = $text.LastIndexOf('bindings: ["lwin+shift+s", "rwin+shift+s"]')
    $bindingModesIndex = $text.IndexOf("binding_modes:")
    Assert-True ($globalIndex -ge 0) "GlazeWM has a global keybindings section"
    Assert-True ($flameshotIndex -gt $globalIndex) "Win+Shift+S Flameshot bind is global, not trapped inside a binding mode"
    Assert-True (-not (($bindingModesIndex -ge 0) -and ($flameshotIndex -gt $bindingModesIndex) -and ($flameshotIndex -lt $globalIndex))) "Flameshot bind is not trapped inside a binding mode"
    Assert-True ($text -notmatch 'win\+shift\+f') "old Win+Shift+F Flameshot bind is removed"
    Assert-True ($text -match 'wgdot\.exe quick-launch') "GlazeWM launcher aliases route through the WGDot YASB helper"
    Assert-True ($text -match 'bindings:\s*\["lwin\+v",\s*"rwin\+v"\]') "GlazeWM owns Super+V for the EarTrumpet mixer"
    Assert-True ($text -match 'bindings:\s*\["lwin\+c",\s*"rwin\+c"\]') "GlazeWM adds Super+C for WGDot Clipboard History"
    Assert-True ($text -match 'bindings:\s*\["lwin\+p",\s*"rwin\+p"\]') "Super+P opens the WGDot power menu"
    Assert-True ($text -match 'name:\s*"mouse"') "GlazeWM defines the Awtarchy-style mouse binding mode"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+m",\s*"rwin\+alt\+m"\]') "Super+Alt+M toggles the mouse binding mode"
    Assert-True ($text -match 'mouse-mode-disable') "active mouse mode retains an unconditional Super+Alt+M escape path"
    Assert-True ($text -match 'bindings:\s*\["lwin\+ctrl\+m",\s*"rwin\+ctrl\+m"\]') "Super+Ctrl+M opens Windows display settings"
    Assert-True ($text -match 'flameshot-gui') "Flameshot bindings route through the WGDot executable resolver"
    Assert-True ($text -match 'bindings:\s*\["alt\+ctrl\+shift\+r"\]') "Alt+Ctrl+Shift+R reloads GlazeWM"
    Assert-True ($text -match 'bindings:\s*\["alt\+ctrl\+b"\]') "Alt+Ctrl+B toggles coordinated YASB auto-hide and the GlazeWM top gap"
    Assert-True ($text -match 'bar-autohide-toggle') "bar visibility binding uses the coordinated WGDot auto-hide helper"
    Assert-True ($text -notmatch 'yasbc toggle-bar') "GlazeWM does not use the unsafe hard-hide YASB command"
    Assert-True ($text -match 'inner_gap:\s*"5px"') "GlazeWM uses the requested 5px inner gap"
    Assert-True ($text -match 'top:\s*"35px"') "GlazeWM reserves the requested 35px top gap"
    Assert-True ($text -match 'clipboard-history') "Super+C routes through the WGDot Clipboard History helper"
    Assert-True ($text -match 'color:\s*"#a1a1a1"') "GlazeWM focused border is theme-neutral"
    Assert-True (($text -split 'bindings:\s*\["lwin\+t",\s*"rwin\+t"\]').Count - 1 -ge 1) "Win+T theme picker exists globally"
    Assert-True ($text -match 'theme-toggle') "theme shortcut uses the single-instance WGDot selector"
    Assert-True ($text -match 'window_title:\s*\{ equals: "WGDot Themes" \}') "WGDot theme selector has a dedicated floating title rule"
    Assert-True ($text -notmatch 'wgdot theme.*wm-reload-config|wm-reload-config.*wgdot theme') "theme shortcut does not reload GlazeWM"
    Assert-True ($text -match 'name:\s*"noalt"') "GlazeWM noalt mode remains available with selective shell-hotkey filtering"
    Assert-True ($text -match 'glazewm-binding-mode-set noalt') "noalt mode transitions route through WGDot tracked state"
    Assert-True ($text -match 'commands:\s*\["wm-toggle-pause"\]') "GlazeWM uses its real pause command"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+p",\s*"rwin\+alt\+p"\]') "Alt+Super+P toggles real GlazeWM pause"
    Assert-True ($text -match 'name:\s*"vm"') "GlazeWM has a VM binding mode"
    Assert-True ($text -match 'glazewm-binding-mode-set vm') "VM mode transitions route through WGDot tracked state"
    Assert-True ($text -match 'glazewm-binding-mode-set normal') "binding modes have an explicit WGDot normal-mode escape"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+v",\s*"rwin\+alt\+v"\]') "Win+Alt+V toggles/switches VM mode"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+alt\+d",\s*"rwin\+alt\+d"\]') "GlazeWM leaves the private YASB bridge out of normal bindings"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+ctrl\+v",\s*"rwin\+alt\+ctrl\+v"\]') "VM mode retains host EarTrumpet on Win+Alt+Ctrl+V"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+s",\s*"rwin\+alt\+s"\]') "VM mode retains host Flameshot on Win+Alt+S"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+1",\s*"rwin\+alt\+1"\]') "VM mode keeps host workspace switching on Win+Alt+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+shift\+1",\s*"rwin\+alt\+shift\+1"\]') "VM mode keeps host move-to-workspace on Win+Alt+Shift+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+shift\+e",\s*"rwin\+shift\+e"\]') "Yazi uses both Windows keys for Win+Shift+E"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin",\s*"rwin"\]') "GlazeWM does not use ineffective bare-Super bindings; WGDot desktop worker owns lone-Super suppression"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+l",\s*"rwin\+l"') "reserved Windows Super+L is not advertised as a usable GlazeWM focus binding"
    Assert-True ($text -match 'bindings:\s*\["lwin\+right",\s*"rwin\+right"\]') "Super+Right remains the Windows-safe focus-right binding"
    Assert-True ($text -match 'bindings:\s*\["lwin\+1",\s*"rwin\+1"\]') "noalt/global Super+number workspace switching is present"
    Assert-True ($text -match 'bindings:\s*\["lwin\+shift\+1",\s*"rwin\+shift\+1"\]') "noalt/global Super+Shift+number move-to-workspace is present"
    Assert-True ($text -notmatch 'bindings:\s*\["alt\+shift\+e"\]') "Yazi no longer uses Alt+Shift+E"
    Assert-True ($text -notmatch '(?i)-ExecutionPolicy\s+Bypass') "GlazeWM managed configs do not bypass execution policy"
}

$temp = Join-Path $env:LOCALAPPDATA ("wgdot-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    $script:BaselineRoot = Join-Path $temp "baseline"
    $script:BaselineIndexPath = Join-Path $script:BaselineRoot "index.json"
    $script:BackupStatePath = Join-Path $temp "backups.json"
    New-Item -ItemType Directory -Path $script:BaselineRoot -Force | Out-Null

    $sourceRoot = Join-Path $temp "source"
    New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $sourceRoot "target.txt") -Value "release-two" -NoNewline
    $live = Join-Path $temp "live.txt"

    $fakeManifest = [pscustomobject]@{
        components = @([pscustomobject]@{
            id = "fake"
            name = "Fake"
            files = @([pscustomobject]@{
                id = "fake-file"
                source = "target.txt"
                destination = $live
                merge = $true
            })
        })
        migrations = @()
    }
    $installation = [pscustomobject]@{ components = @("fake"); glazewmProfile = "normal" }

    $plan = @(Get-WgdotPlan -Manifest $fakeManifest -SourceRoot $sourceRoot -Installation $installation -Mode update)
    Assert-Equal "NEW" $plan[0].Status "missing live file is NEW"
    Assert-Equal "APPLY" $plan[0].Action "NEW applies"

    Set-Content -LiteralPath $live -Value "local-old" -NoNewline
    $plan = @(Get-WgdotPlan -Manifest $fakeManifest -SourceRoot $sourceRoot -Installation $installation -Mode update)
    Assert-Equal "LEGACY" $plan[0].Status "unbaselined live file is LEGACY"
    Assert-Equal "PRESERVE" $plan[0].Action "LEGACY preserves during update"

    Set-Content -LiteralPath (Get-WgdotBaselinePath -FileId "fake-file") -Value "release-one" -NoNewline
    Set-Content -LiteralPath $live -Value "release-one" -NoNewline
    $plan = @(Get-WgdotPlan -Manifest $fakeManifest -SourceRoot $sourceRoot -Installation $installation -Mode update)
    Assert-Equal "UPSTREAM" $plan[0].Status "baseline live plus changed target is UPSTREAM"
    Assert-Equal "REPLACE" $plan[0].Action "UPSTREAM replaces"

    Set-Content -LiteralPath (Join-Path $sourceRoot "target.txt") -Value "release-one" -NoNewline
    Set-Content -LiteralPath $live -Value "user-edit" -NoNewline
    $plan = @(Get-WgdotPlan -Manifest $fakeManifest -SourceRoot $sourceRoot -Installation $installation -Mode update)
    Assert-Equal "USER" $plan[0].Status "local-only edit is USER"
    Assert-Equal "PRESERVE" $plan[0].Action "USER preserves"

    Set-Content -LiteralPath (Join-Path $sourceRoot "target.txt") -Value "release-two" -NoNewline
    $plan = @(Get-WgdotPlan -Manifest $fakeManifest -SourceRoot $sourceRoot -Installation $installation -Mode update)
    Assert-Equal "BOTH" $plan[0].Status "local and upstream edit is BOTH"
    Assert-Equal "MERGE" $plan[0].Action "merge-safe BOTH attempts merge"

    Assert-True (-not [bool]$plan[0].CommitTargetBaseline) "BOTH does not advance baseline before a merge succeeds"

    $oldIndex = [pscustomobject]@{ files = @([pscustomobject]@{ fileId = "fake-file"; component = "fake"; destination = $live; sha256 = (Get-WgdotSha256 -Path (Get-WgdotBaselinePath -FileId "fake-file")) }) }
    Write-WgdotJson -Path $script:BaselineIndexPath -Value $oldIndex
    $removedManifest = [pscustomobject]@{
        components = @([pscustomobject]@{ id = "fake"; name = "Fake"; files = @() })
        migrations = @()
    }
    $removedInstallation = [pscustomobject]@{ components = @("fake"); glazewmProfile = "normal" }
    $removedPlan = @(Get-WgdotPlan -Manifest $removedManifest -SourceRoot $sourceRoot -Installation $removedInstallation -Mode update)
    Assert-Equal "REMOVED-UPSTREAM" $removedPlan[0].Status "upstream removal is tracked for a still-selected component"
    Assert-Equal "PRESERVE" $removedPlan[0].Action "upstream removal preserves live file"
    Assert-True (-not [bool]$removedPlan[0].CommitTargetBaseline) "removed-upstream does not advance baseline"

    $deselectedInstallation = [pscustomobject]@{ components = @(); glazewmProfile = "normal" }
    $deselectedPlan = @(Get-WgdotPlan -Manifest $removedManifest -SourceRoot $sourceRoot -Installation $deselectedInstallation -Mode update)
    Assert-Equal 0 $deselectedPlan.Count "deselected components stop baseline ownership without deleting live files"

    $backup = New-WgdotBackup -Path $live -Operation "test"
    Assert-True (Test-Path -LiteralPath $backup -PathType Leaf) "backup was created"
    Assert-True ($backup -match '\.wgdot\.backup') "backup is WGDot-identifiable"

    $legacy = Join-Path $temp "clipboard.yazi"
    New-Item -ItemType Directory -Path (Join-Path $legacy ".git") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $legacy ".git\config") -Value '[remote "origin"]`nurl = https://github.com/XYenon/clipboard.yazi.git'
    $migration = [pscustomobject]@{ type = "git-remote-directory"; path = $legacy; expectedRemoteFragment = "XYenon/clipboard.yazi" }
    Assert-True (Test-WgdotLegacyMigrationMatch -Migration $migration) "known Yazi plugin remote matches"

    Set-Content -LiteralPath (Join-Path $legacy ".git\config") -Value '[remote "origin"]`nurl = https://example.invalid/custom.git'
    Assert-True (-not (Test-WgdotLegacyMigrationMatch -Migration $migration)) "custom same-name Yazi plugin is not treated as managed legacy"

    $knownLegacy = Join-Path $temp "known-clipboard.yazi"
    New-Item -ItemType Directory -Path (Join-Path $knownLegacy ".git") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $knownLegacy ".git\config") -Value '[remote "origin"]`nurl = https://github.com/XYenon/clipboard.yazi.git'
    $migrationManifest = [pscustomobject]@{
        components = @()
        migrations = @([pscustomobject]@{
            id = "remove-test-legacy"
            component = "yazi"
            path = $knownLegacy
            type = "git-remote-directory"
            expectedRemoteFragment = "XYenon/clipboard.yazi"
        })
    }
    $migrationInstallation = [pscustomobject]@{ components = @("yazi"); glazewmProfile = "normal" }
    Invoke-WgdotMigrations -Manifest $migrationManifest -Installation $migrationInstallation
    Assert-True (-not (Test-Path -LiteralPath $knownLegacy)) "known legacy migration removes the positively identified directory"
    $migrationState = Read-WgdotJson -Path $script:BackupStatePath
    $migrationBackup = @($migrationState.records | Where-Object { $_.operation -eq "migration" -and $_.original -eq $knownLegacy } | Select-Object -Last 1)
    Assert-True ($migrationBackup.Count -eq 1) "legacy directory migration records one backup"
    Assert-True (Test-Path -LiteralPath ([string]$migrationBackup[0].backup) -PathType Container) "legacy directory migration creates an adjacent directory backup"

    $script:ConfigStatePath = Join-Path $temp "config.json"
    $reviewResult = Invoke-WgdotPlan -Plan @($plan) -Manifest $fakeManifest -Installation $installation -SourceMode stable -Tag "v9.9.9" -Revision ("a" * 40) -ReviewOnly
    Assert-True (-not [bool]$reviewResult) "review reports no apply"
    Assert-True (-not (Test-Path -LiteralPath $script:ConfigStatePath)) "review does not write config state"
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "WGDot tests passed." -ForegroundColor Green
 "Flow Launcher fallback accepts only the official setup asset"
Assert-Equal ([int]$flowPackage.wingetInstallTimeoutSeconds) 180 "Flow Launcher WinGet attempt times out before indefinite stalls"
Assert-True ($nativeSourceText -notmatch '(?i)sudo(?:\.exe)?\s+winget') "software batching does not depend on Windows sudo"
Assert-True ($nativeSourceText -notmatch '(?i)winget(?:\.exe)?\s+upgrade\s+--all') "native runtime never upgrades all WinGet packages"
Assert-True ($nativeSourceText -match '\.wgdot\.backup') "native runtime uses identifiable adjacent backup names"
Assert-True ($nativeSourceText -match 'REMOVED-UPSTREAM') "native runtime preserves upstream-removal planning"
Assert-True ($nativeSourceText -match 'merge-file') "native runtime includes three-way merge support"
Assert-True ($nativeSourceText -match 'BackupManager') "native runtime includes backup manager"
Assert-True ($nativeSourceText -match 'releases/latest') "native runtime resolves published stable releases"
Assert-True ($nativeSourceText -match 'TryRefreshRuntimeAndRun\(args, out refreshedExitCode\)') "normal WGDot commands check for runtime refresh before dispatch"
Assert-True ($nativeSourceText -match 'ShouldAutoRefreshRuntime') "runtime refresh policy is centralized"
Assert-True ($nativeSourceText -match 'BuildCommandLine\(originalArgs\)') "refreshed runtime preserves the requested WGDot command"
Assert-True ($nativeSourceText -match 'wgdot-next-') "native runtime stages a replacement executable safely"
Assert-True ($nativeSourceText -match 'ScheduleStagedRuntimeInstall') "staged runtime installs itself after the requested operation exits"
Assert-True ($nativeSourceText -match 'CreateRuntimeSwapHelper') "native runtime defers replacing the running executable"
Assert-True ($nativeSourceText -match '"mark-runtime"') "runtime revision is recorded by the successfully swapped executable"
Assert-True ($nativeSourceText -match 'WGDOT_SKIP_RUNTIME_REFRESH') "staged runtime avoids recursive refresh while running the requested operation"
Assert-True ($nativeSourceText -match '"maintenance-self-test"') "native runtime exposes isolated maintenance self-test"
Assert-True ($nativeSourceText -match 'WGDOT_TEST_ROOT') "native maintenance self-test redirects state away from normal WGDot state"
Assert-True ($nativeSourceText -match 'TweakManager') "native runtime includes Windows tweak manager"
Assert-True ($nativeSourceText -match 'ApplyMicroTextDefaults') "native runtime manages Micro text associations"
Assert-True ($nativeSourceText -match 'ReadPackageChoicesByCategory') "software selector is grouped by category"
Assert-True ($nativeSourceText -match 'PackageCategoryLabel') "software selector has friendly category labels"
Assert-True ($nativeSourceText -match 'E: extensions/options') "Browser category advertises E for nested browser options"
Assert-True ($nativeSourceText -match 'IsBrowserOptionsKey\(ConsoleKey\.E\)') "E opens browser-specific options"
Assert-True ($nativeSourceText -match 'ReadBrowserOptionChoices') "browser-specific options use a nested keyboard checklist"
Assert-True ($nativeSourceText -match 'if \(edited == null\) edited = choices;') "Q/Esc back preserves browser-option checkbox changes"
Assert-True ($nativeSourceText -match 'default-OFF Firefox options such as Dark Reader') "nested Firefox option persistence regression is documented in code"
Assert-True ($nativeSourceText -match 'BrowserOptionsConfigured') "browser selection migration state is explicit"
Assert-True ($nativeSourceText -match 'Software\\Policies\\Mozilla\\Firefox\\Extensions\\Install') "Firefox uses Mozilla Extensions.Install Windows policy"
Assert-True ($nativeSourceText -match 'Profiles/wgdot\.betterfox') "Betterfox uses a dedicated WGDot Firefox profile"
Assert-True ($nativeSourceText -match 'Make the WGDot Betterfox profile the Firefox default\? \[y/N\]') "Betterfox default-profile change requires explicit review"
Assert-True ($nativeSourceText -match 'Firefox default profile changed outside WGDot') "Betterfox rollback preserves newer user default-profile changes"
Assert-True ($nativeSourceText -match 'manual Add to Brave approval') "Brave Chrome Web Store setup requires browser/user approval"
Assert-True ($nativeSourceText -match 'brave://settings/extensions/v2') "Brave full uBlock Origin uses Brave's supported Manifest V2 settings page"
Assert-True ($nativeSourceText -match 'braveGuidedReviewedOptions') "Brave guided extension pages are remembered instead of reopening every reconcile"
Assert-True ($nativeSourceText -match 'Close Firefox before WGDot creates the dedicated Betterfox profile') "Betterfox profile metadata is not rewritten while Firefox is running"
Assert-True ($nativeSourceText -match 'defaultProfileReviewed') "Betterfox remembers a reviewed default-profile choice"
Assert-True ($nativeSourceText -match 'Browser selection persistence self-test failed') "native self-test covers persisted browser selections"
Assert-True ($nativeSourceText -match 'Firefox default-profile rollback self-test failed') "native self-test isolates Betterfox default-profile rollback"
Assert-True ($nativeSourceText -match 'key == ConsoleKey\.Escape \|\| key == ConsoleKey\.Q') "Q and Escape share the global back-key behavior"
Assert-True ($nativeSourceText -match 'Q/Esc: back') "keyboard UI advertises Q and Escape as back keys"
Assert-True ($nativeSourceText -match 'launch-open-shell') "native runtime starts Open-Shell after installation"
Assert-True ($nativeSourceText -match 'ApplyFlowLauncherAltP') "native runtime manages Flow Launcher Alt+P"
Assert-True ($nativeSourceText -match 'command == "quick-launch"') "native runtime exposes the YASB Quick Launch bridge"
Assert-True ($nativeSourceText -match '(?s)static int OpenYasbQuickLaunch\(\).*?PostThreadMessage.*?new UIntPtr\(1\)') "YASB Quick Launch dispatches directly to hotkey ID 1 without synthetic keys"
Assert-True ($nativeSourceText -match 'OpenFlowLauncher') "native runtime retains the optional Flow Launcher helper"
Assert-True ($nativeSourceText -match 'command == "flow-open"') "optional Flow Launcher alias command remains dispatchable"
Assert-True ($nativeSourceText -match 'ApplyEarTrumpetMixerAltV') "native runtime manages EarTrumpet Alt+V"
Assert-True ($nativeSourceText -match 'OpenEarTrumpetMixer') "native runtime exposes the EarTrumpet bar helper"
Assert-True ($nativeSourceText -match 'keybd_event\(VkMenu') "EarTrumpet helper triggers the configured Alt+V mixer hotkey"
Assert-True ($nativeSourceText -match 'ApplicationDataManager\.CreateForPackageFamily') "EarTrumpet AppX settings use Windows packaged LocalSettings"
Assert-True ($nativeSourceText -match '40459File-New-Project\.EarTrumpet_725pr5jq8wr8a') "EarTrumpet package family is explicit"
Assert-True ($nativeSourceText -match 'ApplyClassicContextMenu') "native runtime manages classic context menu"
Assert-True ($nativeSourceText -match 'DeleteRegistryKeyIfOriginallyAbsentAndEmpty') "native tweak rollback prunes only WGDot-created empty registry keys"
Assert-True ($nativeSourceText -notmatch 'DeleteSubKeyTree\(clsid') "classic context-menu rollback does not delete unknown pre-WGDot CLSID state"
Assert-True ($nativeSourceText -match 'base64-bytes') "registry rollback preserves binary and REG_NONE values losslessly"
Assert-True ($nativeSourceText -match 'RegistryKeyWasAbsentInSnapshot') "registry rollback tracks pre-WGDot key existence"
Assert-True ($nativeSourceText -match 'ApplyOopsCursor') "native runtime manages optional cursor install"
Assert-True ($nativeSourceText -match 'undergroundwires/privacy\.sexy/releases/latest') "privacy.sexy uses official latest GitHub release"
Assert-True ($nativeSourceText -match 'GAC_MSIL') "EarTrumpet helper can find framework facades on normal Windows without developer reference assemblies"
Assert-True ($nativeSourceText -match 'System\.Runtime\.WindowsRuntime') "EarTrumpet helper includes Windows Runtime interop fallback"
Assert-True ($nativeSourceText -match 'SetupDiGetClassDevs') "native runtime detects present display adapters through SetupAPI"
Assert-True ($nativeSourceText -match 'VEN_1002') "GPU detection recognizes AMD PCI vendor IDs"
Assert-True ($nativeSourceText -match 'VEN_10DE') "GPU detection recognizes NVIDIA PCI vendor IDs"
Assert-True ($nativeSourceText -match 'VEN_8086') "GPU detection recognizes Intel PCI vendor IDs"
Assert-True ($nativeSourceText -match 'Wagnardsoft\.DisplayDriverUninstaller') "GPU maintenance uses the exact DDU WinGet package"
Assert-True ($nativeSourceText -match '\*WGDotGpuSafeModeResume') "DDU workflow registers a Safe Mode-capable RunOnce handoff"
Assert-True ($nativeSourceText -match '/set \{current\} safeboot minimal') "DDU workflow explicitly stages Safe Mode"
Assert-True ($nativeSourceText -match '/deletevalue \{current\} safeboot') "DDU workflow removes forced Safe Mode before launching DDU"
Assert-True ($nativeSourceText -match 'drivers\.amd\.com') "AMD installer resolver is restricted to the official AMD driver host"
Assert-True ($nativeSourceText -match 'us\.download\.nvidia\.com') "NVIDIA installer resolver is restricted to NVIDIA's official download host"
Assert-True ($nativeSourceText -match 'dsadata\.intel\.com') "Intel installer uses Intel's official Driver & Support Assistant endpoint"
Assert-True ($nativeSourceText -match 'GPU DRIVER ACTION REQUIRED') "pending GPU cleanup is surfaced on the next WGDot run"
Assert-True ($nativeSourceText -match 'Review only\. No files, backups, baselines, or selection state were changed\.') "native Git review is explicitly non-mutating"
Assert-True ($nativeSourceText -match 'HKCU\\\\Environment|OpenSubKey\("Environment"|CreateSubKey\("Environment"') "native installer persists user PATH"
Assert-True ($nativeBootstrapText -notmatch '(?i)powershell(?:\.exe)?') "native bootstrap does not invoke PowerShell"
Assert-True ($nativeBootstrapText -match 'raw\.githubusercontent\.com/dillacorn/win-glaze-dots') "native bootstrap can acquire source from GitHub"
Assert-True ($nativeBootstrapText -match '(?i)--revision') "native bootstrap supports exact revision testing"
Assert-True ($nativeBootstrapText -match '(?i)--ref') "native bootstrap supports explicit ref testing"
Assert-True ($nativeBootstrapText -match 'WGDOT_SOURCE_EXPLICIT') "native bootstrap records explicit ref-testing intent"
Assert-True ($nativeSourceText -match 'sourceExplicit') "native runtime preserves explicit ref-testing state"
Assert-True ($nativeSourceText -match 'explicitRefTesting') "native runtime can use explicit main as the maintainer config source"
Assert-True ($nativeBootstrapText -match '(?i)curl\.exe') "native bootstrap has a location-independent download path"
Assert-True ($runtimeText -notmatch '(?i)winget\s+upgrade\s+--all') "runtime never upgrades all WinGet packages"
Assert-True ($manualText -notmatch '(?i)winget\s+upgrade\s+--all') "manual path never upgrades all WinGet packages"
Assert-True ($runtimeText -notmatch '(?i)rmdir\s+/s') "runtime does not use destructive CMD directory removal"

$glazeNormalText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.glzr\glazewm\config.yaml") -Raw
$glazeWorkText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.glzr\glazewm\custom_work_config.yaml") -Raw
foreach ($text in @($glazeNormalText, $glazeWorkText)) {
    $globalMarker = [Environment]::NewLine + "keybindings:" + [Environment]::NewLine
    $globalIndex = $text.LastIndexOf($globalMarker)
    $flameshotIndex = $text.LastIndexOf('bindings: ["lwin+shift+s", "rwin+shift+s"]')
    $bindingModesIndex = $text.IndexOf("binding_modes:")
    Assert-True ($globalIndex -ge 0) "GlazeWM has a global keybindings section"
    Assert-True ($flameshotIndex -gt $globalIndex) "Win+Shift+S Flameshot bind is global, not trapped inside a binding mode"
    Assert-True (-not (($bindingModesIndex -ge 0) -and ($flameshotIndex -gt $bindingModesIndex) -and ($flameshotIndex -lt $globalIndex))) "Flameshot bind is not trapped inside a binding mode"
    Assert-True ($text -notmatch 'win\+shift\+f') "old Win+Shift+F Flameshot bind is removed"
    Assert-True ($text -match 'wgdot\.exe quick-launch') "GlazeWM launcher aliases route through the WGDot YASB helper"
    Assert-True ($text -match 'bindings:\s*\["lwin\+v",\s*"rwin\+v"\]') "GlazeWM owns Super+V for the EarTrumpet mixer"
    Assert-True ($text -match 'bindings:\s*\["lwin\+c",\s*"rwin\+c"\]') "Super+C opens WGDot Clipboard History"
    Assert-True ($text -notmatch 'shell-exec --hide-window "%LOCALAPPDATA%\\wgdot\\bin\\wgdot\.exe"') "WGDot GlazeWM helper paths avoid parser-breaking executable quotes"
    Assert-True ($text -match 'name:\s*"noalt"') "GlazeWM noalt mode is restored"
    Assert-True ($text -match 'glazewm-binding-mode-set noalt') "noalt mode transitions route through WGDot tracked state"
    Assert-True ($text -match 'commands:\s*\["wm-toggle-pause"\]') "GlazeWM real pause command is present"
    Assert-True ($text -match 'name:\s*"vm"') "GlazeWM has a VM binding mode"
    Assert-True ($text -match 'glazewm-binding-mode-set vm') "VM mode transitions route through WGDot tracked state"
    Assert-True ($text -match 'glazewm-binding-mode-set normal') "binding modes have an explicit WGDot normal-mode escape"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+v",\s*"rwin\+alt\+v"\]') "Win+Alt+V toggles/switches VM mode"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+alt\+d",\s*"rwin\+alt\+d"\]') "GlazeWM leaves the private YASB bridge out of normal bindings"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+ctrl\+v",\s*"rwin\+alt\+ctrl\+v"\]') "VM mode retains host EarTrumpet on Win+Alt+Ctrl+V"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+s",\s*"rwin\+alt\+s"\]') "VM mode retains host Flameshot on Win+Alt+S"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+1",\s*"rwin\+alt\+1"\]') "VM mode keeps host workspace switching on Win+Alt+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+shift\+1",\s*"rwin\+alt\+shift\+1"\]') "VM mode keeps host move-to-workspace on Win+Alt+Shift+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+shift\+e",\s*"rwin\+shift\+e"\]') "Yazi uses both Windows keys for Win+Shift+E"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin",\s*"rwin"\]') "GlazeWM does not use ineffective bare-Super bindings; WGDot desktop worker owns lone-Super suppression"
    Assert-True ($text -match 'bindings:\s*\["lwin\+1",\s*"rwin\+1"\]') "noalt/global Super+number workspace switching is present"
    Assert-True ($text -match 'bindings:\s*\["lwin\+shift\+1",\s*"rwin\+shift\+1"\]') "noalt/global Super+Shift+number move-to-workspace is present"
    Assert-True ($text -notmatch 'bindings:\s*\["alt\+shift\+e"\]') "Yazi no longer uses Alt+Shift+E"
    Assert-True ($text -notmatch '(?i)-ExecutionPolicy\s+Bypass') "GlazeWM managed configs do not bypass execution policy"
}

$temp = Join-Path $env:LOCALAPPDATA ("wgdot-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    $script:BaselineRoot = Join-Path $temp "baseline"
    $script:BaselineIndexPath = Join-Path $script:BaselineRoot "index.json"
    $script:BackupStatePath = Join-Path $temp "backups.json"
    New-Item -ItemType Directory -Path $script:BaselineRoot -Force | Out-Null

    $sourceRoot = Join-Path $temp "source"
    New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $sourceRoot "target.txt") -Value "release-two" -NoNewline
    $live = Join-Path $temp "live.txt"

    $fakeManifest = [pscustomobject]@{
        components = @([pscustomobject]@{
            id = "fake"
            name = "Fake"
            files = @([pscustomobject]@{
                id = "fake-file"
                source = "target.txt"
                destination = $live
                merge = $true
            })
        })
        migrations = @()
    }
    $installation = [pscustomobject]@{ components = @("fake"); glazewmProfile = "normal" }

    $plan = @(Get-WgdotPlan -Manifest $fakeManifest -SourceRoot $sourceRoot -Installation $installation -Mode update)
    Assert-Equal "NEW" $plan[0].Status "missing live file is NEW"
    Assert-Equal "APPLY" $plan[0].Action "NEW applies"

    Set-Content -LiteralPath $live -Value "local-old" -NoNewline
    $plan = @(Get-WgdotPlan -Manifest $fakeManifest -SourceRoot $sourceRoot -Installation $installation -Mode update)
    Assert-Equal "LEGACY" $plan[0].Status "unbaselined live file is LEGACY"
    Assert-Equal "PRESERVE" $plan[0].Action "LEGACY preserves during update"

    Set-Content -LiteralPath (Get-WgdotBaselinePath -FileId "fake-file") -Value "release-one" -NoNewline
    Set-Content -LiteralPath $live -Value "release-one" -NoNewline
    $plan = @(Get-WgdotPlan -Manifest $fakeManifest -SourceRoot $sourceRoot -Installation $installation -Mode update)
    Assert-Equal "UPSTREAM" $plan[0].Status "baseline live plus changed target is UPSTREAM"
    Assert-Equal "REPLACE" $plan[0].Action "UPSTREAM replaces"

    Set-Content -LiteralPath (Join-Path $sourceRoot "target.txt") -Value "release-one" -NoNewline
    Set-Content -LiteralPath $live -Value "user-edit" -NoNewline
    $plan = @(Get-WgdotPlan -Manifest $fakeManifest -SourceRoot $sourceRoot -Installation $installation -Mode update)
    Assert-Equal "USER" $plan[0].Status "local-only edit is USER"
    Assert-Equal "PRESERVE" $plan[0].Action "USER preserves"

    Set-Content -LiteralPath (Join-Path $sourceRoot "target.txt") -Value "release-two" -NoNewline
    $plan = @(Get-WgdotPlan -Manifest $fakeManifest -SourceRoot $sourceRoot -Installation $installation -Mode update)
    Assert-Equal "BOTH" $plan[0].Status "local and upstream edit is BOTH"
    Assert-Equal "MERGE" $plan[0].Action "merge-safe BOTH attempts merge"

    Assert-True (-not [bool]$plan[0].CommitTargetBaseline) "BOTH does not advance baseline before a merge succeeds"

    $oldIndex = [pscustomobject]@{ files = @([pscustomobject]@{ fileId = "fake-file"; component = "fake"; destination = $live; sha256 = (Get-WgdotSha256 -Path (Get-WgdotBaselinePath -FileId "fake-file")) }) }
    Write-WgdotJson -Path $script:BaselineIndexPath -Value $oldIndex
    $removedManifest = [pscustomobject]@{
        components = @([pscustomobject]@{ id = "fake"; name = "Fake"; files = @() })
        migrations = @()
    }
    $removedInstallation = [pscustomobject]@{ components = @("fake"); glazewmProfile = "normal" }
    $removedPlan = @(Get-WgdotPlan -Manifest $removedManifest -SourceRoot $sourceRoot -Installation $removedInstallation -Mode update)
    Assert-Equal "REMOVED-UPSTREAM" $removedPlan[0].Status "upstream removal is tracked for a still-selected component"
    Assert-Equal "PRESERVE" $removedPlan[0].Action "upstream removal preserves live file"
    Assert-True (-not [bool]$removedPlan[0].CommitTargetBaseline) "removed-upstream does not advance baseline"

    $deselectedInstallation = [pscustomobject]@{ components = @(); glazewmProfile = "normal" }
    $deselectedPlan = @(Get-WgdotPlan -Manifest $removedManifest -SourceRoot $sourceRoot -Installation $deselectedInstallation -Mode update)
    Assert-Equal 0 $deselectedPlan.Count "deselected components stop baseline ownership without deleting live files"

    $backup = New-WgdotBackup -Path $live -Operation "test"
    Assert-True (Test-Path -LiteralPath $backup -PathType Leaf) "backup was created"
    Assert-True ($backup -match '\.wgdot\.backup') "backup is WGDot-identifiable"

    $legacy = Join-Path $temp "clipboard.yazi"
    New-Item -ItemType Directory -Path (Join-Path $legacy ".git") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $legacy ".git\config") -Value '[remote "origin"]`nurl = https://github.com/XYenon/clipboard.yazi.git'
    $migration = [pscustomobject]@{ type = "git-remote-directory"; path = $legacy; expectedRemoteFragment = "XYenon/clipboard.yazi" }
    Assert-True (Test-WgdotLegacyMigrationMatch -Migration $migration) "known Yazi plugin remote matches"

    Set-Content -LiteralPath (Join-Path $legacy ".git\config") -Value '[remote "origin"]`nurl = https://example.invalid/custom.git'
    Assert-True (-not (Test-WgdotLegacyMigrationMatch -Migration $migration)) "custom same-name Yazi plugin is not treated as managed legacy"

    $knownLegacy = Join-Path $temp "known-clipboard.yazi"
    New-Item -ItemType Directory -Path (Join-Path $knownLegacy ".git") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $knownLegacy ".git\config") -Value '[remote "origin"]`nurl = https://github.com/XYenon/clipboard.yazi.git'
    $migrationManifest = [pscustomobject]@{
        components = @()
        migrations = @([pscustomobject]@{
            id = "remove-test-legacy"
            component = "yazi"
            path = $knownLegacy
            type = "git-remote-directory"
            expectedRemoteFragment = "XYenon/clipboard.yazi"
        })
    }
    $migrationInstallation = [pscustomobject]@{ components = @("yazi"); glazewmProfile = "normal" }
    Invoke-WgdotMigrations -Manifest $migrationManifest -Installation $migrationInstallation
    Assert-True (-not (Test-Path -LiteralPath $knownLegacy)) "known legacy migration removes the positively identified directory"
    $migrationState = Read-WgdotJson -Path $script:BackupStatePath
    $migrationBackup = @($migrationState.records | Where-Object { $_.operation -eq "migration" -and $_.original -eq $knownLegacy } | Select-Object -Last 1)
    Assert-True ($migrationBackup.Count -eq 1) "legacy directory migration records one backup"
    Assert-True (Test-Path -LiteralPath ([string]$migrationBackup[0].backup) -PathType Container) "legacy directory migration creates an adjacent directory backup"

    $script:ConfigStatePath = Join-Path $temp "config.json"
    $reviewResult = Invoke-WgdotPlan -Plan @($plan) -Manifest $fakeManifest -Installation $installation -SourceMode stable -Tag "v9.9.9" -Revision ("a" * 40) -ReviewOnly
    Assert-True (-not [bool]$reviewResult) "review reports no apply"
    Assert-True (-not (Test-Path -LiteralPath $script:ConfigStatePath)) "review does not write config state"
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "WGDot tests passed." -ForegroundColor Green

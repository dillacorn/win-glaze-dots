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
Assert-True (Test-Path -LiteralPath $nativeSourcePath -PathType Leaf) "native bootstrap source exists"

$env:WGDOT_TEST_MODE = "1"
. $runtimePath

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-Equal 1 ([int]$manifest.schemaVersion) "manifest schema"
Assert-Equal "dillacorn/win-glaze-dots" ([string]$manifest.runtime.repository) "repository identity"

$componentIds = @($manifest.components | ForEach-Object { [string]$_.id })
Assert-True ($componentIds -contains "glazewm") "GlazeWM component exists"
Assert-True ($componentIds -contains "yazi") "Yazi component exists"

$glaze = $manifest.components | Where-Object { $_.id -eq "glazewm" } | Select-Object -First 1
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
Assert-True (-not $packageIds.ContainsKey("discord.discord")) "Discord is not offered; Vesktop is the Discord-family option"
Assert-True (-not $packageIds.ContainsKey("openwhispersystems.signal")) "Signal is not offered by WGDot"
Assert-True (-not $packageIds.ContainsKey("bitwarden.bitwarden")) "Bitwarden is not offered by WGDot"
Assert-True (-not $packageIds.ContainsKey("betaflight.betaflight-configurator")) "Betaflight Configurator is not offered by WGDot"
Assert-True (-not $packageIds.ContainsKey("trackersoftware.pdf-xchangeeditor")) "PDF-XChange Editor is not offered by WGDot"

function Get-ManifestPackage {
    param([string]$Id)
    return $manifest.packages | Where-Object { [string]$_.id -eq $Id } | Select-Object -First 1
}

$expectedDefaultOnPackages = @(
    "Git.Git",
    "Microsoft.WindowsTerminal",
    "AltSnap.AltSnap",
    "Microsoft.VCRedist.2015+.x64",
    "AmN.yasb",
    "Flameshot.Flameshot",
    "Flow-Launcher.Flow-Launcher",
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
Assert-Equal 10 $firefoxOptionIds.Count "Firefox exposes only the researched WGDot option set"
$betterfox = $firefoxBrowser.options | Where-Object { [string]$_.id -eq "betterfox" } | Select-Object -First 1
Assert-Equal "https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js" ([string]$betterfox.sourceUrl) "Betterfox uses official upstream user.js"
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
    "clean-taskbar-items",
    "disable-printscreen-snipping",
    "disable-enhanced-pointer-precision",
    "communications-do-nothing",
    "disable-snap-assist",
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
    "reduce-visual-effects"
)) {
    $t = $manifest.tweaks | Where-Object { $_.id -eq $id } | Select-Object -First 1
    Assert-True (-not [bool]$t.defaultNormal) "$id defaults off"
}


foreach ($id in @("flow-launcher-alt-p", "eartrumpet-mixer-alt-v")) {
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
Assert-True ($nativeBootstrapText -notmatch '(?i)Set-ExecutionPolicy|-ExecutionPolicy\s+(Bypass|Unrestricted)') "native bootstrap does not change or bypass execution policy"
Assert-True ($nativeSourceText -notmatch '(?i)Set-ExecutionPolicy|-ExecutionPolicy\s+(Bypass|Unrestricted)') "native bootstrap source does not change or bypass execution policy"
Assert-True ($nativeSourceText -match 'WmSettingChange') "native installer broadcasts environment changes"
Assert-True ($nativeSourceText -match '"git-review"') "native runtime exposes Git review command"
Assert-True ($nativeSourceText -match 'Select remote branch') "native Git UI exposes selectable remote branches"
Assert-True ($nativeSourceText -match 'Use selected branch head') "native Git UI defaults to branch head without commit typing"
Assert-True ($nativeSourceText -match 'ReadMultiChoice') "native runtime contains keyboard multi-select UI"
Assert-True ($nativeSourceText -match 'SoftwareReconcile') "native runtime includes software reconciliation"
Assert-True ($nativeSourceText -match 'Install/reconcile this software selection\? \[y/N\]') "software mutation requires confirmation"
Assert-True ($nativeSourceText -match 'if \(command == "software-elevated"\) return SoftwareElevatedFromArgs') "native runtime exposes the internal elevated software worker command"
Assert-True ($nativeSourceText -match 'RunElevatedSelfWithExitCode\("software-elevated --plan "') "software reconciliation elevates one WGDot worker rather than each package"
Assert-True ([regex]::Matches($nativeSourceText, 'RunElevatedSelfWithExitCode\("software-elevated --plan "').Count -eq 1) "software reconciliation contains one batch elevation handoff"
Assert-True ($nativeSourceText -match 'WGDot will request administrator approval once for this software batch') "software UI explains the single elevation request"
Assert-True ($nativeSourceText -match 'Elevated software plans must stay inside the WGDot state directory') "elevated software plan path is constrained to WGDot state"
Assert-True ($nativeSourceText -match 'sourceRevision') "elevated software worker checks the selected source revision"
Assert-True ($nativeSourceText -match 'TweakNeedsAdministrator') "software batching separates administrator-only tweaks from normal user-level tweaks"
Assert-True ($nativeSourceText -match 'const string Version = "native-preview-27"') "native runtime version tracks WinGet hang protection"
Assert-True ($nativeSourceText -match 'WingetPreflightTimeoutMs = 30000') "WinGet preflight has a finite timeout"
Assert-True ($nativeSourceText -match 'Reading installed WinGet package state') "software reconciliation snapshots installed packages once before per-package network validation"
Assert-True ($nativeSourceText -match 'RunWithTimeout') "native process runner supports bounded preflight calls"
Assert-True ($nativeSourceText -match 'BeginOutputReadLine') "captured stdout is drained asynchronously"
Assert-True ($nativeSourceText -match 'BeginErrorReadLine') "captured stderr is drained asynchronously"
Assert-True ($nativeSourceText -match 'Process timeout self-test failed') "native self-test exercises timeout handling"
Assert-True ($nativeSourceText -match '--disable-interactivity') "WinGet reconciliation suppresses WinGet CLI prompts"
Assert-True ($nativeSourceText -match 'const string Version = "native-preview-28"') "native runtime version tracks WinGet install fallback"
Assert-True ($nativeSourceText -match 'RunInteractiveWithTimeout') "actual WinGet install phase is bounded"
Assert-True ($nativeSourceText -match 'taskkill\.exe') "timed-out WinGet install attempts terminate the stuck process tree"
Assert-True ($nativeSourceText -match 'trying the approved official GitHub fallback') "WinGet install timeout/failure can fall back to an approved official GitHub release"
Assert-True ($nativeSourceText -match 'GetWingetInstallTimeoutMs') "package-specific WinGet install timeout is manifest-driven"
$flowPackage = @($manifest.packages | Where-Object { $_.id -eq 'Flow-Launcher.Flow-Launcher' })[0]
Assert-True ($null -ne $flowPackage) "Flow Launcher package exists"
Assert-Equal ([string]$flowPackage.fallbackGitHubRepo) 'Flow-Launcher/Flow.Launcher' "Flow Launcher fallback is restricted to the official upstream repository"
Assert-Equal ([string]$flowPackage.fallbackAssetRegex) '^Flow-Launcher-Setup\.exe
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
Assert-True ($nativeSourceText -match 'OpenFlowLauncher') "native runtime exposes the Flow Launcher Win+D alias target"
Assert-True ($nativeSourceText -match 'command == "flow-open"') "Flow Launcher alias command is dispatchable"
Assert-True ($nativeSourceText -match 'ApplyEarTrumpetMixerAltV') "native runtime manages EarTrumpet Alt+V"
Assert-True ($nativeSourceText -match 'OpenEarTrumpetMixer') "native runtime exposes the EarTrumpet Win+V alias target"
Assert-True ($nativeSourceText -match 'keybd_event\(VkMenu') "EarTrumpet Win+V alias triggers the existing Alt+V mixer hotkey"
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
    Assert-True ($text -match 'bindings:\s*\["lwin\+d",\s*"rwin\+d"\]') "Flow Launcher has Win+D aliases"
    Assert-True ($text -match 'bindings:\s*\["lwin\+v",\s*"rwin\+v"\]') "EarTrumpet has Win+V aliases"
    Assert-True ($text -match 'name:\s*"noalt"') "GlazeWM has a noalt binding mode"
    Assert-True ($text -match 'wm-enable-binding-mode --name noalt') "noalt mode can be enabled"
    Assert-True ($text -match 'wm-disable-binding-mode --name noalt') "noalt mode can be disabled"
    Assert-True ($text -match 'name:\s*"vm"') "GlazeWM has a VM binding mode"
    Assert-True ($text -match 'wm-enable-binding-mode --name vm') "VM mode can be entered from global/noalt bindings"
    Assert-True ($text -match 'wm-disable-binding-mode --name vm') "VM mode can be exited"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+v",\s*"rwin\+alt\+v"\]') "Win+Alt+V toggles/switches VM mode"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+p",\s*"rwin\+alt\+p"\]') "VM mode retains host Flow Launcher on Win+Alt+P"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+ctrl\+v",\s*"rwin\+alt\+ctrl\+v"\]') "VM mode retains host EarTrumpet on Win+Alt+Ctrl+V"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+s",\s*"rwin\+alt\+s"\]') "VM mode retains host Flameshot on Win+Alt+S"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+1",\s*"rwin\+alt\+1"\]') "VM mode keeps host workspace switching on Win+Alt+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+shift\+1",\s*"rwin\+alt\+shift\+1"\]') "VM mode keeps host move-to-workspace on Win+Alt+Shift+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+shift\+e",\s*"rwin\+shift\+e"\]') "Yazi uses both Windows keys for Win+Shift+E"
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
Assert-True ($nativeSourceText -match 'OpenFlowLauncher') "native runtime exposes the Flow Launcher Win+D alias target"
Assert-True ($nativeSourceText -match 'command == "flow-open"') "Flow Launcher alias command is dispatchable"
Assert-True ($nativeSourceText -match 'ApplyEarTrumpetMixerAltV') "native runtime manages EarTrumpet Alt+V"
Assert-True ($nativeSourceText -match 'OpenEarTrumpetMixer') "native runtime exposes the EarTrumpet Win+V alias target"
Assert-True ($nativeSourceText -match 'keybd_event\(VkMenu') "EarTrumpet Win+V alias triggers the existing Alt+V mixer hotkey"
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
    Assert-True ($text -match 'bindings:\s*\["lwin\+d",\s*"rwin\+d"\]') "Flow Launcher has Win+D aliases"
    Assert-True ($text -match 'bindings:\s*\["lwin\+v",\s*"rwin\+v"\]') "EarTrumpet has Win+V aliases"
    Assert-True ($text -match 'name:\s*"noalt"') "GlazeWM has a noalt binding mode"
    Assert-True ($text -match 'wm-enable-binding-mode --name noalt') "noalt mode can be enabled"
    Assert-True ($text -match 'wm-disable-binding-mode --name noalt') "noalt mode can be disabled"
    Assert-True ($text -match 'name:\s*"vm"') "GlazeWM has a VM binding mode"
    Assert-True ($text -match 'wm-enable-binding-mode --name vm') "VM mode can be entered from global/noalt bindings"
    Assert-True ($text -match 'wm-disable-binding-mode --name vm') "VM mode can be exited"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+v",\s*"rwin\+alt\+v"\]') "Win+Alt+V toggles/switches VM mode"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+p",\s*"rwin\+alt\+p"\]') "VM mode retains host Flow Launcher on Win+Alt+P"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+ctrl\+v",\s*"rwin\+alt\+ctrl\+v"\]') "VM mode retains host EarTrumpet on Win+Alt+Ctrl+V"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+s",\s*"rwin\+alt\+s"\]') "VM mode retains host Flameshot on Win+Alt+S"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+1",\s*"rwin\+alt\+1"\]') "VM mode keeps host workspace switching on Win+Alt+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+shift\+1",\s*"rwin\+alt\+shift\+1"\]') "VM mode keeps host move-to-workspace on Win+Alt+Shift+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+shift\+e",\s*"rwin\+shift\+e"\]') "Yazi uses both Windows keys for Win+Shift+E"
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

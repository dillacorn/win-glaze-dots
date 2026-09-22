# Manual PowerShell workflow

This is the fallback path for a Windows machine where local policy permits pasted PowerShell commands but does not permit running downloaded `.ps1` files.

Do not change execution policy. Do not use an execution-policy bypass.

The normal `wgdot` runtime should be preferred where local policy allows it because it can preserve baselines and distinguish user-only changes from upstream changes. The manual path below intentionally behaves like a reviewed reset/install for the selected managed components: an existing differing destination is backed up beside itself before replacement.

## Apply managed files from the latest stable WGDot release

Paste the complete block into PowerShell. It is one script block so a source/download failure aborts before any later theme or Yazi post-step can run. Change `$scope`, `$glazeProfile`, or `$selectedComponents` before running it if needed. The stable tag and exact immutable release revision are pinned here deliberately so this path does not require `api.github.com`, `github.com`, Git, `.ps1`, or `.cmd` execution.

```powershell
& {
$ErrorActionPreference = "Stop"
$repoName = "dillacorn/win-glaze-dots"
$releaseTag = "v4.5.2"
$releaseRevision = "1a2925b87d2bc9e90679668030a25fad13ba6d08"
$scope = "work"              # work or normal
$glazeProfile = "work"       # work or normal
$selectedComponents = @(
    "glazewm",
    "yasb",
    "yazi",
    "terminal",
    "altsnap",
    "flameshot"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$rawBase = "https://raw.githubusercontent.com/$repoName/$releaseRevision"

function Get-WgdotRawFile {
    param(
        [Parameter(Mandatory = $true)][string]$Relative,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $encodedRelative = (($Relative -replace '\\', '/') -split '/' | ForEach-Object {
        [Uri]::EscapeDataString($_)
    }) -join '/'
    $uri = "$rawBase/$encodedRelative"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null

    $client = New-Object Net.WebClient
    try {
        $client.Headers["User-Agent"] = "wgdot-manual"
        $client.DownloadFile($uri, $Destination)
    } catch {
        throw "Could not download '$Relative' from raw.githubusercontent.com: $($_.Exception.Message)"
    } finally {
        $client.Dispose()
    }

    if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
        throw "Downloaded source is missing: $Relative"
    }
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("wgdot-manual-" + [guid]::NewGuid().ToString("N"))

try {
    New-Item -ItemType Directory -Force -Path $work | Out-Null

    $manifestPath = Join-Path $work "wgdot\manifest.json"
    Get-WgdotRawFile -Relative "wgdot/manifest.json" -Destination $manifestPath

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ([int]$manifest.schemaVersion -ne 1) { throw "Unsupported WGDot manifest schema." }

    $componentMap = @{}
    foreach ($component in $manifest.components) {
        $componentMap[[string]$component.id] = $component
    }

    $unknownComponents = @($selectedComponents | Where-Object { -not $componentMap.ContainsKey([string]$_) })
    if ($unknownComponents.Count -gt 0) {
        throw "Unknown managed component(s): $($unknownComponents -join ', ')"
    }

    # Download every selected managed source before changing the live profile.
    foreach ($componentId in $selectedComponents) {
        $component = $componentMap[[string]$componentId]
        foreach ($file in $component.files) {
            if ($file.PSObject.Properties.Name -contains "sourceByGlazeProfile") {
                $relative = if ($glazeProfile -eq "work") { [string]$file.sourceByGlazeProfile.work } else { [string]$file.sourceByGlazeProfile.normal }
            } else {
                $relative = [string]$file.source
            }

            $source = Join-Path $work ($relative -replace '/', '\\')
            Get-WgdotRawFile -Relative $relative -Destination $source

            if (($file.PSObject.Properties.Name -contains "validator") -and [string]$file.validator -eq "json") {
                Get-Content -LiteralPath $source -Raw | ConvertFrom-Json | Out-Null
            }
        }
    }

    Write-Host "Source ready: $releaseTag ($releaseRevision)"

foreach ($component in $manifest.components) {
    if ($selectedComponents -notcontains [string]$component.id) { continue }
    foreach ($file in $component.files) {
        if ($file.PSObject.Properties.Name -contains "sourceByGlazeProfile") {
            $relative = if ($glazeProfile -eq "work") { [string]$file.sourceByGlazeProfile.work } else { [string]$file.sourceByGlazeProfile.normal }
        } else {
            $relative = [string]$file.source
        }
        $source = Join-Path $work ($relative -replace '/', '\')
        $dest = [Environment]::ExpandEnvironmentVariables([string]$file.destination)
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing managed source: $relative" }

        $parent = Split-Path -Parent $dest
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
        $same = $false
        if (Test-Path -LiteralPath $dest -PathType Leaf) {
            $same = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        }
        if (-not $same) {
            if (Test-Path -LiteralPath $dest -PathType Leaf) {
                $backup = "$dest.wgdot.backup"
                if (Test-Path -LiteralPath $backup) {
                    $backup = "$dest.wgdot.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                }
                Copy-Item -LiteralPath $dest -Destination $backup
                Write-Host "Backup: $backup"
            }
            Copy-Item -LiteralPath $source -Destination $dest -Force
            Write-Host "Applied: $dest"
        } else {
            Write-Host "Current: $dest"
        }
    }
}

if ($selectedComponents -contains "yasb") {
    $themeStatePath = Join-Path $env:LOCALAPPDATA "wgdot\state\theme.json"
    $themeId = "carbon-night"
    if (Test-Path -LiteralPath $themeStatePath -PathType Leaf) {
        try {
            $savedTheme = Get-Content -LiteralPath $themeStatePath -Raw | ConvertFrom-Json
            if ($savedTheme.id) { $themeId = ([string]$savedTheme.id).Replace("_", "-") }
        } catch {
            Write-Warning "Existing WGDot theme state is unreadable; using Carbon Night."
        }
    }

    $themes = @{
        "carbon-night" = @("Carbon Night", "#353535", "#d0d0d0", "#404040", "#4a4a4a", "#2b2b2b", "#ff5555", "#1a1a1a", "#6a9955", "#ff5555", "#5c5c5c")
        "catppuccin-frappe" = @("Catppuccin Frappe", "#303446", "#c6d0f5", "#414559", "#535970", "#383c4d", "#e78284", "#232634", "#a6d189", "#ef9f76", "#a5adce")
        "crimson-red" = @("Crimson Red", "#1e1e2e", "#f38ba8", "#352630", "#5a3442", "#292330", "#f38ba8", "#1e1e2e", "#fab387", "#f38ba8", "#9f8994")
        "electric-blue" = @("Electric Blue", "#1e1e2e", "#89b4fa", "#293448", "#34445e", "#252938", "#f38ba8", "#1e1e2e", "#a6e3a1", "#fab387", "#8993a8")
        "gruvbox" = @("Gruvbox", "#282828", "#ebdbb2", "#4a423c", "#665c4e", "#3c3836", "#b16286", "#fbf1c7", "#98971a", "#cc241d", "#a89984")
        "iron-forge" = @("Iron Forge", "#0f1113", "#bcd2d2", "#1f2328", "#242a32", "#0d0f12", "#a31717", "#ffffff", "#1f6f6f", "#a31717", "#6a7b86")
        "obsidian-night" = @("Obsidian Night", "#0f0f0f", "#cdd6f4", "#1e1e2e", "#313244", "#1a1a1a", "#ff5555", "#1e1e2e", "#6a9955", "#ff5555", "#4b4b4b")
        "pink" = @("Pink", "#D297A1", "#2E2E2E", "#B77F91", "#C0AFC0", "#C0AFC0", "#B04155", "#FFFFFF", "#D3D3D3", "#B04155", "#7A7A7A")
        "pipboy" = @("Pip-Boy", "#050805", "#a4ff47", "#1f301f", "#1b281b", "#101810", "#263826", "#050805", "#a4ff47", "#3c1b1b", "#2a3d2a")
    }

    if (-not $themes.ContainsKey($themeId)) { $themeId = "carbon-night" }
    $theme = $themes[$themeId]
    $red = [Convert]::ToInt32($theme[2].Substring(1, 2), 16)
    $green = [Convert]::ToInt32($theme[2].Substring(3, 2), 16)
    $blue = [Convert]::ToInt32($theme[2].Substring(5, 2), 16)

    $themeCss = @(
        "/* Generated by WGDot. Active YASB theme: $($theme[0]) */",
        ":root {",
        "    --background: $($theme[1]);",
        "    --foreground: $($theme[2]);",
        "    --hover: $($theme[3]);",
        "    --focus: $($theme[4]);",
        "    --active: $($theme[5]);",
        "    --urgent: $($theme[6]);",
        "    --dark: $($theme[7]);",
        "    --charging: $($theme[8]);",
        "    --critical: $($theme[9]);",
        "    --muted: $($theme[10]);",
        "    --subtle-hover: rgba($red, $green, $blue, 20);",
        "    --subtle-active: rgba($red, $green, $blue, 26);",
        "    --strong-hover: rgba(115, 121, 148, 64);",
        "}",
        ""
    ) -join [Environment]::NewLine

    $themePath = Join-Path $env:USERPROFILE ".config\yasb\theme.css"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $themePath) | Out-Null
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($themePath, $themeCss, $utf8NoBom)
    [IO.File]::AppendAllText($themePath, [Environment]::NewLine, $utf8NoBom)

    $terminalSynced = $false
    $terminalSettingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (Test-Path -LiteralPath $terminalSettingsPath -PathType Leaf) {
        $terminal = Get-Content -LiteralPath $terminalSettingsPath -Raw | ConvertFrom-Json
        $schemeName = "WGDot $($theme[0])"

        if (-not ($terminal.PSObject.Properties.Name -contains "profiles")) {
            $terminal | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{})
        }
        if (-not ($terminal.profiles.PSObject.Properties.Name -contains "defaults")) {
            $terminal.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{})
        }
        $terminal.profiles.defaults | Add-Member -NotePropertyName colorScheme -NotePropertyValue $schemeName -Force

        $terminalSchemes = @()
        if ($terminal.PSObject.Properties.Name -contains "schemes") {
            $terminalSchemes = @($terminal.schemes | Where-Object {
                -not ([string]$_.name).StartsWith("WGDot ", [StringComparison]::OrdinalIgnoreCase)
            })
        }
        # Terminal ANSI colors are semantic foreground colors, not YASB surface colors.
        # Use the selected theme when it is readable, otherwise fall back to the
        # proven Dark Pastels hue for that ANSI slot.
        function Get-ManualTerminalLuminance {
            param([Parameter(Mandatory = $true)][string]$Hex)
            $channel = {
                param([int]$Value)
                $c = $Value / 255.0
                if ($c -le 0.03928) { return ($c / 12.92) }
                return [Math]::Pow((($c + 0.055) / 1.055), 2.4)
            }
            $r = [Convert]::ToInt32($Hex.Substring(1, 2), 16)
            $g = [Convert]::ToInt32($Hex.Substring(3, 2), 16)
            $b = [Convert]::ToInt32($Hex.Substring(5, 2), 16)
            return (0.2126 * (& $channel $r)) + (0.7152 * (& $channel $g)) + (0.0722 * (& $channel $b))
        }
        function Get-ManualTerminalContrast {
            param([string]$First, [string]$Second)
            $a = Get-ManualTerminalLuminance -Hex $First
            $b = Get-ManualTerminalLuminance -Hex $Second
            return ([Math]::Max($a, $b) + 0.05) / ([Math]::Min($a, $b) + 0.05)
        }
        function Get-ManualTerminalBlend {
            param([string]$Background, [string]$Foreground, [double]$Weight)
            $backWeight = 1.0 - $Weight
            $parts = foreach ($start in @(1, 3, 5)) {
                $back = [Convert]::ToInt32($Background.Substring($start, 2), 16)
                $front = [Convert]::ToInt32($Foreground.Substring($start, 2), 16)
                [int][Math]::Round(($back * $backWeight) + ($front * $Weight))
            }
            return ('#{0:X2}{1:X2}{2:X2}' -f $parts[0], $parts[1], $parts[2])
        }
        function Get-ManualTerminalColor {
            param(
                [string]$Candidate,
                [double]$MinimumContrast,
                [double]$FallbackWeight,
                [string]$PreferredFallback
            )
            if ((Get-ManualTerminalContrast -First $Candidate -Second $theme[1]) -ge $MinimumContrast) {
                return $Candidate
            }
            if (-not [string]::IsNullOrWhiteSpace($PreferredFallback) -and
                (Get-ManualTerminalContrast -First $PreferredFallback -Second $theme[1]) -ge $MinimumContrast) {
                return $PreferredFallback
            }
            return Get-ManualTerminalBlend -Background $theme[1] -Foreground $theme[2] -Weight $FallbackWeight
        }

        $terminalScheme = [pscustomobject][ordered]@{
            name = $schemeName
            background = $theme[1]
            foreground = $theme[2]
            cursorColor = $theme[2]
            selectionBackground = Get-ManualTerminalColor -Candidate $theme[4] -MinimumContrast 1.6 -FallbackWeight 0.45
            black = $theme[7]
            red = Get-ManualTerminalColor -Candidate $theme[6] -MinimumContrast 3.0 -FallbackWeight 0.72 -PreferredFallback "#705050"
            green = Get-ManualTerminalColor -Candidate $theme[8] -MinimumContrast 3.0 -FallbackWeight 0.72 -PreferredFallback "#60B48A"
            yellow = Get-ManualTerminalColor -Candidate $theme[9] -MinimumContrast 3.0 -FallbackWeight 0.72 -PreferredFallback "#DFAF8F"
            blue = Get-ManualTerminalColor -Candidate $theme[4] -MinimumContrast 3.0 -FallbackWeight 0.72 -PreferredFallback "#9AB8D7"
            purple = Get-ManualTerminalColor -Candidate $theme[5] -MinimumContrast 3.0 -FallbackWeight 0.72 -PreferredFallback "#DC8CC3"
            cyan = Get-ManualTerminalColor -Candidate $theme[3] -MinimumContrast 4.5 -FallbackWeight 0.82 -PreferredFallback "#8CD0D3"
            white = $theme[2]
            brightBlack = Get-ManualTerminalColor -Candidate $theme[10] -MinimumContrast 3.0 -FallbackWeight 0.60 -PreferredFallback "#709080"
            brightRed = Get-ManualTerminalColor -Candidate $theme[6] -MinimumContrast 4.0 -FallbackWeight 0.82 -PreferredFallback "#DCA3A3"
            brightGreen = Get-ManualTerminalColor -Candidate $theme[8] -MinimumContrast 4.0 -FallbackWeight 0.82 -PreferredFallback "#72D5A3"
            brightYellow = Get-ManualTerminalColor -Candidate $theme[9] -MinimumContrast 4.0 -FallbackWeight 0.82 -PreferredFallback "#F0DFAF"
            brightBlue = Get-ManualTerminalColor -Candidate $theme[4] -MinimumContrast 4.0 -FallbackWeight 0.82 -PreferredFallback "#94BFF3"
            brightPurple = Get-ManualTerminalColor -Candidate $theme[5] -MinimumContrast 4.0 -FallbackWeight 0.82 -PreferredFallback "#EC93D3"
            brightCyan = Get-ManualTerminalColor -Candidate $theme[3] -MinimumContrast 4.5 -FallbackWeight 0.90 -PreferredFallback "#93E0E3"
            brightWhite = $theme[2]
        }
        $terminal | Add-Member -NotePropertyName schemes -NotePropertyValue @($terminalSchemes + $terminalScheme) -Force

        $terminalThemes = @()
        if ($terminal.PSObject.Properties.Name -contains "themes") {
            $terminalThemes = @($terminal.themes | Where-Object {
                -not ([string]$_.name).StartsWith("WGDot ", [StringComparison]::OrdinalIgnoreCase)
            })
        }
        $bgRed = [Convert]::ToInt32($theme[1].Substring(1, 2), 16)
        $bgGreen = [Convert]::ToInt32($theme[1].Substring(3, 2), 16)
        $bgBlue = [Convert]::ToInt32($theme[1].Substring(5, 2), 16)
        $applicationTheme = if (((0.2126 * $bgRed) + (0.7152 * $bgGreen) + (0.0722 * $bgBlue)) -ge 155) { "light" } else { "dark" }
        $terminalUiTheme = [pscustomobject][ordered]@{
            name = "$schemeName UI"
            window = [pscustomobject][ordered]@{
                applicationTheme = $applicationTheme
                useMica = $false
            }
            tab = [pscustomobject][ordered]@{
                background = "terminalBackground"
                unfocusedBackground = $theme[1]
            }
            tabRow = [pscustomobject][ordered]@{
                background = $theme[1]
                unfocusedBackground = $theme[1]
            }
        }
        $terminal | Add-Member -NotePropertyName themes -NotePropertyValue @($terminalThemes + $terminalUiTheme) -Force
        $terminal | Add-Member -NotePropertyName theme -NotePropertyValue "$schemeName UI" -Force

        $terminalTmp = "$terminalSettingsPath.tmp-$([guid]::NewGuid().ToString("N"))"
        try {
            [IO.File]::WriteAllText(
                $terminalTmp,
                (($terminal | ConvertTo-Json -Depth 32) + [Environment]::NewLine),
                $utf8NoBom)
            Move-Item -LiteralPath $terminalTmp -Destination $terminalSettingsPath -Force
        } finally {
            if (Test-Path -LiteralPath $terminalTmp) {
                Remove-Item -LiteralPath $terminalTmp -Force
            }
        }
        $terminalSynced = $true
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $themeStatePath) | Out-Null
    [pscustomobject]@{
        id = $themeId
        label = $theme[0]
        appliedAt = (Get-Date).ToUniversalTime().ToString("o")
        cssPath = $themePath
        terminalSynced = [bool]$terminalSynced
        terminalSettingsPath = $terminalSettingsPath
        glazewmReloaded = $false
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $themeStatePath -Encoding UTF8

    Write-Host "YASB / Windows Terminal theme generated: $themePath"

    $appearanceStatePath = Join-Path $env:LOCALAPPDATA "wgdot\state\yasb-appearance.json"
    $runningAppsVisible = $true
    $shadeRunningApps = $false
    if (Test-Path -LiteralPath $appearanceStatePath -PathType Leaf) {
        try {
            $savedAppearance = Get-Content -LiteralPath $appearanceStatePath -Raw | ConvertFrom-Json
            if ($null -ne $savedAppearance.runningAppsVisible) {
                $runningAppsVisible = [bool]$savedAppearance.runningAppsVisible
            }
            if ($null -ne $savedAppearance.shadeRunningApps) {
                $shadeRunningApps = [bool]$savedAppearance.shadeRunningApps
            }
        } catch {
            Write-Warning "Existing WGDot YASB appearance state is unreadable; using visible/unshaded running apps."
        }
    }

    $appearanceLines = @("/* Generated by WGDot. YASB live appearance toggles. */")
    if (-not $runningAppsVisible) {
        $appearanceLines += @(
            ".taskbar-widget,",
            ".taskbar-widget .widget-container,",
            ".taskbar-widget .app-container {",
            "    min-width: 0;",
            "    max-width: 0;",
            "    margin: 0;",
            "    padding: 0;",
            "    border: none;",
            "}"
        )
    } elseif ($shadeRunningApps) {
        $appearanceLines += @(
            ".taskbar-widget .app-container.running {",
            "    background-color: var(--subtle-hover);",
            "}",
            ".taskbar-widget .app-container.foreground {",
            "    background-color: var(--subtle-active);",
            "}",
            ".taskbar-widget .app-container.running.minimized {",
            "    background-color: var(--active);",
            "    opacity: 0.55;",
            "}"
        )
    }
    $appearanceLines += ""

    $appearancePath = Join-Path $env:USERPROFILE ".config\yasb\appearance.css"
    [IO.File]::WriteAllText(
        $appearancePath,
        ($appearanceLines -join [Environment]::NewLine),
        $utf8NoBom
    )
    [IO.File]::AppendAllText($appearancePath, [Environment]::NewLine, $utf8NoBom)

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $appearanceStatePath) | Out-Null
    [pscustomobject]@{
        runningAppsVisible = $runningAppsVisible
        shadeRunningApps = $shadeRunningApps
        updatedAt = (Get-Date).ToUniversalTime().ToString("o")
        cssPath = $appearancePath
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $appearanceStatePath -Encoding UTF8

    Write-Host "YASB appearance generated: $appearancePath"
}

$legacyClipboard = Join-Path $env:APPDATA "yazi\config\plugins\clipboard.yazi"
$legacyGitConfig = Join-Path $legacyClipboard ".git\config"
if (Test-Path -LiteralPath $legacyClipboard -PathType Container) {
    if ((Test-Path -LiteralPath $legacyGitConfig -PathType Leaf) -and ((Get-Content -LiteralPath $legacyGitConfig -Raw).IndexOf("XYenon/clipboard.yazi", [StringComparison]::OrdinalIgnoreCase) -ge 0)) {
        $legacyBackup = "$legacyClipboard.wgdot.backup"
        if (Test-Path -LiteralPath $legacyBackup) {
            $legacyBackup = "$legacyClipboard.wgdot.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        }
        Copy-Item -LiteralPath $legacyClipboard -Destination $legacyBackup -Recurse
        Remove-Item -LiteralPath $legacyClipboard -Recurse -Force
        Write-Host "Removed known legacy XYenon Yazi clipboard plugin."
        Write-Host "Backup: $legacyBackup"
    } else {
        Write-Warning "Legacy clipboard.yazi path exists but is not positively identified as the old managed plugin; preserved it."
    }
}

$gitFileCandidates = @(
    (Join-Path $env:ProgramFiles "Git\usr\bin\file.exe"),
    (Join-Path $env:USERPROFILE "scoop\apps\git\current\usr\bin\file.exe")
)
$gitFile = $gitFileCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if ($gitFile) {
    [Environment]::SetEnvironmentVariable("YAZI_FILE_ONE", $gitFile, "User")
    Write-Host "Set YAZI_FILE_ONE=$gitFile"
}

    Write-Host "Manual dots update completed from $releaseTag."
} finally {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}
}
```

## Install selected software from the same release manifest

WinGet is a WGDot requirement. The normal native runtime handles a missing WinGet installation automatically. For this paste-only fallback, use Microsoft's WinGet repair/bootstrap path before package reconciliation when `winget.exe` is absent.

This example uses the profile defaults stored in the release manifest. It verifies every exact WinGet ID before installation and does not upgrade unrelated software.

```powershell
& {
$ErrorActionPreference = "Stop"
$repoName = "dillacorn/win-glaze-dots"
$releaseTag = "v4.5.2"
$releaseRevision = "1a2925b87d2bc9e90679668030a25fad13ba6d08"
$manifestUri = "https://raw.githubusercontent.com/$repoName/$releaseRevision/wgdot/manifest.json"

if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    Write-Host "WinGet is missing; repairing/installing Microsoft Windows Package Manager..."
    Install-PackageProvider -Name NuGet -Force | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
    Import-Module Microsoft.WinGet.Client -Force
    Repair-WinGetPackageManager -Force -Latest
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue

    $windowsApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
    if ($env:PATH -notlike "*$windowsApps*") {
        $env:PATH += ";$windowsApps"
    }

    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "WinGet repair completed but winget.exe is still unavailable in this user session."
    }
}

$scope = "work"  # work or normal
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$client = New-Object Net.WebClient
try {
    $client.Headers["User-Agent"] = "wgdot-manual"
    $manifestJson = $client.DownloadString($manifestUri)
} finally {
    $client.Dispose()
}
$manifest = $manifestJson | ConvertFrom-Json
if ([int]$manifest.schemaVersion -ne 1) { throw "Unsupported WGDot manifest schema." }

foreach ($package in $manifest.packages) {
    $selected = if ($scope -eq "work") { [bool]$package.defaultWork } else { [bool]$package.defaultNormal }
    if (-not $selected) { continue }

    winget show --id $package.id --exact --source winget --accept-source-agreements *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Unavailable WinGet ID: $($package.id)"
        continue
    }

    $installedOutput = (winget list --id $package.id --exact --source winget --accept-source-agreements 2>$null | Out-String)
    if ($installedOutput.IndexOf([string]$package.id, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        winget install --id $package.id --exact --source winget --accept-source-agreements --accept-package-agreements
    }
}
Write-Host "Software defaults read from $releaseTag."
}
```

Software upgrades remain explicit. For one selected package, use `winget upgrade --id <PackageId> --exact` after reviewing what WinGet reports.

## Reversible startup management

The normal `wgdot software` menu owns startup state and individual uninstall behavior. If native WGDot is unavailable, the startup entries it creates are ordinary current-user Run values named `WGDot.*` under:

```text
HKCU\Software\Microsoft\Windows\CurrentVersion\Run
```

To disable every WGDot-managed login startup entry without uninstalling applications:

```powershell
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
if (Test-Path -LiteralPath $runKey) {
    $values = Get-ItemProperty -LiteralPath $runKey
    $values.PSObject.Properties |
        Where-Object { $_.Name -like "WGDot.*" } |
        ForEach-Object {
            Remove-ItemProperty -LiteralPath $runKey -Name $_.Name -ErrorAction SilentlyContinue
            Write-Host "Disabled startup: $($_.Name)"
        }
}
```

This does not remove vendor/user startup entries and does not uninstall software.

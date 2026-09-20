# Manual PowerShell workflow

This is the fallback path for a Windows machine where local policy permits pasted PowerShell commands but does not permit running downloaded `.ps1` files.

Do not change execution policy. Do not use an execution-policy bypass.

The normal `wgdot` runtime should be preferred where local policy allows it because it can preserve baselines and distinguish user-only changes from upstream changes. The manual path below intentionally behaves like a reviewed reset/install for the selected managed components: an existing differing destination is backed up beside itself before replacement.

## Apply managed files from the latest stable WGDot release

Paste the complete block into PowerShell. Change `$scope`, `$glazeProfile`, or `$selectedComponents` before running it if needed.

```powershell
$ErrorActionPreference = "Stop"
$repoName = "dillacorn/win-glaze-dots"
$scope = "work"              # work or normal
$glazeProfile = "work"       # work or normal
$selectedComponents = @(
    "glazewm",
    "yasb",
    "yazi",
    "terminal",
    "altsnap",
    "flameshot",
    "doublecmd"
)

$headers = @{ "User-Agent" = "wgdot-manual"; "Accept" = "application/vnd.github+json" }
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoName/releases/latest" -Headers $headers -UseBasicParsing
if ($release.draft -or $release.prerelease -or $release.tag_name -notmatch '^v\d+\.\d+\.\d+$') {
    throw "Latest published release is not a normal WGDot semantic stable release."
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("wgdot-manual-" + [guid]::NewGuid().ToString("N"))
git clone --depth 1 --branch $release.tag_name "https://github.com/$repoName.git" $work
if ($LASTEXITCODE -ne 0) { throw "Could not clone stable release $($release.tag_name)." }

$manifestPath = Join-Path $work "wgdot\manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "This release is not WGDot-compatible." }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([int]$manifest.schemaVersion -ne 1) { throw "Unsupported WGDot manifest schema." }

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

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $themeStatePath) | Out-Null
    [pscustomobject]@{
        id = $themeId
        label = $theme[0]
        appliedAt = (Get-Date).ToUniversalTime().ToString("o")
        cssPath = $themePath
        glazewmReloaded = $false
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $themeStatePath -Encoding UTF8

    Write-Host "YASB theme generated: $themePath"
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
```

## Install selected software from the same release manifest

This example uses the profile defaults stored in the release manifest. It verifies every exact WinGet ID before installation and does not upgrade unrelated software.

```powershell
$ErrorActionPreference = "Stop"
$scope = "work"  # work or normal
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

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
```

Software upgrades remain explicit. For one selected package, use `winget upgrade --id <PackageId> --exact` after reviewing what WinGet reports.

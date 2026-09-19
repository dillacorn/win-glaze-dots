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

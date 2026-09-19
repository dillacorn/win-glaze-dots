[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = "menu",

    [string]$Branch,
    [string]$Revision,
    [switch]$ReviewOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$script:RepoOwner = "dillacorn"
$script:RepoName = "win-glaze-dots"
$script:RepoFullName = "$($script:RepoOwner)/$($script:RepoName)"
$script:RepoUrl = "https://github.com/$($script:RepoFullName).git"
$script:ApiBase = "https://api.github.com/repos/$($script:RepoFullName)"
$script:InstallRoot = Join-Path $env:LOCALAPPDATA "wgdot"
$script:BinRoot = Join-Path $script:InstallRoot "bin"
$script:StateRoot = Join-Path $script:InstallRoot "state"
$script:CacheRoot = Join-Path $script:InstallRoot "cache"
$script:BaselineRoot = Join-Path $script:StateRoot "baseline"
$script:RuntimeStatePath = Join-Path $script:StateRoot "runtime.json"
$script:ConfigStatePath = Join-Path $script:StateRoot "config.json"
$script:InstallStatePath = Join-Path $script:StateRoot "installation.json"
$script:GitStatePath = Join-Path $script:StateRoot "git-testing.json"
$script:BackupStatePath = Join-Path $script:StateRoot "backups.json"
$script:BaselineIndexPath = Join-Path $script:BaselineRoot "index.json"
$script:RuntimeScriptPath = Join-Path $script:BinRoot "wgdot.ps1"
$script:RuntimeLauncherPath = Join-Path $script:BinRoot "wgdot.cmd"
$script:StableTagRegex = '^v\d+\.\d+\.\d+$'

function Write-WgdotTitle {
    param([string]$Subtitle)
    Clear-Host
    Write-Host "WGDot" -ForegroundColor Cyan
    if ($Subtitle) {
        Write-Host $Subtitle -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Ensure-WgdotDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Initialize-WgdotStateDirectories {
    Ensure-WgdotDirectory -Path $script:InstallRoot
    Ensure-WgdotDirectory -Path $script:BinRoot
    Ensure-WgdotDirectory -Path $script:StateRoot
    Ensure-WgdotDirectory -Path $script:CacheRoot
    Ensure-WgdotDirectory -Path $script:BaselineRoot
}

function Read-WgdotJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    return ($raw | ConvertFrom-Json)
}

function Write-WgdotJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $parent = Split-Path -Parent $Path
    Ensure-WgdotDirectory -Path $parent
    $tmp = "$Path.tmp"
    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tmp -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Invoke-WgdotApi {
    param([Parameter(Mandatory = $true)][string]$Uri)

    $headers = @{
        "User-Agent" = "wgdot"
        "Accept" = "application/vnd.github+json"
    }
    return Invoke-RestMethod -Uri $Uri -Headers $headers -UseBasicParsing
}

function Get-WgdotSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Expand-WgdotPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [Environment]::ExpandEnvironmentVariables($Path)
}

function Get-WgdotRelativeSourcePath {
    param(
        [Parameter(Mandatory = $true)]$File,
        [Parameter(Mandatory = $true)][string]$GlazeProfile
    )

    if ($File.PSObject.Properties.Name -contains "sourceByGlazeProfile") {
        if ($GlazeProfile -eq "work") {
            return [string]$File.sourceByGlazeProfile.work
        }
        return [string]$File.sourceByGlazeProfile.normal
    }

    return [string]$File.source
}

function Test-WgdotManagedDestination {
    param([Parameter(Mandatory = $true)][string]$Destination)

    $full = [System.IO.Path]::GetFullPath((Expand-WgdotPath -Path $Destination))
    $roots = @(
        [System.IO.Path]::GetFullPath($env:USERPROFILE),
        [System.IO.Path]::GetFullPath($env:APPDATA),
        [System.IO.Path]::GetFullPath($env:LOCALAPPDATA)
    ) | Select-Object -Unique

    foreach ($root in $roots) {
        $rootWithSlash = $root.TrimEnd('\') + '\'
        if ($full.StartsWith($rootWithSlash, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Get-WgdotBaselinePath {
    param([Parameter(Mandatory = $true)][string]$FileId)
    $safe = $FileId -replace '[^A-Za-z0-9._-]', '_'
    return Join-Path $script:BaselineRoot $safe
}

function Read-WgdotManifest {
    param([Parameter(Mandatory = $true)][string]$SourceRoot)

    $path = Join-Path $SourceRoot "wgdot\manifest.json"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "WGDot manifest not found in source: $path"
    }

    $manifest = Read-WgdotJson -Path $path
    if ($null -eq $manifest -or [int]$manifest.schemaVersion -ne 1) {
        throw "Unsupported or invalid WGDot manifest."
    }

    return $manifest
}

function Resolve-WgdotGitObjectToCommit {
    param([Parameter(Mandatory = $true)]$Object)

    $current = $Object
    $guard = 0
    while ([string]$current.type -eq "tag") {
        $guard++
        if ($guard -gt 8) {
            throw "Tag resolution exceeded safety limit."
        }
        $tag = Invoke-WgdotApi -Uri "$($script:ApiBase)/git/tags/$($current.sha)"
        $current = $tag.object
    }

    if ([string]$current.type -ne "commit") {
        throw "Git tag did not resolve to a commit."
    }

    $sha = [string]$current.sha
    if ($sha -notmatch '^[0-9a-fA-F]{40}$') {
        throw "Resolved commit is not a full SHA."
    }
    return $sha.ToLowerInvariant()
}

function Get-WgdotStableRelease {
    $release = Invoke-WgdotApi -Uri "$($script:ApiBase)/releases/latest"
    if ([bool]$release.draft -or [bool]$release.prerelease) {
        throw "Latest release is not a normal published stable release."
    }

    $tag = [string]$release.tag_name
    if ($tag -notmatch $script:StableTagRegex) {
        throw "Latest published release '$tag' is not a WGDot semantic stable tag."
    }

    $ref = Invoke-WgdotApi -Uri "$($script:ApiBase)/git/ref/tags/$tag"
    $commit = Resolve-WgdotGitObjectToCommit -Object $ref.object

    return [pscustomobject]@{
        Mode = "stable"
        Tag = $tag
        Revision = $commit
        PublishedAt = [string]$release.published_at
    }
}

function Get-WgdotMainRevision {
    $ref = Invoke-WgdotApi -Uri "$($script:ApiBase)/git/ref/heads/main"
    $sha = [string]$ref.object.sha
    if ($sha -notmatch '^[0-9a-fA-F]{40}$') {
        throw "Could not resolve main to a full commit SHA."
    }
    return $sha.ToLowerInvariant()
}

function Get-WgdotSourceRoot {
    param([Parameter(Mandatory = $true)][string]$Revision)

    if ($Revision -notmatch '^[0-9a-fA-F]{40}$') {
        throw "Source revision must be a full 40-character SHA."
    }

    $revisionRoot = Join-Path $script:CacheRoot ("revision-" + $Revision.ToLowerInvariant())
    $marker = Join-Path $revisionRoot ".wgdot-source"
    if (Test-Path -LiteralPath $marker -PathType Leaf) {
        return (Get-Content -LiteralPath $marker -Raw).Trim()
    }

    Ensure-WgdotDirectory -Path $script:CacheRoot
    $zipPath = Join-Path $script:CacheRoot ("$Revision.zip")
    $extractRoot = Join-Path $script:CacheRoot ("extract-" + $Revision)

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    if (Test-Path -LiteralPath $extractRoot) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }

    Invoke-WebRequest -Uri "https://github.com/$($script:RepoFullName)/archive/$Revision.zip" -OutFile $zipPath -UseBasicParsing
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force

    $children = @(Get-ChildItem -LiteralPath $extractRoot -Directory)
    if ($children.Count -ne 1) {
        throw "Unexpected GitHub archive layout."
    }

    $source = $children[0].FullName
    $manifestPath = Join-Path $source "wgdot\manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Revision $Revision is not WGDot-compatible."
    }

    Ensure-WgdotDirectory -Path $revisionRoot
    Set-Content -LiteralPath $marker -Value $source -Encoding ASCII
    return $source
}

function Install-WgdotRuntime {
    Initialize-WgdotStateDirectories
    $sourceScript = Join-Path $PSScriptRoot "wgdot.ps1"
    $sourceLauncher = Join-Path $PSScriptRoot "wgdot.cmd"
    if (-not (Test-Path -LiteralPath $sourceLauncher -PathType Leaf)) {
        throw "wgdot.cmd must be beside wgdot.ps1 during installation."
    }

    Copy-Item -LiteralPath $sourceScript -Destination $script:RuntimeScriptPath -Force
    Copy-Item -LiteralPath $sourceLauncher -Destination $script:RuntimeLauncherPath -Force

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $segments = @()
    if (-not [string]::IsNullOrWhiteSpace($userPath)) {
        $segments = @($userPath.Split(';') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    $present = $false
    foreach ($segment in $segments) {
        if ($segment.TrimEnd('\') -ieq $script:BinRoot.TrimEnd('\')) {
            $present = $true
        }
    }
    if (-not $present) {
        $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $script:BinRoot } else { "$userPath;$($script:BinRoot)" }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    }

    Write-WgdotJson -Path $script:RuntimeStatePath -Value ([pscustomobject]@{
        source = "local"
        revision = $null
        installedAt = (Get-Date).ToString("o")
    })

    Write-Host "WGDot installed to $($script:BinRoot)."
    Write-Host "Open a new terminal before using the bare 'wgdot' command if this directory was just added to PATH."
}

function Update-WgdotRuntimeFromMain {
    Initialize-WgdotStateDirectories
    $installed = Read-WgdotJson -Path $script:RuntimeStatePath
    $remote = Get-WgdotMainRevision
    if ($null -ne $installed -and [string]$installed.revision -eq $remote) {
        return $false
    }

    try {
        $source = Get-WgdotSourceRoot -Revision $remote
    } catch {
        Write-Warning "main does not currently contain an installable WGDot runtime; keeping the installed runtime. $($_.Exception.Message)"
        return $false
    }

    $nextScript = Join-Path $source "wgdot\wgdot.ps1"
    $nextLauncher = Join-Path $source "wgdot\wgdot.cmd"
    if (-not (Test-Path -LiteralPath $nextScript) -or -not (Test-Path -LiteralPath $nextLauncher)) {
        Write-Warning "main is missing WGDot runtime files; keeping the installed runtime."
        return $false
    }

    Copy-Item -LiteralPath $nextScript -Destination $script:RuntimeScriptPath -Force
    Copy-Item -LiteralPath $nextLauncher -Destination $script:RuntimeLauncherPath -Force
    Write-WgdotJson -Path $script:RuntimeStatePath -Value ([pscustomobject]@{
        source = "main"
        revision = $remote
        installedAt = (Get-Date).ToString("o")
    })

    Write-Host "WGDot runtime refreshed from main: $remote" -ForegroundColor Green
    return $true
}

function Read-WgdotSingleChoice {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string[]]$Items,
        [int]$InitialIndex = 0
    )

    $index = $InitialIndex
    if ($index -lt 0 -or $index -ge $Items.Count) { $index = 0 }

    while ($true) {
        Write-WgdotTitle -Subtitle $Title
        for ($i = 0; $i -lt $Items.Count; $i++) {
            if ($i -eq $index) {
                Write-Host ("> " + $Items[$i]) -ForegroundColor Cyan
            } else {
                Write-Host ("  " + $Items[$i])
            }
        }
        Write-Host ""
        Write-Host "Up/Down: move   Enter: select   Esc: cancel" -ForegroundColor DarkGray
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::UpArrow) { $index = ($index - 1 + $Items.Count) % $Items.Count }
        elseif ($key.Key -eq [ConsoleKey]::DownArrow) { $index = ($index + 1) % $Items.Count }
        elseif ($key.Key -eq [ConsoleKey]::Enter) { return $index }
        elseif ($key.Key -eq [ConsoleKey]::Escape) { return -1 }
    }
}

function Read-WgdotMultiChoice {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][object[]]$Items
    )

    $index = 0
    while ($true) {
        Write-WgdotTitle -Subtitle $Title
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $mark = if ([bool]$Items[$i].Selected) { "[x]" } else { "[ ]" }
            $line = "$mark $($Items[$i].Label)"
            if ($i -eq $index) { Write-Host ("> " + $line) -ForegroundColor Cyan } else { Write-Host ("  " + $line) }
        }
        Write-Host ""
        Write-Host "Up/Down: move   Space: toggle   Enter: accept   Esc: cancel" -ForegroundColor DarkGray
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::UpArrow) { $index = ($index - 1 + $Items.Count) % $Items.Count }
        elseif ($key.Key -eq [ConsoleKey]::DownArrow) { $index = ($index + 1) % $Items.Count }
        elseif ($key.Key -eq [ConsoleKey]::Spacebar) { $Items[$index].Selected = -not [bool]$Items[$index].Selected }
        elseif ($key.Key -eq [ConsoleKey]::Enter) { return $Items }
        elseif ($key.Key -eq [ConsoleKey]::Escape) { return $null }
    }
}

function New-WgdotInstallationSelection {
    param([Parameter(Mandatory = $true)]$Manifest)

    $scopeIndex = Read-WgdotSingleChoice -Title "Choose installation profile" -Items @("Normal / personal PC", "Work PC")
    if ($scopeIndex -lt 0) { return $null }
    $scope = if ($scopeIndex -eq 1) { "work" } else { "normal" }

    $glazeIndex = Read-WgdotSingleChoice -Title "Which GlazeWM config created by dillacorn do you want to use?" -Items @("Normal", "Work") -InitialIndex $(if ($scope -eq "work") { 1 } else { 0 })
    if ($glazeIndex -lt 0) { return $null }
    $glazeProfile = if ($glazeIndex -eq 1) { "work" } else { "normal" }

    $componentChoices = @()
    foreach ($component in $Manifest.components) {
        $selected = if ($scope -eq "work") { [bool]$component.defaultWork } else { [bool]$component.defaultNormal }
        $componentChoices += [pscustomobject]@{ Id = [string]$component.id; Label = [string]$component.name; Selected = $selected }
    }
    $componentChoices = Read-WgdotMultiChoice -Title "Managed components" -Items $componentChoices
    if ($null -eq $componentChoices) { return $null }

    $packageChoices = @()
    foreach ($package in $Manifest.packages) {
        $selected = if ($scope -eq "work") { [bool]$package.defaultWork } else { [bool]$package.defaultNormal }
        $packageChoices += [pscustomobject]@{ Id = [string]$package.id; Label = "$($package.name) [$($package.category)]"; Selected = $selected }
    }
    $packageChoices = Read-WgdotMultiChoice -Title "Software to install/reconcile" -Items $packageChoices
    if ($null -eq $packageChoices) { return $null }

    return [pscustomobject]@{
        scope = $scope
        glazewmProfile = $glazeProfile
        components = @($componentChoices | Where-Object { $_.Selected } | ForEach-Object { $_.Id })
        packages = @($packageChoices | Where-Object { $_.Selected } | ForEach-Object { $_.Id })
        configuredAt = (Get-Date).ToString("o")
    }
}

function Get-WgdotSelectedComponents {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$Installation
    )

    $selected = @{}
    foreach ($id in @($Installation.components)) { $selected[[string]$id] = $true }
    return @($Manifest.components | Where-Object { $selected.ContainsKey([string]$_.id) })
}

function Get-WgdotPlan {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)]$Installation,
        [ValidateSet("update", "reset")][string]$Mode = "update"
    )

    $plan = @()
    $selectedComponents = Get-WgdotSelectedComponents -Manifest $Manifest -Installation $Installation

    foreach ($component in $selectedComponents) {
        foreach ($file in $component.files) {
            $relativeSource = Get-WgdotRelativeSourcePath -File $file -GlazeProfile ([string]$Installation.glazewmProfile)
            $target = Join-Path $SourceRoot ($relativeSource -replace '/', '\')
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                throw "Managed source missing: $relativeSource"
            }

            $destination = Expand-WgdotPath -Path ([string]$file.destination)
            if (-not (Test-WgdotManagedDestination -Destination $destination)) {
                throw "Unsafe managed destination: $destination"
            }

            $baseline = Get-WgdotBaselinePath -FileId ([string]$file.id)
            $targetHash = Get-WgdotSha256 -Path $target
            $liveHash = Get-WgdotSha256 -Path $destination
            $baselineHash = Get-WgdotSha256 -Path $baseline
            $status = ""
            $action = ""

            if ($null -eq $liveHash) {
                $status = "NEW"
                $action = "APPLY"
            } elseif ($liveHash -eq $targetHash) {
                $status = "CURRENT"
                $action = "NONE"
            } elseif ($Mode -eq "reset") {
                $status = "RESET"
                $action = "REPLACE"
            } elseif ($null -eq $baselineHash) {
                $status = "LEGACY"
                $action = "PRESERVE"
            } elseif ($liveHash -eq $baselineHash -and $targetHash -ne $baselineHash) {
                $status = "UPSTREAM"
                $action = "REPLACE"
            } elseif ($liveHash -ne $baselineHash -and $targetHash -eq $baselineHash) {
                $status = "USER"
                $action = "PRESERVE"
            } else {
                $status = "BOTH"
                $action = if ([bool]$file.merge) { "MERGE" } else { "PRESERVE" }
            }

            $plan += [pscustomobject]@{
                FileId = [string]$file.id
                Component = [string]$component.id
                Destination = $destination
                Target = $target
                Baseline = $baseline
                Status = $status
                Action = $action
                Merge = [bool]$file.merge
                CommitTargetBaseline = ($status -in @("NEW", "CURRENT", "RESET", "UPSTREAM", "USER"))
                Validator = if ($file.PSObject.Properties.Name -contains "validator") { [string]$file.validator } else { "" }
            }
        }
    }

    $oldIndex = Read-WgdotJson -Path $script:BaselineIndexPath
    if ($null -ne $oldIndex) {
        $currentIds = @{}
        foreach ($item in $plan) { $currentIds[$item.FileId] = $true }
        $selectedComponentIds = @{}
        foreach ($component in $selectedComponents) { $selectedComponentIds[[string]$component.id] = $true }
        foreach ($old in @($oldIndex.files)) {
            if ($selectedComponentIds.ContainsKey([string]$old.component) -and -not $currentIds.ContainsKey([string]$old.fileId)) {
                $destination = [string]$old.destination
                if (Test-Path -LiteralPath $destination) {
                    $plan += [pscustomobject]@{
                        FileId = [string]$old.fileId
                        Component = [string]$old.component
                        Destination = $destination
                        Target = $null
                        Baseline = Get-WgdotBaselinePath -FileId ([string]$old.fileId)
                        Status = "REMOVED-UPSTREAM"
                        Action = "PRESERVE"
                        Merge = $false
                        CommitTargetBaseline = $false
                        Validator = ""
                    }
                }
            }
        }
    }

    return $plan
}

function Show-WgdotPlan {
    param([Parameter(Mandatory = $true)][object[]]$Plan)

    Write-Host ""
    Write-Host "Plan" -ForegroundColor Cyan
    foreach ($item in $Plan) {
        $display = "{0,-17} {1,-9} {2}" -f $item.Status, $item.Action, $item.Destination
        if ($item.Action -eq "PRESERVE" -or $item.Status -eq "REMOVED-UPSTREAM") {
            Write-Host $display -ForegroundColor Yellow
        } elseif ($item.Action -eq "NONE") {
            Write-Host $display -ForegroundColor DarkGray
        } else {
            Write-Host $display
        }
    }
}

function Add-WgdotBackupRecord {
    param(
        [Parameter(Mandatory = $true)][string]$Original,
        [Parameter(Mandatory = $true)][string]$Backup,
        [Parameter(Mandatory = $true)][string]$Operation
    )

    $state = Read-WgdotJson -Path $script:BackupStatePath
    $records = @()
    if ($null -ne $state -and $state.PSObject.Properties.Name -contains "records") {
        $records = @($state.records)
    }
    $records += [pscustomobject]@{
        original = $Original
        backup = $Backup
        operation = $Operation
        createdAt = (Get-Date).ToString("o")
    }
    Write-WgdotJson -Path $script:BackupStatePath -Value ([pscustomobject]@{ records = $records })
}

function New-WgdotBackup {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Operation
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $backup = "$Path.wgdot.backup"
    if (Test-Path -LiteralPath $backup) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backup = "$Path.wgdot.backup.$stamp"
        $n = 1
        while (Test-Path -LiteralPath $backup) {
            $backup = "$Path.wgdot.backup.$stamp-$n"
            $n++
        }
    }

    if (Test-Path -LiteralPath $Path -PathType Container) {
        Copy-Item -LiteralPath $Path -Destination $backup -Recurse
    } else {
        Copy-Item -LiteralPath $Path -Destination $backup
    }
    Add-WgdotBackupRecord -Original $Path -Backup $backup -Operation $Operation
    return $backup
}

function Test-WgdotFileValidation {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Validator
    )

    if ([string]::IsNullOrWhiteSpace($Validator)) { return $true }
    if ($Validator -eq "json") {
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json | Out-Null
        return $true
    }
    if ($Validator -eq "xml") {
        [xml](Get-Content -LiteralPath $Path -Raw) | Out-Null
        return $true
    }
    throw "Unknown validator '$Validator'."
}

function Invoke-WgdotAtomicCopy {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [string]$Validator
    )

    $parent = Split-Path -Parent $Destination
    Ensure-WgdotDirectory -Path $parent
    $temp = Join-Path $parent (".wgdot-" + [guid]::NewGuid().ToString("N") + ".tmp")
    try {
        Copy-Item -LiteralPath $Source -Destination $temp -Force
        Test-WgdotFileValidation -Path $temp -Validator $Validator | Out-Null
        Move-Item -LiteralPath $temp -Destination $Destination -Force
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
    }
}

function Invoke-WgdotMerge {
    param([Parameter(Mandatory = $true)]$Item)

    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($null -eq $git) {
        Write-Warning "Git is unavailable; preserving user-modified file: $($Item.Destination)"
        return $false
    }

    $tempRoot = Join-Path $script:CacheRoot ("merge-" + [guid]::NewGuid().ToString("N"))
    Ensure-WgdotDirectory -Path $tempRoot
    $local = Join-Path $tempRoot "local"
    $base = Join-Path $tempRoot "base"
    $remote = Join-Path $tempRoot "remote"
    try {
        Copy-Item -LiteralPath $Item.Destination -Destination $local
        Copy-Item -LiteralPath $Item.Baseline -Destination $base
        Copy-Item -LiteralPath $Item.Target -Destination $remote

        & $git.Source merge-file -- $local $base $remote 2>$null
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            Write-Warning "Merge conflict; preserving local file: $($Item.Destination)"
            return $false
        }
        Test-WgdotFileValidation -Path $local -Validator $Item.Validator | Out-Null
        New-WgdotBackup -Path $Item.Destination -Operation "merge" | Out-Null
        Invoke-WgdotAtomicCopy -Source $local -Destination $Item.Destination -Validator $Item.Validator
        return $true
    } catch {
        Write-Warning "Merge validation failed; preserving local file: $($Item.Destination). $($_.Exception.Message)"
        return $false
    } finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    }
}

function Test-WgdotLegacyMigrationMatch {
    param([Parameter(Mandatory = $true)]$Migration)

    $path = Expand-WgdotPath -Path ([string]$Migration.path)
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { return $false }
    if ([string]$Migration.type -ne "git-remote-directory") { return $false }

    $config = Join-Path $path ".git\config"
    if (-not (Test-Path -LiteralPath $config -PathType Leaf)) { return $false }
    $raw = Get-Content -LiteralPath $config -Raw
    return ($raw.IndexOf([string]$Migration.expectedRemoteFragment, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Invoke-WgdotMigrations {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$Installation,
        [switch]$WhatIfOnly
    )

    $selected = @{}
    foreach ($id in @($Installation.components)) { $selected[[string]$id] = $true }
    foreach ($migration in @($Manifest.migrations)) {
        if (-not $selected.ContainsKey([string]$migration.component)) { continue }
        $path = Expand-WgdotPath -Path ([string]$migration.path)
        if (-not (Test-Path -LiteralPath $path)) { continue }

        if (Test-WgdotLegacyMigrationMatch -Migration $migration) {
            Write-Host "MIGRATION matched: $($migration.id) -> $path"
            if (-not $WhatIfOnly) {
                $backup = New-WgdotBackup -Path $path -Operation "migration"
                Remove-Item -LiteralPath $path -Recurse -Force
                Write-Host "Migration backup: $backup"
            }
        } else {
            Write-Warning "Migration target exists but was not positively identified as WGDot-managed; preserving: $path"
        }
    }
}

function Invoke-WgdotPostActions {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$Installation
    )

    $selected = @{}
    foreach ($id in @($Installation.components)) { $selected[[string]$id] = $true }
    foreach ($component in $Manifest.components) {
        if (-not $selected.ContainsKey([string]$component.id)) { continue }
        if (-not ($component.PSObject.Properties.Name -contains "postActions")) { continue }

        foreach ($post in $component.postActions) {
            if ([string]$post.type -eq "set-yazi-file-one") {
                $candidates = @(
                    (Join-Path $env:ProgramFiles "Git\usr\bin\file.exe"),
                    (Join-Path $env:USERPROFILE "scoop\apps\git\current\usr\bin\file.exe")
                )
                $fileExe = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
                if ($fileExe) {
                    [Environment]::SetEnvironmentVariable("YAZI_FILE_ONE", $fileExe, "User")
                    Write-Host "Set YAZI_FILE_ONE=$fileExe"
                } else {
                    Write-Warning "Git file.exe not found; Yazi MIME detection may be incomplete."
                }
            } elseif ([string]$post.type -eq "yazi-package-install") {
                $ya = Get-Command ya.exe -ErrorAction SilentlyContinue
                if ($null -ne $ya) {
                    & $ya.Source pkg install
                    if ($LASTEXITCODE -ne 0) { Write-Warning "ya pkg install failed." }
                } else {
                    Write-Warning "Yazi package helper 'ya' not found; run 'ya pkg install' manually after Yazi is installed."
                }
            }
        }
    }
}

function Commit-WgdotBaseline {
    param(
        [Parameter(Mandatory = $true)][object[]]$Plan,
        [Parameter(Mandatory = $true)][string]$SourceMode,
        [string]$Tag,
        [Parameter(Mandatory = $true)][string]$Revision,
        [Parameter(Mandatory = $true)]$Installation
    )

    Ensure-WgdotDirectory -Path $script:BaselineRoot
    $index = @()
    foreach ($item in $Plan) {
        $baseline = Get-WgdotBaselinePath -FileId $item.FileId
        if ($null -ne $item.Target -and [bool]$item.CommitTargetBaseline) {
            Copy-Item -LiteralPath $item.Target -Destination $baseline -Force
        }
        if (Test-Path -LiteralPath $baseline -PathType Leaf) {
            $index += [pscustomobject]@{
                fileId = $item.FileId
                component = $item.Component
                destination = $item.Destination
                sha256 = Get-WgdotSha256 -Path $baseline
            }
        }
    }
    Write-WgdotJson -Path $script:BaselineIndexPath -Value ([pscustomobject]@{ files = $index; generatedAt = (Get-Date).ToString("o") })
    if ($SourceMode -eq "stable") {
        Write-WgdotJson -Path $script:ConfigStatePath -Value ([pscustomobject]@{
            mode = "stable"
            tag = $Tag
            revision = $Revision
            appliedAt = (Get-Date).ToString("o")
            glazewmProfile = [string]$Installation.glazewmProfile
        })
    }
}

function Invoke-WgdotPlan {
    param(
        [Parameter(Mandatory = $true)][object[]]$Plan,
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$Installation,
        [Parameter(Mandatory = $true)][string]$SourceMode,
        [string]$Tag,
        [Parameter(Mandatory = $true)][string]$Revision,
        [switch]$ReviewOnly
    )

    Show-WgdotPlan -Plan $Plan
    Invoke-WgdotMigrations -Manifest $Manifest -Installation $Installation -WhatIfOnly
    if ($ReviewOnly) {
        Write-Host ""
        Write-Host "Review only: no changes were applied." -ForegroundColor Green
        return $false
    }

    Write-Host ""
    $confirm = Read-Host "Apply exactly this plan? [y/N]"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "No changes were applied." -ForegroundColor Yellow
        return $false
    }

    foreach ($item in $Plan) {
        if ($item.Action -eq "NONE" -or $item.Action -eq "PRESERVE") { continue }
        if ($item.Action -eq "MERGE") {
            if (Invoke-WgdotMerge -Item $item) {
                $item.CommitTargetBaseline = $true
            }
            continue
        }
        if ($item.Action -eq "REPLACE") {
            New-WgdotBackup -Path $item.Destination -Operation "replace" | Out-Null
        }
        Invoke-WgdotAtomicCopy -Source $item.Target -Destination $item.Destination -Validator $item.Validator
    }

    Invoke-WgdotMigrations -Manifest $Manifest -Installation $Installation
    Invoke-WgdotPostActions -Manifest $Manifest -Installation $Installation
    Commit-WgdotBaseline -Plan $Plan -SourceMode $SourceMode -Tag $Tag -Revision $Revision -Installation $Installation
    Write-Host "WGDot managed configuration applied." -ForegroundColor Green
    return $true
}

function Resolve-WgdotStableSource {
    $release = Get-WgdotStableRelease
    $source = Get-WgdotSourceRoot -Revision $release.Revision
    $manifest = Read-WgdotManifest -SourceRoot $source
    return [pscustomobject]@{ Release = $release; Source = $source; Manifest = $manifest }
}

function Get-WgdotGitRevision {
    param(
        [Parameter(Mandatory = $true)][string]$Branch,
        [string]$Revision
    )

    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($null -eq $git) { throw "Git is required for WGDot Git-testing mode." }

    $tmp = Join-Path $script:CacheRoot "git-verify"
    if (-not (Test-Path -LiteralPath (Join-Path $tmp ".git"))) {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        & $git.Source clone --filter=blob:none --no-checkout $script:RepoUrl $tmp | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not initialize Git-testing verification clone." }
    }

    & $git.Source -C $tmp fetch --prune origin "+refs/heads/*:refs/remotes/origin/*" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not fetch remote branches." }

    $branchRef = "refs/remotes/origin/$Branch"
    $head = (& $git.Source -C $tmp rev-parse --verify $branchRef 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $head -notmatch '^[0-9a-fA-F]{40}$') {
        throw "Remote branch '$Branch' was not found."
    }

    if ([string]::IsNullOrWhiteSpace($Revision)) {
        return $head.ToLowerInvariant()
    }
    if ($Revision -notmatch '^[0-9a-fA-F]{40}$') {
        throw "Exact Git-testing revision must be a full 40-character SHA."
    }

    & $git.Source -C $tmp cat-file -e "$Revision^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Commit '$Revision' is unavailable after fetching the selected repository." }
    & $git.Source -C $tmp merge-base --is-ancestor $Revision $branchRef
    if ($LASTEXITCODE -ne 0) { throw "Commit '$Revision' does not belong to branch '$Branch'." }
    return $Revision.ToLowerInvariant()
}

function Invoke-WgdotManagedOperation {
    param(
        [ValidateSet("update", "reset", "review")][string]$Mode,
        [ValidateSet("stable", "git")][string]$SourceMode = "stable",
        [string]$Branch,
        [string]$Revision
    )

    Initialize-WgdotStateDirectories
    $previousStable = $null
    $previousConfig = Read-WgdotJson -Path $script:ConfigStatePath
    if ($null -ne $previousConfig -and [string]$previousConfig.mode -eq "stable") {
        $previousStable = [string]$previousConfig.tag
    } else {
        $previousGit = Read-WgdotJson -Path $script:GitStatePath
        if ($null -ne $previousGit -and $previousGit.PSObject.Properties.Name -contains "stableRelease") {
            $previousStable = [string]$previousGit.stableRelease
        }
    }

    if ($SourceMode -eq "stable") {
        $resolved = Resolve-WgdotStableSource
        $sourceRoot = $resolved.Source
        $manifest = $resolved.Manifest
        $sourceRevision = [string]$resolved.Release.Revision
        $tag = [string]$resolved.Release.Tag
    } else {
        if ([string]::IsNullOrWhiteSpace($Branch)) { throw "Git-testing requires a branch." }
        $sourceRevision = Get-WgdotGitRevision -Branch $Branch -Revision $Revision
        $sourceRoot = Get-WgdotSourceRoot -Revision $sourceRevision
        $manifest = Read-WgdotManifest -SourceRoot $sourceRoot
        $tag = $null
    }

    $installation = Read-WgdotJson -Path $script:InstallStatePath
    $selectionChanged = $false
    if ($null -eq $installation -or $Mode -eq "reset") {
        $installation = New-WgdotInstallationSelection -Manifest $manifest
        if ($null -eq $installation) { return }
        $selectionChanged = $true
    }

    $hasBaseline = Test-Path -LiteralPath $script:BaselineIndexPath -PathType Leaf
    $effectiveMode = if ($Mode -eq "reset" -or -not $hasBaseline) { "reset" } else { "update" }
    $plan = @(Get-WgdotPlan -Manifest $manifest -SourceRoot $sourceRoot -Installation $installation -Mode $effectiveMode)
    $review = ($Mode -eq "review") -or $ReviewOnly
    $applied = Invoke-WgdotPlan -Plan $plan -Manifest $manifest -Installation $installation -SourceMode $SourceMode -Tag $tag -Revision $sourceRevision -ReviewOnly:$review

    if ($review -or -not $applied) {
        return
    }

    if ($selectionChanged) {
        Write-WgdotJson -Path $script:InstallStatePath -Value $installation
    }

    if ($SourceMode -eq "git") {
        Write-WgdotJson -Path $script:GitStatePath -Value ([pscustomobject]@{
            branch = $Branch
            revision = $sourceRevision
            stableRelease = $previousStable
            testedAt = (Get-Date).ToString("o")
        })
    } elseif (Test-Path -LiteralPath $script:GitStatePath) {
        Remove-Item -LiteralPath $script:GitStatePath -Force
    }
}

function Test-WgdotPackageAvailable {
    param([Parameter(Mandatory = $true)][string]$PackageId)
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($null -eq $winget) { throw "WinGet was not found." }
    & $winget.Source show --id $PackageId --exact --source winget --accept-source-agreements *> $null
    return ($LASTEXITCODE -eq 0)
}

function Invoke-WgdotSoftwareReconcile {
    Initialize-WgdotStateDirectories
    $installation = Read-WgdotJson -Path $script:InstallStatePath
    $resolved = Resolve-WgdotStableSource
    $manifest = $resolved.Manifest
    if ($null -eq $installation) {
        $installation = New-WgdotInstallationSelection -Manifest $manifest
        if ($null -eq $installation) { return }
        Write-WgdotJson -Path $script:InstallStatePath -Value $installation
    }

    $wanted = @{}
    foreach ($id in @($installation.packages)) { $wanted[[string]$id] = $true }
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($null -eq $winget) { throw "WinGet was not found." }

    foreach ($package in $manifest.packages) {
        $id = [string]$package.id
        if (-not $wanted.ContainsKey($id)) { continue }
        Write-Host "Checking $id..."
        if (-not (Test-WgdotPackageAvailable -PackageId $id)) {
            Write-Warning "WinGet package not currently available by exact ID: $id"
            continue
        }
        $installedOutput = (& $winget.Source list --id $id --exact --source winget --accept-source-agreements 2>$null | Out-String)
        if ($installedOutput.IndexOf($id, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            Write-Host "Installing $id"
            & $winget.Source install --id $id --exact --source winget --accept-source-agreements --accept-package-agreements
        }
    }

    Write-Host ""
    $answer = Read-Host "Check selected packages for upgrades now? [y/N]"
    if ($answer -match '^[Yy]$') {
        foreach ($package in $manifest.packages) {
            $id = [string]$package.id
            if (-not $wanted.ContainsKey($id)) { continue }
            $upgradeOutput = (& $winget.Source list --id $id --exact --upgrade-available --source winget --accept-source-agreements 2>$null | Out-String)
            if ($upgradeOutput.IndexOf($id, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
            $approve = Read-Host "Upgrade $id? [y/N]"
            if ($approve -match '^[Yy]$') {
                & $winget.Source upgrade --id $id --exact --source winget --accept-source-agreements --accept-package-agreements
            }
        }
    }
}

function Convert-WgdotPlanToPowerShell {
    param([Parameter(Mandatory = $true)][object[]]$Plan)

    Write-Host "# Pasteable PowerShell generated from the same WGDot plan"
    Write-Host '$ErrorActionPreference = "Stop"'
    foreach ($item in $Plan) {
        $dest = $item.Destination.Replace("'", "''")
        if ($item.Action -eq "NONE" -or $item.Action -eq "PRESERVE") {
            Write-Host "# $($item.Status): preserve '$dest'"
            continue
        }
        $src = ([string]$item.Target).Replace("'", "''")
        Write-Host "`$dest = '$dest'"
        Write-Host "`$src = '$src'"
        Write-Host "New-Item -ItemType Directory -Force -Path (Split-Path -Parent `$dest) | Out-Null"
        Write-Host "if (Test-Path -LiteralPath `$dest) {"
        Write-Host '    $backup = "$dest.wgdot.backup"'
        Write-Host '    if (Test-Path -LiteralPath $backup) { $backup = "$dest.wgdot.backup.$(Get-Date -Format ''yyyyMMdd-HHmmss'')" }' 
        Write-Host "    Copy-Item -LiteralPath `$dest -Destination `$backup"
        Write-Host "}"
        Write-Host "Copy-Item -LiteralPath `$src -Destination `$dest -Force"
        Write-Host ""
    }
}

function Show-WgdotManualCommands {
    $resolved = Resolve-WgdotStableSource
    $installation = Read-WgdotJson -Path $script:InstallStatePath
    if ($null -eq $installation) {
        $installation = New-WgdotInstallationSelection -Manifest $resolved.Manifest
        if ($null -eq $installation) { return }
    }
    $mode = if ($null -eq (Read-WgdotJson -Path $script:ConfigStatePath)) { "reset" } else { "update" }
    $plan = @(Get-WgdotPlan -Manifest $resolved.Manifest -SourceRoot $resolved.Source -Installation $installation -Mode $mode)
    Convert-WgdotPlanToPowerShell -Plan $plan
}

function Show-WgdotBackupManager {
    Initialize-WgdotStateDirectories
    $state = Read-WgdotJson -Path $script:BackupStatePath
    $records = @()
    if ($null -ne $state -and $state.PSObject.Properties.Name -contains "records") {
        $records = @($state.records | Where-Object { Test-Path -LiteralPath ([string]$_.backup) })
    }
    Write-WgdotTitle -Subtitle "Backup manager"
    if ($records.Count -eq 0) {
        Write-Host "No recorded WGDot backups exist."
        [Console]::ReadKey($true) | Out-Null
        return
    }

    $ageText = Read-Host "Only show backups older than N days (blank = all)"
    if (-not [string]::IsNullOrWhiteSpace($ageText)) {
        $days = 0
        if (-not [int]::TryParse($ageText, [ref]$days) -or $days -lt 0) {
            Write-Warning "Invalid age filter; showing all backups."
        } else {
            $cutoff = (Get-Date).AddDays(-$days)
            $records = @($records | Where-Object { [datetime]$_.createdAt -lt $cutoff })
        }
    }

    if ($records.Count -eq 0) {
        Write-Host "No WGDot backups match that filter."
        [Console]::ReadKey($true) | Out-Null
        return
    }

    $choices = @()
    for ($i = 0; $i -lt $records.Count; $i++) {
        $record = $records[$i]
        $choices += [pscustomobject]@{
            Id = [string]$i
            Label = "$($record.createdAt)  $($record.backup)"
            Selected = $false
        }
    }
    $choices = Read-WgdotMultiChoice -Title "Select WGDot backups to delete" -Items $choices
    if ($null -eq $choices) { return }
    $selected = @($choices | Where-Object { $_.Selected })
    if ($selected.Count -eq 0) { return }

    Write-WgdotTitle -Subtitle "Backup cleanup review"
    foreach ($choice in $selected) {
        Write-Host "DELETE  $($records[[int]$choice.Id].backup)"
    }
    Write-Host ""
    Write-Host "Dry-run complete. Nothing has been deleted yet." -ForegroundColor Yellow
    $confirm = Read-Host "Delete exactly these recorded WGDot backups? [y/N]"
    if ($confirm -notmatch '^[Yy]$') { return }

    $deleteSet = @{}
    foreach ($choice in $selected) {
        $record = $records[[int]$choice.Id]
        $deleteSet[[string]$record.backup] = $true
        if (Test-Path -LiteralPath ([string]$record.backup) -PathType Container) {
            Remove-Item -LiteralPath ([string]$record.backup) -Recurse -Force
        } elseif (Test-Path -LiteralPath ([string]$record.backup) -PathType Leaf) {
            Remove-Item -LiteralPath ([string]$record.backup) -Force
        }
    }

    $allRecords = @()
    if ($null -ne $state -and $state.PSObject.Properties.Name -contains "records") { $allRecords = @($state.records) }
    $remaining = @($allRecords | Where-Object { -not $deleteSet.ContainsKey([string]$_.backup) })
    Write-WgdotJson -Path $script:BackupStatePath -Value ([pscustomobject]@{ records = $remaining })
    Write-Host "Selected WGDot backups deleted." -ForegroundColor Green
    [Console]::ReadKey($true) | Out-Null
}

function Show-WgdotStatus {
    Write-WgdotTitle -Subtitle "Version / status"
    $runtime = Read-WgdotJson -Path $script:RuntimeStatePath
    $config = Read-WgdotJson -Path $script:ConfigStatePath
    $install = Read-WgdotJson -Path $script:InstallStatePath
    $git = Read-WgdotJson -Path $script:GitStatePath
    Write-Host "Runtime:    $($runtime | ConvertTo-Json -Compress)"
    Write-Host "Config:     $($config | ConvertTo-Json -Compress)"
    Write-Host "Selection:  $($install | ConvertTo-Json -Compress -Depth 10)"
    Write-Host "Git test:   $($git | ConvertTo-Json -Compress)"
    Write-Host ""
    Write-Host "Press any key to return."
    [Console]::ReadKey($true) | Out-Null
}

function Show-WgdotGitMenu {
    $branchName = Read-Host "Remote branch"
    if ([string]::IsNullOrWhiteSpace($branchName)) { return }
    $exact = Read-Host "Exact 40-character commit (optional; Enter uses branch head)"
    $modeIndex = Read-WgdotSingleChoice -Title "Git-testing operation" -Items @("Review", "Update", "Reset")
    if ($modeIndex -lt 0) { return }
    $mode = @("review", "update", "reset")[$modeIndex]
    Invoke-WgdotManagedOperation -Mode $mode -SourceMode git -Branch $branchName -Revision $exact
    Write-Host ""
    Write-Host "Press any key to continue."
    [Console]::ReadKey($true) | Out-Null
}

function Show-WgdotMenu {
    Initialize-WgdotStateDirectories
    try {
        $refreshed = Update-WgdotRuntimeFromMain
        if ($refreshed -and (Test-Path -LiteralPath $script:RuntimeScriptPath -PathType Leaf)) {
            Write-Host "Restarting with refreshed WGDot runtime..."
            & powershell.exe -NoLogo -NoProfile -File $script:RuntimeScriptPath menu
            return
        }
    } catch {
        Write-Warning "Runtime refresh check failed: $($_.Exception.Message)"
    }

    while ($true) {
        $items = @(
            "Update managed dots",
            "Install / reconcile software",
            "Reset / reconfigure managed dots",
            "Review changes without applying",
            "Backup manager",
            "Manual PowerShell commands",
            "Version / status",
            "Advanced / Git testing",
            "Exit"
        )
        $choice = Read-WgdotSingleChoice -Title "Maintenance" -Items $items
        if ($choice -lt 0 -or $choice -eq 8) { return }
        try {
            if ($choice -eq 0) { Invoke-WgdotManagedOperation -Mode update -SourceMode stable }
            elseif ($choice -eq 1) { Invoke-WgdotSoftwareReconcile }
            elseif ($choice -eq 2) { Invoke-WgdotManagedOperation -Mode reset -SourceMode stable }
            elseif ($choice -eq 3) { Invoke-WgdotManagedOperation -Mode review -SourceMode stable }
            elseif ($choice -eq 4) { Show-WgdotBackupManager }
            elseif ($choice -eq 5) { Write-WgdotTitle -Subtitle "Manual PowerShell commands"; Show-WgdotManualCommands; Write-Host ""; Write-Host "Press any key to return."; [Console]::ReadKey($true) | Out-Null }
            elseif ($choice -eq 6) { Show-WgdotStatus }
            elseif ($choice -eq 7) { Show-WgdotGitMenu }
        } catch {
            Write-Host ""
            Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Press any key to return."
            [Console]::ReadKey($true) | Out-Null
        }
    }
}

if ($env:WGDOT_TEST_MODE -ne "1") {
    switch ($Command.ToLowerInvariant()) {
        "menu" { Show-WgdotMenu }
        "install" { Install-WgdotRuntime }
        "update" { Invoke-WgdotManagedOperation -Mode update -SourceMode stable }
        "reset" { Invoke-WgdotManagedOperation -Mode reset -SourceMode stable }
        "review" { Invoke-WgdotManagedOperation -Mode review -SourceMode stable }
        "software" { Invoke-WgdotSoftwareReconcile }
        "manual" { Show-WgdotManualCommands }
        "git" {
            if ([string]::IsNullOrWhiteSpace($Branch)) { throw "Use -Branch with the git command." }
            Invoke-WgdotManagedOperation -Mode $(if ($ReviewOnly) { "review" } else { "update" }) -SourceMode git -Branch $Branch -Revision $Revision
        }
        default { throw "Unknown WGDot command '$Command'. Run wgdot with no arguments for the menu." }
    }
}
) {
        Write-Host "No changes were applied." -ForegroundColor Yellow
        return $false
    }

    foreach ($item in $Plan) {
        if ($item.Action -eq "NONE" -or $item.Action -eq "PRESERVE") { continue }
        if ($item.Action -eq "MERGE") {
            if (Invoke-WgdotMerge -Item $item) {
                $item.CommitTargetBaseline = $true
            }
            continue
        }
        if ($item.Action -eq "REPLACE") {
            New-WgdotBackup -Path $item.Destination -Operation "replace" | Out-Null
        }
        Invoke-WgdotAtomicCopy -Source $item.Target -Destination $item.Destination -Validator $item.Validator
    }

    Invoke-WgdotPostActions -Manifest $Manifest -Installation $Installation
    Commit-WgdotBaseline -Plan $Plan -SourceMode $SourceMode -Tag $Tag -Revision $Revision -Installation $Installation
    Write-Host "WGDot managed configuration applied." -ForegroundColor Green
}

function Resolve-WgdotStableSource {
    $release = Get-WgdotStableRelease
    $source = Get-WgdotSourceRoot -Revision $release.Revision
    $manifest = Read-WgdotManifest -SourceRoot $source
    return [pscustomobject]@{ Release = $release; Source = $source; Manifest = $manifest }
}

function Get-WgdotGitRevision {
    param(
        [Parameter(Mandatory = $true)][string]$Branch,
        [string]$Revision
    )

    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($null -eq $git) { throw "Git is required for WGDot Git-testing mode." }

    $tmp = Join-Path $script:CacheRoot "git-verify"
    if (-not (Test-Path -LiteralPath (Join-Path $tmp ".git"))) {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        & $git.Source clone --filter=blob:none --no-checkout $script:RepoUrl $tmp | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not initialize Git-testing verification clone." }
    }

    & $git.Source -C $tmp fetch --prune origin "+refs/heads/*:refs/remotes/origin/*" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not fetch remote branches." }

    $branchRef = "refs/remotes/origin/$Branch"
    $head = (& $git.Source -C $tmp rev-parse --verify $branchRef 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $head -notmatch '^[0-9a-fA-F]{40}$') {
        throw "Remote branch '$Branch' was not found."
    }

    if ([string]::IsNullOrWhiteSpace($Revision)) {
        return $head.ToLowerInvariant()
    }
    if ($Revision -notmatch '^[0-9a-fA-F]{40}$') {
        throw "Exact Git-testing revision must be a full 40-character SHA."
    }

    & $git.Source -C $tmp cat-file -e "$Revision^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Commit '$Revision' is unavailable after fetching the selected repository." }
    & $git.Source -C $tmp merge-base --is-ancestor $Revision $branchRef
    if ($LASTEXITCODE -ne 0) { throw "Commit '$Revision' does not belong to branch '$Branch'." }
    return $Revision.ToLowerInvariant()
}

function Invoke-WgdotManagedOperation {
    param(
        [ValidateSet("update", "reset", "review")][string]$Mode,
        [ValidateSet("stable", "git")][string]$SourceMode = "stable",
        [string]$Branch,
        [string]$Revision
    )

    Initialize-WgdotStateDirectories
    if ($SourceMode -eq "stable") {
        $resolved = Resolve-WgdotStableSource
        $sourceRoot = $resolved.Source
        $manifest = $resolved.Manifest
        $sourceRevision = [string]$resolved.Release.Revision
        $tag = [string]$resolved.Release.Tag
    } else {
        if ([string]::IsNullOrWhiteSpace($Branch)) { throw "Git-testing requires a branch." }
        $sourceRevision = Get-WgdotGitRevision -Branch $Branch -Revision $Revision
        $sourceRoot = Get-WgdotSourceRoot -Revision $sourceRevision
        $manifest = Read-WgdotManifest -SourceRoot $sourceRoot
        $tag = $null
        $previousConfig = Read-WgdotJson -Path $script:ConfigStatePath
        $previousStable = $null
        if ($null -ne $previousConfig -and [string]$previousConfig.mode -eq "stable") {
            $previousStable = [string]$previousConfig.tag
        }
        Write-WgdotJson -Path $script:GitStatePath -Value ([pscustomobject]@{
            branch = $Branch
            revision = $sourceRevision
            stableRelease = $previousStable
            testedAt = (Get-Date).ToString("o")
        })
    }

    $installation = Read-WgdotJson -Path $script:InstallStatePath
    if ($null -eq $installation -or $Mode -eq "reset") {
        $installation = New-WgdotInstallationSelection -Manifest $manifest
        if ($null -eq $installation) { return }
        Write-WgdotJson -Path $script:InstallStatePath -Value $installation
    }

    $effectiveMode = if ($Mode -eq "reset" -or $null -eq (Read-WgdotJson -Path $script:ConfigStatePath)) { "reset" } else { "update" }
    $plan = @(Get-WgdotPlan -Manifest $manifest -SourceRoot $sourceRoot -Installation $installation -Mode $effectiveMode)
    $review = ($Mode -eq "review") -or $ReviewOnly
    Invoke-WgdotPlan -Plan $plan -Manifest $manifest -Installation $installation -SourceMode $SourceMode -Tag $tag -Revision $sourceRevision -ReviewOnly:$review

    if (-not $review -and $SourceMode -eq "stable" -and (Test-Path -LiteralPath $script:GitStatePath)) {
        Remove-Item -LiteralPath $script:GitStatePath -Force
    }
}

function Test-WgdotPackageAvailable {
    param([Parameter(Mandatory = $true)][string]$PackageId)
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($null -eq $winget) { throw "WinGet was not found." }
    & $winget.Source show --id $PackageId --exact --source winget --accept-source-agreements *> $null
    return ($LASTEXITCODE -eq 0)
}

function Invoke-WgdotSoftwareReconcile {
    Initialize-WgdotStateDirectories
    $installation = Read-WgdotJson -Path $script:InstallStatePath
    $resolved = Resolve-WgdotStableSource
    $manifest = $resolved.Manifest
    if ($null -eq $installation) {
        $installation = New-WgdotInstallationSelection -Manifest $manifest
        if ($null -eq $installation) { return }
        Write-WgdotJson -Path $script:InstallStatePath -Value $installation
    }

    $wanted = @{}
    foreach ($id in @($installation.packages)) { $wanted[[string]$id] = $true }
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($null -eq $winget) { throw "WinGet was not found." }

    foreach ($package in $manifest.packages) {
        $id = [string]$package.id
        if (-not $wanted.ContainsKey($id)) { continue }
        Write-Host "Checking $id..."
        if (-not (Test-WgdotPackageAvailable -PackageId $id)) {
            Write-Warning "WinGet package not currently available by exact ID: $id"
            continue
        }
        $installedOutput = (& $winget.Source list --id $id --exact --source winget --accept-source-agreements 2>$null | Out-String)
        if ($installedOutput.IndexOf($id, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            Write-Host "Installing $id"
            & $winget.Source install --id $id --exact --source winget --accept-source-agreements --accept-package-agreements
        }
    }

    Write-Host ""
    $answer = Read-Host "Check selected packages for upgrades now? [y/N]"
    if ($answer -match '^[Yy]$') {
        foreach ($package in $manifest.packages) {
            $id = [string]$package.id
            if (-not $wanted.ContainsKey($id)) { continue }
            $upgradeOutput = (& $winget.Source list --id $id --exact --upgrade-available --source winget --accept-source-agreements 2>$null | Out-String)
            if ($upgradeOutput.IndexOf($id, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
            $approve = Read-Host "Upgrade $id? [y/N]"
            if ($approve -match '^[Yy]$') {
                & $winget.Source upgrade --id $id --exact --source winget --accept-source-agreements --accept-package-agreements
            }
        }
    }
}

function Convert-WgdotPlanToPowerShell {
    param([Parameter(Mandatory = $true)][object[]]$Plan)

    Write-Host "# Pasteable PowerShell generated from the same WGDot plan"
    Write-Host '$ErrorActionPreference = "Stop"'
    foreach ($item in $Plan) {
        $dest = $item.Destination.Replace("'", "''")
        if ($item.Action -eq "NONE" -or $item.Action -eq "PRESERVE") {
            Write-Host "# $($item.Status): preserve '$dest'"
            continue
        }
        $src = ([string]$item.Target).Replace("'", "''")
        Write-Host "`$dest = '$dest'"
        Write-Host "`$src = '$src'"
        Write-Host "New-Item -ItemType Directory -Force -Path (Split-Path -Parent `$dest) | Out-Null"
        Write-Host "if (Test-Path -LiteralPath `$dest) {"
        Write-Host '    $backup = "$dest.wgdot.backup"'
        Write-Host '    if (Test-Path -LiteralPath $backup) { $backup = "$dest.wgdot.backup.$(Get-Date -Format ''yyyyMMdd-HHmmss'')" }' 
        Write-Host "    Copy-Item -LiteralPath `$dest -Destination `$backup"
        Write-Host "}"
        Write-Host "Copy-Item -LiteralPath `$src -Destination `$dest -Force"
        Write-Host ""
    }
}

function Show-WgdotManualCommands {
    $resolved = Resolve-WgdotStableSource
    $installation = Read-WgdotJson -Path $script:InstallStatePath
    if ($null -eq $installation) {
        $installation = New-WgdotInstallationSelection -Manifest $resolved.Manifest
        if ($null -eq $installation) { return }
    }
    $mode = if ($null -eq (Read-WgdotJson -Path $script:ConfigStatePath)) { "reset" } else { "update" }
    $plan = @(Get-WgdotPlan -Manifest $resolved.Manifest -SourceRoot $resolved.Source -Installation $installation -Mode $mode)
    Convert-WgdotPlanToPowerShell -Plan $plan
}

function Show-WgdotBackupManager {
    Initialize-WgdotStateDirectories
    $state = Read-WgdotJson -Path $script:BackupStatePath
    $records = @()
    if ($null -ne $state -and $state.PSObject.Properties.Name -contains "records") {
        $records = @($state.records | Where-Object { Test-Path -LiteralPath ([string]$_.backup) })
    }
    Write-WgdotTitle -Subtitle "Backup manager"
    if ($records.Count -eq 0) {
        Write-Host "No recorded WGDot backups exist."
        [Console]::ReadKey($true) | Out-Null
        return
    }

    $ageText = Read-Host "Only show backups older than N days (blank = all)"
    if (-not [string]::IsNullOrWhiteSpace($ageText)) {
        $days = 0
        if (-not [int]::TryParse($ageText, [ref]$days) -or $days -lt 0) {
            Write-Warning "Invalid age filter; showing all backups."
        } else {
            $cutoff = (Get-Date).AddDays(-$days)
            $records = @($records | Where-Object { [datetime]$_.createdAt -lt $cutoff })
        }
    }

    if ($records.Count -eq 0) {
        Write-Host "No WGDot backups match that filter."
        [Console]::ReadKey($true) | Out-Null
        return
    }

    $choices = @()
    for ($i = 0; $i -lt $records.Count; $i++) {
        $record = $records[$i]
        $choices += [pscustomobject]@{
            Id = [string]$i
            Label = "$($record.createdAt)  $($record.backup)"
            Selected = $false
        }
    }
    $choices = Read-WgdotMultiChoice -Title "Select WGDot backups to delete" -Items $choices
    if ($null -eq $choices) { return }
    $selected = @($choices | Where-Object { $_.Selected })
    if ($selected.Count -eq 0) { return }

    Write-WgdotTitle -Subtitle "Backup cleanup review"
    foreach ($choice in $selected) {
        Write-Host "DELETE  $($records[[int]$choice.Id].backup)"
    }
    Write-Host ""
    Write-Host "Dry-run complete. Nothing has been deleted yet." -ForegroundColor Yellow
    $confirm = Read-Host "Delete exactly these recorded WGDot backups? [y/N]"
    if ($confirm -notmatch '^[Yy]$') { return }

    $deleteSet = @{}
    foreach ($choice in $selected) {
        $record = $records[[int]$choice.Id]
        $deleteSet[[string]$record.backup] = $true
        if (Test-Path -LiteralPath ([string]$record.backup) -PathType Leaf) {
            Remove-Item -LiteralPath ([string]$record.backup) -Force
        }
    }

    $allRecords = @()
    if ($null -ne $state -and $state.PSObject.Properties.Name -contains "records") { $allRecords = @($state.records) }
    $remaining = @($allRecords | Where-Object { -not $deleteSet.ContainsKey([string]$_.backup) })
    Write-WgdotJson -Path $script:BackupStatePath -Value ([pscustomobject]@{ records = $remaining })
    Write-Host "Selected WGDot backups deleted." -ForegroundColor Green
    [Console]::ReadKey($true) | Out-Null
}

function Show-WgdotStatus {
    Write-WgdotTitle -Subtitle "Version / status"
    $runtime = Read-WgdotJson -Path $script:RuntimeStatePath
    $config = Read-WgdotJson -Path $script:ConfigStatePath
    $install = Read-WgdotJson -Path $script:InstallStatePath
    $git = Read-WgdotJson -Path $script:GitStatePath
    Write-Host "Runtime:    $($runtime | ConvertTo-Json -Compress)"
    Write-Host "Config:     $($config | ConvertTo-Json -Compress)"
    Write-Host "Selection:  $($install | ConvertTo-Json -Compress -Depth 10)"
    Write-Host "Git test:   $($git | ConvertTo-Json -Compress)"
    Write-Host ""
    Write-Host "Press any key to return."
    [Console]::ReadKey($true) | Out-Null
}

function Show-WgdotGitMenu {
    $branchName = Read-Host "Remote branch"
    if ([string]::IsNullOrWhiteSpace($branchName)) { return }
    $exact = Read-Host "Exact 40-character commit (optional; Enter uses branch head)"
    $modeIndex = Read-WgdotSingleChoice -Title "Git-testing operation" -Items @("Review", "Update", "Reset")
    if ($modeIndex -lt 0) { return }
    $mode = @("review", "update", "reset")[$modeIndex]
    Invoke-WgdotManagedOperation -Mode $mode -SourceMode git -Branch $branchName -Revision $exact
    Write-Host ""
    Write-Host "Press any key to continue."
    [Console]::ReadKey($true) | Out-Null
}

function Show-WgdotMenu {
    Initialize-WgdotStateDirectories
    try {
        $refreshed = Update-WgdotRuntimeFromMain
        if ($refreshed -and (Test-Path -LiteralPath $script:RuntimeScriptPath -PathType Leaf)) {
            Write-Host "Restarting with refreshed WGDot runtime..."
            & powershell.exe -NoLogo -NoProfile -File $script:RuntimeScriptPath menu
            return
        }
    } catch {
        Write-Warning "Runtime refresh check failed: $($_.Exception.Message)"
    }

    while ($true) {
        $items = @(
            "Update managed dots",
            "Install / reconcile software",
            "Reset / reconfigure managed dots",
            "Review changes without applying",
            "Backup manager",
            "Manual PowerShell commands",
            "Version / status",
            "Advanced / Git testing",
            "Exit"
        )
        $choice = Read-WgdotSingleChoice -Title "Maintenance" -Items $items
        if ($choice -lt 0 -or $choice -eq 8) { return }
        try {
            if ($choice -eq 0) { Invoke-WgdotManagedOperation -Mode update -SourceMode stable }
            elseif ($choice -eq 1) { Invoke-WgdotSoftwareReconcile }
            elseif ($choice -eq 2) { Invoke-WgdotManagedOperation -Mode reset -SourceMode stable }
            elseif ($choice -eq 3) { Invoke-WgdotManagedOperation -Mode review -SourceMode stable }
            elseif ($choice -eq 4) { Show-WgdotBackupManager }
            elseif ($choice -eq 5) { Write-WgdotTitle -Subtitle "Manual PowerShell commands"; Show-WgdotManualCommands; Write-Host ""; Write-Host "Press any key to return."; [Console]::ReadKey($true) | Out-Null }
            elseif ($choice -eq 6) { Show-WgdotStatus }
            elseif ($choice -eq 7) { Show-WgdotGitMenu }
        } catch {
            Write-Host ""
            Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Press any key to return."
            [Console]::ReadKey($true) | Out-Null
        }
    }
}

if ($env:WGDOT_TEST_MODE -ne "1") {
    switch ($Command.ToLowerInvariant()) {
        "menu" { Show-WgdotMenu }
        "install" { Install-WgdotRuntime }
        "update" { Invoke-WgdotManagedOperation -Mode update -SourceMode stable }
        "reset" { Invoke-WgdotManagedOperation -Mode reset -SourceMode stable }
        "review" { Invoke-WgdotManagedOperation -Mode review -SourceMode stable }
        "software" { Invoke-WgdotSoftwareReconcile }
        "manual" { Show-WgdotManualCommands }
        "git" {
            if ([string]::IsNullOrWhiteSpace($Branch)) { throw "Use -Branch with the git command." }
            Invoke-WgdotManagedOperation -Mode $(if ($ReviewOnly) { "review" } else { "update" }) -SourceMode git -Branch $Branch -Revision $Revision
        }
        default { throw "Unknown WGDot command '$Command'. Run wgdot with no arguments for the menu." }
    }
}

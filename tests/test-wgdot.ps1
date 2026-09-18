$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$runtimePath = Join-Path $repoRoot "wgdot\wgdot.ps1"
$manifestPath = Join-Path $repoRoot "wgdot\manifest.json"
$manualPath = Join-Path $repoRoot "MANUAL_POWERSHELL.md"

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

$env:WGDOT_TEST_MODE = "1"
. $runtimePath

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-Equal 1 ([int]$manifest.schemaVersion) "manifest schema"
Assert-Equal "dillacorn/win-glaze-dots" ([string]$manifest.runtime.repository) "repository identity"

$componentIds = @($manifest.components | ForEach-Object { [string]$_.id })
Assert-True ($componentIds -contains "glazewm") "GlazeWM component exists"
Assert-True ($componentIds -contains "yazi") "Yazi component exists"
Assert-True ($componentIds -contains "doublecmd") "Double Commander component exists"

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
Assert-True ($packageIds.ContainsKey("microsoft.sysinternals.processexplorer")) "correct Process Explorer ID is cataloged"

$runtimeText = Get-Content -LiteralPath $runtimePath -Raw
$manualText = Get-Content -LiteralPath $manualPath -Raw
Assert-True ($runtimeText -notmatch '(?i)-ExecutionPolicy\s+Bypass') "runtime does not bypass execution policy"
Assert-True ($manualText -notmatch '(?i)-ExecutionPolicy\s+Bypass') "manual path does not bypass execution policy"
Assert-True ($runtimeText -notmatch '(?i)winget\s+upgrade\s+--all') "runtime never upgrades all WinGet packages"
Assert-True ($manualText -notmatch '(?i)winget\s+upgrade\s+--all') "manual path never upgrades all WinGet packages"
Assert-True ($runtimeText -notmatch '(?i)rmdir\s+/s') "runtime does not use destructive CMD directory removal"

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
    $removedManifest = [pscustomobject]@{ components = @(); migrations = @() }
    $removedInstallation = [pscustomobject]@{ components = @(); glazewmProfile = "normal" }
    $removedPlan = @(Get-WgdotPlan -Manifest $removedManifest -SourceRoot $sourceRoot -Installation $removedInstallation -Mode update)
    Assert-Equal "REMOVED-UPSTREAM" $removedPlan[0].Status "upstream removal is tracked"
    Assert-Equal "PRESERVE" $removedPlan[0].Action "upstream removal preserves live file"
    Assert-True (-not [bool]$removedPlan[0].CommitTargetBaseline) "removed-upstream does not advance baseline"

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
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "WGDot tests passed." -ForegroundColor Green

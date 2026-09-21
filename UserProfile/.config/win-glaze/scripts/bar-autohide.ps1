param(
    [ValidateSet('toggle','show','hide')]
    [string]$Mode = 'toggle'
)

$ErrorActionPreference = 'Stop'

$yasbPath = Join-Path $env:USERPROFILE '.config\yasb\config.yaml'
$glazePath = Join-Path $env:USERPROFILE '.glzr\glazewm\config.yaml'

if (-not (Test-Path -LiteralPath $yasbPath)) { throw "YASB config not found: $yasbPath" }
if (-not (Test-Path -LiteralPath $glazePath)) { throw "GlazeWM config not found: $glazePath" }

$yasb = [IO.File]::ReadAllText($yasbPath)
$glaze = [IO.File]::ReadAllText($glazePath)

$autoMatches = [regex]::Matches($yasb, '(?m)^(\s*)auto_hide:\s*(true|false)\s*$')
if ($autoMatches.Count -ne 1) { throw "Expected exactly one YASB auto_hide setting; found $($autoMatches.Count)." }

$currentHidden = $autoMatches[0].Groups[2].Value -ieq 'true'
$hide = switch ($Mode) {
    'show' { $false }
    'hide' { $true }
    default { -not $currentHidden }
}

$yasbNext = [regex]::Replace(
    $yasb,
    '(?m)^(\s*)auto_hide:\s*(true|false)\s*$',
    ('$1auto_hide: ' + $(if ($hide) { 'true' } else { 'false' }))
)

$gapMatches = [regex]::Matches($glaze, '(?m)^(\s*)top:\s*"(5|35)px"\s*$')
if ($gapMatches.Count -ne 1) { throw "Expected exactly one GlazeWM top gap of 5px or 35px; found $($gapMatches.Count)." }

$targetGap = if ($hide) { '5' } else { '35' }
$glazeNext = [regex]::Replace(
    $glaze,
    '(?m)^(\s*)top:\s*"(5|35)px"\s*$',
    ('$1top: "' + $targetGap + 'px"')
)

$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($yasbPath, $yasbNext, $utf8)
[IO.File]::WriteAllText($glazePath, $glazeNext, $utf8)

$yasbc = Get-Command yasbc.exe -ErrorAction SilentlyContinue
if ($yasbc) { & $yasbc.Source reload -s }

$glazeExe = Get-Command glazewm.exe -ErrorAction SilentlyContinue
if ($glazeExe) { & $glazeExe.Source command wm-reload-config | Out-Null }

Write-Host ('Bar auto-hide: ' + $(if ($hide) { 'enabled' } else { 'disabled' }))

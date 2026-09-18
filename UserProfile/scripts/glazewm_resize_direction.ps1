param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("left", "right", "up", "down")]
    [string]$Direction,

    [ValidateRange(1, 50)]
    [int]$Step = 2
)

$ErrorActionPreference = "Stop"

$glazewm = (Get-Command glazewm.exe -ErrorAction Stop).Source

function Invoke-GlazeQuery {
    param([string]$Name)

    $raw = & $glazewm query $Name 2>$null | Out-String
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "GlazeWM query '$Name' returned no data."
    }

    $response = $raw | ConvertFrom-Json
    if (-not $response.success) {
        throw "GlazeWM query '$Name' failed: $($response.error)"
    }

    return $response.data
}

function Get-WorkspaceWindows {
    param($Node)

    $result = @()

    foreach ($child in @($Node.children)) {
        if ($child.type -eq "window") {
            $result += $child
            continue
        }

        if ($null -ne $child.children) {
            $result += Get-WorkspaceWindows -Node $child
        }
    }

    return $result
}

function Get-Overlap {
    param(
        [int]$StartA,
        [int]$LengthA,
        [int]$StartB,
        [int]$LengthB
    )

    $endA = $StartA + $LengthA
    $endB = $StartB + $LengthB
    return [Math]::Max(0, [Math]::Min($endA, $endB) - [Math]::Max($StartA, $StartB))
}

$focusedData = Invoke-GlazeQuery -Name "focused"
$focused = $focusedData.focused

if ($null -eq $focused -or $focused.type -ne "window") {
    exit 0
}

$isTiling = $focused.state.type -eq "tiling"

if (-not $isTiling) {
    switch ($Direction) {
        "left"  { & $glazewm command resize --width  "-$Step%" | Out-Null }
        "right" { & $glazewm command resize --width  "+$Step%" | Out-Null }
        "up"    { & $glazewm command resize --height "-$Step%" | Out-Null }
        "down"  { & $glazewm command resize --height "+$Step%" | Out-Null }
    }
    exit 0
}

$workspaceData = Invoke-GlazeQuery -Name "workspaces"
$workspace = @($workspaceData.workspaces | Where-Object { $_.hasFocus }) | Select-Object -First 1

if ($null -eq $workspace) {
    exit 0
}

$windows = @(
    Get-WorkspaceWindows -Node $workspace |
        Where-Object {
            $_.id -ne $focused.id -and
            $_.state.type -eq "tiling" -and
            ($_.displayState -eq "shown" -or $_.displayState -eq "showing")
        }
)

$focusedLeft   = [int]$focused.x
$focusedTop    = [int]$focused.y
$focusedRight  = $focusedLeft + [int]$focused.width
$focusedBottom = $focusedTop + [int]$focused.height

$neighborExists = $false

foreach ($window in $windows) {
    $left   = [int]$window.x
    $top    = [int]$window.y
    $right  = $left + [int]$window.width
    $bottom = $top + [int]$window.height

    switch ($Direction) {
        "left" {
            $overlap = Get-Overlap -StartA $focusedTop -LengthA $focused.height -StartB $top -LengthB $window.height
            if ($overlap -gt 0 -and $right -le $focusedLeft) {
                $neighborExists = $true
            }
        }
        "right" {
            $overlap = Get-Overlap -StartA $focusedTop -LengthA $focused.height -StartB $top -LengthB $window.height
            if ($overlap -gt 0 -and $left -ge $focusedRight) {
                $neighborExists = $true
            }
        }
        "up" {
            $overlap = Get-Overlap -StartA $focusedLeft -LengthA $focused.width -StartB $left -LengthB $window.width
            if ($overlap -gt 0 -and $bottom -le $focusedTop) {
                $neighborExists = $true
            }
        }
        "down" {
            $overlap = Get-Overlap -StartA $focusedLeft -LengthA $focused.width -StartB $left -LengthB $window.width
            if ($overlap -gt 0 -and $top -ge $focusedBottom) {
                $neighborExists = $true
            }
        }
    }

    if ($neighborExists) {
        break
    }
}

$delta = if ($neighborExists) { "+$Step%" } else { "-$Step%" }

switch ($Direction) {
    "left"  { & $glazewm command resize --width  $delta | Out-Null }
    "right" { & $glazewm command resize --width  $delta | Out-Null }
    "up"    { & $glazewm command resize --height $delta | Out-Null }
    "down"  { & $glazewm command resize --height $delta | Out-Null }
}

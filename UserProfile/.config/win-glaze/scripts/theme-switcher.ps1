param(
    [Parameter(Position = 0)]
    [string]$Theme
)

$ErrorActionPreference = 'Stop'

$themes = [ordered]@{
    'carbon-night' = [ordered]@{ Label='Carbon Night'; Background='#353535'; Foreground='#d0d0d0'; Hover='#404040'; Focus='#4a4a4a'; Active='#2b2b2b'; Urgent='#ff5555'; Dark='#1a1a1a'; Charging='#6a9955'; Critical='#ff5555'; Muted='#5c5c5c' }
    'catppuccin-frappe' = [ordered]@{ Label='Catppuccin Frappe'; Background='#303446'; Foreground='#c6d0f5'; Hover='#414559'; Focus='#535970'; Active='#383c4d'; Urgent='#e78284'; Dark='#232634'; Charging='#a6d189'; Critical='#ef9f76'; Muted='#a5adce' }
    'crimson-red' = [ordered]@{ Label='Crimson Red'; Background='#1e1e2e'; Foreground='#f38ba8'; Hover='#352630'; Focus='#5a3442'; Active='#292330'; Urgent='#f38ba8'; Dark='#1e1e2e'; Charging='#fab387'; Critical='#f38ba8'; Muted='#9f8994' }
    'electric-blue' = [ordered]@{ Label='Electric Blue'; Background='#1e1e2e'; Foreground='#89b4fa'; Hover='#293448'; Focus='#34445e'; Active='#252938'; Urgent='#f38ba8'; Dark='#1e1e2e'; Charging='#a6e3a1'; Critical='#fab387'; Muted='#8993a8' }
    'gruvbox' = [ordered]@{ Label='Gruvbox'; Background='#282828'; Foreground='#ebdbb2'; Hover='#4a423c'; Focus='#665c4e'; Active='#3c3836'; Urgent='#b16286'; Dark='#fbf1c7'; Charging='#98971a'; Critical='#cc241d'; Muted='#a89984' }
    'iron-forge' = [ordered]@{ Label='Iron Forge'; Background='#0f1113'; Foreground='#bcd2d2'; Hover='#1f2328'; Focus='#242a32'; Active='#0d0f12'; Urgent='#a31717'; Dark='#ffffff'; Charging='#1f6f6f'; Critical='#a31717'; Muted='#6a7b86' }
    'obsidian-night' = [ordered]@{ Label='Obsidian Night'; Background='#0f0f0f'; Foreground='#cdd6f4'; Hover='#1e1e2e'; Focus='#313244'; Active='#1a1a1a'; Urgent='#ff5555'; Dark='#1e1e2e'; Charging='#6a9955'; Critical='#ff5555'; Muted='#4b4b4b' }
    'pink' = [ordered]@{ Label='Pink'; Background='#D297A1'; Foreground='#2E2E2E'; Hover='#B77F91'; Focus='#C0AFC0'; Active='#C0AFC0'; Urgent='#B04155'; Dark='#FFFFFF'; Charging='#D3D3D3'; Critical='#B04155'; Muted='#7A7A7A' }
    'pipboy' = [ordered]@{ Label='Pip-Boy'; Background='#050805'; Foreground='#a4ff47'; Hover='#1f301f'; Focus='#1b281b'; Active='#101810'; Urgent='#263826'; Dark='#050805'; Charging='#a4ff47'; Critical='#3c1b1b'; Muted='#2a3d2a' }
}

$configRoot = Join-Path $env:USERPROFILE '.config\win-glaze'
$yasbRoot = Join-Path $env:USERPROFILE '.config\yasb'
$statePath = Join-Path $configRoot 'theme-state.json'
$themeCssPath = Join-Path $yasbRoot 'theme.css'
$terminalSettingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'

New-Item -ItemType Directory -Force -Path $configRoot, $yasbRoot | Out-Null

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}

function Set-ObjectProperty($Object, [string]$Name, $Value) {
    if ($Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Get-TerminalRelativeLuminance([string]$Hex) {
    $channel = {
        param([int]$Value)
        $c = $Value / 255.0
        if ($c -le 0.03928) { return ($c / 12.92) }
        return [Math]::Pow((($c + 0.055) / 1.055), 2.4)
    }

    $red = [Convert]::ToInt32($Hex.Substring(1, 2), 16)
    $green = [Convert]::ToInt32($Hex.Substring(3, 2), 16)
    $blue = [Convert]::ToInt32($Hex.Substring(5, 2), 16)
    return (0.2126 * (& $channel $red)) + (0.7152 * (& $channel $green)) + (0.0722 * (& $channel $blue))
}

function Get-TerminalContrast([string]$First, [string]$Second) {
    $firstLuminance = Get-TerminalRelativeLuminance $First
    $secondLuminance = Get-TerminalRelativeLuminance $Second
    return ([Math]::Max($firstLuminance, $secondLuminance) + 0.05) / ([Math]::Min($firstLuminance, $secondLuminance) + 0.05)
}

function Get-TerminalBlend([string]$Background, [string]$Foreground, [double]$Weight) {
    $backWeight = 1.0 - $Weight
    $parts = foreach ($start in @(1, 3, 5)) {
        $back = [Convert]::ToInt32($Background.Substring($start, 2), 16)
        $front = [Convert]::ToInt32($Foreground.Substring($start, 2), 16)
        [int][Math]::Round(($back * $backWeight) + ($front * $Weight))
    }
    return ('#{0:X2}{1:X2}{2:X2}' -f $parts[0], $parts[1], $parts[2])
}

function Get-ReadableTerminalColor(
    [string]$Candidate,
    [double]$MinimumContrast,
    [double]$FallbackWeight,
    [string]$PreferredFallback
) {
    if ((Get-TerminalContrast $Candidate $t.Background) -ge $MinimumContrast) {
        return $Candidate
    }
    if (-not [string]::IsNullOrWhiteSpace($PreferredFallback) -and
        (Get-TerminalContrast $PreferredFallback $t.Background) -ge $MinimumContrast) {
        return $PreferredFallback
    }
    return Get-TerminalBlend $t.Background $t.Foreground $FallbackWeight
}

$currentId = 'carbon-night'
if (Test-Path -LiteralPath $statePath) {
    try {
        $saved = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
        if ($saved.id -and $themes.Contains([string]$saved.id)) {
            $currentId = [string]$saved.id
        }
    } catch {}
}

if ([string]::IsNullOrWhiteSpace($Theme)) {
    $ids = @($themes.Keys)
    for ($i = 0; $i -lt $ids.Count; $i++) {
        $id = $ids[$i]
        $mark = if ($id -eq $currentId) { '*' } else { ' ' }
        Write-Host ('{0} {1,2}. {2}' -f $mark, ($i + 1), $themes[$id].Label)
    }

    $choice = Read-Host 'Theme number or id'
    $number = 0
    if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $ids.Count) {
        $Theme = $ids[$number - 1]
    } else {
        $Theme = $choice.Trim().ToLowerInvariant().Replace('_','-')
    }
}

if (-not $themes.Contains($Theme)) {
    throw "Unknown theme '$Theme'. Available: $($themes.Keys -join ', ')"
}

$t = $themes[$Theme]
$r = [Convert]::ToInt32($t.Foreground.Substring(1,2),16)
$g = [Convert]::ToInt32($t.Foreground.Substring(3,2),16)
$b = [Convert]::ToInt32($t.Foreground.Substring(5,2),16)

$css = @"
 /* Active YASB theme: $($t.Label) */
:root {
    --background: $($t.Background);
    --foreground: $($t.Foreground);
    --hover: $($t.Hover);
    --focus: $($t.Focus);
    --active: $($t.Active);
    --urgent: $($t.Urgent);
    --dark: $($t.Dark);
    --charging: $($t.Charging);
    --critical: $($t.Critical);
    --muted: $($t.Muted);
    --subtle-hover: rgba($r, $g, $b, 20);
    --subtle-active: rgba($r, $g, $b, 26);
    --strong-hover: rgba(115, 121, 148, 64);
}
"@.TrimStart()

Write-Utf8NoBom $themeCssPath ($css + [Environment]::NewLine)

$terminalSynced = $false
if (Test-Path -LiteralPath $terminalSettingsPath) {
    $root = Get-Content -Raw -LiteralPath $terminalSettingsPath | ConvertFrom-Json
    if (-not $root.profiles) {
        Set-ObjectProperty $root 'profiles' ([pscustomobject]@{})
    }
    if (-not $root.profiles.defaults) {
        Set-ObjectProperty $root.profiles 'defaults' ([pscustomobject]@{})
    }

    $schemeName = "Win Glaze $($t.Label)"
    $uiThemeName = "$schemeName UI"
    Set-ObjectProperty $root.profiles.defaults 'colorScheme' $schemeName

    $schemes = @($root.schemes | Where-Object { -not ([string]$_.name).StartsWith('Win Glaze ', [StringComparison]::OrdinalIgnoreCase) })
    $schemes += [pscustomobject][ordered]@{
        name = $schemeName
        background = $t.Background
        foreground = $t.Foreground
        cursorColor = $t.Foreground
        selectionBackground = Get-ReadableTerminalColor $t.Focus 1.6 0.45 $null
        black = $t.Dark
        red = Get-ReadableTerminalColor $t.Urgent 3.0 0.72 '#705050'
        green = Get-ReadableTerminalColor $t.Charging 3.0 0.72 '#60B48A'
        yellow = Get-ReadableTerminalColor $t.Critical 3.0 0.72 '#DFAF8F'
        blue = Get-ReadableTerminalColor $t.Focus 3.0 0.72 '#9AB8D7'
        purple = Get-ReadableTerminalColor $t.Active 3.0 0.72 '#DC8CC3'
        cyan = Get-ReadableTerminalColor $t.Hover 4.5 0.82 '#8CD0D3'
        white = $t.Foreground
        brightBlack = Get-ReadableTerminalColor $t.Muted 3.0 0.60 '#709080'
        brightRed = Get-ReadableTerminalColor $t.Urgent 4.0 0.82 '#DCA3A3'
        brightGreen = Get-ReadableTerminalColor $t.Charging 4.0 0.82 '#72D5A3'
        brightYellow = Get-ReadableTerminalColor $t.Critical 4.0 0.82 '#F0DFAF'
        brightBlue = Get-ReadableTerminalColor $t.Focus 4.0 0.82 '#94BFF3'
        brightPurple = Get-ReadableTerminalColor $t.Active 4.0 0.82 '#EC93D3'
        brightCyan = Get-ReadableTerminalColor $t.Hover 4.5 0.90 '#93E0E3'
        brightWhite = $t.Foreground
    }
    Set-ObjectProperty $root 'schemes' $schemes

    $uiThemes = @($root.themes | Where-Object { -not ([string]$_.name).StartsWith('Win Glaze ', [StringComparison]::OrdinalIgnoreCase) })
    $uiThemes += [pscustomobject][ordered]@{
        name = $uiThemeName
        window = [pscustomobject][ordered]@{ applicationTheme = 'dark'; useMica = $false }
        tab = [pscustomobject][ordered]@{ background = 'terminalBackground'; unfocusedBackground = $t.Background }
        tabRow = [pscustomobject][ordered]@{ background = $t.Background; unfocusedBackground = $t.Background }
    }
    Set-ObjectProperty $root 'themes' $uiThemes
    Set-ObjectProperty $root 'theme' $uiThemeName

    Write-Utf8NoBom $terminalSettingsPath (($root | ConvertTo-Json -Depth 32) + [Environment]::NewLine)
    $terminalSynced = $true
}

$state = [ordered]@{
    id = $Theme
    label = $t.Label
    appliedAt = [DateTime]::UtcNow.ToString('o')
    terminalSynced = $terminalSynced
}
Write-Utf8NoBom $statePath (($state | ConvertTo-Json -Compress) + [Environment]::NewLine)

Write-Host "Theme applied: $($t.Label)"
if ($terminalSynced) {
    Write-Host 'Windows Terminal theme updated.'
} else {
    Write-Host 'Windows Terminal settings were not found; Terminal sync skipped.'
}

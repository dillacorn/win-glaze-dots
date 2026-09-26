$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$runtimePath = Join-Path $repoRoot "wgdot\wgdot.ps1"
$manifestPath = Join-Path $repoRoot "wgdot\manifest.json"
$launcherPath = Join-Path $repoRoot "wgdot\wgdot.cmd"
$manualPath = Join-Path $repoRoot "MANUAL_POWERSHELL.md"
$installGuidePath = Join-Path $repoRoot "INSTALL.md"
$shortInstallerPath = Join-Path $repoRoot "i.ps1"
$nativeBootstrapPath = Join-Path $repoRoot "wgdot\\bootstrap.cmd"
$nativeSourcePath = Join-Path $repoRoot "wgdot\\wgdot-native.cs"
$installSoftwarePath = Join-Path $repoRoot "install_software.md"
$legacyThemeSwitcherPath = Join-Path $repoRoot "UserProfile\.config\win-glaze\scripts\theme-switcher.ps1"

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
Assert-True (Test-Path -LiteralPath $shortInstallerPath -PathType Leaf) "short installer exists"
$shortInstallerText = Get-Content -LiteralPath $shortInstallerPath -Raw
[scriptblock]::Create($shortInstallerText) | Out-Null
Assert-True ($shortInstallerText -match 'raw\.githubusercontent\.com/dillacorn/win-glaze-dots/main/wgdot/bootstrap\.cmd') "short installer hands off to the native bootstrap on main"
Assert-True ($shortInstallerText -match 'Invoke-WebRequest') "short installer downloads the native bootstrap without duplicating installer logic"
Assert-True ($shortInstallerText -match 'LOCALAPPDATA.*wgdot') "short installer stages its live batch outside TEMP so first-run cleanup tools cannot delete it"
Assert-True ($shortInstallerText -notmatch 'Join-Path \$env:TEMP "wgdot-bootstrap\.cmd"') "short installer does not keep its live batch in TEMP"
Assert-True ($shortInstallerText -notmatch '(?i)Set-ExecutionPolicy|-ExecutionPolicy\s+(Bypass|Unrestricted)') "short installer does not change or bypass execution policy"
Assert-True (Test-Path -LiteralPath $installGuidePath -PathType Leaf) "install guide exists"
$installGuideText = Get-Content -LiteralPath $installGuidePath -Raw
Assert-True ($installGuideText -match 'irm https://github\.com/dillacorn/win-glaze-dots/raw/main/i\.ps1 \| iex') "install guide advertises the short public install command"
Assert-True (Test-Path -LiteralPath $nativeBootstrapPath -PathType Leaf) "native bootstrap exists"
$nativeBootstrapText = Get-Content -LiteralPath $nativeBootstrapPath -Raw
Assert-True ($nativeBootstrapText -match '--no-launch') "native bootstrap exposes a noninteractive no-launch mode for automation"
Assert-True ($nativeBootstrapText -match 'curl\.exe -fsSL --retry 2 --connect-timeout 15') "native bootstrap keeps source download output quiet while preserving curl failures"
Assert-True ($nativeBootstrapText -match 'Starting WGDot\.\.\.') "interactive native bootstrap launches WGDot immediately after installation"
Assert-True ($nativeBootstrapText -match 'System\.Windows\.Forms\.dll') "native bootstrap references WinForms for the WGDot power overlay"
Assert-True ($nativeBootstrapText -match 'System\.Drawing\.dll') "native bootstrap references System.Drawing for the WGDot power overlay"
Assert-True (Test-Path -LiteralPath $nativeSourcePath -PathType Leaf) "native bootstrap source exists"
Assert-True (Test-Path -LiteralPath $installSoftwarePath -PathType Leaf) "software guide exists"
Assert-True (Test-Path -LiteralPath $legacyThemeSwitcherPath -PathType Leaf) "legacy theme switcher source exists"
$legacyThemeSwitcherText = Get-Content -LiteralPath $legacyThemeSwitcherPath -Raw
[scriptblock]::Create($legacyThemeSwitcherText) | Out-Null
Assert-True ($legacyThemeSwitcherText -match '#9AB8D7') "legacy theme switcher keeps readable ANSI blue fallback"
Assert-True ($legacyThemeSwitcherText -match '#8CD0D3') "legacy theme switcher keeps readable ANSI cyan fallback"
Assert-True ($legacyThemeSwitcherText -match '#709080') "legacy theme switcher keeps readable brightBlack fallback"
$installSoftwareText = Get-Content -LiteralPath $installSoftwarePath -Raw
Assert-True ($installSoftwareText -match 'Noto Nerd Font') "software guide documents the managed Awtarchy-matching Noto font"
Assert-True ($installSoftwareText -match 'Open-Shell remains selectable but defaults OFF') "software guide documents Open-Shell default-off behavior"
Assert-True ($installSoftwareText -match 'uses \*\*Skip\*\* rather than \*\*Cancel\*\*') "software guide documents privacy.sexy Skip wording"

$env:WGDOT_TEST_MODE = "1"
. $runtimePath

$manifestText = Get-Content -LiteralPath $manifestPath -Raw
$manifest = $manifestText | ConvertFrom-Json
Assert-Equal 1 ([int]$manifest.schemaVersion) "manifest schema"
Assert-Equal "dillacorn/win-glaze-dots" ([string]$manifest.runtime.repository) "repository identity"

$fakeYaziPlan = @(
    [pscustomobject]@{ FileId = "yazi-init"; Action = "REPLACE" }
)
$fakeOtherPlan = @(
    [pscustomobject]@{ FileId = "yasb-config"; Action = "REPLACE" }
)
Assert-True (Test-WgdotPlanWritesYazi -Plan $fakeYaziPlan) "PowerShell Yazi plan detector recognizes a Yazi write"
Assert-True (-not (Test-WgdotPlanWritesYazi -Plan $fakeOtherPlan)) "PowerShell Yazi plan detector ignores unrelated managed writes"

$componentIds = @($manifest.components | ForEach-Object { [string]$_.id })
Assert-True ($componentIds -contains "glazewm") "GlazeWM component exists"
Assert-True ($componentIds -contains "yasb") "YASB component exists"
Assert-True ($componentIds -contains "cursor") "cursor component exists"
Assert-True ($componentIds -contains "yazi") "Yazi component exists"
$yaziKeymapPath = Join-Path $repoRoot "UserProfile\AppData\Roaming\yazi\config\keymap.toml"
$yaziKeymapText = Get-Content -LiteralPath $yaziKeymapPath -Raw
Assert-True ($yaziKeymapText -match 'on = \["<Up>"\].*WgdotYaziArrow\(-1\)') "Yazi Up commits a Shift range before native movement"
Assert-True ($yaziKeymapText -match 'on = \["<Down>"\].*WgdotYaziArrow\(1\)') "Yazi Down commits a Shift range before native movement"
Assert-True ($yaziKeymapText -match 'on = \["k"\].*run = "arrow prev"') "Yazi k keeps native wraparound previous navigation"
Assert-True ($yaziKeymapText -match 'on = \["j"\].*run = "arrow next"') "Yazi j keeps native wraparound next navigation"
Assert-True ($yaziKeymapText -match 'on = \["g", "g"\], run = "arrow top"') "Yazi gg still jumps to top"
Assert-True ($yaziKeymapText -match 'on = \["G"\],\s+run = "arrow bot"') "Yazi G still jumps to bottom"
Assert-True ($yaziKeymapText -notmatch 'run = "arrow -1"') "Yazi old non-wrapping previous navigation is removed"
Assert-True ($yaziKeymapText -notmatch 'run = "arrow 1"') "Yazi old non-wrapping next navigation is removed"
Assert-True ($yaziKeymapText -cnotmatch 'on = \["n"\]') "Yazi lowercase n is inherited from native find-next instead of custom create"
Assert-True ($yaziKeymapText -notmatch 'create --interactive') "Yazi no longer duplicates create on n"
Assert-True ($yaziKeymapText -match 'on = \["\?"\],\s+run = "help"') "Yazi custom question-mark help binding is intentionally preserved"
Assert-True ($yaziKeymapText -match 'on = \["r"\].*WgdotYaziToggleRecents') "Yazi r toggles recent files and return"
Assert-True ($yaziKeymapText -match 'on = \["g", "r"\].*WgdotYaziGoRecents') "Yazi g r explicitly opens recently opened files"
Assert-True ($yaziKeymapText -match 'on = \["g", "r"\].*Go to recently opened folder') "Yazi g r help describes the recent-files destination"
Assert-True ($yaziKeymapText -match 'on = \["<C-t>"\].*tab_create --current') "Yazi Ctrl+T creates a tab in the current directory"
Assert-True ($yaziKeymapText -match 'on = \["<C-1>"\].*tab_switch 0') "Yazi Ctrl+1 switches to tab 1"
Assert-True ($yaziKeymapText -match 'on = \["<C-9>"\].*tab_switch 8') "Yazi Ctrl+9 switches to tab 9"
Assert-True ($yaziKeymapText -match 'on = \["b"\].*WgdotYaziToggleBookmarks') "Yazi b toggles bookmarks and return"
Assert-True ($yaziKeymapText -cmatch 'on = \["B"\].*WgdotYaziBookmarkHovered') "Yazi Shift+B bookmarks the highlighted item"
Assert-True ($yaziKeymapText -match 'on = \["g", "b"\].*WgdotYaziGoBookmarks') "Yazi g b explicitly opens bookmarked folders"
Assert-True ($yaziKeymapText -cnotmatch 'on = \["g", "B"\]') "Yazi no longer overloads the Go namespace with bookmark mutation"
Assert-True ($yaziKeymapText -match 'on = \["g", "m"\].*plugin drives') "Yazi g m opens the Windows drive picker"
Assert-True ($yaziKeymapText -match 'on = \["<C-f>"\].*WgdotYaziSearchMenu') "Yazi Ctrl+F opens recursive current-tree search"
Assert-True ($yaziKeymapText -match 'on = \["o"\].*WgdotYaziOpen\(false\)') "Yazi o records files before native open"
Assert-True ($yaziKeymapText -match 'on = \["O"\].*WgdotYaziOpen\(true\)') "Yazi O records files before interactive open"
Assert-True ($yaziKeymapText -match 'on = \["<S-Enter>"\].*WgdotYaziOpen\(true\)') "Yazi Shift+Enter records files before interactive open"
Assert-True ($yaziKeymapText -match 'on = \["m", "t"\].*WgdotYaziToggleTimeFormat') "Yazi m t toggles highlighted-item time format"
Assert-True ($yaziKeymapText -match 'desc = "Toggle modified time 24h/12h"') "Yazi time-format toggle is documented in the built-in Help menu"
Assert-True ($yaziKeymapText -match 'on = \["m", "v"\].*WgdotYaziTogglePreview') "Yazi m v toggles the preview pane"
Assert-True ($yaziKeymapText -match 'on = \["m", "x"\].*WgdotYaziTogglePreviewMax') "Yazi m x maximizes/restores preview"
Assert-True ($yaziKeymapText -match 'on = \["m", "c"\].*WgdotYaziSelectPreviewText') "Yazi m c opens selectable text mode for a highlighted text file"
Assert-True ($yaziKeymapText -match 'on = \["<Esc>"\].*WgdotYaziEscape') "Yazi manager Esc exits maximized preview before normal cancellation"
Assert-True ($yaziKeymapText -match 'on = \["t", "e"\].*wt\.exe -w new new-tab -d \.' ) "Yazi t e opens Windows Terminal in the current directory"
Assert-True ($yaziKeymapText -match 'desc = "Open terminal here"') "Yazi terminal-here shortcut is documented in Help"
Assert-True ($yaziKeymapText -match 'on = \["t", "n"\].*WgdotYaziOpenHoveredTab') "Yazi t n opens the hovered directory in a new tab"
Assert-True ($yaziKeymapText -match 'on = \["<C-c>"\].*\["yank".*"plugin system-clipboard"') "Yazi Ctrl+C yanks then exports to the Windows file clipboard"
Assert-True ($yaziKeymapText -match 'on = \["c", "y"\].*\["yank".*"plugin system-clipboard"') "Yazi c y uses the same proven Windows file-clipboard path"
Assert-True ($yaziKeymapText -match 'on = \["<Space>"\].*run = "toggle"') "Yazi Space toggles individual selection"
Assert-True ($yaziKeymapText -match 'on = \["<C-Space>"\].*run = "toggle"') "Yazi Ctrl+Space toggles individual selection"
Assert-True ($yaziKeymapText -match 'on = \["<S-Up>"\].*WgdotYaziShiftArrow\(-1\)') "Yazi Shift+Up extends range selection"
Assert-True ($yaziKeymapText -match 'on = \["<S-Down>"\].*WgdotYaziShiftArrow\(1\)') "Yazi Shift+Down extends range selection"
Assert-True ($yaziKeymapText -match 'on = \["<Delete>"\].*WgdotYaziRemoveMenu') "Yazi Delete opens the managed trash/permanent-delete chooser"
Assert-True ($yaziKeymapText -match 'on = \["d", "d"\].*WgdotYaziRemoveMenu') "Yazi d d opens the managed trash/permanent-delete chooser"
Assert-True ($yaziKeymapText -match 'on = \["y"\].*WgdotYaziYank') "Yazi y preserves yank outside the delete modal and confirms trash inside it"
Assert-True ($yaziKeymapText -match 'on = \["D"\].*WgdotYaziPermanentDelete') "Yazi D preserves permanent delete outside the delete modal and selects it inside the modal"
Assert-True ($yaziKeymapText -match 'on = \["q"\].*WgdotYaziConfirmQuit\(false\)') "Yazi q requires quit confirmation"
Assert-True ($yaziKeymapText -match 'on = \["Q"\].*WgdotYaziConfirmQuit\(true\)') "Yazi Q preserves no-cwd-file behavior behind confirmation"
Assert-True ($yaziKeymapText -match 'on = \["<C-w>"\].*WgdotYaziCloseTab') "Yazi Ctrl+W replaces the upstream Ctrl+C tab-close shortcut"
Assert-True ($yaziKeymapText -match '(?s)\[confirm\].*on = \["<Space>"\].*close --submit') "Yazi confirmation accepts Space as Yes"
Assert-True ($yaziKeymapText -match 'on = \["<C-x>"\].*run = "yank --cut"') "Yazi Ctrl+X cuts selected files"
Assert-True ($yaziKeymapText -match 'on = \["<C-v>"\].*run = "paste"') "Yazi Ctrl+V pastes copied/cut files"
Assert-True ($yaziKeymapText -cmatch 'on = \["R"\].*run = "rename"') "Yazi Shift+R renames the highlighted file or folder"
Assert-True ($yaziKeymapText -match 'on = \["<F2>"\].*run = "rename"') "Yazi F2 provides Windows-style rename"
Assert-True ($yaziKeymapText -notmatch 'on = \["<C-x>"\].*toggle_all') "Yazi Ctrl+X is no longer overloaded as clear selection"
Assert-True ($yaziKeymapText -match 'on = \["c", "z"\].*WgdotYaziCompressSelection') "Yazi c z compresses selection to ZIP"
Assert-True ($yaziKeymapText -match 'on = \["e", "h"\].*WgdotYaziExtractZipHere') "Yazi e h extracts ZIP into current directory"
Assert-True ($yaziKeymapText -match 'on = \["e", "f"\].*WgdotYaziExtractZipFolder') "Yazi e f extracts ZIP into a named folder"
$yaziConfigPath = Join-Path $repoRoot "UserProfile\AppData\Roaming\yazi\config\yazi.toml"
$yaziThemePath = Join-Path $repoRoot "UserProfile\AppData\Roaming\yazi\config\theme.toml"
$yaziThemeText = Get-Content -LiteralPath $yaziThemePath -Raw
$yaziConfigText = Get-Content -LiteralPath $yaziConfigPath -Raw
Assert-True ($yaziConfigText -match '(?m)^linemode = "size_and_mtime"\r?$') "Yazi starts with combined size and modified-date linemode"
Assert-True ($yaziConfigText -match '(?m)^mouse_events = \["click", "scroll", "drag", "move"\]\r?$') "Yazi enables event-driven mouse move for menu hover"
$yaziInitPath = Join-Path $repoRoot "UserProfile\AppData\Roaming\yazi\config\init.lua"
$yaziInitText = Get-Content -LiteralPath $yaziInitPath -Raw
$yaziArrowBlock = [regex]::Match($yaziInitText, '(?ms)function WgdotYaziArrow\(step\).*?^end').Value
Assert-True ($yaziArrowBlock -match 'step < 0 and "prev" or "next"') "Yazi Up/Down wrapper converts numeric direction to native wraparound prev/next"
Assert-True ($yaziArrowBlock -match 'ya\.emit\("arrow", \{ direction \}\)') "Yazi Up/Down wrapper dispatches native wraparound movement"
Assert-True ($yaziInitText -match 'function WgdotYaziEscape\(\)') "Yazi manager Esc wrapper is defined"
$yaziEscapeBlock = [regex]::Match($yaziInitText, '(?ms)function WgdotYaziEscape\(\).*?^end').Value
Assert-True ($yaziEscapeBlock -match 'ya\.emit\("escape", \{\}\)') "Yazi manager Esc delegates normal cancel/selection ordering to native escape"
Assert-True ($yaziEscapeBlock -notmatch 'select\s*=\s*true|cx\.active\.selected') "Yazi manager Esc does not bypass upstream one-layer-at-a-time escape precedence"
$yaziClipboardPath = Join-Path $repoRoot "UserProfile\AppData\Roaming\yazi\config\plugins\system-clipboard.yazi\main.lua"
$yaziClipboardText = Get-Content -LiteralPath $yaziClipboardPath -Raw
Assert-True ($yaziClipboardText -match 'function M:entry') "Yazi Windows file clipboard remains an explicit plugin action"
Assert-True ($yaziClipboardText -match 'ya\.sync\(function\(\)') "Yazi clipboard plugin reads completed yank state through a sync bridge"
Assert-True ($yaziClipboardText -notmatch 'ya\.async') "Yazi clipboard plugin does not nest ya.async inside its async entry"
Assert-True ($yaziClipboardText -match 'Command\("powershell\.exe"\)') "Yazi clipboard plugin uses the in-box PowerShell clipboard API"
Assert-True ($yaziClipboardText -match 'SetFileDropList') "Yazi clipboard plugin exports native Windows FileDrop data"
Assert-True ($yaziClipboardText -match 'Copied 1 file to Windows clipboard') "Yazi c y reports successful single-file Windows clipboard export"
Assert-True ($yaziClipboardText -match 'Copied %d files to Windows clipboard') "Yazi c y reports successful multi-file Windows clipboard export"
$yaziRecentPath = Join-Path $repoRoot "UserProfile\AppData\Roaming\yazi\config\plugins\recent-files.yazi\main.lua"
$yaziRecentText = Get-Content -LiteralPath $yaziRecentPath -Raw
$yaziBookmarksPath = Join-Path $repoRoot "UserProfile\AppData\Roaming\yazi\config\plugins\bookmarks.yazi\main.lua"
$yaziBookmarksText = Get-Content -LiteralPath $yaziBookmarksPath -Raw
$yaziPluginTexts = @($yaziRecentText, $yaziBookmarksText, $yaziClipboardText)
Assert-True (-not ($yaziPluginTexts -match 'io\.popen|os\.execute')) "Managed Windows Yazi plugins avoid Lua subprocess APIs that can corrupt Ctrl+C console handling"
Assert-True ($yaziRecentText -match 'fs\.create\("dir_all", Url\(state_dir\(\)\)\)') "Yazi recent-files creates state directories through Yazi fs API"
Assert-True ($yaziBookmarksText -match 'fs\.create\("dir_all", Url\(state_dir\(\)\)\)') "Yazi bookmarks creates state directories through Yazi fs API"
$yaziPreviewRefitPath = Join-Path $repoRoot "UserProfile\AppData\Roaming\yazi\config\plugins\preview-refit.yazi\main.lua"
$yaziPreviewRefitText = Get-Content -LiteralPath $yaziPreviewRefitPath -Raw
$yaziVfsPath = Join-Path $repoRoot "UserProfile\AppData\Roaming\yazi\config\vfs.toml"
$yaziVfsText = Get-Content -LiteralPath $yaziVfsPath -Raw
$yaziDrivesPath = Join-Path $repoRoot "UserProfile\AppData\Roaming\yazi\config\plugins\drives.yazi\main.lua"
$yaziDrivesText = Get-Content -LiteralPath $yaziDrivesPath -Raw
$yaziGitPath = Join-Path $repoRoot "UserProfile\AppData\Roaming\yazi\config\plugins\git.yazi\main.lua"
$yaziGitText = Get-Content -LiteralPath $yaziGitPath -Raw
Assert-True ($yaziInitText -notmatch '(?m)^\s*#') "Yazi init.lua rejects shell-style hash comments"
Assert-True ($yaziInitText -match 'function Linemode:size_and_mtime\(\)') "Yazi custom size/date linemode is defined"
Assert-True ($yaziInitText -match 'require\("recent-files"\)') "Yazi init loads the managed recent-files plugin"
Assert-True ($yaziInitText -match 'require\("recent-files"\):setup\(\)') "Yazi recent-files DDS subscription is initialized at startup"
Assert-True ($yaziInitText -match 'require\("bookmarks"\):setup\(\)') "Yazi bookmarks DDS subscription is initialized at startup"
Assert-True ($yaziInitText -match 'require\("git"\):setup \{ order = 1500 \}') "Yazi Git signs augment the current linemode"
Assert-True ($yaziInitText -notmatch 'WgdotYaziMirrorYankToSystemClipboard|require\("system-clipboard"\)') "Yazi init keeps Windows file-clipboard integration out of the normal manager runtime path"
Assert-True ($yaziInitText -match 'local function WgdotYaziPluginHex\(value\)') "Yazi plugin argument encoder is defined"
Assert-True ($yaziInitText -match 'WgdotYaziPluginArgs\("record", recent\)') "Yazi recent recording carries full file paths in plugin arguments"
Assert-True ($yaziInitText -match 'function WgdotYaziToggleBookmarks\(\)') "Yazi one-key bookmarks toggle helper is defined"
Assert-True ($yaziInitText -match 'function WgdotYaziToggleRecents\(\)') "Yazi one-key recents toggle helper is defined"
Assert-True ($yaziInitText -match 'local tab_key = tostring\(cx\.active\.id\)') "Yazi collection return targets are scoped per tab"
Assert-True ($yaziInitText -match 'state\[kind\] = tostring\(cx\.active\.current\.cwd\)') "Yazi collection toggles remember the exact source directory"
Assert-True ($yaziInitText -match 'ya\.emit\("cd", \{ Url\(target\), raw = true \}\)') "Yazi collection toggles return to the remembered source directory"
Assert-True ($yaziInitText -match 'function WgdotYaziBookmarkHovered\(\)') "Yazi highlighted-item bookmark helper is defined"
Assert-True ($yaziInitText -match 'WgdotYaziBookmarkTarget\(tostring\(hovered\.url\), hovered\.cha\.is_dir\)') "Yazi highlighted-item bookmark targets the real hovered file/folder"
Assert-True ($yaziInitText -match 'WgdotYaziBookmarkTarget\(tostring\(cx\.active\.current\.cwd\), true\)') "Yazi blank-space context menu can bookmark the current directory"
Assert-True ($yaziInitText -match 'elseif not WgdotYaziPreviewMaximized and rt\.mgr\.ratio\[3\] > 0 then') "Yazi Right Arrow uses the live preview ratio without the late-local scoping bug"
Assert-True ($yaziInitText -match 'ya\.emit\("app:resize", \{\}\)') "Yazi preview ratio changes dispatch the stable app-layer resize/reflow action"
Assert-True ($yaziInitText -notmatch 'WgdotYaziQueuePreviewRefit') "Yazi preview resize does not schedule a redundant second re-peek"
Assert-True ($yaziInitText -match 'function WgdotYaziSelectPreviewText\(\)') "Yazi exposes selectable text mode for maximized text previews"
Assert-True ($yaziInitText -match 'WgdotYaziTextSelectButton = \{') "Yazi maximized text preview exposes a clickable Select text control"
Assert-True ($yaziInitText -match 'Select text with the mouse; it copies automatically') "Yazi selectable text mode documents Windows Terminal copy-on-select behavior"
Assert-True ($yaziInitText -match '"Clear-Host; "') "Yazi selectable text mode clears the terminal before rendering file text"
Assert-True ($yaziInitText -match 'Select text \[m c\]') "Yazi selectable text control teaches the m c shortcut"
Assert-True ($yaziInitText -match 'block = true') "Yazi selectable text mode suspends Yazi so terminal selection can own the mouse"
Assert-True ($yaziInitText -match 'ya\.emit\("shell", \{ run = command, block = true \}\)') "Yazi selectable text mode passes its command through the stable shell run field"
Assert-True ($yaziInitText -match 'EncodedCommand') "Yazi selectable text mode avoids fragile nested cmd and PowerShell quoting"
Assert-True ($yaziInitText -match 'utf8\.codes') "Yazi selectable text mode builds the UTF-16LE payload required by Windows PowerShell EncodedCommand"
Assert-True ($yaziInitText -match 'WgdotYaziTextExtensions') "Yazi selectable text mode falls back to known text extensions when MIME data is unavailable"
Assert-True ($yaziInitText -match 'The highlighted item is not recognized as a text file') "Yazi selectable text mode reports unsupported files instead of silently doing nothing"
Assert-True ($yaziInitText -notmatch 'ya\.emit\("shell", \{ command, block = true \}\)') "Yazi selectable text mode does not use the ignored positional variable form"
Assert-True ($yaziInitText -match 'ui\.render\(\)') "Yazi time toggle requests an immediate redraw"
Assert-True ($yaziInitText -match 'ui\.Span\(flags\):style\(th\.mgr\.find_keyword\)') "Yazi header filter/search/find suffix uses a distinct command color"
Assert-True ($yaziInitText -notmatch 'Entity:children_add\(function\(\)') "Yazi rejected global row/icon padding is removed"
Assert-True ($yaziInitText -match 'x = area\.x \+ area\.w - preview_toggle_width') "Yazi preview visibility button sits at the current-pane right edge"
Assert-True ($yaziConfigText -match '(?m)^\[preview\]\r?$') "Yazi preview overrides are configured"
Assert-True ($yaziConfigText -match '(?m)^max_width = 2000\r?$') "Yazi maximized image preview is not capped at the upstream 600px width"
Assert-True ($yaziConfigText -match '(?m)^max_height = 2000\r?$') "Yazi maximized image preview has sufficient height"
Assert-True ($yaziConfigText -match '(?m)^wrap = "yes"\r?$') "Yazi text previews reflow to the resized preview pane"
Assert-True ($yaziRecentText -match 'paths\[#paths \+ 1\] = decode_arg\(job\.args\[i\]\)') "Yazi recents decode managed path arguments"
Assert-True ($yaziBookmarksText -match 'job\.args\[3\].*decode_arg\(job\.args\[3\]\)') "Yazi bookmarks decode typed managed path arguments"
Assert-True ($yaziBookmarksText -match 'value:match\("\^\(\[DFU\]\)\\t\(\.\*\)\$"\)') "Yazi bookmarks preserve legacy untyped entries without filesystem I/O"
$bookmarkParseMatch = [regex]::Match($yaziBookmarksText, 'local function parse_entry\(value\)(?<body>[\s\S]*?)\r?\nend')
Assert-True ($bookmarkParseMatch.Success) "Yazi bookmark parser exists"
Assert-True ($bookmarkParseMatch.Groups['body'].Value -notmatch 'fs\.cha\(') "Yazi bookmark parser avoids yielding filesystem I/O inside synchronized state callbacks"
Assert-True ($yaziInitText -match 'function WgdotYaziSearchMenu\(\)') "Yazi recursive search menu is defined"
Assert-True ($yaziInitText -match 'tostring\(file\.url\)') "Yazi recents use the File.url API"
Assert-True ($yaziInitText -match 'ya\.emit\("search", \{ via = "fd" \}\)') "Yazi name search uses native fd search"
Assert-True ($yaziInitText -match 'ya\.emit\("search", \{ via = "rg" \}\)') "Yazi content search uses native ripgrep search"
Assert-True ($yaziInitText -match 'desc = "Name search"') "Yazi name search chooser label stays compact"
Assert-True ($yaziInitText -match 'desc = "Content search"') "Yazi content search chooser label stays compact"
Assert-True ($yaziInitText -match 'WgdotYaziPreviewToggleButton = \{') "Yazi current pane has a clickable preview visibility toggle"
Assert-True ($yaziInitText -match 'visible and " 󰞔 \[m v\] " or " 󰞓 \[m v\] "') "Yazi preview visibility control teaches the m v shortcut"
Assert-True ($yaziInitText -match 'preview_toggle_width = math\.min\(10, area\.w\)') "Yazi preview visibility control reserves enough width for its shortcut hint"
Assert-True ($yaziInitText -match 'local label = visible and " 󰞔 \[m v\] " or " 󰞓 \[m v\] "') "Yazi preview visibility glyphs and shortcut hint are correct"
Assert-True ($yaziInitText -match ':type\(ui\.Border\.PLAIN\)') "Yazi custom context menu uses square corners"
Assert-True ($yaziInitText -match 'function WgdotYaziBookmarkHovered\(\)') "Yazi Shift+B highlighted-item bookmark helper is defined"
Assert-True ($yaziInitText -match 'WgdotYaziBookmarkTarget\(tostring\(cx\.active\.current\.cwd\), true\)') "Yazi background context menu can bookmark the current directory"
Assert-True ($yaziInitText -match 'WgdotYaziBookmarkTarget\(tostring\(hovered\.url\), hovered\.cha\.is_dir\)') "Yazi item context menu bookmarks the hovered file or folder"
Assert-True ($yaziInitText -notmatch ':is_bookmarked\(') "Yazi directory context menu does not call an unavailable bookmarks API"
Assert-True ($yaziBookmarksText -match '\\collections\\\\Bookmarks') "Yazi bookmarks materialize into a real local collection folder"
Assert-True ($yaziBookmarksText -match 'fs\.create\("dir_all", Url\(root\)\)') "Yazi bookmarks create the real collection directory"
Assert-True ($yaziBookmarksText -match '\\.wgdot-target') "Yazi directory bookmark markers retain their real target"
Assert-True ($yaziBookmarksText -notmatch 'function M:provide\(') "Yazi bookmarks do not depend on a custom VFS provider"
Assert-True ($yaziInitText -match 'WgdotYaziNavigateCollection') "Yazi collection rows navigate to their real targets"
Assert-True ($yaziInitText -match 'WgdotYaziDeleteCollectionSelection') "Yazi collection delete removes metadata instead of the real target"
Assert-True ($yaziInitText -match 'function WgdotYaziOpenHoveredTab\(\)') "Yazi new-tab keyboard helper is defined"
Assert-True ($yaziInitText -match 'function WgdotYaziTogglePreview\(\)') "Yazi preview pane toggle is defined"
Assert-True ($yaziInitText -match 'function WgdotYaziTogglePreviewMax\(\)') "Yazi preview maximize toggle is defined"
Assert-True ($yaziInitText -match 'WgdotYaziPreviewButton = \{') "Yazi preview pane has a clickable maximize/restore control"
Assert-True ($yaziInitText -match 'and " 󰘕 \[m x\] " or " 󰹶 \[m x\] "') "Yazi preview maximize/restore control teaches the m x shortcut"
Assert-True ($yaziInitText -match 'preview_button_width = math\.min\(10, area\.w\)') "Yazi preview maximize control reserves enough width for its shortcut hint"
Assert-True ($yaziInitText -match 'h = area\.h - 1') "Yazi preview control reserves a non-overlapping bottom row"
Assert-True ($yaziInitText -match 'function WgdotYaziPreviewButton:click\(event, up\)') "Yazi preview control has native click handling"
Assert-True ($yaziInitText -match 'function WgdotYaziEscape\(\)') "Yazi conditional manager Esc is defined"
Assert-True ($yaziInitText -match 'function Header:cwd\(\)') "Yazi clickable breadcrumb renderer is defined"
Assert-True ($yaziInitText -match 'WgdotYaziBreadcrumbTarget') "Yazi breadcrumb forward-trail state is defined"
Assert-True ($yaziInitText -match 'ui\.Style\(\):dim\(\)') "Yazi breadcrumb forward trail is dimmed"
Assert-True ($yaziInitText -match 'function Status:task_summary\(\)') "Yazi task summary status is defined"
Assert-True ($yaziInitText -match 'ya\.emit\("tasks:show", \{\}\)') "Yazi active task status opens the native task manager"
Assert-True ($yaziInitText -match 'action = "bulk_rename"') "Yazi multi-selection context menu exposes bulk rename"
Assert-True ($yaziInitText -match 'local function WgdotYaziOpenFiles\(interactive, hovered_only\)') "Yazi central file-open recorder is defined"
Assert-True ($yaziInitText -match 'if file and not file\.cha\.is_dir then') "Yazi recent history excludes hovered directories"
Assert-True ($yaziInitText -match 'if not file\.cha\.is_dir then') "Yazi recent history excludes selected directories"
Assert-True ($yaziInitText -match 'WgdotYaziPluginArgs\("record", recent\)') "Yazi records opened files through the recent-files plugin argument payload"
Assert-True ($yaziInitText -match 'function WgdotYaziShiftArrow\(step\)') "Yazi Shift+Arrow range-selection helper is defined"
Assert-True ($yaziInitText -match 'WgdotYaziShiftRangeActive = true') "Yazi tracks ranges started specifically by Shift+Arrow"
Assert-True ($yaziInitText -match 'function WgdotYaziArrow\(step\)') "Yazi plain-arrow range commit helper is defined"
Assert-True ($yaziInitText -match 'ya\.emit\("escape", \{ visual = true \}\)') "Yazi plain arrow commits an active Shift+Arrow range"
Assert-True ($yaziInitText -match 'function WgdotYaziConfirmQuit\(no_cwd_file\)') "Yazi quit confirmation helper is defined"
Assert-True ($yaziInitText -match 'function WgdotYaziCloseTab\(\)') "Yazi tab-close helper is defined"
Assert-True ($yaziInitText -match 'if #cx\.tabs > 1 then') "Yazi Ctrl+W closes an existing tab before offering last-tab quit"
Assert-True ($yaziInitText -match 'title = "Quit Yazi\?"') "Yazi quit confirmation prompt is defined"
Assert-True ($yaziInitText -match 'Yes: Y / Enter / Space') "Yazi quit confirmation documents affirmative keys"
Assert-True ($yaziInitText -match 'No:  N / Esc') "Yazi quit confirmation documents cancel keys"
Assert-True ($yaziInitText -match 'ya\.emit\("quit", \{ no_cwd_file = no_cwd_file == true \}\)') "Yazi q/Q confirmation preserves cwd-file semantics"
Assert-True ($yaziInitText -match 'WgdotYaziContextMenu = \{') "Yazi native mouse context-menu component is defined"
Assert-True ($yaziInitText -match 'Modal:children_add\(WgdotYaziContextMenu, 20\)') "Yazi mouse context menu is registered as a clickable modal child"
Assert-True ($yaziInitText -match 'function Current:click\(event, up\)') "Yazi current-pane click handler supports blank-space context actions"
Assert-True ($yaziInitText -match 'WgdotYaziContextMenu:show\("background", event\.x, event\.y\)') "Yazi blank-space right-click opens folder actions"
Assert-True ($yaziInitText -match 'WgdotYaziContextMenu:show\("item", event\.x, event\.y, selected_count, self\._file\)') "Yazi item right-click freezes the exact clicked target"
Assert-True ($yaziInitText -match 'function Header:click\(event, up\)') "Yazi header path has mouse clipboard behavior"
Assert-True ($yaziInitText -match 'ya\.emit\("copy", \{ "dirpath" \}\)') "Yazi header click copies the current directory path with the native copy action"
Assert-True ($yaziInitText -match 'Copied to clipboard: ') "Yazi header click reports clipboard success to the user"
Assert-True ($yaziInitText -match 'label = "New file".*shortcut = "a"') "Yazi folder context menu exposes New file with its keyboard hint"
Assert-True ($yaziInitText -match 'label = "New folder".*shortcut = "a /"') "Yazi folder context menu exposes New folder with the upstream create convention"
Assert-True ($yaziInitText -match 'label = "Terminal here".*shortcut = "t e"') "Yazi folder context menu exposes Terminal here with keyboard parity"
Assert-True ($yaziInitText -cmatch 'label = "Rename".*shortcut = "R"') "Yazi item context menu shows the Shift+R rename shortcut"
Assert-True ($yaziInitText -match 'label = "Trash".*shortcut = "d d"') "Yazi item context menu shows the spaced trash chord"
Assert-True ($yaziInitText -match 'function WgdotYaziContextMenu:row_at\(event\)') "Yazi compact context popup has exact mouse-row hit testing"
Assert-True ($yaziInitText -notmatch '"wgdot-context-menu"|WgdotYaziPluginArgs\("show", values\)') "Yazi right-click popup does not depend on the async Which helper"
Assert-True ($yaziInitText -match 'menu\._visible = true') "Yazi direct context popup becomes visible without changing layers"
Assert-True ($yaziInitText -match 'local action = index and self\._choice_actions and self\._choice_actions\[index\] or nil') "Yazi mouse rows resolve directly to frozen context actions"
Assert-True ($yaziInitText -match 'self:run\(action\)') "Yazi context mouse click directly runs the chosen action"
Assert-True ($yaziInitText -match 'local function WgdotYaziContextShortcutSpans\(shortcut\)') "Yazi compact popup splits displayed chord keys for styling"
Assert-True ($yaziInitText -match 'ui\.Span\(keys\[1\]\):style\(th\.which\.cand\)') "Yazi compact popup highlights the primary chord key"
Assert-True ($yaziInitText -match 'ui\.Span\(keys\[i\]\):style\(th\.which\.rest\)') "Yazi compact popup gives secondary chord keys distinct highlighting"
Assert-True ($yaziInitText -match 'shortcut = "c z"') "Yazi ZIP context action exposes the c z chord"
Assert-True ($yaziInitText -match 'shortcut = "d d"') "Yazi Trash context action exposes the d d chord"
Assert-True ($yaziThemeText -match 'cand = \{ fg = "lightcyan", bold = true \}') "Yazi primary context chord key styling is defined"
Assert-True ($yaziThemeText -match 'rest = \{ fg = "lightmagenta", bold = true \}') "Yazi secondary context chord key styling is distinct"
Assert-True ($yaziInitText -notmatch 'function Root:redraw\(\)|function Root:layout\(\)|function Root:reflow\(\)') "Yazi compact context popup does not replace Root drawing or layout"
Assert-True ($yaziInitText -match 'local width = 28') "Yazi compact context popup starts from a narrow minimum width"
Assert-True ($yaziInitText -match 'width = math\.min\(width, 48, area\.w\)') "Yazi compact context popup caps width without spanning the terminal"
Assert-True ($yaziInitText -match 'local height = #actions \+ 2') "Yazi compact context popup contains only action rows plus its border"
Assert-True ($yaziInitText -match 'local x = self\._x \+ 2') "Yazi compact context popup opens beside the right-click cursor"
Assert-True ($yaziInitText -match 'x = self\._x - width - 1') "Yazi compact context popup flips left near the right edge"
Assert-True ($yaziInitText -match 'y = self\._y - height \+ 1') "Yazi compact context popup flips upward near the bottom edge"
Assert-True ($yaziInitText -match ':title\(ui\.Line\(self:title\(\)\)\)') "Yazi compact context popup keeps its title inline with the border"
Assert-True ($yaziInitText -notmatch 'function WgdotYaziContextMenu:footer\(\)') "Yazi compact context popup does not render a separate footer"
Assert-True ($yaziInitText -match 'ya\.emit\("create", \{ dir = true \}\)') "Yazi New folder uses the stable native create dir flag"
Assert-True ($yaziInitText -notmatch 'ya\.sync\(') "Yazi init.lua does not use plugin-only ya.sync"
Assert-True ($yaziInitText -match 'local function WgdotYaziArchiveSnapshot\(\)') "Yazi archive snapshot helper is synchronous init.lua code"
Assert-True ($yaziInitText -match '(?s)function WgdotYaziCompressSelection\(\).*?local snapshot = WgdotYaziArchiveSnapshot\(\).*?ya\.async\(function\(\)') "Yazi captures archive state before entering async work"
Assert-True ($yaziInitText -match 'function WgdotYaziCompressSelection\(\)') "Yazi ZIP compression helper is defined"
Assert-True ($yaziInitText -match 'function WgdotYaziExtractZipHere\(\)') "Yazi extract-here helper is defined"
Assert-True ($yaziInitText -match 'function WgdotYaziExtractZipFolder\(\)') "Yazi extract-to-folder helper is defined"
Assert-True ($yaziInitText -match 'Compress to ZIP\.\.\.') "Yazi item context menu exposes ZIP compression"
Assert-True ($yaziInitText -match 'Extract here') "Yazi ZIP context menu exposes extract-here"
Assert-True ($yaziInitText -match 'Extract to folder') "Yazi ZIP context menu exposes extract-to-folder"
Assert-True ($yaziInitText -match '7z\.exe') "Yazi Windows archive helper tries the installed 7-Zip executable"
Assert-True ($yaziInitText -match 'string\.format\("%s \(%d\)\.zip", stem, index\)') "Yazi ZIP creation protects existing archive names"
Assert-True ($yaziInitText -match '"-aou"') "Yazi extract-here auto-renames colliding files"
Assert-True ($yaziInitText -match 'ya\.emit\("shell", \{ "wt\.exe -w new new-tab -d \.", orphan = true \}\)') "Yazi Terminal here uses the managed Windows Terminal path without a helper script"
Assert-True ($yaziInitText -match 'WgdotYaziPendingClick = \{') "Yazi defers second-click action until Mouse1 release"
Assert-True ($yaziInitText -match 'pending\.was_hovered') "Yazi release opens only an item that was already highlighted on Mouse1 down"
Assert-True ($yaziInitText -match 'function Current:drag\(event\)') "Yazi handles drag gestures at the current-pane layer"
Assert-True ($yaziInitText -match 'WgdotYaziPendingClick = nil') "Yazi drag cancels the pending click-open action"
Assert-True ($yaziInitText -match 'WgdotYaziOpenFiles\(false, true\)') "Yazi second-click release opens highlighted files and records recents"
Assert-True ($yaziInitText -match 'event\.is_middle') "Yazi recognizes middle-click directory actions"
Assert-True ($yaziInitText -match 'ya\.emit\("tab_create", \{ tostring\(self\._file\.url\), raw = true \}\)') "Yazi middle-click opens directories in a new tab"
Assert-True ($yaziInitText -match 'self\._selection_count > 1') "Yazi context menu displays multi-selection counts"
Assert-True ($yaziInitText -match 'function WgdotYaziContextMenu:move\(event\)') "Yazi context menu tracks mouse hover"
Assert-True ($yaziInitText -match 'function Root:move\(event\)') "Yazi root routes enabled mouse-move events to the open menu"
Assert-True ($yaziInitText -match 'row:style\(th\.help\.hovered\)') "Yazi context menu highlights hovered actions"
Assert-True ($yaziInitText -match 'WgdotYaziContextMenu:show_drop') "Yazi drag release over a directory opens the Copy/Move destination menu"
Assert-True ($yaziInitText -match 'WgdotYaziDropInto\("copy"') "Yazi internal drag can copy selected items into a folder"
Assert-True ($yaziInitText -match 'WgdotYaziDropInto\("move"') "Yazi internal drag can move selected items into a folder"
Assert-True ($yaziInitText -match '\\\\wgdot\\\\bin\\\\wgdotw\.exe') "Yazi resolves the installed windowless WGDot helper for outbound drag"
Assert-True ($yaziInitText -match 'function WgdotYaziDragOut\(\)') "Yazi exposes explicit outbound drag"
Assert-True ($yaziKeymapText -match 'on = \["d", "g"\].*WgdotYaziDragOut') "Yazi d g opens the outbound drag surface"
Assert-True ($yaziInitText -match 'label = "Drag out\.\.\.", shortcut = "d g", action = "drag_out"') "Yazi context menu exposes Drag out"
Assert-True ($yaziInitText -match 'Command\(helper\):arg\(\{ "yazi-drag", list_path \}\)') "Yazi explicit outbound drag invokes the native helper"
$currentDragBlock = [regex]::Match($yaziInitText, '(?ms)function Current:drag\(event\).*?^end').Value
Assert-True ($currentDragBlock -notmatch 'WgdotYaziStartOutboundDrag') "Yazi internal mouse drag does not auto-launch the outbound drag surface"
Assert-True ($yaziInitText -match 'ya\.readable_size\(size\)') "Yazi combined linemode uses native readable file sizes"
Assert-True ($yaziInitText -match 'self\._file\.cha\.mtime') "Yazi combined linemode uses the current stable Yazi file cha mtime API"
Assert-True ($yaziInitText -notmatch 'self\._file\.stat\.mtime') "Yazi combined linemode does not use the incompatible stat mtime field"
Assert-True ($yaziInitText -match '"%d/%d/%02d"') "Yazi modified dates use compact M/D/YY formatting"
Assert-True ($yaziInitText -match '"%9s  %8s"') "Yazi size/date fields stay aligned with date at the far right"
Assert-True ($yaziInitText -match 'function Status:selected_count\(\)') "Yazi multi-selection count is defined in the bottom status"
Assert-True ($yaziInitText -match 'local count = #cx\.active\.selected') "Yazi selection status uses only selected-item count"
Assert-True ($yaziInitText -match 'if count < 2 then') "Yazi selection count stays hidden for zero/one selected item"
Assert-True ($yaziInitText -match '" %d selected "') "Yazi selection count avoids recursive size statistics"
Assert-True ($yaziInitText -match 'function Status:modified_time\(\)') "Yazi highlighted-item modified timestamp is defined in the bottom status"
Assert-True ($yaziInitText -match 'hovered\.cha\.mtime') "Yazi highlighted-item timestamp uses the stable hovered cha mtime API"
Assert-True ($yaziInitText -match 'WgdotYaziTimeFormat = "24h"') "Yazi highlighted-item clock defaults to 24-hour time"
Assert-True ($yaziInitText -match 'ps\.sub\("@wgdot-yazi-time-format"') "Yazi restores the retained time-format preference through DDS"
Assert-True ($yaziInitText -match 'ps\.pub\("@wgdot-yazi-time-format", next_format\)') "Yazi persists the toggled time format through DDS"
Assert-True ($yaziInitText -match 'function WgdotYaziToggleTimeFormat\(\)') "Yazi exposes the time-format toggle to the m t inline Lua action"
Assert-True ($yaziInitText -match 'Modified: %d/%d/%02d %02d:%02d') "Yazi highlighted-item timestamp supports compact date plus 24-hour time"
Assert-True ($yaziInitText -match 'Modified: %d/%d/%02d %d:%02d %s') "Yazi highlighted-item timestamp supports compact date plus 12-hour time"
Assert-True ($yaziInitText -match 'parts\.hour % 12') "Yazi 12-hour mode converts midnight/noon correctly"
Assert-True ($yaziInitText -match '"AM" or "PM"') "Yazi 12-hour mode labels AM and PM"
Assert-True ($yaziInitText -match 'Status:children_add\(function\(self\)') "Yazi modified timestamp is attached through the status component API"
Assert-True ($yaziInitText -match '500, Status\.RIGHT') "Yazi highlighted-item modified timestamp is placed on the right side of the bottom status"
Assert-True ($yaziRecentText -match 'local KIND = "@dillacorn-yazi-recent-files"') "Yazi recents use retained DDS static state"
Assert-True ($yaziRecentText -match 'local MAX_RECENTS = 1000') "Yazi recents collection has a bounded retained history"
Assert-True ($yaziRecentText -match 'local snapshot = ya\.sync') "Yazi recents keep plugin state behind a valid plugin-only sync boundary"
Assert-True ($yaziRecentText -match 'local record = ya\.sync') "Yazi recents record through the plugin sync context"
Assert-True ($yaziRecentText -match 'local subscribe = ya\.sync') "Yazi recents subscribe from the same plugin state used by record and snapshot"
Assert-True ($yaziRecentText -match 'ps\.sub_remote\(KIND') "Yazi recents subscribe to shared cross-instance state"
Assert-True ($yaziRecentText -match 'ps\.pub_to\(0, KIND, self\.recents\)') "Yazi recents publish shared cross-instance state"
Assert-True ($yaziRecentText -match '\\collections\\\\Recently Opened') "Yazi recents materialize into a real local collection folder"
Assert-True ($yaziRecentText -match 'fs\.write\(Url\(marker\), path\)') "Yazi recents materialize local marker files"
Assert-True ($yaziRecentText -notmatch 'function M:provide\(') "Yazi recents do not depend on a custom VFS provider"
Assert-True ($yaziRecentText -match 'ya\.emit\("cd", \{ Url\(collection_dir\(\)\), raw = true \}\)') "Yazi g r enters the real recent-files folder"
Assert-True ($yaziRecentText -match 'wgdot-recent-files\.txt') "Yazi recents use deterministic restart-safe state"
Assert-True ($yaziRecentText -match 'read_state\(\)') "Yazi recents reload canonical state when used"
Assert-True ($yaziBookmarksText -match 'wgdot-bookmarks\.txt') "Yazi bookmarks use deterministic restart-safe state"
Assert-True ($yaziBookmarksText -match 'read_state\(\)') "Yazi bookmarks reload canonical state when used"
Assert-True ($yaziBookmarksText -match 'local KIND = "@wgdot-yazi-bookmarks"') "Yazi bookmarks use retained WGDot DDS state"
Assert-True ($yaziBookmarksText -match 'local MAX_BOOKMARKS = 1000') "Yazi bookmarks are bounded"
Assert-True ($yaziBookmarksText -match 'ps\.sub_remote\(KIND') "Yazi bookmarks synchronize across Yazi instances"
Assert-True ($yaziBookmarksText -match 'ya\.emit\("cd", \{ Url\(collection_dir\(\)\), raw = true \}\)') "Yazi g b enters the real bookmark folder"
Assert-True ($yaziVfsText -notmatch '^\s*\[') "Yazi custom VFS services stay disabled for bookmark/recent collections"
Assert-True ($yaziInitText -match 'WgdotYaziDeleteMenu = \{') "Yazi managed two-row delete modal is defined"
Assert-True ($yaziInitText -match 'function WgdotYaziDeleteMenu:move\(step\)') "Yazi delete modal supports Up/Down navigation"
Assert-True ($yaziInitText -match 'function WgdotYaziDeleteMenu:submit\(choice\)') "Yazi delete modal submits the highlighted choice"
Assert-True ($yaziInitText -match '\{ label = "Move to trash", shortcut = "y / Enter" \}') "Yazi delete modal defaults to the trash choice"
Assert-True ($yaziInitText -match '\{ label = "Permanently delete\.\.\.", shortcut = "D" \}') "Yazi delete modal exposes permanent deletion"
Assert-True ($yaziInitText -match 'ya\.emit\("remove", \{ force = true \}\)') "Yazi trash choice submits directly"
Assert-True ($yaziInitText -match 'ya\.emit\("remove", \{ permanently = true \}\)') "Yazi permanent choice uses native permanent deletion"
Assert-True ($yaziDrivesText -match 'fs\.partitions\(\)') "Yazi Windows drive picker uses native Yazi partition discovery"
Assert-True ($yaziDrivesText -match 'ya\.emit\("cd", \{ Url\(tostring\(drive\.dist\)\), raw = true \}\)') "Yazi Windows drive picker navigates with native cd"
Assert-True ($yaziDrivesText -notmatch 'udisksctl|sudo') "Yazi Windows drive picker has no Linux mount or sudo assumptions"
Assert-True ($yaziGitText -match 'Linemode:children_add') "Yazi Git signs augment rather than replace size/date linemode"
$yaziComponent = $manifest.components | Where-Object { $_.id -eq "yazi" } | Select-Object -First 1
Assert-True (@($yaziComponent.files | Where-Object { $_.id -eq "yazi-init" }).Count -eq 1) "Yazi init.lua is a managed config file"
Assert-True (@($yaziComponent.files | Where-Object { $_.id -eq "yazi-recent-files" }).Count -eq 1) "Yazi recent-files plugin is a managed config file"
Assert-True (@($yaziComponent.files | Where-Object { $_.id -eq "yazi-bookmarks" }).Count -eq 1) "Yazi bookmarks plugin is managed"
Assert-True (@($yaziComponent.files | Where-Object { $_.id -eq "yazi-vfs" }).Count -eq 1) "Yazi VFS config is managed"
Assert-True (@($yaziComponent.files | Where-Object { $_.id -eq "yazi-preview-refit" }).Count -eq 1) "Yazi preview-refit plugin is managed"
Assert-True (@($yaziComponent.files | Where-Object { $_.id -eq "yazi-drives" }).Count -eq 1) "Yazi Windows drive picker plugin is managed"
Assert-True (@($yaziComponent.files | Where-Object { $_.id -eq "yazi-git" }).Count -eq 1) "Yazi Git status plugin is managed"
Assert-True (@($yaziComponent.files | Where-Object { $_.id -eq "yazi-git-license" }).Count -eq 1) "Yazi Git plugin license is managed"
Assert-True (@($yaziComponent.files | Where-Object { $_.id -eq "yazi-theme" }).Count -eq 1) "Yazi theme override is managed"
Assert-True ($yaziThemeText -match 'sep_inner\s*=\s*\{ open = "", close = "" \}') "Yazi tabs use square separators"
Assert-True ($yaziThemeText -match 'padding\s*=\s*\{ open = " ", close = " " \}') "Yazi hovered-row indicator uses square padding"
Assert-True ($yaziThemeText -match 'sep_left\s*=\s*\{ open = "", close = "" \}') "Yazi status cells use square separators"
Assert-True ($componentIds -notcontains "desktop-scripts") "obsolete desktop scripts component is removed"

$yasb = $manifest.components | Where-Object { $_.id -eq "yasb" } | Select-Object -First 1
Assert-True (@($yasb.postActions | Where-Object { $_.type -match "ensure-(yasb-theme|hidden-launcher)" }).Count -eq 0) "YASB config has no WGDot runtime post-actions"
Assert-Equal "UserProfile/.config/yasb/config.yaml" ([string]$yasb.files[0].sourceByGlazeProfile.normal) "normal YASB source"
Assert-Equal "UserProfile/.config/yasb/custom_work_config.yaml" ([string]$yasb.files[0].sourceByGlazeProfile.work) "work YASB source"
$cursorComponent = $manifest.components | Where-Object { $_.id -eq "cursor" } | Select-Object -First 1
Assert-True (@($cursorComponent.postActions | Where-Object { $_.type -eq "ensure-cursor-theme" }).Count -eq 1) "cursor component has exactly one cursor post-action"

$glaze = $manifest.components | Where-Object { $_.id -eq "glazewm" } | Select-Object -First 1
Assert-True (@($glaze.postActions | Where-Object { $_.type -eq "ensure-desktop-worker" }).Count -eq 0) "GlazeWM config has no WGDot desktop-worker post-action"
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
Assert-True ($installSoftwareText -match 'Yazi \+ Explorer') "software guide records Yazi + Explorer as the preferred file-manager path"
Assert-True ($packageIds.ContainsKey("mozilla.firefox")) "Firefox is cataloged"
Assert-True ($packageIds.ContainsKey("vencord.vesktop")) "Vesktop is cataloged"
Assert-True ($packageIds.ContainsKey("softfever.orcaslicer")) "OrcaSlicer is cataloged"
Assert-True ($packageIds.ContainsKey("prusa3d.prusaslicer")) "PrusaSlicer is cataloged"
Assert-True ($packageIds.ContainsKey("wireguard.wireguard")) "WireGuard is cataloged"
Assert-True ($packageIds.ContainsKey("wagnardsoft.displaydriveruninstaller")) "DDU is cataloged for GPU maintenance"
Assert-True (-not $packageIds.ContainsKey("spotify.spotify")) "Spotify is not offered by WGDot"
Assert-True ($packageIds.ContainsKey("rustdesk.rustdesk")) "RustDesk is cataloged"
Assert-True ($packageIds.ContainsKey("rawaccelofficial.rawaccel")) "Raw Accel is cataloged"
Assert-True ($packageIds.ContainsKey("nerdfonts.noto")) "Noto Nerd Font is cataloged"
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

$notoFontPackage = Get-ManifestPackage -Id "NerdFonts.Noto"
Assert-True ($null -ne $notoFontPackage) "Noto Nerd Font package exists"
Assert-Equal "official-github-font-archive" ([string]$notoFontPackage.installMode) "Noto Nerd Font uses the official GitHub font-archive path"
Assert-Equal "ryanoasis/nerd-fonts" ([string]$notoFontPackage.fallbackGitHubRepo) "Noto Nerd Font source is the official Nerd Fonts repository"
Assert-Equal "^Noto\.zip$" ([string]$notoFontPackage.fallbackAssetRegex) "Noto Nerd Font accepts only the official Noto release archive"
Assert-Equal "NotoSansMNerdFontMono-Regular.ttf" ([string]$notoFontPackage.fontFile) "Noto Nerd Font installs the Awtarchy-matching mono face"
Assert-Equal "NotoSansM NFM" ([string]$notoFontPackage.fontFamily) "Noto Nerd Font registers the embedded Windows family name"
Assert-True ([bool]$notoFontPackage.defaultNormal) "Noto Nerd Font is selected by default on fresh Normal installs"
Assert-True ([bool]$notoFontPackage.defaultWork) "Noto Nerd Font is selected by default on fresh Work installs"
Assert-Equal "official-github-font-archive" ([string]$notoFontPackage.installMode) "Noto Nerd Font uses the managed current-user font installer"

$micLockTrayPackage = Get-ManifestPackage -Id "dillacorn.MicLockTray"
Assert-True ($null -ne $micLockTrayPackage) "MicLockTray package exists"
Assert-Equal "official-github-portable" ([string]$micLockTrayPackage.installMode) "MicLockTray uses the unelevated official GitHub portable path"
Assert-Equal "dillacorn/MicLockTray" ([string]$micLockTrayPackage.fallbackGitHubRepo) "MicLockTray source is the official repository"
Assert-Equal "MicLockTray.exe" ([string]$micLockTrayPackage.installedFile) "MicLockTray installs the published standalone executable"
Assert-Equal $true ([bool]$micLockTrayPackage.launchAfterInstall) "MicLockTray launches after its user-level portable install"

$startupExpectations = @{
    "glzr-io.glazewm" = @{ Handler = "glazewm"; Default = $true }
    "AltSnap.AltSnap" = @{ Handler = "altsnap"; Default = $true }
    "File-New-Project.EarTrumpet" = @{ Handler = "eartrumpet"; Default = $true }
    "dillacorn.MicLockTray" = @{ Handler = "miclocktray"; Default = $true }
    "RawAccelOfficial.RawAccel" = @{ Handler = "rawaccel"; Default = $false }
}
foreach ($entry in $startupExpectations.GetEnumerator()) {
    $package = Get-ManifestPackage -Id $entry.Key
    Assert-True ($null -ne $package) "startup package exists: $($entry.Key)"
    Assert-Equal ([string]$entry.Value.Handler) ([string]$package.startupHandler) "$($entry.Key) has the expected WGDot startup handler"
    Assert-Equal ([bool]$entry.Value.Default) ([bool]$package.startupDefault) "$($entry.Key) startup default is intentional"
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
    "NerdFonts.Noto"
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
Assert-Equal $false ([bool]$openShell.defaultNormal) "Open-Shell is optional/default-off for Normal"
Assert-Equal $false ([bool]$openShell.defaultWork) "Open-Shell is optional/default-off for Work"
Assert-Equal "launch-open-shell" ([string]$openShell.postInstallAction) "Open-Shell launches after first install only when explicitly selected"

$rustDesk = Get-ManifestPackage -Id "RustDesk.RustDesk"
Assert-Equal "rustdesk/rustdesk" ([string]$rustDesk.fallbackGitHubRepo) "RustDesk approved fallback repository"

$tweakIds = @($manifest.tweaks | ForEach-Object { [string]$_.id })
foreach ($id in @(
    "micro-text-defaults",
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
    "disable-windows-shell-hotkeys"
)) {
    $t = $manifest.tweaks | Where-Object { $_.id -eq $id } | Select-Object -First 1
    Assert-True (-not [bool]$t.defaultNormal) "$id defaults off"
}


foreach ($id in @("automatic-time-and-timezone")) {
    $tweak = $manifest.tweaks | Where-Object { $_.id -eq $id } | Select-Object -First 1
    Assert-True ([bool]$tweak.defaultNormal) "$id defaults on for Normal"
    Assert-True ([bool]$tweak.defaultWork) "$id defaults on for Work"
}

$runtimeText = Get-Content -LiteralPath $runtimePath -Raw
$launcherText = Get-Content -LiteralPath $launcherPath -Raw
$manualText = Get-Content -LiteralPath $manualPath -Raw
$nativeBootstrapText = Get-Content -LiteralPath $nativeBootstrapPath -Raw
$nativeSourceText = Get-Content -LiteralPath $nativeSourcePath -Raw
Assert-True ($nativeSourceText -match 'YasbTheme theme = FindYasbTheme\(CurrentYasbThemeId\(\)\) \?\? YasbThemes\[0\]') "Yazi drag surface resolves the current WGDot theme"
Assert-True ($nativeSourceText -match 'theme\.Background') "Yazi drag surface uses the active theme background"
Assert-True ($nativeSourceText -match 'theme\.Foreground') "Yazi drag surface uses the active theme foreground"
Assert-True ($nativeSourceText -match 'theme\.Active') "Yazi drag surface uses the active theme field color"
Assert-True ($nativeSourceText -match 'theme\.Hover') "Yazi drag surface uses the active theme hover color"
Assert-True ($nativeSourceText -match 'theme\.Focus') "Yazi drag surface uses the active theme border/focus color"
Assert-True ($nativeSourceText -match 'scope == "work" \? GetBool\(package, "defaultWork"\) : GetBool\(package, "defaultNormal"\)') "fresh package selection honors profile default flags"
Assert-True ($nativeSourceText -match 'if \(command == "bar-font-install"\) return BarFontInstall\(\);') "native runtime exposes targeted YASB font install"
Assert-True ($nativeSourceText -match 'FindPackageById\(source\.Manifest, "NerdFonts\.Noto"\)') "targeted YASB font install resolves only the managed Noto package"
Assert-True ($nativeSourceText -match 'No WinGet packages or unrelated software will be reconciled\.') "targeted YASB font install documents its narrow scope"
Assert-True ($nativeSourceText -match 'NotoSansM Nerd Font Mono \(TrueType\)') "font installer recognizes the legacy verbose Noto registry alias"
Assert-True ($nativeSourceText -match 'key\.DeleteValue\(legacyValueName, false\)') "font installer removes only the matching legacy WGDot Noto registry alias"
Assert-True ($nativeSourceText -match 'reuseExistingFontFile') "font installer can reuse an already-loaded managed font file"
Assert-True ($nativeSourceText -match 'Registered existing ') "font installer reports registry-only reuse instead of overwriting a loaded font"
Assert-True ($nativeSourceText -match 'Windows family: NotoSansM NFM') "targeted bar-font command reports the actual Windows family name"
Assert-True ($runtimeText -notmatch '(?i)-ExecutionPolicy\s+Bypass') "runtime does not bypass execution policy"
Assert-True ($runtimeText -match 'browserOptions = \[pscustomobject\]\$browserOptions') "PowerShell fallback persists browser option state on fresh/reconfigure selection"
Assert-True ($runtimeText -match 'New-WgdotInstallationSelection -Manifest \$manifest -Existing \$existingInstallation') "PowerShell reset path preserves existing browser option selections"
Assert-True ($launcherText -notmatch '(?i)-ExecutionPolicy\s+(Bypass|Unrestricted)') "launcher does not override execution policy"
Assert-True ($launcherText -notmatch '(?i)Set-ExecutionPolicy') "launcher does not change execution policy"
Assert-True ($launcherText -match 'Get-ExecutionPolicy') "launcher checks effective execution policy"
Assert-True ($launcherText -match '(?i)Restricted') "launcher handles Restricted policy"
Assert-True ($launcherText -match '(?i)AllSigned') "launcher handles AllSigned policy"
Assert-True ($manualText -notmatch '(?i)-ExecutionPolicy\s+Bypass') "manual path does not bypass execution policy"
Assert-True ($manualText -match 'raw\.githubusercontent\.com') "paste-only manual workflow supports raw.githubusercontent.com-only corporate networks"
Assert-True ($manualText -notmatch 'https://api\.github\.com') "paste-only manual workflow does not call api.github.com"
Assert-True ($manualText -notmatch '(?im)^\s*git clone\b') "paste-only manual workflow does not depend on git clone"
Assert-True ($manualText -match '\$releaseRevision\s*=\s*"[0-9a-f]{40}"') "paste-only manual workflow pins an immutable stable release revision"
Assert-True ($manualText -notmatch '"doublecmd"') "paste-only manual workflow contains no retired Double Commander component"
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
$manualSoftwareBlock = [regex]::Match(
    $manualText,
    '(?s)## Install selected software from the same release manifest.*?```powershell\r?\n(.*?)\r?\n```'
)
Assert-True $manualSoftwareBlock.Success "paste-only software PowerShell block can be extracted"
[scriptblock]::Create($manualSoftwareBlock.Groups[1].Value) | Out-Null
Assert-True ($nativeBootstrapText -notmatch '(?i)Set-ExecutionPolicy|-ExecutionPolicy\s+(Bypass|Unrestricted)') "native bootstrap does not change or bypass execution policy"
Assert-True ($nativeSourceText -notmatch '(?i)Set-ExecutionPolicy|-ExecutionPolicy\s+(Bypass|Unrestricted)') "native bootstrap source does not change or bypass execution policy"
Assert-True ($nativeSourceText -match 'WmSettingChange') "native installer broadcasts environment changes"
Assert-True ($nativeSourceText -match '"git-review"') "native runtime exposes Git review command"
Assert-True ($nativeSourceText -match '"git-update"') "native runtime exposes explicit Git update command"
Assert-True ($nativeSourceText -match '"git-reset"') "native runtime exposes explicit Git reset command"
Assert-True ($nativeSourceText -match 'GitManagedFromArgs\("update"') "Git update uses the shared exact-revision Git-testing path"
Assert-True ($nativeSourceText -match 'GitManagedFromArgs\("reset"') "Git reset uses the shared exact-revision Git-testing path"
Assert-True ($nativeSourceText -match 'PrepareGitRuntimeSync\(source\)') "Git-testing Update/Reset prepares the exact branch runtime before applying"
Assert-True ($nativeSourceText -match 'ScheduleGitRuntimeSync\(source, pendingGitRuntime\)') "Git-testing schedules runtime alignment only after managed apply"
Assert-True ($nativeSourceText -match '(?s)ApplyPlan\(plan, source\.Manifest, selection, source\);\s*RestoreRememberedThemeAfterManagedApply\(plan\);') "normal managed update/reset restores selected theme after applying files"
Assert-True ($nativeSourceText -match 'Managed file verification failed after write') "managed file writes are hash-verified before baseline commit"
$runtimeText = Get-Content -LiteralPath $runtimePath -Raw
Assert-True ($runtimeText -match 'function Test-WgdotPlanWritesYazi') "PowerShell maintenance path detects actual Yazi config writes"
Assert-True ($runtimeText -match 'function Write-WgdotYaziRestartNoticeForPlan') "PowerShell maintenance path reports when Yazi should be restarted"
Assert-True ($runtimeText -match 'Yazi configuration was updated\. Restart any open Yazi sessions to load the new configuration\.') "PowerShell maintenance path tells users to restart Yazi after config changes"
Assert-True ($runtimeText -notmatch 'Confirm-WgdotYaziClosedForPlan|Close Yazi and continue\?') "PowerShell maintenance path does not require Yazi to close before managed writes"
Assert-True ($nativeSourceText -match 'RestartDesktopSessionAfterManagedApply\(plan\)') "managed update/reset refreshes the running desktop after file application"
Assert-True ($nativeSourceText -match 'ManagedPlanNeedsDesktopRestart') "managed desktop restart is gated by actual non-theme writes"
Assert-True ($nativeSourceText -match 'ManagedPlanWritesYazi') "native managed apply detects actual Yazi config writes"
Assert-True ($nativeSourceText -match 'WriteYaziRestartNoticeAfterManagedApply') "native managed apply reports when Yazi should be restarted"
Assert-True ($nativeSourceText -match 'Yazi configuration was updated\. Restart any open Yazi sessions to load the new configuration\.') "native managed apply tells users to restart Yazi after config changes"
Assert-True ($nativeSourceText -notmatch 'ConfirmYaziClosedForManagedApply|Close Yazi and continue\?|StopProcessesByName\("yazi"\)') "native managed apply leaves running Yazi sessions alone"
Assert-True ($nativeSourceText -match 'Restarted GlazeWM and YASB') "desktop refresh reports the paired GlazeWM/YASB restart"
Assert-True ($nativeSourceText -match 'ReturnRuntimeSourceToMainAfterStableApply\(source\)') "stable managed apply returns runtime source tracking to main"
Assert-True ($nativeSourceText -match 'if \(command == "update"\) return ManagedOperation\("update", ResolveStableSource\(\)\)') "direct managed update resolves the published stable source"
Assert-True ($nativeSourceText -match 'ManagedOperation\("update", ResolveStableSource\(\)\);') "interactive managed update resolves the published stable source"
Assert-True ($nativeSourceText -match 'Git-testing runtime self-test failed') "Git-testing runtime sync fails closed when the exact runtime self-test fails"
Assert-True ($nativeSourceText -match 'runtimeSyncPendingRevision') "Git-testing records pending runtime sync state without claiming installation"
Assert-True ($nativeSourceText -match 'state\.Remove\("runtimeSyncPendingRevision"\)') "runtime pending state clears only through successful runtime mark"
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
Assert-True ($nativeSourceText -match 'static bool StartupPackageIsInstalled\(') "startup manager can positively detect supported installed applications"
Assert-True ($nativeSourceText -match '(?s)selectedPackages\.Contains\(GetString\(p, "id"\)\)\s*\|\|\s*StartupPackageIsInstalled\(p\)') "startup manager lists selected or already-installed supported applications"
Assert-True ($nativeSourceText -match 'bool desired = \(packageSelected \|\| packageInstalled\) && preferred;') "remembered startup preferences remain effective for installed-but-unselected applications"
Assert-True ($nativeSourceText -match 'preferred = packageSelected && GetBool\(package, "startupDefault"\)') "installed-but-unselected startup entries default off until explicitly enabled"
Assert-True ($nativeSourceText -match 'static bool IsRawAccelGuiExecutable\(') "RawAccel startup positively identifies the GUI executable"
Assert-True ($nativeSourceText -match 'static string FindRawAccelExe\(') "RawAccel startup uses one deterministic executable resolver"
Assert-True ($nativeSourceText -match 'Path\.Combine\(local, "Programs", "RawAccel", "rawaccel\.exe"\)') "RawAccel resolver covers the WGDot-managed per-user install"
Assert-True ($nativeSourceText -match 'Path\.Combine\(programFiles, "RawAccel", "rawaccel\.exe"\)') "RawAccel resolver covers a conventional Program Files install"
Assert-True ($nativeSourceText -match 'FindRegisteredAppPath\("rawaccel\.exe"\)') "RawAccel resolver accepts a positively registered application path"
Assert-True ($nativeSourceText -match 'where\.exe", "rawaccel\.exe"') "RawAccel resolver accepts an explicit PATH-resolved GUI"
Assert-True ($nativeSourceText -match 'FirstOrDefault\(IsRawAccelGuiExecutable\)') "RawAccel resolver rejects unverified candidates"
Assert-True ($nativeSourceText -match 'Q\(HiddenLauncherPath\(\)\) \+ " rawaccel-startup"') "RawAccel HKCU Run command uses the quoted windowless startup helper"
Assert-True ($nativeSourceText -match 'if \(command == "rawaccel-startup"\) return RawAccelStartup\(\);') "RawAccel startup helper has an explicit native command"
$rawAccelDefaultProcessStartBlock = [regex]::Match($nativeSourceText, '(?ms)static Process StartRawAccelGuiProcess\(\).*?^    }').Value
Assert-True ($rawAccelDefaultProcessStartBlock -match 'return StartRawAccelGuiProcess\(false\);') "RawAccel normal/hotkey launch uses the visible process-start policy"
$rawAccelProcessStartBlock = [regex]::Match($nativeSourceText, '(?ms)static Process StartRawAccelGuiProcess\(bool startMinimized\).*?^    }').Value
Assert-True ($rawAccelProcessStartBlock -match 'psi\.FileName = exe;') "RawAccel startup launches the resolved GUI executable"
Assert-True ($rawAccelProcessStartBlock -match 'psi\.WorkingDirectory = workingDirectory;') "RawAccel startup sets the GUI working directory"
Assert-True ($rawAccelProcessStartBlock -match 'Path\.GetDirectoryName\(exe\)') "RawAccel startup derives working directory from the executable"
Assert-True ($rawAccelProcessStartBlock -match 'psi\.WindowStyle = startMinimized') "RawAccel process launch explicitly controls minimized startup state"
Assert-True ($rawAccelProcessStartBlock -match 'ProcessWindowStyle\.Minimized') "RawAccel login startup can request a minimized GUI before first paint"
Assert-True ($rawAccelProcessStartBlock -notmatch 'settings\.json|\.config|File\.Write') "RawAccel process launch never changes the acceleration profile/configuration"
$rawAccelStartBlock = [regex]::Match($nativeSourceText, '(?ms)static int StartRawAccelGui\(\).*?^    }').Value
Assert-True ($rawAccelStartBlock -match 'StartRawAccelGuiProcess\(\)') "RawAccel startup delegates to the shared working-directory-safe process launcher"
Assert-True ($rawAccelStartBlock -notmatch 'SizeRawAccelHotkeyWindow') "RawAccel generic startup path does not apply hotkey-only sizing"
Assert-True ($nativeSourceText -match 'const double RawAccelHotkeyWidthRatio = 0\.625;') "RawAccel hotkey window width scales with active monitor working area"
Assert-True ($nativeSourceText -match 'const double RawAccelHotkeyHeightRatio = 0\.825;') "RawAccel hotkey window height scales with active monitor working area"
$rawAccelSizeBlock = [regex]::Match($nativeSourceText, '(?ms)static void SizeRawAccelHotkeyWindow\(.*?^    }').Value
Assert-True (-not [string]::IsNullOrWhiteSpace($rawAccelSizeBlock)) "RawAccel hotkey window sizing helper is present"
Assert-True ($rawAccelSizeBlock -match 'SetWindowPos\(') "RawAccel hotkey launch resizes the native GUI window"
Assert-True ($rawAccelSizeBlock -match 'work\.Width \* RawAccelHotkeyWidthRatio') "RawAccel hotkey width derives from active monitor resolution/scale-aware working area"
Assert-True ($rawAccelSizeBlock -match 'work\.Height \* RawAccelHotkeyHeightRatio') "RawAccel hotkey height derives from active monitor resolution/scale-aware working area"
Assert-True ($rawAccelSizeBlock -match 'System\.Threading\.Thread\.Sleep\(300\)') "RawAccel hotkey sizing waits for GlazeWM window management before applying geometry"
Assert-True ($rawAccelSizeBlock -match 'for \(int i = 0; i < 8; i\+\+\)') "RawAccel hotkey sizing reapplies geometry long enough to avoid the GlazeWM float-rule race"
Assert-True ($rawAccelSizeBlock -match 'SetForegroundWindow\(window\)') "RawAccel hotkey launch brings the resized GUI forward"
$rawAccelToggleBlock = [regex]::Match($nativeSourceText, '(?ms)static int RawAccelToggle\(\).*?^    }').Value
Assert-True ($rawAccelToggleBlock -match 'CurrentInteractionScreen\(\)') "RawAccel hotkey sizing targets the active monitor"
Assert-True ($rawAccelToggleBlock -match 'SizeRawAccelHotkeyWindow\(started, targetScreen\)') "RawAccel toggle applies compact hotkey sizing after launch"
$rawAccelStartupBlock = [regex]::Match($nativeSourceText, '(?ms)static int RawAccelStartup\(\).*?^    }').Value
Assert-True ($rawAccelStartupBlock -match 'TryRunRawAccelStartupWriter\(\)') "RawAccel Windows-login startup prefers the upstream headless writer path"
Assert-True ($rawAccelStartupBlock -match 'StartRawAccelGuiProcess\(true\)') "RawAccel Windows-login fallback starts the GUI minimized before bounded initialization"
Assert-True ($rawAccelStartupBlock -match 'CompleteRawAccelGuiStartupAndClose\(started\)') "RawAccel Windows-login fallback closes the GUI after initialization"
Assert-True ($rawAccelStartupBlock -notmatch 'SizeRawAccelHotkeyWindow') "RawAccel Windows-login startup is not resized by the hotkey-only policy"
$rawAccelWriterBlock = [regex]::Match($nativeSourceText, '(?ms)static bool TryRunRawAccelStartupWriter\(\).*?^    }').Value
Assert-True ($rawAccelWriterBlock -match 'Path\.Combine\(directory, "writer\.exe"\)') "RawAccel login startup resolves the bundled writer next to the verified GUI"
Assert-True ($rawAccelWriterBlock -match 'Path\.Combine\(directory, "settings\.json"\)') "RawAccel login startup applies the saved settings.json"
Assert-True ($rawAccelWriterBlock -match 'RunWithTimeout\(') "RawAccel login writer is bounded instead of becoming a persistent startup process"
Assert-True ($rawAccelWriterBlock -match 'Q\(settings\)') "RawAccel login writer preserves settings path argument boundaries"
$rawAccelStartupCloseBlock = [regex]::Match($nativeSourceText, '(?ms)static void CompleteRawAccelGuiStartupAndClose\(.*?^    }').Value
Assert-True ($rawAccelStartupCloseBlock -match 'PostMessage\(window, WmClose') "RawAccel login GUI fallback closes its window normally after initialization"
Assert-True ($rawAccelStartupCloseBlock -match 'process\.WaitForExit\(5000\)') "RawAccel login GUI fallback verifies the process exits"
Assert-True ($nativeSourceText -notmatch 'ShowWindowAsync|SwShowMinNoActive|MinimizeRawAccelStartupWindow') "RawAccel login startup no longer leaves a minimized resident GUI"
Assert-True ($nativeSourceText -notmatch 'return "explorer\.exe shell:AppsFolder\\\\40459File-New-Project\.EarTrumpet') "EarTrumpet startup no longer uses the Explorer/Documents-prone AppsFolder command"
Assert-True ($nativeSourceText -match 'Q\(HiddenLauncherPath\(\)\) \+ " eartrumpet-startup"') "EarTrumpet startup uses the windowless Start Menu launcher helper"
Assert-True ($nativeSourceText -match 'if \(command == "eartrumpet-startup"\) return EarTrumpetStartup\(\);') "EarTrumpet login startup has an explicit native command"
Assert-True ($nativeSourceText -match 'uninstall --id ') "standard catalog applications use exact WinGet uninstall"
$upgradeRecoveryBlock = [regex]::Match($nativeSourceText, '(?ms)foreach \(string id in GetStringList\(plan, "upgradeIds"\).*?^            }').Value
Assert-True ($upgradeRecoveryBlock -match 'upgrade --id ') "approved software upgrades use exact WinGet IDs"
Assert-True ($upgradeRecoveryBlock -match 'uninstall --id ') "failed WinGet upgrades automatically attempt exact-ID uninstall recovery"
Assert-True ($upgradeRecoveryBlock -match '--all-versions') "multi-version WinGet uninstall ambiguity retries by removing all versions of the exact package ID"
Assert-True ($upgradeRecoveryBlock -match 'PrepareWingetPackageMutation') "upgrade recovery closes declared package-blocking processes"
Assert-True ($upgradeRecoveryBlock -match 'install --id ') "failed WinGet upgrades reinstall the exact package after successful uninstall"
Assert-True ($upgradeRecoveryBlock -match 'reinstalledIds\.Add\(id\)') "successful upgrade recovery is tracked separately"
Assert-True ($nativeSourceText -match 'Reinstalled after failed upgrade: ') "software reconciliation reports recovered upgrade reinstalls"
Assert-True ($nativeSourceText -match 'Uninstall exactly these applications\?') "software removal requires a dedicated confirmation"
Assert-True ($nativeSourceText -match 'selection\.Packages\.RemoveAll') "successfully uninstalled software is removed from WGDot desired state"
Assert-True ($nativeSourceText -match 'Install/reconcile this software selection\? \[y/N\]') "software mutation requires confirmation"
Assert-True ($nativeSourceText -match 'if \(command == "software-elevated"\) return SoftwareElevatedFromArgs') "native runtime exposes the internal elevated software worker command"
Assert-True ($nativeSourceText -match 'RunElevatedSelfWithExitCode\("software-elevated --plan "') "software reconciliation elevates one WGDot worker rather than each package"
Assert-True ([regex]::Matches($nativeSourceText, 'RunElevatedSelfWithExitCode\("software-elevated --plan "').Count -eq 1) "software reconciliation contains one batch elevation handoff"
Assert-True ($nativeSourceText -match '(?s)software-elevated --plan .*?--plan-sha256') "software elevation binds the exact plan digest"
$softwareElevatedArgsBlock = [regex]::Match($nativeSourceText, '(?ms)static int SoftwareElevatedFromArgs\(.*?^    }').Value
Assert-True ($softwareElevatedArgsBlock -match 'GetOption\(args, "--plan-sha256"\)') "elevated software worker requires the expected plan digest"
$softwareElevatedPlanBlock = [regex]::Match($nativeSourceText, '(?ms)static int RunSoftwareElevatedPlan\(.*?^    }').Value
Assert-True ($softwareElevatedPlanBlock -match 'ReadVerifiedJson\(planPath, expectedPlanSha256\)') "elevated software worker parses only verified plan bytes"
Assert-True ($softwareElevatedPlanBlock -notmatch 'ReadJson\(planPath\)') "elevated software worker never reopens an unverified plan"
Assert-True ($softwareElevatedPlanBlock -match 'string winget = RequireWingetExe\(\);') "elevated software worker resolves one trusted WinGet path"
Assert-True ($softwareElevatedPlanBlock -notmatch '(?:RunWithTimeout|RunInteractiveWithTimeout|RunInteractive)\(\s*"winget\.exe"') "elevated software worker never launches a bare WinGet name"
$findWingetBlock = [regex]::Match($nativeSourceText, '(?ms)static string FindWingetExe\(\).*?^    }').Value
Assert-True ($findWingetBlock -match 'GetWindowsAppsRoot\(\)') "WinGet resolution is rooted in the current user WindowsApps directory"
Assert-True ($findWingetBlock -notmatch 'ExecutableExists\("winget\.exe"\)|return "winget\.exe"') "WinGet resolution never accepts inherited PATH"
$ensureDduBlock = [regex]::Match($nativeSourceText, '(?ms)static string EnsureDduInstalled\(\).*?^    }').Value
Assert-True ($ensureDduBlock -match 'string winget = RequireWingetExe\(\);') "DDU installation uses the same trusted WinGet path"
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
Assert-True ($nativeBootstrapText -match '(?i)--dots-only') "native bootstrap exposes explicit dots-only mode"
Assert-True ($nativeBootstrapText -match '(?i)--profile') "native dots-only bootstrap requires an explicit profile"
$dotsBootstrapBlock = [regex]::Match($nativeBootstrapText, '(?s):apply_dots_only.*?(?=:cleanup)').Value
Assert-True (-not [string]::IsNullOrWhiteSpace($dotsBootstrapBlock)) "native bootstrap has a dedicated dots-only execution block"
Assert-True ($dotsBootstrapBlock -match '"%INSTALLED_WGDOT%" dots-only --profile "%DOTS_PROFILE%" --yes') "dots-only bootstrap dispatches through the installed WGDot runtime"
Assert-True ($dotsBootstrapBlock -notmatch '(?i)ensure-winget|winget\.exe|software-reconcile|software-elevated') "dots-only bootstrap cannot enter software prerequisite or reconciliation paths"
Assert-True ($nativeSourceText -match 'YASB font note: NotoSansM Nerd Font Mono is not installed') "dots-only warns when the managed bar font is missing"
Assert-True ($nativeSourceText -match 'Install only the managed bar font with: wgdot bar-font-install') "dots-only points to the narrow font-only repair command"
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
Assert-True ($null -eq $flowPackage) "Flow Launcher is retired from the WGDot software catalog"
Assert-True ($nativeSourceText -match 'result\.Packages\.RemoveAll\(x => String\.Equals\(x, "Flow-Launcher\.Flow-Launcher"') "older saved Flow Launcher package selections are retired without uninstalling the app"
Assert-True ($nativeSourceText -match 'result\.Packages\.RemoveAll\(x => String\.Equals\(x, "Alexx2000\.DoubleCommander"') "older saved Double Commander package selections are retired without uninstalling the app"
Assert-True ($runtimeText -match 'Alexx2000\.DoubleCommander') "compatibility updater also retires saved Double Commander selections"
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
Assert-True ($nativeSourceText -match '"Standard \(repo guide default\)", "Strict", "Skip"') "privacy.sexy optional action is labeled Skip instead of Cancel"
Assert-True ($nativeSourceText -match 'or disable antivirus') "privacy.sexy integration does not weaken antivirus protection"
Assert-True ($null -ne (@($manifest.tweaks | Where-Object { $_.id -eq 'restore-clipboard-history' })[0])) "privacy.sexy Clipboard History restore action is present"
Assert-True ([bool](@($manifest.tweaks | Where-Object { $_.id -eq 'restore-clipboard-history' })[0].actionOnly)) "Clipboard History restore is action-only"
Assert-True ($nativeSourceText -match 'command == "restore-clipboard-history"') "Clipboard History restore has a direct elevated re-entry command"
Assert-True ($nativeSourceText -match 'EnableClipboardHistory') "Clipboard History restore repairs the current-user history setting"
Assert-True ($nativeSourceText -match 'AllowClipboardHistory') "Clipboard History restore removes the privacy.sexy machine deny policy"
Assert-True ($nativeSourceText -match 'cbdhsvc') "Clipboard History restore repairs the Clipboard User Service when privacy.sexy disabled it"
Assert-True ($nativeSourceText -match 'Cross-device clipboard sync settings were not changed') "Clipboard History restore stays narrowly scoped and does not enable cloud clipboard sync"
Assert-True ($nativeSourceText -match 'result\["failureDetails"\] = failureDetails') "elevated worker returns human-readable failure details"
Assert-True ($nativeSourceText -match 'Failure details:') "software reconciliation prints exact failure details in the main WGDot window"
Assert-True ($nativeSourceText -match 'Administrator tweak') "elevated tweak failures identify the exact tweak and reason"
Assert-True ($nativeSourceText -match 'Firefox extension policy:') "Firefox policy failures remain identifiable after the elevated window closes"
Assert-True ($nativeSourceText -match 'OpenRegistryKeyForValueWrite') "registry writes open existing keys before attempting to create them"
Assert-True ($nativeSourceText -match 'RegistryRights\.QueryValues \| RegistryRights\.SetValue') "existing registry keys request only value query/write rights"
Assert-True ($nativeSourceText -match 'Registry access denied:') "registry failures identify the exact hive/path/value"
Assert-True ($nativeSourceText -match 'catch \(SecurityException ex\)') "registry mutation helper normalizes SecurityException access denials"
Assert-True ($nativeSourceText -match 'Microsoft\.Win32 can surface protected registry writes as either') "registry helper documents both Windows access-denied exception paths"
Assert-True ($nativeSourceText -match 'DiscardRegistryOriginalSnapshot') "failed TaskbarDa writes do not leave a false rollback snapshot"
Assert-True ($nativeSourceText -match 'AllowNewsAndInterests') "protected TaskbarDa falls back to the documented Widgets policy"
Assert-True ($nativeSourceText -match 'using the supported Widgets policy fallback') "Widgets fallback is visible during reconciliation"
Assert-True ($nativeSourceText -match 'Windows also protected the Widgets machine policy') "double-protected Widgets state is reported as a compatibility warning"
Assert-True ($nativeSourceText -match 'Widgets were left unchanged; the remaining taskbar cleanup will continue') "Widgets access denial does not abort the rest of clean-taskbar-items"
Assert-True ($nativeSourceText -match 'DiscardRegistryOriginalSnapshot\(\s*id,\s*"HKLM",\s*widgetsPolicyPath,\s*widgetsPolicyName\)') "failed Widgets policy fallback does not retain false rollback ownership"
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
Assert-True ($nativeSourceText -match 'IsOfficialGitHubPortablePackage\(package\) \|\|\s*IsOfficialGitHubFontArchivePackage\(package\)') "portable applications and user-font archives share the unelevated package guard"
Assert-True ($nativeSourceText -match 'Refusing to install a user-level package inside the elevated worker') "user-level packages are kept out of the elevated worker"
Assert-True ($nativeSourceText -match 'official GitHub OK') "audit reports official GitHub packages without a false WinGet-missing warning"
Assert-True ($nativeSourceText -match 'Official GitHub source selected') "reconcile skips dead WinGet lookup for official GitHub packages"
$glazePackage = @($manifest.packages | Where-Object { $_.id -eq 'glzr-io.glazewm' })[0]
Assert-True (@($glazePackage.wingetForceStopProcesses) -contains 'glazewm') "GlazeWM WinGet maintenance can stop its running WM process"
Assert-True ([bool]$glazePackage.wingetRestartAfterMutation) "GlazeWM is restarted after package maintenance when it was previously running"
$obsPackage = @($manifest.packages | Where-Object { $_.id -eq 'OBSProject.OBSStudio' })[0]
Assert-True (@($obsPackage.wingetCloseProcesses) -contains 'obs64') "OBS WinGet maintenance closes 64-bit OBS before package mutation"
Assert-True (@($obsPackage.wingetCloseProcesses) -contains 'obs32') "OBS WinGet maintenance covers legacy 32-bit OBS process naming"
Assert-True ([bool]$obsPackage.wingetObsHookRecovery) "OBS enables targeted graphics-hook package-in-use recovery"
Assert-True ($nativeSourceText -match 'RunWingetInstallWithObsHookRecovery') "OBS install path has one targeted WinGet package-in-use retry"
Assert-True ($nativeSourceText -match 'graphics-hook64\.dll') "OBS recovery detects 64-bit graphics-hook users"
Assert-True ($nativeSourceText -match 'graphics-hook32\.dll') "OBS recovery detects 32-bit graphics-hook users"
Assert-True ($nativeSourceText -match 'DISABLE_VULKAN_OBS_CAPTURE') "OBS recovery disables Vulkan hook injection while blockers are closed"
Assert-True ($nativeSourceText -match 'obs-vulkan64\.json') "OBS recovery temporarily disables the registered 64-bit Vulkan layer"
Assert-True ($nativeSourceText -match 'obs-vulkan32\.json') "OBS recovery temporarily disables the registered 32-bit Vulkan layer"
Assert-True ($nativeSourceText -match 'first\.ExitCode != -1978334959') "OBS recovery is limited to WinGet package-in-use-by-application failures"
Assert-True ($nativeSourceText -match 'obs-studio-hook') "OBS recovery knows the upstream ProgramData global hook directory"
Assert-True ($nativeSourceText -match 'CleanupOrphanedObsHookStateForInstall') "OBS reinstall cleans stale global hook state before trying the package again"
Assert-True ($nativeSourceText -match 'MakeWingetInteractiveArguments') "OBS recovery can fall back to the official interactive installer for an unknown lock holder"
Assert-True ($nativeSourceText -match 'Opening the official OBS installer interactively') "OBS fallback explains the interactive recovery step"
Assert-True ($nativeSourceText -match 'StopAsusFrameworkForObsInstall') "OBS recovery explicitly handles the ASUS NodeJS Web Framework blocker"
Assert-True ($nativeSourceText -match 'taskkill\.exe') "OBS ASUS recovery stops the blocker process tree rather than only its parent process"
Assert-True ($nativeSourceText -match 'asus_framework\.exe /T /F') "OBS ASUS recovery targets the confirmed ASUS framework executable and child processes"
Assert-True ($nativeSourceText -match 'ASUS\\Framework Service') "OBS ASUS recovery restarts the vendor framework through its scheduled task"
Assert-True ($nativeSourceText -match 'RestartAsusFrameworkAfterObsInstall') "OBS ASUS recovery restores the vendor framework after package maintenance"
$rustDeskPackage = @($manifest.packages | Where-Object { $_.id -eq 'RustDesk.RustDesk' })[0]
Assert-True ($null -ne $rustDeskPackage) "RustDesk catalog entry exists"
Assert-Equal ([string]$rustDeskPackage.installMode) 'official-github' "RustDesk uses its verified official GitHub source instead of a missing WinGet ID"
Assert-Equal ([string]$rustDeskPackage.fallbackGitHubRepo) 'rustdesk/rustdesk' "RustDesk official GitHub source remains publisher-owned"
Assert-True ($nativeSourceText -match 'const string Version = "native-preview-94"') "native runtime version tracks current WGDot maintenance changes"
Assert-True ($nativeSourceText -match 'InstallGitHubFontArchivePackage') "native runtime installs managed Nerd Font archives without inventing a WinGet ID"
Assert-True ($nativeSourceText -match 'AddFontResourceEx') "managed Noto font is loaded into the current Windows session"
Assert-True ($nativeSourceText -match 'Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts') "managed Noto font registers under the current-user Windows Fonts key"
Assert-True ($nativeSourceText -match 'if \(command == "theme"\) return ThemeManagerFromArgs') "compiled WGDot exposes the approved live theme helper"
$requiredRefreshBlock = [regex]::Match($nativeSourceText, '(?s)string\[\] requiredRefreshCommands\s*=\s*\{.*?\};').Value
Assert-True (-not [string]::IsNullOrWhiteSpace($requiredRefreshBlock)) "acceptance audit refresh-policy block is present"
Assert-True ($requiredRefreshBlock -notmatch '"theme"') "theme switching is not part of WGDot runtime refresh policy"
Assert-True ($manifestText -notmatch 'script-theme-switcher|theme-switcher\.ps1|bar-autohide\.ps1|idle-inhibitor\.ps1|rawaccel-toggle\.ps1') "manifest does not deploy obsolete desktop runtime scripts"
Assert-True ($manifestText -match 'yasb-theme') "YASB theme CSS is a tracked managed dotfile"
foreach ($microTheme in @("geany", "zenburn", "gruvbox", "gotham", "railscast", "cmc-16", "catppuccin-frappe-transparent", "catppuccin-mocha-transparent")) {
    Assert-True ($manifestText -match ("micro-theme-" + [regex]::Escape($microTheme))) "Micro theme is managed: $microTheme"
    Assert-True (Test-Path -LiteralPath (Join-Path $repoRoot ("UserProfile\.config\micro\colorschemes\" + $microTheme + ".micro")) -PathType Leaf) "Micro theme source exists: $microTheme"
}
Assert-True ($nativeSourceText -match '(?s)requiredRefreshCommands.*?"cursor"') "acceptance audit requires cursor runtime auto-refresh"
Assert-True ($nativeSourceText -match '(?s)requiredRefreshCommands.*?"dots-only"') "acceptance audit requires dots-only runtime auto-refresh"
Assert-True ($nativeSourceText -match 'BuildYasbThemeCss') "compiled WGDot retains YASB theme generation for restricted Work"
Assert-True ($nativeSourceText -match 'ApplyMicroTheme') "compiled WGDot theme manager synchronizes Micro"
Assert-True ($nativeSourceText -match 'MICRO_CONFIG_HOME') "WGDot Micro theme sync honors MICRO_CONFIG_HOME"
Assert-True ($nativeSourceText -match 'XDG_CONFIG_HOME') "WGDot Micro theme sync honors XDG_CONFIG_HOME"
Assert-True ($nativeSourceText -match 'SpecialFolder\.UserProfile') "WGDot Micro theme sync defaults to the user profile .config path"
Assert-True ($nativeSourceText -match '"carbon-night".*"geany"') "Carbon Night maps to Awtarchy Micro geany"
Assert-True ($nativeSourceText -match '"catppuccin-frappe".*"catppuccin-frappe-transparent"') "Catppuccin Frappe maps to Awtarchy Micro theme"
Assert-True ($nativeSourceText -match '"pink".*"catppuccin-mocha-transparent"') "Pink maps to Awtarchy Micro theme"
Assert-True ($nativeSourceText -match '"pipboy".*"cmc-16"') "Pip-Boy maps to Awtarchy Micro cmc-16"
Assert-True ($nativeSourceText -match 'ApplyWindowsTerminalTheme') "compiled WGDot retains Windows Terminal theme synchronization"
Assert-True ($nativeSourceText -match '"#9AB8D7"') "compiled WGDot retains readable ANSI blue fallback for terminal/Yazi directories"
Assert-True ($nativeSourceText -match '"#8CD0D3"') "compiled WGDot retains readable ANSI cyan fallback for terminal/Yazi documents"
Assert-True ($nativeSourceText -match '"#709080"') "compiled WGDot retains readable brightBlack fallback for dim terminal text"
Assert-True ($manualText -match '"#9AB8D7"') "paste-only workflow retains readable ANSI blue fallback"
Assert-True ($manualText -match '"#8CD0D3"') "paste-only workflow retains readable ANSI cyan fallback"
Assert-True ($manualText -match '"#709080"') "paste-only workflow retains readable brightBlack fallback"
Assert-True ($nativeSourceText -match 'ThemeManagerFromArgs') "compiled WGDot exposes the scoped theme manager"
Assert-True ($nativeSourceText -notmatch 'OpenYasbQuickLaunch|OpenFlowLauncher|OpenEarTrumpetMixer|OpenWindowsClipboardHistory|OpenFlameshotGui|OpenRawAccel|OpenDisplaySettings|GlazeWmPauseToggle|ThemeToggle') "native-capable desktop helper implementations stay removed"
Assert-True ($nativeSourceText -match 'BarAutoHideToggle') "compiled WGDot retains the approved coordinated auto-hide helper"
Assert-True ($nativeSourceText -match 'GlazeWmWindowBehaviorToggle') "compiled WGDot exposes the scoped GlazeWM window behavior toggle"
Assert-True ($nativeSourceText -match 'initial_state:\\s\*""\(tiling\|floating\)""') "window behavior helper only toggles supported tiling/floating initial states"
Assert-True ($nativeSourceText -match 'RequireGlazeWmSuccess\(reload, "GlazeWM config reload"\)') "window behavior toggle validates GlazeWM reload success"
Assert-True ($nativeSourceText -match 'ShowWgdotNotification\("GlazeWM window_behavior", summary\)') "window behavior toggle reports the resulting state"
Assert-True ($nativeSourceText -match 'RawAccelToggle') "compiled WGDot retains the narrowly scoped RawAccel toggle"
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
Assert-True ($nativeSourceText -match 'wgdot-next-" \+ remoteRevision \+ "-" \+ Guid\.NewGuid\(\)\.ToString\("N"\)') "runtime auto-refresh uses a unique staged executable path"
Assert-True ($nativeSourceText -match 'wgdot-git-next-" \+ source\.Revision\.ToLowerInvariant\(\) \+ "-"') "Git-testing runtime sync uses a separate unique staged executable path"
Assert-True ($nativeSourceText.Contains('^wgdot-next-([0-9a-fA-F]{40})(?:-[0-9a-fA-F]{32})?\.exe$')) "staged runtime finalization recognizes unique runtime filenames"
Assert-True ($nativeSourceText -match 'string pendingRevision = state == null \? "" : GetString\(state, "runtimeSyncPendingRevision"\)') "runtime finalization reads pending Git runtime state"
Assert-True ($nativeSourceText -match 'if \(!String\.IsNullOrWhiteSpace\(pendingRevision\)\)\s*return;') "outer staged runtime does not race a Git-testing runtime replacement"
Assert-True ($nativeSourceText -match 'ScheduleStagedRuntimeInstall') "staged runtime installs itself after the requested operation exits"
Assert-True ($nativeSourceText -match 'CreateRuntimeSwapHelper') "native runtime defers replacing the running executable"
Assert-True ($nativeSourceText -match 'if \(command == "dots-only"\) return DotsOnlyFromArgs') "native runtime exposes explicit dots-only managed apply"
Assert-True ($nativeSourceText -match 'String\.Equals\(command, "dots-only"') "dots-only participates in direct-command runtime refresh policy"
$dotsOnlyMethod = [regex]::Match($nativeSourceText, '(?s)static int DotsOnlyFromArgs\(.*?(?=\r?\n    static InstallationSelection BuildDotsOnlySelection)').Value
Assert-True (-not [string]::IsNullOrWhiteSpace($dotsOnlyMethod)) "dots-only command implementation is present"
Assert-True ($dotsOnlyMethod -match 'ResolveDotsOnlySource\(\)') "dots-only keeps its explicit bootstrap-aware source resolver"
Assert-True ($dotsOnlyMethod -match 'ApplyPlan\(plan, source\.Manifest, selection, source, true\)') "dots-only applies through strict post-action gating"
Assert-True ($dotsOnlyMethod -match 'RestoreRememberedThemeAfterManagedApply\(plan\)') "dots-only restores the selected theme after managed files are written"
Assert-True ($nativeSourceText -match 'ManagedPlanWritesThemeState') "theme preservation is gated by the actual managed plan"
Assert-True ($nativeSourceText -match 'String\.Equals\(item\.FileId, "yasb-theme"') "theme preservation watches managed YASB theme writes"
Assert-True ($nativeSourceText -match 'String\.Equals\(item\.FileId, "terminal-settings"') "theme preservation watches managed Terminal settings writes"
Assert-True ($nativeSourceText -match 'Preserved selected WGDot theme') "theme preservation reports the retained selected theme"
Assert-True ($dotsOnlyMethod -notmatch 'SoftwareReconcile\(|EnsureWingetAvailable\(|SoftwareElevatedFromArgs\(|RunElevatedSelfWithExitCode\(') "dots-only command does not invoke software or elevation workers"
Assert-True ($nativeSourceText -match 'GetList\(component, "files"\)\.Count == 0') "dots-only excludes post-action-only components such as cursor registry configuration"
Assert-True ($nativeSourceText -match 'dotsOnly && !IsDotsOnlyPostAction\(type\)') "dots-only post-actions remain strictly gated"
$dotsPostActionAllowlist = [regex]::Match($nativeSourceText, '(?s)static bool IsDotsOnlyPostAction\(string type\).*?(?=\r?\n    static void RunPostActions)').Value
Assert-True ($dotsPostActionAllowlist -match 'return false;') "dots-only runs no post-actions"
Assert-True ($dotsPostActionAllowlist -notmatch 'ensure-desktop-worker|ensure-hidden-launcher|ensure-yasb-theme|yazi-package-install|set-yazi-file-one|migrate-legacy-windows-hotkeys|retire-windows-shell-hotkeys|retire-printscreen-snipping|ensure-cursor-theme') "dots-only has no runtime/system post-action exceptions"
Assert-True ($nativeSourceText -match 'PrepareRawRevisionSource') "native runtime can acquire exact managed sources from raw.githubusercontent.com"
Assert-True ($nativeSourceText -match 'WGDOT_FORCE_RAW_SOURCE') "CI can force the restricted-network raw source path"
Assert-True ($nativeSourceText -match 'source-self-test') "native runtime exposes an internal exact-source validation command"
Assert-True ($nativeSourceText -match '(?s)string recordedRevision = GetString\(bootstrap, "sourceRevision"\);.*?explicitRefTesting.*?Regex\.IsMatch\(recordedRevision.*?\? recordedRevision\.ToLowerInvariant\(\).*?: ResolveBranchHeadViaApi\(sourceRef\)') "explicit exact bootstrap revisions stay pinned without requiring a branch-head API lookup"
Assert-True ($nativeSourceText -match 'runtime-refresh\.log') "blocked API refresh checks are recorded without killing the installed runtime"
Assert-True ($nativeSourceText -match 'CopyRuntimeWithRetry') "runtime install retries replacement across transient executable locks"
Assert-True ($nativeSourceText -match 'runtime-swap-stop') "runtime self-refresh can stop legacy WGDot workers before replacing the installed executable"
Assert-True ($nativeSourceText -match 'runtime-swap-restore') "runtime self-refresh keeps a compatibility restore endpoint for older swap helpers"
Assert-True ($nativeSourceText -match 'wgdot-worker-state-') "runtime self-refresh retains a bounded staged-swap state marker"
Assert-True ($nativeSourceText -match 'IsRuntimeSwapInternalCommand') "runtime-swap internals cannot recursively schedule another staged replacement"
$runtimeRestoreBlock = [regex]::Match($nativeSourceText, '(?s)static int RuntimeSwapRestoreFromArgs\(string\[\] args\).*?(?=\r?\n    static void ScheduleStagedRuntimeInstall)').Value
Assert-True ($runtimeRestoreBlock -match 'SafeDeleteFile\(statePath\)') "compatibility restore deletes the old swap marker"
Assert-True ($runtimeRestoreBlock -notmatch 'StartRuntimeWorkerFrom|idle-inhibitor-worker|mouse-mode-hook|desktop-worker|super-l-hook') "runtime replacement never restores legacy desktop workers"
$installMethod = [regex]::Match($nativeSourceText, '(?s)static int Install\(\).*?(?=\r?\n    static int Status\(\))').Value
Assert-True ($installMethod -match 'SignalIdleInhibitorStop|SignalMouseModeHookStop|SignalDesktopWorkerStop') "runtime install retires legacy WGDot desktop workers when encountered"
Assert-True ($installMethod -notmatch 'StartRuntimeWorkerFrom') "runtime install never restarts retired desktop helpers"
Assert-True ($nativeSourceText -match 'EnsureHiddenLauncher') "native install maintains a windowless WGDot runtime frontend"
Assert-True ($nativeSourceText -match '/target:winexe') "windowless WGDot frontend compiles without a console subsystem"
Assert-True ($nativeSourceText -match 'const string HiddenLauncherVersion = "2\.0\.0\.0"') "windowless WGDot frontend has an explicit update version"
Assert-True ($nativeSourceText -match 'static string QuoteForwardedArgument\(string value\)') "windowless WGDot frontend quotes each forwarded argument"
Assert-True ($nativeSourceText -match 'psi\.Arguments = BuildForwardedArguments\(args\);') "windowless WGDot frontend preserves argument boundaries"
Assert-True ($nativeSourceText -notmatch 'psi\.Arguments = String\.Join\("" "", args') "windowless WGDot frontend never forwards raw space-joined arguments"
Assert-True ($nativeSourceText -match 'if \(command == "ensure-hidden-launcher"\)') "native runtime exposes the internal windowless frontend refresh command"
$runtimeSwapHelperBlock = [regex]::Match($nativeSourceText, '(?ms)static string CreateRuntimeSwapHelper\(.*?^    }').Value
Assert-True ($runtimeSwapHelperBlock -match 'ensure-hidden-launcher') "runtime self-refresh updates an outdated windowless frontend"
Assert-True ($runtimeSwapHelperBlock -match '(?s)ensure-hidden-launcher.*?mark-runtime') "runtime revision is recorded only after the windowless frontend is current"
Assert-True ($nativeSourceText -match 'Runtime replacement helper self-test failed') "native self-test exercises runtime replacement helper"
Assert-True ($nativeSourceText -match '"mark-runtime"') "runtime revision is recorded by the successfully swapped executable"
Assert-True ($nativeSourceText -match 'WGDOT_SKIP_RUNTIME_REFRESH') "staged runtime avoids recursive refresh while running the requested operation"
Assert-True ($nativeSourceText -match '"maintenance-self-test"') "native runtime exposes isolated maintenance self-test"
Assert-True ($nativeSourceText -notmatch 'String.Equals\(type, "ensure-yasb-theme"') "native runtime no longer runs generated YASB theme post-actions"
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

    Set-WgdotYasbTheme -Id "carbon-night" -CssPath $themeCssPath -StatePath $themeStatePath -TerminalSettingsPath $terminalSettingsPath
    $carbonTerminalSettings = Get-Content -LiteralPath $terminalSettingsPath -Raw | ConvertFrom-Json
    $carbonScheme = @($carbonTerminalSettings.schemes | Where-Object { $_.name -eq "WGDot Carbon Night" }) | Select-Object -First 1
    Assert-True ($null -ne $carbonScheme) "PowerShell fallback writes Carbon Night Terminal scheme"
    Assert-Equal "#9AB8D7" ([string]$carbonScheme.blue) "Carbon Night ANSI blue stays readable for Yazi directory names"
    Assert-Equal "#8CD0D3" ([string]$carbonScheme.cyan) "Carbon Night ANSI cyan stays readable for Yazi PDF/document names"
    Assert-Equal "#709080" ([string]$carbonScheme.brightBlack) "Carbon Night brightBlack stays readable for dim terminal text"

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
Assert-True ($tweakIds -notcontains "flow-launcher-alt-p") "Flow Launcher global Alt+P tweak is retired"
Assert-True ($tweakIds -notcontains "eartrumpet-mixer-super-v") "retired EarTrumpet Super+V tweak stays out of the catalog"
Assert-True ($nativeSourceText -notmatch 'ApplyEarTrumpetMixerSuperV|set-win-v|ApplicationDataManager\.CreateForPackageFamily') "WGDot no longer rewrites EarTrumpet's mixer hotkey"
Assert-True ($nativeSourceText -match 'result\.Tweaks\.RemoveAll\(x => String\.Equals\(x, "flow-launcher-alt-p"') "saved selections retire the old Flow global hotkey"
Assert-True ($nativeSourceText -match 'eartrumpet-mixer-alt-v') "saved selections retire the legacy EarTrumpet Alt+V tweak id"
Assert-True ($nativeSourceText -match 'eartrumpet-mixer-super-v') "saved selections retire the later EarTrumpet Super+V tweak id"
Assert-True ($nativeSourceText -notmatch 'result\.Tweaks\.Add\("eartrumpet-mixer-super-v"\)') "saved selections never re-add the retired EarTrumpet Super+V tweak"
Assert-True ($nativeSourceText -match 'ApplyWindowsShellHotkeysPolicy') "native runtime implements reversible selective Windows hotkey filtering"
Assert-True ($nativeSourceText -match 'MigrateLegacyWindowsShellHotkeys') "native runtime migrates WGDot-owned legacy NoWinKeys state"
Assert-True ($nativeSourceText -match '(?s)MigrateLegacyWindowsShellHotkeys\(bool allowElevation\).*?if \(!IsAdministrator\(\)\).*?RunElevatedSelf\("migrate-legacy-hotkeys"\)') "legacy NoWinKeys migration elevates before opening the protected policy key for write"
Assert-True ($nativeSourceText -match 'DiscardRegistryOriginalSnapshot\(id, "HKCU", legacyPath, legacyName\)') "legacy NoWinKeys ownership is retired after migration"
Assert-True ([bool](@(($manifest.components | Where-Object { $_.id -eq "glazewm" }).postActions | Where-Object { $_.type -eq "retire-windows-shell-hotkeys" }).Count -eq 1)) "managed GlazeWM updates retire the optional Windows shell-hotkey filter"
Assert-True ([bool](@(($manifest.components | Where-Object { $_.id -eq "glazewm" }).postActions | Where-Object { $_.type -eq "retire-printscreen-snipping" }).Count -eq 1)) "managed GlazeWM updates restore the retired Print Screen interception tweak"
foreach ($hiddenTweakId in @("disable-printscreen-snipping", "disable-windows-shell-hotkeys", "oops-all-links-cursor")) {
    $hiddenTweak = $manifest.tweaks | Where-Object { $_.id -eq $hiddenTweakId }
    Assert-True ([bool]$hiddenTweak.hiddenFromMenu) "retired setup tweak is hidden from the interactive menu: $hiddenTweakId"
    Assert-True (-not [bool]$hiddenTweak.defaultNormal -and -not [bool]$hiddenTweak.defaultWork) "retired setup tweak defaults off: $hiddenTweakId"
}
foreach ($defaultOffTweakId in @(
    "disable-enhanced-pointer-precision",
    "disable-snap-assist",
    "disable-remote-assistance",
    "enable-windows-sudo",
    "reduce-visual-effects",
    "classic-context-menu"
)) {
    $defaultOffTweak = $manifest.tweaks | Where-Object { $_.id -eq $defaultOffTweakId }
    Assert-True (-not [bool]$defaultOffTweak.defaultNormal -and -not [bool]$defaultOffTweak.defaultWork) "preference-sensitive tweak defaults off: $defaultOffTweakId"
}
Assert-True ($nativeSourceText -match 'CurrentTweakDefaultsVersion = 1') "tweak defaults carry a one-time saved-selection migration version"
Assert-True ($nativeSourceText -match 'savedTweakDefaultsVersion < CurrentTweakDefaultsVersion') "existing tweak selections migrate to the new preference-sensitive defaults once"
Assert-True ($nativeSourceText -match 'hiddenFromMenu') "tweak menu skips retired compatibility entries"
Assert-True ($nativeSourceText -match '"DisabledHotkeys"') "native runtime uses selective Explorer DisabledHotkeys instead of blanket NoWinKeys"
Assert-True ($nativeSourceText -match '"ABCDEFGHIJKLMOPQRSTUWXYZ0123456789"') "selective shell filter preserves native Win+V and Win+N"
Assert-True ($nativeSourceText -match 'RestoreRegistryOriginals\(id\)') "Windows hotkey tweak participates in registry rollback"
foreach ($desktopCommand in @(
    "quick-launch", "flow-open", "eartrumpet-mixer", "clipboard-history",
    "desktop-worker", "desktop-worker-stop",
    "flameshot-gui", "rawaccel-open", "display-settings",
    "yasb-running-apps-toggle", "yasb-running-apps-shade-toggle",
    "mouse-mode-switch", "mouse-mode-toggle", "mouse-mode-disable", "mouse-mode-hook", "glazewm-binding-mode-set",
    "glazewm-reload-config", "glazewm-pause-status", "glazewm-pause-toggle",
    "theme-toggle"
)) {
    Assert-True ($nativeSourceText -notmatch ('command == "' + [regex]::Escape($desktopCommand) + '"')) "WGDot does not dispatch unapproved desktop helper command: $desktopCommand"
}
foreach ($approvedDesktopCommand in @(
    "bar-autohide-toggle",
    "glazewm-binding-mode-toggle", "glazewm-window-behavior-toggle", "theme", "theme-window-toggle", "clipboard-history-open", "eartrumpet-mixer-toggle", "launcher", "power-menu", "btop-toggle", "rawaccel-toggle"
)) {
    Assert-True ($nativeSourceText -match ('command == "' + [regex]::Escape($approvedDesktopCommand) + '"')) "WGDot exposes approved scoped runtime helper: $approvedDesktopCommand"
}
Assert-True ($nativeSourceText -match 'const int width = 380;') "launcher remains compact at 380 px"
Assert-True ($nativeSourceText -match 'sealed class LauncherResultsView') "launcher uses the owner-drawn pixel-scroll results viewport"
Assert-True ($nativeSourceText -match 'const int ScrollbarWidth = 16;') "launcher scrollbar exposes a wider click/drag target"
Assert-True ($nativeSourceText -match 'const int ScrollbarThumbWidth = 12;') "launcher scrollbar thumb is visibly wider"
Assert-True ($nativeSourceText -match 'const double WheelPixelsPerNotch = 48\.0;') "launcher wheel uses pixel-based movement rather than ListBox item stepping"
Assert-True ($nativeSourceText -match '_scrollTimer\.Interval = 15;') "launcher smooth scrolling uses a responsive animation timer"
Assert-True ($nativeSourceText -match '_scrollOffset \+= distance \* 0\.35;') "launcher smooth scrolling eases toward the target offset"
Assert-True ($nativeSourceText -match 'new System\.Drawing\.SolidBrush\(_fieldColor\)') "launcher scrollbar track follows the active YASB surface color"
Assert-True ($nativeSourceText -match '_scrollThumbHover \|\| _draggingScrollThumb\s*\? _focusColor\s*:\s*_foregroundColor') "launcher scrollbar thumb follows the same foreground/focus theme treatment as YASB sliders"
Assert-True ($nativeSourceText -match 'LauncherCachePath = Path\.Combine\(CacheRoot, "launcher-apps\.json"\)') "launcher maintains a persistent app index cache"
Assert-True ($nativeSourceText -match 'List<LauncherApp> apps = ReadLauncherAppCache\(\);') "launcher reads the persistent app index before showing"
Assert-True ($nativeSourceText -match 'WriteLauncherAppCache\(loadedApps\)') "launcher refreshes the persistent app index asynchronously"
Assert-True ($nativeSourceText -match 'RefreshLauncherAppCache\(\);') "runtime installation prewarms the launcher app index"
Assert-True ($nativeSourceText -notmatch 'new System\.Windows\.Forms\.ListBox\(\)') "launcher no longer depends on item-stepped WinForms ListBox scrolling"
Assert-True ($nativeSourceText -match '(?s)if \(String\.Equals\(source, "bar".*?return new System\.Drawing\.Point\(\s*screen\.Bounds\.Left,') "bar launcher is flush with the active display left edge"
Assert-True ($nativeSourceText -match '(?s)bool centerScreen =.*?screen\.Bounds\.Left \+ \(\(screen\.Bounds\.Width - width\) / 2\)') "hotkey launcher retains centered placement"
Assert-True ($nativeSourceText -match 'ResolveLauncherShortcutIconPath') "launcher resolves underlying shortcut targets for clean application icons"
Assert-True ($nativeSourceText -notmatch 'ApplyEarTrumpetMixerSuperV|EnsureEarTrumpetStorageHelper|set-win-v') "retired EarTrumpet hotkey-management helper stays removed"
Assert-True ($nativeSourceText -match 'command == "eartrumpet-mixer-toggle"') "native runtime exposes the bar-only EarTrumpet mixer toggle"
Assert-True ($nativeSourceText -match 'SendEarTrumpetMixerChord') "EarTrumpet toggle bridge invokes the application-owned hotkey"
Assert-True ($nativeSourceText -match 'StartEarTrumpetFromStartMenu') "EarTrumpet toggle bridge can start the app through its Start Menu shortcut"
Assert-True ($nativeSourceText -match 'const byte VkLmenu = 0xA4;') "EarTrumpet toggle uses left Alt rather than rewriting app settings"
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
Assert-True ($nativeSourceText -match 'if \(command == "yazi-drag"\) return YaziDragFromArgs') "native runtime exposes the narrow Yazi file-drag primitive"
Assert-True ($nativeSourceText -match 'NormalizeYaziDragListPath') "Yazi native drag validates its temporary manifest path"
Assert-True ($nativeSourceText -match 'DoDragDrop') "Yazi native drag uses Windows OLE drag-drop through WinForms"
Assert-True ($nativeSourceText -match 'if \(command == "power-menu"\) return PowerMenu\(\)') "native runtime exposes the approved compiled power surface"
Assert-True ($nativeSourceText -match 'form\.Opacity = 0\.0') "power surface starts fully transparent to avoid first-frame flash"
Assert-True ($nativeSourceText -match 'StartPowerMenuFadeIn') "power surface implements fade-in"
Assert-True ($nativeSourceText -match 'BeginPowerMenuFadeOut') "power surface implements fade-out"
Assert-True ($nativeSourceText -match 'undergroundwires/privacy\.sexy/releases/latest') "privacy.sexy uses official latest GitHub release"
Assert-True ($nativeSourceText -match 'privacy\.sexy download did not return a valid Windows executable') "privacy.sexy installer payload is validated before execution"
Assert-True ($nativeSourceText -match 'SetupDiGetClassDevs') "native runtime detects present display adapters through SetupAPI"
Assert-True ($nativeSourceText -match 'VEN_1002') "GPU detection recognizes AMD PCI vendor IDs"
Assert-True ($nativeSourceText -match 'VEN_10DE') "GPU detection recognizes NVIDIA PCI vendor IDs"
Assert-True ($nativeSourceText -match 'VEN_8086') "GPU detection recognizes Intel PCI vendor IDs"
Assert-True ($nativeSourceText -match 'Wagnardsoft\.DisplayDriverUninstaller') "GPU maintenance uses the exact DDU WinGet package"
Assert-True ($nativeSourceText -match '\*WGDotGpuSafeModeResume') "DDU workflow registers a Safe Mode-capable RunOnce handoff"
Assert-True ($nativeSourceText -match 'gpu-safe-resume --state-sha256') "Safe Mode RunOnce binds the exact GPU state digest"
Assert-True ($nativeSourceText -match 'if \(command == "gpu-safe-resume"\) return GpuSafeResumeFromArgs\(args\.Skip\(1\)\.ToArray\(\)\);') "GPU resume parses its digest argument"
$gpuResumeBlock = [regex]::Match($nativeSourceText, '(?ms)static int GpuSafeResume\(.*?^    }').Value
Assert-True ($gpuResumeBlock -match 'ReadVerifiedJson\(GpuStatePath, expectedStateSha256\)') "GPU resume parses only verified state bytes"
Assert-True ($gpuResumeBlock -match 'RunElevatedSelf\("gpu-safe-resume --state-sha256 "') "GPU resume preserves its digest through UAC"
Assert-True ($gpuResumeBlock -match 'FindTrustedDduExe\(\)') "GPU resume re-resolves DDU after elevation"
Assert-True ($gpuResumeBlock -notmatch 'GetString\(state, "dduPath"\)') "GPU resume never executes the stored DDU path"
$menuBlock = [regex]::Match($nativeSourceText, '(?ms)static int Menu\(\).*?^    }').Value
Assert-True ($menuBlock -match 'GpuSafeResume\(ReadPendingGpuStateSha256\(\)\)') "Safe Mode menu fallback uses the digest protected by HKLM RunOnce"
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
Assert-True ($nativeBootstrapText -match 'curl\.exe HTTPS transport failed; trying Windows PowerShell \.NET WebClient') "native bootstrap has a managed-PC HTTPS fallback when curl Schannel fails"
Assert-True ($nativeBootstrapText -match 'New-Object Net\.WebClient') "native bootstrap fallback uses the in-box .NET WebClient"
Assert-True ($nativeBootstrapText -match 'WGDOT_FORCE_POWERSHELL_DOWNLOAD') "CI can force the bootstrap WebClient transport"
Assert-True ($nativeBootstrapText -notmatch '(?i)Set-ExecutionPolicy|-ExecutionPolicy\s+(Bypass|Unrestricted)') "bootstrap transport fallback does not alter or bypass PowerShell execution policy"
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
$yasbWorkConfigText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.config\yasb\custom_work_config.yaml") -Raw
Assert-True ($yasbConfigText -match 'context_menu:\s*false') "YASB blank-bar context menu is disabled while Alt+Ctrl+B keeps coordinated auto-hide"
Assert-True ($yasbConfigText -notmatch 'idle_inhibitor|idle-inhibitor-(?:status|toggle|worker)') "Normal YASB contains no retired idle inhibitor"
Assert-True ($yasbWorkConfigText -notmatch 'idle_inhibitor|idle-inhibitor-(?:status|toggle|worker)') "Work YASB contains no retired idle inhibitor"
Assert-True ($nativeSourceText -notmatch 'command == "idle-inhibitor-(?:status|toggle|worker)"') "WGDot no longer dispatches live idle-inhibitor commands"
Assert-True ($nativeSourceText -match 'SignalIdleInhibitorStop') "runtime replacement can still stop a legacy idle worker from an older build"
Assert-True ($yasbConfigText -match 'wgdotw\.exe clipboard-history-open') "YASB clipboard button uses the bar-only native Win+V helper"
Assert-True ($yasbConfigText -match 'glazewm_tiling_direction') "YASB exposes GlazeWM tiling direction"
Assert-True ($yasbConfigText -match 'GlazewmTilingDirectionWidget') "YASB uses its native GlazeWM tiling-direction widget"
Assert-True ($yasbConfigText -notmatch 'keys:\s*"f24"') "Normal YASB has no synthetic F24 Quick Launch bridge"
Assert-True ($yasbConfigText -notmatch 'keys:\s*"alt\+p"|keys:\s*"win\+d"') "Normal YASB leaves user-facing launcher chords to GlazeWM"
Assert-True ($yasbWorkConfigText -notmatch 'keys:\s*"f24"') "Work YASB has no synthetic F24 Quick Launch bridge"
Assert-True ($yasbWorkConfigText -notmatch 'keys:\s*"alt\+p"|keys:\s*"win\+d"') "Work YASB leaves user-facing launcher chords to GlazeWM"
Assert-True ($yasbConfigText -notmatch 'workspace_move_hub|workspace-move-hub|workspace_move_group|workspace-move-grouper') "Normal YASB removes the retired workspace hub slot"
Assert-True ($yasbWorkConfigText -notmatch 'workspace_move_hub|workspace-move-hub|workspace_move_group|workspace-move-grouper') "Work YASB removes the retired workspace hub slot"
Assert-True ($yasbConfigText -match 'glazewm\.exe command move-workspace --direction left') "Normal YASB keeps direct workspace arrows"
Assert-True ($yasbWorkConfigText -match 'glazewm\.exe command move-workspace --direction left') "Work YASB keeps direct workspace arrows"
Assert-True ($yasbConfigText -match 'populated_label:\s*"\{display_name\}"') "Normal YASB renders GlazeWM workspace display_name values"
Assert-True ($yasbWorkConfigText -match 'populated_label:\s*"\{display_name\}"') "Work YASB renders GlazeWM workspace display_name values"
Assert-True ($yasbConfigText -notmatch 'populated_label:\s*"\{name\}"') "Normal YASB does not override workspace display_name with raw name"
Assert-True ($yasbWorkConfigText -notmatch 'populated_label:\s*"\{name\}"') "Work YASB does not override workspace display_name with raw name"
Assert-True ($yasbConfigText -notmatch 'mouse-mode-toggle|workspace_mouse') "Normal YASB contains no retired mouse-mode runtime"
Assert-True ($yasbWorkConfigText -notmatch 'mouse-mode-toggle|workspace_mouse') "Work YASB contains no retired mouse-mode runtime"
$glazeNormalText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.glzr\glazewm\config.yaml") -Raw
$glazeWorkText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.glzr\glazewm\custom_work_config.yaml") -Raw
for ($workspaceIndex = 1; $workspaceIndex -le 10; $workspaceIndex++) {
    $expectedDisplayName = 'display_name: "' + $workspaceIndex + '"'
    Assert-True ($glazeNormalText.Contains($expectedDisplayName)) "Normal workspace $workspaceIndex defaults to a numeric display_name"
    Assert-True ($glazeWorkText.Contains($expectedDisplayName)) "Work workspace $workspaceIndex defaults to a numeric display_name"
}
Assert-True ($yasbConfigText -match 'populated_label:\s*"\{display_name\}"') "Normal YASB still renders editable GlazeWM display_name values"
Assert-True ($yasbWorkConfigText -match 'populated_label:\s*"\{display_name\}"') "Work YASB still renders editable GlazeWM display_name values"
Assert-True ($glazeNormalText -notmatch 'flow-launcher\.ps1|yasb-quick-launch\.ps1') "Normal GlazeWM contains no launcher relay script"
Assert-True ($glazeWorkText -notmatch 'flow-launcher\.ps1|yasb-quick-launch\.ps1') "Work GlazeWM contains no launcher relay script"
Assert-True ($glazeNormalText -match 'wgdotw\.exe launcher hotkey') "Normal GlazeWM uses the compiled launcher"
Assert-True ($glazeWorkText -match 'wgdotw\.exe launcher hotkey') "Work GlazeWM uses the compiled launcher"
Assert-True ($glazeWorkText -notmatch 'shell-exec %LOCALAPPDATA%/FlowLauncher/Flow\.Launcher\.exe') "Work GlazeWM no longer defaults launcher hotkeys to Flow Launcher"
Assert-True ($glazeNormalText -match '%LOCALAPPDATA%\\wgdot\\bin\\wgdotw\.exe.*launcher hotkey') "Normal launcher hotkeys use the deterministic WGDot runtime path"
Assert-True (($glazeNormalText | Select-String -Pattern 'wgdotw\.exe btop-toggle' -AllMatches).Matches.Count -ge 2) "Normal profile routes global and noalt Super+Shift+B through the windowless btop toggle"
Assert-True (($glazeNormalText | Select-String -Pattern 'lwin\+shift\+b' -AllMatches).Matches.Count -ge 2) "Normal profile binds left Super+Shift+B globally and in noalt mode"
Assert-True (($glazeNormalText | Select-String -Pattern 'rwin\+shift\+b' -AllMatches).Matches.Count -ge 2) "Normal profile binds right Super+Shift+B globally and in noalt mode"
Assert-True ($glazeNormalText -match 'window_title:\s*\{ equals: "btop" \}') "Normal btop Windows Terminal receives a centered floating rule"
Assert-True ($glazeNormalText -notmatch 'shell-exec wt\.exe.*btop4win\.exe') "Normal profile no longer assumes btop4win.exe is directly launchable"
Assert-True ($glazeWorkText -notmatch 'btop-toggle|btop4win\.exe') "Work profile does not carry a dead btop launcher while btop defaults off"
Assert-True ($nativeSourceText -match 'static string FindBtopExe\(\)') "compiled btop helper resolves the installed executable"
Assert-True ($nativeSourceText -match 'FindExecutableWithCandidates\("btop\.exe"') "btop resolver prefers the WinGet btop command/link"
Assert-True ($nativeSourceText -match 'aristocratos\.btop4win') "btop resolver falls back only within the WinGet btop package payload"
Assert-True ($nativeSourceText -match 'static int BtopToggle\(\)') "compiled btop toggle exists"
Assert-True ($nativeSourceText -match 'FindTopLevelWindowByExactTitle\("btop"\)') "btop toggle targets its dedicated terminal title"
Assert-True ($nativeSourceText -match 'PostMessage\(existing, WmClose') "second btop invocation closes the existing dedicated terminal"

Assert-True ($glazeWorkText -match '%LOCALAPPDATA%\\wgdot\\bin\\wgdotw\.exe.*launcher hotkey') "Work launcher hotkeys use the deterministic WGDot runtime path"
Assert-True ($nativeSourceText -match 'UseShellExecute = true') "compiled launcher activates Start Menu shortcuts through Windows shell semantics"
Assert-True ($nativeSourceText -match 'const int width = 380') "compiled launcher uses the compact near-half-width search surface"
Assert-True ($nativeSourceText -match 'searchWrap\.Height = 42') "compiled launcher uses the reduced search-field height"
Assert-True ($nativeSourceText -match 'form\.Opacity = 0\.0;') "compiled launcher hides the unpainted first WinForms frame"
Assert-True ($nativeSourceText -match 'results\.Refresh\(\);\s*form\.Opacity = 0\.98;') "compiled launcher reveals immediately after the themed surface paints"
Assert-True ($nativeSourceText -notmatch 'fade\.Interval = 15') "compiled launcher spawn animation stays removed"
Assert-True ($nativeSourceText -match 'ResolveLauncherShortcutIconPath') "compiled launcher resolves shortcut-backed application icons"
Assert-True ($nativeSourceText -match '"WScript\.Shell"') "compiled launcher resolves Windows shortcut targets without adding a runtime script dependency"
Assert-True ($nativeSourceText -match '"TargetPath"') "compiled launcher prefers the underlying shortcut target for clean application icons"
Assert-True ($nativeSourceText -match '"IconLocation"') "compiled launcher can use explicit shortcut icon locations before falling back to the shortcut object"

Assert-True ($yasbConfigText -match 'yasb\.custom\.CustomWidget') "YASB uses a lightweight custom power button"
Assert-True ($yasbConfigText -match 'on_left:\s*"exec wgdotw\.exe power-menu"') "YASB power button opens the compiled Awtarchy-style surface"
Assert-True ($yasbWorkConfigText -match 'on_left:\s*"exec wgdotw\.exe power-menu"') "Work YASB power button opens the compiled Awtarchy-style surface"
Assert-True ($yasbConfigText -match 'class_name:\s*"awtarchy-launcher"') "Normal YASB renders the compiled launcher button"
Assert-True ($yasbWorkConfigText -match 'class_name:\s*"awtarchy-launcher"') "Work YASB renders the compiled launcher button"
Assert-True ($yasbConfigText -match 'on_left:\s*"exec wgdotw\.exe launcher bar"') "Normal YASB launcher button opens the bar-relative compiled launcher"
Assert-True ($yasbWorkConfigText -match 'on_left:\s*"exec wgdotw\.exe launcher bar"') "Work YASB launcher button opens the bar-relative compiled launcher"
Assert-True ($yasbConfigText -match 'wgdotw\.exe theme-window-toggle') "Normal YASB theme action uses the windowless theme-window toggle"
Assert-True ($yasbWorkConfigText -match 'wgdotw\.exe theme-window-toggle') "Work YASB theme action uses the windowless theme-window toggle"
Assert-True ($yasbConfigText -match 'wgdotw\.exe bar-autohide-toggle') "YASB auto-hide uses the approved compiled coordination helper"
Assert-True ($yasbConfigText -notmatch '(?i)(quick-launch|flow-open|eartrumpet-mixer(?:\s|$)|clipboard-anchor|flameshot-gui|display-settings|idle-inhibitor)') "Normal YASB does not route native-capable actions through WGDot"
Assert-True ($yasbWorkConfigText -notmatch '(?i)(quick-launch|flow-open|eartrumpet-mixer(?:\s|$)|clipboard-anchor|flameshot-gui|display-settings|idle-inhibitor)') "Work YASB does not route native-capable actions through WGDot"
Assert-True ($yasbConfigText -notmatch '\.ps1') "Normal YASB has no PowerShell script-file runtime dependency"
Assert-True ($yasbWorkConfigText -notmatch '\.ps1') "Work YASB has no PowerShell script-file runtime dependency"
Assert-True ($yasbConfigText -notmatch 'border_color:\s*None') "YASB popup border colors are not invalid YAML nulls"
Assert-True ($yasbWorkConfigText -notmatch 'border_color:\s*None') "Work YASB popup border colors are not invalid YAML nulls"
foreach ($yasbText in @($yasbConfigText, $yasbWorkConfigText)) {
    $wifiBlock = [regex]::Match($yasbText, '(?ms)^  wifi:\r?\n.*?(?=^  bluetooth:)').Value
    $bluetoothBlock = [regex]::Match($yasbText, '(?ms)^  bluetooth:\r?\n.*?(?=^  systray:)').Value
    Assert-True ($wifiBlock -match 'on_left:\s*"exec explorer\.exe ms-settings:network-status"') "YASB Wi-Fi/Ethernet opens native Windows Network settings"
    Assert-True ($bluetoothBlock -match 'on_left:\s*"exec explorer\.exe ms-settings:bluetooth"') "YASB Bluetooth opens native Windows Bluetooth settings"
    Assert-True ($wifiBlock -notmatch 'on_left:\s*"toggle_menu"') "YASB Wi-Fi/Ethernet mini menu is retired"
    Assert-True ($bluetoothBlock -notmatch 'on_left:\s*"toggle_menu"') "YASB Bluetooth mini menu is retired"
}
Assert-True ($yasbConfigText -notmatch 'cmd\.exe /c start ms-settings') "YASB settings callbacks do not spawn cmd.exe"
Assert-True ($yasbConfigText -notmatch '%USERPROFILE%\\\.config\\win-glaze\\scripts') "YASB custom actions do not rely on percent-style USERPROFILE expansion"


$altSnapConfigText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\AppData\Roaming\AltSnap\AltSnap.ini") -Raw
Assert-True ($altSnapConfigText -match '(?m)^AutoFocus=1\r?$') "AltSnap focuses windows while dragging by default"
Assert-True ($altSnapConfigText -match '(?m)^Hotkeys=A4 A5 5B 5C\r?$') "AltSnap enables left/right Alt and Win modifier keys by default"
Assert-True ($altSnapConfigText -match '(?m)^; Created for AltSnap v1\.68\r?$') "AltSnap managed config is refreshed to the 1.68 template"
Assert-True ($altSnapConfigText -match '(?m)^DragOutThresholdPx=20\r?$') "AltSnap 1.68 DragOutThresholdPx default is present"
Assert-True ($altSnapConfigText -match '(?m)^Processes=.*yasb\.exe,wgdotw\.exe\r?$') "AltSnap ignores YASB and WGDot windowless UI processes"
Assert-True ($altSnapConfigText -notmatch '(?m)^KBMoveS?Step=') "AltSnap removed obsolete pre-1.68 keyboard move-step settings"

$flameshotConfigText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\AppData\Roaming\flameshot\flameshot.ini") -Raw
Assert-True ($flameshotConfigText -match '(?m)^captureActiveMonitor=true') "Flameshot defaults to capturing the active monitor without monitor selection"
Assert-True ($flameshotConfigText -notmatch '(?i)C:/Users/|C:\\Users\\') "Flameshot managed config contains no user-specific profile path"
Assert-True ($flameshotConfigText -notmatch 'TYPE_IMAGELOADER') "Flameshot managed config does not restore the rejected legacy shortcut key"
$flameshotComponent = $manifest.components | Where-Object { $_.id -eq "flameshot" } | Select-Object -First 1
$flameshotManagedFile = $flameshotComponent.files | Where-Object { $_.id -eq "flameshot-config" } | Select-Object -First 1
Assert-True (-not [bool]$flameshotManagedFile.merge) "Flameshot INI is authoritative on reset/dots-only so stale rejected shortcut keys cannot survive a merge"

Assert-True ($nativeSourceText -match 'command == "window-audit"') "native runtime retains explicit diagnostic window auditing"
Assert-True ($nativeSourceText -match 'command == "super-l-test"') "native runtime retains the isolated Super+L development controller"
Assert-True ($nativeSourceText -match 'command == "super-l-hook"') "native runtime retains the hidden Super+L test worker"
Assert-True ($nativeSourceText -match 'String\.Equals\(command, "super-l-test"') "Super+L development controller participates in runtime auto-refresh"
Assert-True (@($yasb.postActions | Where-Object { $_.type -match 'ensure-(hidden-launcher|yasb-theme)' }).Count -eq 0) "YASB apply has no WGDot runtime post-actions"
Assert-True (@($glaze.postActions | Where-Object { $_.type -eq "ensure-desktop-worker" }).Count -eq 0) "GlazeWM apply has no WGDot desktop-worker post-action"
$autoRefreshBlock = [regex]::Match($nativeSourceText, '(?ms)^    static bool ShouldAutoRefreshRuntime\(string command\)\r?\n    \{.*?^    \}').Value
Assert-True ($autoRefreshBlock -match 'window-audit') "window audit command participates in runtime auto-refresh"
Assert-True ($autoRefreshBlock -notmatch 'theme|quick-launch|flow-open|mouse-mode|bar-autohide|glazewm-binding-mode|glazewm-pause|idle-inhibitor') "desktop helpers are absent from runtime auto-refresh policy"
Assert-True ($nativeSourceText -match 'GetWindowThreadProcessId') "window audit resolves process IDs from real top-level windows"
Assert-True ($nativeSourceText -match 'IsWindowVisible') "window audit filters to visible top-level windows"

$terminalSettingsPath = Join-Path $repoRoot "UserProfile\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$terminalSettings = Get-Content -LiteralPath $terminalSettingsPath -Raw | ConvertFrom-Json
Assert-Equal $true ([bool]$terminalSettings.copyOnSelect) "Windows Terminal copies selected text automatically"
Assert-True (@($terminalSettings.keybindings | Where-Object { $null -eq $_.id -and $_.keys -eq "ctrl+c" }).Count -eq 1) "Windows Terminal unbinds Ctrl+C so terminal applications receive it"
Assert-True (@($terminalSettings.keybindings | Where-Object { $null -eq $_.id -and $_.keys -eq "ctrl+v" }).Count -eq 1) "Windows Terminal unbinds Ctrl+V so terminal applications receive it"
Assert-True (@($terminalSettings.keybindings | Where-Object { $_.id -eq "Terminal.CopyToClipboard" -and $_.keys -eq "ctrl+shift+c" }).Count -eq 1) "Windows Terminal keeps Ctrl+Shift+C copy"
Assert-True (@($terminalSettings.keybindings | Where-Object { $_.id -eq "Terminal.PasteFromClipboard" -and $_.keys -eq "ctrl+shift+v" }).Count -eq 1) "Windows Terminal keeps Ctrl+Shift+V paste"

$glazeNormalText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.glzr\glazewm\config.yaml") -Raw
$glazeWorkText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.glzr\glazewm\custom_work_config.yaml") -Raw
Assert-True ($glazeNormalText -match 'bindings:\s*\["lwin\+shift\+m",\s*"rwin\+shift\+m"\]') "Normal profile keeps Raw Accel on Super+Shift+M"
Assert-True ($glazeWorkText -match 'bindings:\s*\["lwin\+shift\+m",\s*"rwin\+shift\+m"\]') "Work profile keeps Raw Accel on Super+Shift+M"
Assert-True ($glazeNormalText -notmatch 'bindings:\s*\["alt\+shift\+m",\s*"lwin\+shift\+m",\s*"rwin\+shift\+m"\]') "Normal profile does not capture Alt+Shift+M for Raw Accel"
Assert-True ($glazeNormalText -match 'bindings:\s*\["alt\+ctrl\+shift\+m"\]') "Normal scripts menu remains on Alt+Ctrl+Shift+M"
Assert-True ($glazeNormalText -match 'window_process:\s*\{ regex: "\^rawaccel') "Raw Accel launches floating and centered in Normal profile"
Assert-True ($glazeNormalText -notmatch 'desktop-worker') "Normal profile has no WGDot desktop worker"
Assert-True ($glazeWorkText -notmatch 'desktop-worker') "Work profile has no WGDot desktop worker"
Assert-True ($glazeNormalText -match 'bindings:\s*\["alt\+shift\+c"\]') "Normal profile keeps Awtarchy Alt+Shift+C SpeedCrunch"
Assert-True ($glazeNormalText -match 'bindings:\s*\["lwin\+shift\+c",\s*"rwin\+shift\+c"\]') "Normal profile keeps Awtarchy Super+Shift+C SpeedCrunch"
Assert-True ($glazeNormalText -match '(?ms)cursor_jump:\s*\r?\n\s+enabled:\s*true\r?\n\s+trigger:\s*"monitor_focus"') "Normal profile jumps cursor on monitor focus"
Assert-True ($glazeWorkText -match '(?ms)cursor_jump:\s*\r?\n\s+enabled:\s*true\r?\n\s+trigger:\s*"monitor_focus"') "Work profile jumps cursor on monitor focus"
Assert-True ($glazeNormalText -notmatch '(?ms)- name: "1"\r?\n\s+display_name: "1: Flame"\r?\n\s+keep_alive:\s*true') "normal GlazeWM workspace 1 is not pinned alive"
Assert-True ($glazeNormalText -notmatch 'yasb-quick-launch\.ps1|flow-launcher\.ps1') "Normal GlazeWM has no launcher relay scripts"
Assert-True ($glazeWorkText -notmatch 'yasb-quick-launch\.ps1|flow-launcher\.ps1') "Work GlazeWM has no launcher relay scripts"
Assert-True ($glazeNormalText -notmatch '\.ps1') "Normal GlazeWM has no PowerShell script-file runtime dependency"
Assert-True ($glazeWorkText -notmatch '\.ps1') "Work GlazeWM has no PowerShell script-file runtime dependency"
Assert-True ($glazeNormalText -match 'wgdotw\.exe rawaccel-toggle') "Normal GlazeWM uses the scoped compiled RawAccel toggle"
Assert-True ($glazeWorkText -match 'wgdotw\.exe rawaccel-toggle') "Work GlazeWM uses the scoped compiled RawAccel toggle"
Assert-True ($glazeNormalText -notmatch 'mouse-mode-toggle|name:\s*"mouse"|lwin\+alt\+m|rwin\+alt\+m') "Normal GlazeWM contains no retired mouse mode"
Assert-True ($glazeWorkText -notmatch 'mouse-mode-toggle|name:\s*"mouse"|lwin\+alt\+m|rwin\+alt\+m') "Work GlazeWM contains no retired mouse mode"
Assert-True ($glazeNormalText -match 'focus_follows_cursor:\s*true') "Normal GlazeWM defaults focus_follows_cursor to true"
Assert-True ($glazeWorkText -match 'focus_follows_cursor:\s*false') "Work GlazeWM keeps focus_follows_cursor false"
Assert-True ($glazeWorkText -match 'wgdotw\.exe bar-autohide-toggle') "Work GlazeWM uses the scoped compiled auto-hide helper"
Assert-True ($glazeNormalText -match 'wgdotw\.exe theme-window-toggle') "Normal GlazeWM uses the windowless theme-window toggle"
Assert-True ($glazeWorkText -match 'wgdotw\.exe theme-window-toggle') "Work GlazeWM uses the windowless theme-window toggle"
Assert-True ($glazeNormalText -match 'bindings:\s*\["alt\+p",\s*"lwin\+d",\s*"rwin\+d"\]') "Normal GlazeWM owns Alt+P and Super+D for the compiled launcher"
Assert-True ($glazeWorkText -match 'bindings:\s*\["alt\+p",\s*"lwin\+d",\s*"rwin\+d"\]') "Work GlazeWM owns Alt+P and Super+D for the compiled launcher"
Assert-True ($glazeWorkText -notmatch 'FlowLauncher/Flow\.Launcher\.exe') "Work launcher hotkeys do not depend on Flow Launcher"
foreach ($text in @($glazeNormalText, $glazeWorkText)) {
    Assert-True ($text -notmatch '(?i)flameshot\.exe') "GlazeWM leaves Flameshot activation to Flameshot itself"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+shift\+x",\s*"rwin\+shift\+x"\]') "GlazeWM does not capture Flameshot Super+Shift+X"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+alt\+s",\s*"rwin\+alt\+s"\]') "GlazeWM does not capture the retired Super+Alt+S Flameshot chord"
    Assert-True ($text -notmatch 'win\+shift\+f') "old Win+Shift+F Flameshot bind is removed"
    Assert-True ($text -notmatch '(?i)wgdotw?\.exe\s+(?:quick-launch|flow-open|eartrumpet-mixer(?:\s|$)|clipboard-anchor(?:\s|$)|clipboard-history(?:\s|$)|flameshot-gui|display-settings)') "GlazeWM does not route native-capable actions through WGDot"
    Assert-True ($text -notmatch 'bindings:\s*\["alt\+v",\s*"lwin\+v",\s*"rwin\+v"\]') "GlazeWM leaves Alt+V and Super+V to EarTrumpet/Windows"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+c",\s*"rwin\+c"\]') "retired Super+C Clipboard History override stays absent"
    Assert-True ($text -notmatch 'clipboard-anchor') "retired Clipboard History hotkey handoff stays absent"
    Assert-True ($text -match 'bindings:\s*\["lwin\+p",\s*"rwin\+p"\]') "GlazeWM owns Super+P for the compiled Awtarchy-style power surface"
    Assert-True ($text -match 'wgdotw\.exe power-menu') "GlazeWM routes Super+P through the approved windowless compiled power helper"
    Assert-True ($text -notmatch 'name:\s*"mouse"') "retired mouse binding mode stays removed"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+alt\+m",\s*"rwin\+alt\+m"\]') "retired Win+Alt+M mouse binding stays removed"
    Assert-True ($text -notmatch 'wgdotw\.exe mouse-mode-toggle') "retired WGDot mouse helper stays out of GlazeWM"
    Assert-True ($text -match 'bindings:\s*\["lwin\+ctrl\+m",\s*"rwin\+ctrl\+m"\]') "Super+Ctrl+M opens Windows display settings"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+shift\+s",\s*"rwin\+shift\+s"\]') "Super+Shift+S remains native Windows Snipping Tool"
    Assert-True ($text -match 'bindings:\s*\["alt\+ctrl\+shift\+r"\]') "Alt+Ctrl+Shift+R reloads GlazeWM"
    Assert-True ($text -match 'bindings:\s*\["alt\+ctrl\+b"\]') "Alt+Ctrl+B toggles coordinated YASB auto-hide and the GlazeWM top gap"
    Assert-True ($text -match 'wgdotw\.exe bar-autohide-toggle') "bar visibility binding uses the compiled coordinated auto-hide helper"
    Assert-True ($text -notmatch 'yasbc toggle-bar') "GlazeWM does not use the unsafe hard-hide YASB command"
    Assert-True ($text -match 'inner_gap:\s*"5px"') "GlazeWM uses the requested 5px inner gap"
    Assert-True ($text -match 'top:\s*"35px"') "GlazeWM reserves the requested 35px top gap"
    Assert-True ($text -match 'color:\s*"#a1a1a1"') "GlazeWM focused border is theme-neutral"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+t",\s*"rwin\+alt\+t"\]') "Super+Alt+T theme picker exists"
    Assert-True ($text -match 'bindings:\s*\["alt\+t",\s*"lwin\+t",\s*"rwin\+t"\]') "global Alt+T and Super+T toggle tiling"
    $noaltBlock = [regex]::Match($text, '(?ms)^  - name: "noalt"\r?\n.*?(?=^  # VM mode|^  - name: "vm")').Value
    Assert-True ($noaltBlock -match 'bindings:\s*\["lwin\+t",\s*"rwin\+t"\]') "noalt keeps Super+T tiling"
    Assert-True ($noaltBlock -match 'bindings:\s*\["lwin\+alt\+t",\s*"rwin\+alt\+t"\]') "noalt keeps Super+Alt+T themes"
    Assert-True ($noaltBlock -notmatch 'bindings:\s*\["alt\+t"\]') "noalt does not capture plain Alt+T"
    Assert-True ($noaltBlock -notmatch 'bindings:\s*\["lwin\+v",\s*"rwin\+v"\]') "noalt leaves native Super+V Clipboard History uncaptured"
    Assert-True ($noaltBlock -notmatch 'bindings:\s*\["alt\+v"\]') "noalt leaves EarTrumpet Alt+V uncaptured by GlazeWM"
    Assert-True ($noaltBlock -match 'bindings:\s*\["lwin\+d",\s*"rwin\+d"\]') "noalt keeps Super+D compiled launcher"
    Assert-True ($noaltBlock -notmatch 'bindings:\s*\["alt\+p"\]') "noalt does not capture plain Alt+P"
    Assert-True ($text -match 'wgdotw\.exe theme-window-toggle') "theme shortcut uses the windowless compiled theme toggle"
    Assert-True ($text -match 'window_title:\s*\{ equals: "Win Glaze Themes" \}') "theme selector has a dedicated floating title rule"
    Assert-True ($text -match 'name:\s*"noalt"') "GlazeWM noalt mode remains available with selective shell-hotkey filtering"
    Assert-True ($text -match 'wm-enable-binding-mode --name noalt') "noalt mode transitions are native GlazeWM commands"
    Assert-True ($text -match 'commands:\s*\["wm-toggle-pause"\]') "GlazeWM uses its real pause command"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+p",\s*"rwin\+alt\+p"\]') "Alt+Super+P toggles real GlazeWM pause"
    Assert-True ($text -match 'name:\s*"vm"') "GlazeWM has a VM binding mode"
    Assert-True ($text -match 'wm-enable-binding-mode --name vm') "VM mode transitions are native GlazeWM commands"
    Assert-True ($text -match 'wm-disable-binding-mode --name (?:noalt|vm)') "binding modes have native GlazeWM escape commands"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+v",\s*"rwin\+alt\+v"\]') "Win+Alt+V toggles/switches VM mode"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+alt\+s",\s*"rwin\+alt\+s"\]') "VM mode leaves retired Win+Alt+S Flameshot chord unbound"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+1",\s*"rwin\+alt\+1"\]') "VM mode keeps host workspace switching on Win+Alt+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+shift\+1",\s*"rwin\+alt\+shift\+1"\]') "VM mode keeps host move-to-workspace on Win+Alt+Shift+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+shift\+e",\s*"rwin\+shift\+e"\]') "Yazi uses both Windows keys for Win+Shift+E"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin",\s*"rwin"\]') "GlazeWM does not use ineffective bare-Super bindings"
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

$yasbComponent = $manifest.components | Where-Object { $_.id -eq "yasb" } | Select-Object -First 1
Assert-True ($null -ne $yasbComponent) "YASB managed component exists"
Assert-True ([bool]$yasbComponent.defaultNormal) "YASB dotfiles are enabled by default for Normal"
Assert-True ([bool]$yasbComponent.defaultWork) "YASB dotfiles are enabled by default for Work"
$yasbConfigFile = $yasbComponent.files | Where-Object { $_.id -eq "yasb-config" } | Select-Object -First 1
$yasbStylesFile = $yasbComponent.files | Where-Object { $_.id -eq "yasb-styles" } | Select-Object -First 1
Assert-Equal "UserProfile/.config/yasb/config.yaml" ([string]$yasbConfigFile.sourceByGlazeProfile.normal) "Normal deploys the managed YASB config"
Assert-Equal "UserProfile/.config/yasb/custom_work_config.yaml" ([string]$yasbConfigFile.sourceByGlazeProfile.work) "Work deploys the managed YASB config"
Assert-Equal "UserProfile/.config/yasb/styles.css" ([string]$yasbStylesFile.source) "Normal and Work share the corrected managed YASB stylesheet"
Assert-Equal "%USERPROFILE%\.config\yasb\styles.css" ([string]$yasbStylesFile.destination) "corrected YASB stylesheet deploys to the live Windows dotfile path"

$managedDesktopRuntimeFiles = @(
    Join-Path $repoRoot "UserProfile/.glzr/glazewm/config.yaml"
    Join-Path $repoRoot "UserProfile/.glzr/glazewm/custom_work_config.yaml"
    Join-Path $repoRoot "UserProfile/.config/yasb/config.yaml"
    Join-Path $repoRoot "UserProfile/.config/yasb/custom_work_config.yaml"
)
foreach ($managedDesktopRuntimeFile in $managedDesktopRuntimeFiles) {
    $managedDesktopRuntimeText = Get-Content -Raw -LiteralPath $managedDesktopRuntimeFile
    Assert-True ($managedDesktopRuntimeText -notmatch '\.ps1') "managed desktop runtime config contains no PowerShell script-file dependency: $managedDesktopRuntimeFile"
    Assert-True ($managedDesktopRuntimeText -notmatch '(?i)wgdotw?\.exe\s+(?:quick-launch|flow-open|eartrumpet-mixer(?:\s|$)|clipboard-anchor(?:\s|$)|clipboard-history(?:\s|$)|flameshot-gui|display-settings)') "managed desktop config does not route native-capable actions through WGDot: $managedDesktopRuntimeFile"
}

Write-Host "WGDot tests passed." -ForegroundColor Green
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
Assert-True ($nativeSourceText -notmatch 'ApplyFlowLauncherAltP') "retired WGDot Flow Launcher Alt+P integration stays removed"
Assert-True ($nativeSourceText -notmatch 'command == "quick-launch"|command == "flow-open"') "retired launcher relay commands stay removed"
Assert-True ($nativeSourceText -match 'if \(command == "launcher"\) return LauncherFromArgs') "native runtime exposes the approved compiled launcher"
Assert-True ($nativeSourceText -match 'LauncherLocation') "compiled launcher has context-aware placement logic"
Assert-True ($nativeSourceText -match 'YasbAutoHideEnabled') "compiled launcher centers when YASB auto-hide is active"
Assert-True ($nativeSourceText -match 'ForegroundWindowFillsScreen') "compiled launcher detects fullscreen/borderless foreground windows"
Assert-True ($nativeSourceText -match 'const int launcherBarGap = 1;') "launcher keeps only a 1px gap below the 28px YASB bar"
Assert-True ($nativeSourceText -match 'int belowBarY = screen\.Bounds\.Top \+ 28 \+ launcherBarGap;') "bar and hotkey launcher placement share the tight below-bar Y position"
Assert-True ($nativeSourceText -match 'Environment\.SpecialFolder\.Programs') "compiled launcher indexes user Start Menu applications"
Assert-True ($nativeSourceText -match 'Environment\.SpecialFolder\.CommonPrograms') "compiled launcher indexes common Start Menu applications"
Assert-True ($nativeSourceText -notmatch 'ApplyEarTrumpetMixerSuperV') "WGDot no longer manages EarTrumpet's mixer hotkey"
Assert-True ($nativeSourceText -match 'static string RequireGlazeWmExe\(\)') "runtime helpers require the resolved GlazeWM executable path"
Assert-True ($nativeSourceText -notmatch 'command == "mouse-mode-(?:toggle|disable|hook)"') "retired mouse-mode commands stay undispatched"
Assert-True ($nativeSourceText -notmatch 'static int MouseModeToggle\(|static int MouseModeHook\(|static IntPtr MouseModeHookCallback\(') "retired mouse-mode runtime implementation stays removed"
Assert-True ($nativeSourceText -match 'SignalMouseModeHookStop') "runtime replacement can still stop a legacy mouse hook from an older build"
Assert-True ($nativeSourceText -match 'ApplyClassicContextMenu') "native runtime manages classic context menu"
Assert-True ($nativeSourceText -match 'DeleteRegistryKeyIfOriginallyAbsentAndEmpty') "native tweak rollback prunes only WGDot-created empty registry keys"
Assert-True ($nativeSourceText -notmatch 'DeleteSubKeyTree\(clsid') "classic context-menu rollback does not delete unknown pre-WGDot CLSID state"
Assert-True ($nativeSourceText -match 'base64-bytes') "registry rollback preserves binary and REG_NONE values losslessly"
Assert-True ($nativeSourceText -match 'RegistryKeyWasAbsentInSnapshot') "registry rollback tracks pre-WGDot key existence"
Assert-True ($nativeSourceText -match 'ApplyOopsCursor') "native runtime manages optional cursor install"
Assert-True ($nativeSourceText -match 'undergroundwires/privacy\.sexy/releases/latest') "privacy.sexy uses official latest GitHub release"
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
Assert-True ($nativeBootstrapText -match 'curl\.exe HTTPS transport failed; trying Windows PowerShell \.NET WebClient') "native bootstrap has a managed-PC HTTPS fallback when curl Schannel fails"
Assert-True ($nativeBootstrapText -match 'New-Object Net\.WebClient') "native bootstrap fallback uses the in-box .NET WebClient"
Assert-True ($nativeBootstrapText -match 'WGDOT_FORCE_POWERSHELL_DOWNLOAD') "CI can force the bootstrap WebClient transport"
Assert-True ($nativeBootstrapText -notmatch '(?i)Set-ExecutionPolicy|-ExecutionPolicy\s+(Bypass|Unrestricted)') "bootstrap transport fallback does not alter or bypass PowerShell execution policy"
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
    Assert-True ($text -notmatch '(?i)flameshot\.exe') "GlazeWM leaves Flameshot activation to Flameshot itself"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+shift\+x",\s*"rwin\+shift\+x"\]') "GlazeWM does not capture Flameshot Super+Shift+X"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+alt\+s",\s*"rwin\+alt\+s"\]') "GlazeWM does not capture the retired Super+Alt+S Flameshot chord"
    Assert-True ($text -notmatch 'win\+shift\+f') "old Win+Shift+F Flameshot bind is removed"
    Assert-True ($text -notmatch '(?i)wgdotw?\.exe\s+(?:quick-launch|flow-open|eartrumpet-mixer(?:\s|$)|clipboard-anchor(?:\s|$)|clipboard-history(?:\s|$)|flameshot-gui|display-settings)') "GlazeWM does not route native-capable actions through WGDot"
    Assert-True ($text -notmatch 'bindings:\s*\["alt\+v",\s*"lwin\+v",\s*"rwin\+v"\]') "GlazeWM leaves Alt+V and Super+V to EarTrumpet/Windows"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+c",\s*"rwin\+c"\]') "retired Super+C Clipboard History override stays absent"
    Assert-True ($text -notmatch 'clipboard-anchor') "retired Clipboard History hotkey handoff stays absent"
    Assert-True ($text -match 'name:\s*"noalt"') "GlazeWM noalt mode is restored"
    Assert-True ($text -match 'wm-enable-binding-mode --name noalt') "noalt mode transitions are native GlazeWM commands"
    Assert-True ($text -match 'commands:\s*\["wm-toggle-pause"\]') "GlazeWM real pause command is present"
    Assert-True ($text -match 'name:\s*"vm"') "GlazeWM has a VM binding mode"
    Assert-True ($text -match 'wm-enable-binding-mode --name vm') "VM mode transitions are native GlazeWM commands"
    Assert-True ($text -match 'wm-disable-binding-mode --name (?:noalt|vm)') "binding modes have native escape commands"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+v",\s*"rwin\+alt\+v"\]') "Win+Alt+V toggles/switches VM mode"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+alt\+s",\s*"rwin\+alt\+s"\]') "VM mode leaves retired Win+Alt+S Flameshot chord unbound"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+1",\s*"rwin\+alt\+1"\]') "VM mode keeps host workspace switching on Win+Alt+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+shift\+1",\s*"rwin\+alt\+shift\+1"\]') "VM mode keeps host move-to-workspace on Win+Alt+Shift+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+shift\+e",\s*"rwin\+shift\+e"\]') "Yazi uses both Windows keys for Win+Shift+E"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin",\s*"rwin"\]') "GlazeWM does not use ineffective bare-Super bindings"
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

Assert-True ($nativeSourceText -match 'installed packages for available upgrades') "software reconcile reports long upgrade-scan progress"
Assert-True ($nativeSourceText -match 'Starting software batch: ') "software reconcile reports elevated batch work before waiting"
Assert-True ($nativeSourceText -match 'Administrator software batch finished\. Reading results') "software reconcile reports when elevated work returns"
Assert-True ($nativeSourceText -match 'Downloading updated WGDot runtime source') "runtime refresh reports network work"
Assert-True ($nativeSourceText -match 'Compiling updated WGDot runtime') "runtime refresh reports compilation work"
Assert-True ($nativeSourceText -match 'Running updated WGDot self-test') "runtime refresh reports self-test work"
Assert-True ($nativeBootstrapText -match 'Compiling WGDot native runtime') "bootstrap reports compile progress"
Assert-True ($nativeBootstrapText -match 'Running WGDot self-test') "bootstrap reports self-test progress"
Assert-True ($nativeBootstrapText -match 'Installing WGDot runtime') "bootstrap reports install progress"
Assert-True ($nativeBootstrapText -match 'Checking WinGet prerequisite') "bootstrap reports WinGet prerequisite work"

Assert-True ($nativeSourceText -match 'SOFTWARE\\glzr\.io\\GlazeWM') "GlazeWM startup detection reads the official installer registry key"
Assert-True ($nativeSourceText -match 'GetValue\("InstallDir"') "GlazeWM startup detection reads the official installer InstallDir value"
Assert-True ($nativeSourceText -match '"GlazeWM",[\s\S]*?"cli",[\s\S]*?"glazewm\.exe"') "GlazeWM startup detection covers the current official CLI install layout"
) "staged runtime finalization recognizes unique runtime filenames"
Assert-True ($nativeSourceText -match 'runtimeSyncPendingRevision') "runtime finalization can detect an already scheduled Git runtime sync"
Assert-True ($nativeSourceText -match 'if \(!String\.IsNullOrWhiteSpace\(pendingRevision\)\)\s*return;') "outer staged runtime does not race a Git-testing runtime replacement"
Assert-True ($nativeSourceText -match 'ScheduleStagedRuntimeInstall') "staged runtime installs itself after the requested operation exits"
Assert-True ($nativeSourceText -match 'CreateRuntimeSwapHelper') "native runtime defers replacing the running executable"
Assert-True ($nativeSourceText -match 'if \(command == "dots-only"\) return DotsOnlyFromArgs') "native runtime exposes explicit dots-only managed apply"
Assert-True ($nativeSourceText -match 'String\.Equals\(command, "dots-only"') "dots-only participates in direct-command runtime refresh policy"
$dotsOnlyMethod = [regex]::Match($nativeSourceText, '(?s)static int DotsOnlyFromArgs\(.*?(?=\r?\n    static InstallationSelection BuildDotsOnlySelection)').Value
Assert-True (-not [string]::IsNullOrWhiteSpace($dotsOnlyMethod)) "dots-only command implementation is present"
Assert-True ($dotsOnlyMethod -match 'ResolveDotsOnlySource\(\)') "dots-only keeps its explicit bootstrap-aware source resolver"
Assert-True ($dotsOnlyMethod -match 'ApplyPlan\(plan, source\.Manifest, selection, source, true\)') "dots-only applies through strict post-action gating"
Assert-True ($dotsOnlyMethod -match 'RestoreRememberedThemeAfterManagedApply\(plan\)') "dots-only restores the selected theme after managed files are written"
Assert-True ($nativeSourceText -match 'ManagedPlanWritesThemeState') "theme preservation is gated by the actual managed plan"
Assert-True ($nativeSourceText -match 'String\.Equals\(item\.FileId, "yasb-theme"') "theme preservation watches managed YASB theme writes"
Assert-True ($nativeSourceText -match 'String\.Equals\(item\.FileId, "terminal-settings"') "theme preservation watches managed Terminal settings writes"
Assert-True ($nativeSourceText -match 'Preserved selected WGDot theme') "theme preservation reports the retained selected theme"
Assert-True ($dotsOnlyMethod -notmatch 'SoftwareReconcile\(|EnsureWingetAvailable\(|SoftwareElevatedFromArgs\(|RunElevatedSelfWithExitCode\(') "dots-only command does not invoke software or elevation workers"
Assert-True ($nativeSourceText -match 'GetList\(component, "files"\)\.Count == 0') "dots-only excludes post-action-only components such as cursor registry configuration"
Assert-True ($nativeSourceText -match 'dotsOnly && !IsDotsOnlyPostAction\(type\)') "dots-only post-actions remain strictly gated"
$dotsPostActionAllowlist = [regex]::Match($nativeSourceText, '(?s)static bool IsDotsOnlyPostAction\(string type\).*?(?=\r?\n    static void RunPostActions)').Value
Assert-True ($dotsPostActionAllowlist -match 'return false;') "dots-only runs no post-actions"
Assert-True ($dotsPostActionAllowlist -notmatch 'ensure-desktop-worker|ensure-hidden-launcher|ensure-yasb-theme|yazi-package-install|set-yazi-file-one|migrate-legacy-windows-hotkeys|retire-windows-shell-hotkeys|retire-printscreen-snipping|ensure-cursor-theme') "dots-only has no runtime/system post-action exceptions"
Assert-True ($nativeSourceText -match 'PrepareRawRevisionSource') "native runtime can acquire exact managed sources from raw.githubusercontent.com"
Assert-True ($nativeSourceText -match 'WGDOT_FORCE_RAW_SOURCE') "CI can force the restricted-network raw source path"
Assert-True ($nativeSourceText -match 'source-self-test') "native runtime exposes an internal exact-source validation command"
Assert-True ($nativeSourceText -match '(?s)string recordedRevision = GetString\(bootstrap, "sourceRevision"\);.*?explicitRefTesting.*?Regex\.IsMatch\(recordedRevision.*?\? recordedRevision\.ToLowerInvariant\(\).*?: ResolveBranchHeadViaApi\(sourceRef\)') "explicit exact bootstrap revisions stay pinned without requiring a branch-head API lookup"
Assert-True ($nativeSourceText -match 'runtime-refresh\.log') "blocked API refresh checks are recorded without killing the installed runtime"
Assert-True ($nativeSourceText -match 'CopyRuntimeWithRetry') "runtime install retries replacement across transient executable locks"
Assert-True ($nativeSourceText -match 'runtime-swap-stop') "runtime self-refresh can stop legacy WGDot workers before replacing the installed executable"
Assert-True ($nativeSourceText -match 'runtime-swap-restore') "runtime self-refresh keeps a compatibility restore endpoint for older swap helpers"
Assert-True ($nativeSourceText -match 'wgdot-worker-state-') "runtime self-refresh retains a bounded staged-swap state marker"
Assert-True ($nativeSourceText -match 'IsRuntimeSwapInternalCommand') "runtime-swap internals cannot recursively schedule another staged replacement"
$runtimeRestoreBlock = [regex]::Match($nativeSourceText, '(?s)static int RuntimeSwapRestoreFromArgs\(string\[\] args\).*?(?=\r?\n    static void ScheduleStagedRuntimeInstall)').Value
Assert-True ($runtimeRestoreBlock -match 'SafeDeleteFile\(statePath\)') "compatibility restore deletes the old swap marker"
Assert-True ($runtimeRestoreBlock -notmatch 'StartRuntimeWorkerFrom|idle-inhibitor-worker|mouse-mode-hook|desktop-worker|super-l-hook') "runtime replacement never restores legacy desktop workers"
$installMethod = [regex]::Match($nativeSourceText, '(?s)static int Install\(\).*?(?=\r?\n    static int Status\(\))').Value
Assert-True ($installMethod -match 'SignalIdleInhibitorStop|SignalMouseModeHookStop|SignalDesktopWorkerStop') "runtime install retires legacy WGDot desktop workers when encountered"
Assert-True ($installMethod -notmatch 'StartRuntimeWorkerFrom') "runtime install never restarts retired desktop helpers"
Assert-True ($nativeSourceText -match 'EnsureHiddenLauncher') "native install maintains a windowless WGDot runtime frontend"
Assert-True ($nativeSourceText -match '/target:winexe') "windowless WGDot frontend compiles without a console subsystem"
Assert-True ($nativeSourceText -match 'const string HiddenLauncherVersion = "2\.0\.0\.0"') "windowless WGDot frontend has an explicit update version"
Assert-True ($nativeSourceText -match 'static string QuoteForwardedArgument\(string value\)') "windowless WGDot frontend quotes each forwarded argument"
Assert-True ($nativeSourceText -match 'psi\.Arguments = BuildForwardedArguments\(args\);') "windowless WGDot frontend preserves argument boundaries"
Assert-True ($nativeSourceText -notmatch 'psi\.Arguments = String\.Join\("" "", args') "windowless WGDot frontend never forwards raw space-joined arguments"
Assert-True ($nativeSourceText -match 'if \(command == "ensure-hidden-launcher"\)') "native runtime exposes the internal windowless frontend refresh command"
$runtimeSwapHelperBlock = [regex]::Match($nativeSourceText, '(?ms)static string CreateRuntimeSwapHelper\(.*?^    }').Value
Assert-True ($runtimeSwapHelperBlock -match 'ensure-hidden-launcher') "runtime self-refresh updates an outdated windowless frontend"
Assert-True ($runtimeSwapHelperBlock -match '(?s)ensure-hidden-launcher.*?mark-runtime') "runtime revision is recorded only after the windowless frontend is current"
Assert-True ($nativeSourceText -match 'Runtime replacement helper self-test failed') "native self-test exercises runtime replacement helper"
Assert-True ($nativeSourceText -match '"mark-runtime"') "runtime revision is recorded by the successfully swapped executable"
Assert-True ($nativeSourceText -match 'WGDOT_SKIP_RUNTIME_REFRESH') "staged runtime avoids recursive refresh while running the requested operation"
Assert-True ($nativeSourceText -match '"maintenance-self-test"') "native runtime exposes isolated maintenance self-test"
Assert-True ($nativeSourceText -notmatch 'String.Equals\(type, "ensure-yasb-theme"') "native runtime no longer runs generated YASB theme post-actions"
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

    Set-WgdotYasbTheme -Id "carbon-night" -CssPath $themeCssPath -StatePath $themeStatePath -TerminalSettingsPath $terminalSettingsPath
    $carbonTerminalSettings = Get-Content -LiteralPath $terminalSettingsPath -Raw | ConvertFrom-Json
    $carbonScheme = @($carbonTerminalSettings.schemes | Where-Object { $_.name -eq "WGDot Carbon Night" }) | Select-Object -First 1
    Assert-True ($null -ne $carbonScheme) "PowerShell fallback writes Carbon Night Terminal scheme"
    Assert-Equal "#9AB8D7" ([string]$carbonScheme.blue) "Carbon Night ANSI blue stays readable for Yazi directory names"
    Assert-Equal "#8CD0D3" ([string]$carbonScheme.cyan) "Carbon Night ANSI cyan stays readable for Yazi PDF/document names"
    Assert-Equal "#709080" ([string]$carbonScheme.brightBlack) "Carbon Night brightBlack stays readable for dim terminal text"

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
Assert-True ($tweakIds -notcontains "flow-launcher-alt-p") "Flow Launcher global Alt+P tweak is retired"
Assert-True ($tweakIds -notcontains "eartrumpet-mixer-super-v") "retired EarTrumpet Super+V tweak stays out of the catalog"
Assert-True ($nativeSourceText -notmatch 'ApplyEarTrumpetMixerSuperV|set-win-v|ApplicationDataManager\.CreateForPackageFamily') "WGDot no longer rewrites EarTrumpet's mixer hotkey"
Assert-True ($nativeSourceText -match 'result\.Tweaks\.RemoveAll\(x => String\.Equals\(x, "flow-launcher-alt-p"') "saved selections retire the old Flow global hotkey"
Assert-True ($nativeSourceText -match 'eartrumpet-mixer-alt-v') "saved selections retire the legacy EarTrumpet Alt+V tweak id"
Assert-True ($nativeSourceText -match 'eartrumpet-mixer-super-v') "saved selections retire the later EarTrumpet Super+V tweak id"
Assert-True ($nativeSourceText -notmatch 'result\.Tweaks\.Add\("eartrumpet-mixer-super-v"\)') "saved selections never re-add the retired EarTrumpet Super+V tweak"
Assert-True ($nativeSourceText -match 'ApplyWindowsShellHotkeysPolicy') "native runtime implements reversible selective Windows hotkey filtering"
Assert-True ($nativeSourceText -match 'MigrateLegacyWindowsShellHotkeys') "native runtime migrates WGDot-owned legacy NoWinKeys state"
Assert-True ($nativeSourceText -match '(?s)MigrateLegacyWindowsShellHotkeys\(bool allowElevation\).*?if \(!IsAdministrator\(\)\).*?RunElevatedSelf\("migrate-legacy-hotkeys"\)') "legacy NoWinKeys migration elevates before opening the protected policy key for write"
Assert-True ($nativeSourceText -match 'DiscardRegistryOriginalSnapshot\(id, "HKCU", legacyPath, legacyName\)') "legacy NoWinKeys ownership is retired after migration"
Assert-True ([bool](@(($manifest.components | Where-Object { $_.id -eq "glazewm" }).postActions | Where-Object { $_.type -eq "retire-windows-shell-hotkeys" }).Count -eq 1)) "managed GlazeWM updates retire the optional Windows shell-hotkey filter"
Assert-True ([bool](@(($manifest.components | Where-Object { $_.id -eq "glazewm" }).postActions | Where-Object { $_.type -eq "retire-printscreen-snipping" }).Count -eq 1)) "managed GlazeWM updates restore the retired Print Screen interception tweak"
foreach ($hiddenTweakId in @("disable-printscreen-snipping", "disable-windows-shell-hotkeys", "oops-all-links-cursor")) {
    $hiddenTweak = $manifest.tweaks | Where-Object { $_.id -eq $hiddenTweakId }
    Assert-True ([bool]$hiddenTweak.hiddenFromMenu) "retired setup tweak is hidden from the interactive menu: $hiddenTweakId"
    Assert-True (-not [bool]$hiddenTweak.defaultNormal -and -not [bool]$hiddenTweak.defaultWork) "retired setup tweak defaults off: $hiddenTweakId"
}
foreach ($defaultOffTweakId in @(
    "disable-enhanced-pointer-precision",
    "disable-snap-assist",
    "disable-remote-assistance",
    "enable-windows-sudo",
    "reduce-visual-effects",
    "classic-context-menu"
)) {
    $defaultOffTweak = $manifest.tweaks | Where-Object { $_.id -eq $defaultOffTweakId }
    Assert-True (-not [bool]$defaultOffTweak.defaultNormal -and -not [bool]$defaultOffTweak.defaultWork) "preference-sensitive tweak defaults off: $defaultOffTweakId"
}
Assert-True ($nativeSourceText -match 'CurrentTweakDefaultsVersion = 1') "tweak defaults carry a one-time saved-selection migration version"
Assert-True ($nativeSourceText -match 'savedTweakDefaultsVersion < CurrentTweakDefaultsVersion') "existing tweak selections migrate to the new preference-sensitive defaults once"
Assert-True ($nativeSourceText -match 'hiddenFromMenu') "tweak menu skips retired compatibility entries"
Assert-True ($nativeSourceText -match '"DisabledHotkeys"') "native runtime uses selective Explorer DisabledHotkeys instead of blanket NoWinKeys"
Assert-True ($nativeSourceText -match '"ABCDEFGHIJKLMOPQRSTUWXYZ0123456789"') "selective shell filter preserves native Win+V and Win+N"
Assert-True ($nativeSourceText -match 'RestoreRegistryOriginals\(id\)') "Windows hotkey tweak participates in registry rollback"
foreach ($desktopCommand in @(
    "quick-launch", "flow-open", "eartrumpet-mixer", "clipboard-history",
    "desktop-worker", "desktop-worker-stop",
    "flameshot-gui", "rawaccel-open", "display-settings",
    "yasb-running-apps-toggle", "yasb-running-apps-shade-toggle",
    "mouse-mode-switch", "mouse-mode-toggle", "mouse-mode-disable", "mouse-mode-hook", "glazewm-binding-mode-set",
    "glazewm-reload-config", "glazewm-pause-status", "glazewm-pause-toggle",
    "theme-toggle"
)) {
    Assert-True ($nativeSourceText -notmatch ('command == "' + [regex]::Escape($desktopCommand) + '"')) "WGDot does not dispatch unapproved desktop helper command: $desktopCommand"
}
foreach ($approvedDesktopCommand in @(
    "bar-autohide-toggle",
    "glazewm-binding-mode-toggle", "glazewm-window-behavior-toggle", "theme", "theme-window-toggle", "clipboard-history-open", "eartrumpet-mixer-toggle", "launcher", "power-menu", "btop-toggle", "rawaccel-toggle"
)) {
    Assert-True ($nativeSourceText -match ('command == "' + [regex]::Escape($approvedDesktopCommand) + '"')) "WGDot exposes approved scoped runtime helper: $approvedDesktopCommand"
}
Assert-True ($nativeSourceText -match 'const int width = 380;') "launcher remains compact at 380 px"
Assert-True ($nativeSourceText -match 'sealed class LauncherResultsView') "launcher uses the owner-drawn pixel-scroll results viewport"
Assert-True ($nativeSourceText -match 'const int ScrollbarWidth = 16;') "launcher scrollbar exposes a wider click/drag target"
Assert-True ($nativeSourceText -match 'const int ScrollbarThumbWidth = 12;') "launcher scrollbar thumb is visibly wider"
Assert-True ($nativeSourceText -match 'const double WheelPixelsPerNotch = 48\.0;') "launcher wheel uses pixel-based movement rather than ListBox item stepping"
Assert-True ($nativeSourceText -match '_scrollTimer\.Interval = 15;') "launcher smooth scrolling uses a responsive animation timer"
Assert-True ($nativeSourceText -match '_scrollOffset \+= distance \* 0\.35;') "launcher smooth scrolling eases toward the target offset"
Assert-True ($nativeSourceText -match 'new System\.Drawing\.SolidBrush\(_fieldColor\)') "launcher scrollbar track follows the active YASB surface color"
Assert-True ($nativeSourceText -match '_scrollThumbHover \|\| _draggingScrollThumb\s*\? _focusColor\s*:\s*_foregroundColor') "launcher scrollbar thumb follows the same foreground/focus theme treatment as YASB sliders"
Assert-True ($nativeSourceText -match 'LauncherCachePath = Path\.Combine\(CacheRoot, "launcher-apps\.json"\)') "launcher maintains a persistent app index cache"
Assert-True ($nativeSourceText -match 'List<LauncherApp> apps = ReadLauncherAppCache\(\);') "launcher reads the persistent app index before showing"
Assert-True ($nativeSourceText -match 'WriteLauncherAppCache\(loadedApps\)') "launcher refreshes the persistent app index asynchronously"
Assert-True ($nativeSourceText -match 'RefreshLauncherAppCache\(\);') "runtime installation prewarms the launcher app index"
Assert-True ($nativeSourceText -notmatch 'new System\.Windows\.Forms\.ListBox\(\)') "launcher no longer depends on item-stepped WinForms ListBox scrolling"
Assert-True ($nativeSourceText -match '(?s)if \(String\.Equals\(source, "bar".*?return new System\.Drawing\.Point\(\s*screen\.Bounds\.Left,') "bar launcher is flush with the active display left edge"
Assert-True ($nativeSourceText -match '(?s)bool centerScreen =.*?screen\.Bounds\.Left \+ \(\(screen\.Bounds\.Width - width\) / 2\)') "hotkey launcher retains centered placement"
Assert-True ($nativeSourceText -match 'ResolveLauncherShortcutIconPath') "launcher resolves underlying shortcut targets for clean application icons"
Assert-True ($nativeSourceText -notmatch 'ApplyEarTrumpetMixerSuperV|EnsureEarTrumpetStorageHelper|set-win-v') "retired EarTrumpet hotkey-management helper stays removed"
Assert-True ($nativeSourceText -match 'command == "eartrumpet-mixer-toggle"') "native runtime exposes the bar-only EarTrumpet mixer toggle"
Assert-True ($nativeSourceText -match 'SendEarTrumpetMixerChord') "EarTrumpet toggle bridge invokes the application-owned hotkey"
Assert-True ($nativeSourceText -match 'StartEarTrumpetFromStartMenu') "EarTrumpet toggle bridge can start the app through its Start Menu shortcut"
Assert-True ($nativeSourceText -match 'const byte VkLmenu = 0xA4;') "EarTrumpet toggle uses left Alt rather than rewriting app settings"
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
Assert-True ($nativeSourceText -match 'if \(command == "yazi-drag"\) return YaziDragFromArgs') "native runtime exposes the narrow Yazi file-drag primitive"
Assert-True ($nativeSourceText -match 'NormalizeYaziDragListPath') "Yazi native drag validates its temporary manifest path"
Assert-True ($nativeSourceText -match 'DoDragDrop') "Yazi native drag uses Windows OLE drag-drop through WinForms"
Assert-True ($nativeSourceText -match 'if \(command == "power-menu"\) return PowerMenu\(\)') "native runtime exposes the approved compiled power surface"
Assert-True ($nativeSourceText -match 'form\.Opacity = 0\.0') "power surface starts fully transparent to avoid first-frame flash"
Assert-True ($nativeSourceText -match 'StartPowerMenuFadeIn') "power surface implements fade-in"
Assert-True ($nativeSourceText -match 'BeginPowerMenuFadeOut') "power surface implements fade-out"
Assert-True ($nativeSourceText -match 'undergroundwires/privacy\.sexy/releases/latest') "privacy.sexy uses official latest GitHub release"
Assert-True ($nativeSourceText -match 'privacy\.sexy download did not return a valid Windows executable') "privacy.sexy installer payload is validated before execution"
Assert-True ($nativeSourceText -match 'SetupDiGetClassDevs') "native runtime detects present display adapters through SetupAPI"
Assert-True ($nativeSourceText -match 'VEN_1002') "GPU detection recognizes AMD PCI vendor IDs"
Assert-True ($nativeSourceText -match 'VEN_10DE') "GPU detection recognizes NVIDIA PCI vendor IDs"
Assert-True ($nativeSourceText -match 'VEN_8086') "GPU detection recognizes Intel PCI vendor IDs"
Assert-True ($nativeSourceText -match 'Wagnardsoft\.DisplayDriverUninstaller') "GPU maintenance uses the exact DDU WinGet package"
Assert-True ($nativeSourceText -match '\*WGDotGpuSafeModeResume') "DDU workflow registers a Safe Mode-capable RunOnce handoff"
Assert-True ($nativeSourceText -match 'gpu-safe-resume --state-sha256') "Safe Mode RunOnce binds the exact GPU state digest"
Assert-True ($nativeSourceText -match 'if \(command == "gpu-safe-resume"\) return GpuSafeResumeFromArgs\(args\.Skip\(1\)\.ToArray\(\)\);') "GPU resume parses its digest argument"
$gpuResumeBlock = [regex]::Match($nativeSourceText, '(?ms)static int GpuSafeResume\(.*?^    }').Value
Assert-True ($gpuResumeBlock -match 'ReadVerifiedJson\(GpuStatePath, expectedStateSha256\)') "GPU resume parses only verified state bytes"
Assert-True ($gpuResumeBlock -match 'RunElevatedSelf\("gpu-safe-resume --state-sha256 "') "GPU resume preserves its digest through UAC"
Assert-True ($gpuResumeBlock -match 'FindTrustedDduExe\(\)') "GPU resume re-resolves DDU after elevation"
Assert-True ($gpuResumeBlock -notmatch 'GetString\(state, "dduPath"\)') "GPU resume never executes the stored DDU path"
$menuBlock = [regex]::Match($nativeSourceText, '(?ms)static int Menu\(\).*?^    }').Value
Assert-True ($menuBlock -match 'GpuSafeResume\(ReadPendingGpuStateSha256\(\)\)') "Safe Mode menu fallback uses the digest protected by HKLM RunOnce"
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
Assert-True ($nativeBootstrapText -match 'curl\.exe HTTPS transport failed; trying Windows PowerShell \.NET WebClient') "native bootstrap has a managed-PC HTTPS fallback when curl Schannel fails"
Assert-True ($nativeBootstrapText -match 'New-Object Net\.WebClient') "native bootstrap fallback uses the in-box .NET WebClient"
Assert-True ($nativeBootstrapText -match 'WGDOT_FORCE_POWERSHELL_DOWNLOAD') "CI can force the bootstrap WebClient transport"
Assert-True ($nativeBootstrapText -notmatch '(?i)Set-ExecutionPolicy|-ExecutionPolicy\s+(Bypass|Unrestricted)') "bootstrap transport fallback does not alter or bypass PowerShell execution policy"
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
$yasbWorkConfigText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.config\yasb\custom_work_config.yaml") -Raw
Assert-True ($yasbConfigText -match 'context_menu:\s*false') "YASB blank-bar context menu is disabled while Alt+Ctrl+B keeps coordinated auto-hide"
Assert-True ($yasbConfigText -notmatch 'idle_inhibitor|idle-inhibitor-(?:status|toggle|worker)') "Normal YASB contains no retired idle inhibitor"
Assert-True ($yasbWorkConfigText -notmatch 'idle_inhibitor|idle-inhibitor-(?:status|toggle|worker)') "Work YASB contains no retired idle inhibitor"
Assert-True ($nativeSourceText -notmatch 'command == "idle-inhibitor-(?:status|toggle|worker)"') "WGDot no longer dispatches live idle-inhibitor commands"
Assert-True ($nativeSourceText -match 'SignalIdleInhibitorStop') "runtime replacement can still stop a legacy idle worker from an older build"
Assert-True ($yasbConfigText -match 'wgdotw\.exe clipboard-history-open') "YASB clipboard button uses the bar-only native Win+V helper"
Assert-True ($yasbConfigText -match 'glazewm_tiling_direction') "YASB exposes GlazeWM tiling direction"
Assert-True ($yasbConfigText -match 'GlazewmTilingDirectionWidget') "YASB uses its native GlazeWM tiling-direction widget"
Assert-True ($yasbConfigText -notmatch 'keys:\s*"f24"') "Normal YASB has no synthetic F24 Quick Launch bridge"
Assert-True ($yasbConfigText -notmatch 'keys:\s*"alt\+p"|keys:\s*"win\+d"') "Normal YASB leaves user-facing launcher chords to GlazeWM"
Assert-True ($yasbWorkConfigText -notmatch 'keys:\s*"f24"') "Work YASB has no synthetic F24 Quick Launch bridge"
Assert-True ($yasbWorkConfigText -notmatch 'keys:\s*"alt\+p"|keys:\s*"win\+d"') "Work YASB leaves user-facing launcher chords to GlazeWM"
Assert-True ($yasbConfigText -notmatch 'workspace_move_hub|workspace-move-hub|workspace_move_group|workspace-move-grouper') "Normal YASB removes the retired workspace hub slot"
Assert-True ($yasbWorkConfigText -notmatch 'workspace_move_hub|workspace-move-hub|workspace_move_group|workspace-move-grouper') "Work YASB removes the retired workspace hub slot"
Assert-True ($yasbConfigText -match 'glazewm\.exe command move-workspace --direction left') "Normal YASB keeps direct workspace arrows"
Assert-True ($yasbWorkConfigText -match 'glazewm\.exe command move-workspace --direction left') "Work YASB keeps direct workspace arrows"
Assert-True ($yasbConfigText -match 'populated_label:\s*"\{display_name\}"') "Normal YASB renders GlazeWM workspace display_name values"
Assert-True ($yasbWorkConfigText -match 'populated_label:\s*"\{display_name\}"') "Work YASB renders GlazeWM workspace display_name values"
Assert-True ($yasbConfigText -notmatch 'populated_label:\s*"\{name\}"') "Normal YASB does not override workspace display_name with raw name"
Assert-True ($yasbWorkConfigText -notmatch 'populated_label:\s*"\{name\}"') "Work YASB does not override workspace display_name with raw name"
Assert-True ($yasbConfigText -notmatch 'mouse-mode-toggle|workspace_mouse') "Normal YASB contains no retired mouse-mode runtime"
Assert-True ($yasbWorkConfigText -notmatch 'mouse-mode-toggle|workspace_mouse') "Work YASB contains no retired mouse-mode runtime"
$glazeNormalText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.glzr\glazewm\config.yaml") -Raw
$glazeWorkText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.glzr\glazewm\custom_work_config.yaml") -Raw
for ($workspaceIndex = 1; $workspaceIndex -le 10; $workspaceIndex++) {
    $expectedDisplayName = 'display_name: "' + $workspaceIndex + '"'
    Assert-True ($glazeNormalText.Contains($expectedDisplayName)) "Normal workspace $workspaceIndex defaults to a numeric display_name"
    Assert-True ($glazeWorkText.Contains($expectedDisplayName)) "Work workspace $workspaceIndex defaults to a numeric display_name"
}
Assert-True ($yasbConfigText -match 'populated_label:\s*"\{display_name\}"') "Normal YASB still renders editable GlazeWM display_name values"
Assert-True ($yasbWorkConfigText -match 'populated_label:\s*"\{display_name\}"') "Work YASB still renders editable GlazeWM display_name values"
Assert-True ($glazeNormalText -notmatch 'flow-launcher\.ps1|yasb-quick-launch\.ps1') "Normal GlazeWM contains no launcher relay script"
Assert-True ($glazeWorkText -notmatch 'flow-launcher\.ps1|yasb-quick-launch\.ps1') "Work GlazeWM contains no launcher relay script"
Assert-True ($glazeNormalText -match 'wgdotw\.exe launcher hotkey') "Normal GlazeWM uses the compiled launcher"
Assert-True ($glazeWorkText -match 'wgdotw\.exe launcher hotkey') "Work GlazeWM uses the compiled launcher"
Assert-True ($glazeWorkText -notmatch 'shell-exec %LOCALAPPDATA%/FlowLauncher/Flow\.Launcher\.exe') "Work GlazeWM no longer defaults launcher hotkeys to Flow Launcher"
Assert-True ($glazeNormalText -match '%LOCALAPPDATA%\\wgdot\\bin\\wgdotw\.exe.*launcher hotkey') "Normal launcher hotkeys use the deterministic WGDot runtime path"
Assert-True (($glazeNormalText | Select-String -Pattern 'wgdotw\.exe btop-toggle' -AllMatches).Matches.Count -ge 2) "Normal profile routes global and noalt Super+Shift+B through the windowless btop toggle"
Assert-True (($glazeNormalText | Select-String -Pattern 'lwin\+shift\+b' -AllMatches).Matches.Count -ge 2) "Normal profile binds left Super+Shift+B globally and in noalt mode"
Assert-True (($glazeNormalText | Select-String -Pattern 'rwin\+shift\+b' -AllMatches).Matches.Count -ge 2) "Normal profile binds right Super+Shift+B globally and in noalt mode"
Assert-True ($glazeNormalText -match 'window_title:\s*\{ equals: "btop" \}') "Normal btop Windows Terminal receives a centered floating rule"
Assert-True ($glazeNormalText -notmatch 'shell-exec wt\.exe.*btop4win\.exe') "Normal profile no longer assumes btop4win.exe is directly launchable"
Assert-True ($glazeWorkText -notmatch 'btop-toggle|btop4win\.exe') "Work profile does not carry a dead btop launcher while btop defaults off"
Assert-True ($nativeSourceText -match 'static string FindBtopExe\(\)') "compiled btop helper resolves the installed executable"
Assert-True ($nativeSourceText -match 'FindExecutableWithCandidates\("btop\.exe"') "btop resolver prefers the WinGet btop command/link"
Assert-True ($nativeSourceText -match 'aristocratos\.btop4win') "btop resolver falls back only within the WinGet btop package payload"
Assert-True ($nativeSourceText -match 'static int BtopToggle\(\)') "compiled btop toggle exists"
Assert-True ($nativeSourceText -match 'FindTopLevelWindowByExactTitle\("btop"\)') "btop toggle targets its dedicated terminal title"
Assert-True ($nativeSourceText -match 'PostMessage\(existing, WmClose') "second btop invocation closes the existing dedicated terminal"

Assert-True ($glazeWorkText -match '%LOCALAPPDATA%\\wgdot\\bin\\wgdotw\.exe.*launcher hotkey') "Work launcher hotkeys use the deterministic WGDot runtime path"
Assert-True ($nativeSourceText -match 'UseShellExecute = true') "compiled launcher activates Start Menu shortcuts through Windows shell semantics"
Assert-True ($nativeSourceText -match 'const int width = 380') "compiled launcher uses the compact near-half-width search surface"
Assert-True ($nativeSourceText -match 'searchWrap\.Height = 42') "compiled launcher uses the reduced search-field height"
Assert-True ($nativeSourceText -match 'form\.Opacity = 0\.0;') "compiled launcher hides the unpainted first WinForms frame"
Assert-True ($nativeSourceText -match 'results\.Refresh\(\);\s*form\.Opacity = 0\.98;') "compiled launcher reveals immediately after the themed surface paints"
Assert-True ($nativeSourceText -notmatch 'fade\.Interval = 15') "compiled launcher spawn animation stays removed"
Assert-True ($nativeSourceText -match 'ResolveLauncherShortcutIconPath') "compiled launcher resolves shortcut-backed application icons"
Assert-True ($nativeSourceText -match '"WScript\.Shell"') "compiled launcher resolves Windows shortcut targets without adding a runtime script dependency"
Assert-True ($nativeSourceText -match '"TargetPath"') "compiled launcher prefers the underlying shortcut target for clean application icons"
Assert-True ($nativeSourceText -match '"IconLocation"') "compiled launcher can use explicit shortcut icon locations before falling back to the shortcut object"

Assert-True ($yasbConfigText -match 'yasb\.custom\.CustomWidget') "YASB uses a lightweight custom power button"
Assert-True ($yasbConfigText -match 'on_left:\s*"exec wgdotw\.exe power-menu"') "YASB power button opens the compiled Awtarchy-style surface"
Assert-True ($yasbWorkConfigText -match 'on_left:\s*"exec wgdotw\.exe power-menu"') "Work YASB power button opens the compiled Awtarchy-style surface"
Assert-True ($yasbConfigText -match 'class_name:\s*"awtarchy-launcher"') "Normal YASB renders the compiled launcher button"
Assert-True ($yasbWorkConfigText -match 'class_name:\s*"awtarchy-launcher"') "Work YASB renders the compiled launcher button"
Assert-True ($yasbConfigText -match 'on_left:\s*"exec wgdotw\.exe launcher bar"') "Normal YASB launcher button opens the bar-relative compiled launcher"
Assert-True ($yasbWorkConfigText -match 'on_left:\s*"exec wgdotw\.exe launcher bar"') "Work YASB launcher button opens the bar-relative compiled launcher"
Assert-True ($yasbConfigText -match 'wgdotw\.exe theme-window-toggle') "Normal YASB theme action uses the windowless theme-window toggle"
Assert-True ($yasbWorkConfigText -match 'wgdotw\.exe theme-window-toggle') "Work YASB theme action uses the windowless theme-window toggle"
Assert-True ($yasbConfigText -match 'wgdotw\.exe bar-autohide-toggle') "YASB auto-hide uses the approved compiled coordination helper"
Assert-True ($yasbConfigText -notmatch '(?i)(quick-launch|flow-open|eartrumpet-mixer(?:\s|$)|clipboard-anchor|flameshot-gui|display-settings|idle-inhibitor)') "Normal YASB does not route native-capable actions through WGDot"
Assert-True ($yasbWorkConfigText -notmatch '(?i)(quick-launch|flow-open|eartrumpet-mixer(?:\s|$)|clipboard-anchor|flameshot-gui|display-settings|idle-inhibitor)') "Work YASB does not route native-capable actions through WGDot"
Assert-True ($yasbConfigText -notmatch '\.ps1') "Normal YASB has no PowerShell script-file runtime dependency"
Assert-True ($yasbWorkConfigText -notmatch '\.ps1') "Work YASB has no PowerShell script-file runtime dependency"
Assert-True ($yasbConfigText -notmatch 'border_color:\s*None') "YASB popup border colors are not invalid YAML nulls"
Assert-True ($yasbWorkConfigText -notmatch 'border_color:\s*None') "Work YASB popup border colors are not invalid YAML nulls"
foreach ($yasbText in @($yasbConfigText, $yasbWorkConfigText)) {
    $wifiBlock = [regex]::Match($yasbText, '(?ms)^  wifi:\r?\n.*?(?=^  bluetooth:)').Value
    $bluetoothBlock = [regex]::Match($yasbText, '(?ms)^  bluetooth:\r?\n.*?(?=^  systray:)').Value
    Assert-True ($wifiBlock -match 'on_left:\s*"exec explorer\.exe ms-settings:network-status"') "YASB Wi-Fi/Ethernet opens native Windows Network settings"
    Assert-True ($bluetoothBlock -match 'on_left:\s*"exec explorer\.exe ms-settings:bluetooth"') "YASB Bluetooth opens native Windows Bluetooth settings"
    Assert-True ($wifiBlock -notmatch 'on_left:\s*"toggle_menu"') "YASB Wi-Fi/Ethernet mini menu is retired"
    Assert-True ($bluetoothBlock -notmatch 'on_left:\s*"toggle_menu"') "YASB Bluetooth mini menu is retired"
}
Assert-True ($yasbConfigText -notmatch 'cmd\.exe /c start ms-settings') "YASB settings callbacks do not spawn cmd.exe"
Assert-True ($yasbConfigText -notmatch '%USERPROFILE%\\\.config\\win-glaze\\scripts') "YASB custom actions do not rely on percent-style USERPROFILE expansion"


$altSnapConfigText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\AppData\Roaming\AltSnap\AltSnap.ini") -Raw
Assert-True ($altSnapConfigText -match '(?m)^AutoFocus=1\r?$') "AltSnap focuses windows while dragging by default"
Assert-True ($altSnapConfigText -match '(?m)^Hotkeys=A4 A5 5B 5C\r?$') "AltSnap enables left/right Alt and Win modifier keys by default"
Assert-True ($altSnapConfigText -match '(?m)^; Created for AltSnap v1\.68\r?$') "AltSnap managed config is refreshed to the 1.68 template"
Assert-True ($altSnapConfigText -match '(?m)^DragOutThresholdPx=20\r?$') "AltSnap 1.68 DragOutThresholdPx default is present"
Assert-True ($altSnapConfigText -match '(?m)^Processes=.*yasb\.exe,wgdotw\.exe\r?$') "AltSnap ignores YASB and WGDot windowless UI processes"
Assert-True ($altSnapConfigText -notmatch '(?m)^KBMoveS?Step=') "AltSnap removed obsolete pre-1.68 keyboard move-step settings"

$flameshotConfigText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\AppData\Roaming\flameshot\flameshot.ini") -Raw
Assert-True ($flameshotConfigText -match '(?m)^captureActiveMonitor=true') "Flameshot defaults to capturing the active monitor without monitor selection"
Assert-True ($flameshotConfigText -notmatch '(?i)C:/Users/|C:\\Users\\') "Flameshot managed config contains no user-specific profile path"
Assert-True ($flameshotConfigText -notmatch 'TYPE_IMAGELOADER') "Flameshot managed config does not restore the rejected legacy shortcut key"
$flameshotComponent = $manifest.components | Where-Object { $_.id -eq "flameshot" } | Select-Object -First 1
$flameshotManagedFile = $flameshotComponent.files | Where-Object { $_.id -eq "flameshot-config" } | Select-Object -First 1
Assert-True (-not [bool]$flameshotManagedFile.merge) "Flameshot INI is authoritative on reset/dots-only so stale rejected shortcut keys cannot survive a merge"

Assert-True ($nativeSourceText -match 'command == "window-audit"') "native runtime retains explicit diagnostic window auditing"
Assert-True ($nativeSourceText -match 'command == "super-l-test"') "native runtime retains the isolated Super+L development controller"
Assert-True ($nativeSourceText -match 'command == "super-l-hook"') "native runtime retains the hidden Super+L test worker"
Assert-True ($nativeSourceText -match 'String\.Equals\(command, "super-l-test"') "Super+L development controller participates in runtime auto-refresh"
Assert-True (@($yasb.postActions | Where-Object { $_.type -match 'ensure-(hidden-launcher|yasb-theme)' }).Count -eq 0) "YASB apply has no WGDot runtime post-actions"
Assert-True (@($glaze.postActions | Where-Object { $_.type -eq "ensure-desktop-worker" }).Count -eq 0) "GlazeWM apply has no WGDot desktop-worker post-action"
$autoRefreshBlock = [regex]::Match($nativeSourceText, '(?ms)^    static bool ShouldAutoRefreshRuntime\(string command\)\r?\n    \{.*?^    \}').Value
Assert-True ($autoRefreshBlock -match 'window-audit') "window audit command participates in runtime auto-refresh"
Assert-True ($autoRefreshBlock -notmatch 'theme|quick-launch|flow-open|mouse-mode|bar-autohide|glazewm-binding-mode|glazewm-pause|idle-inhibitor') "desktop helpers are absent from runtime auto-refresh policy"
Assert-True ($nativeSourceText -match 'GetWindowThreadProcessId') "window audit resolves process IDs from real top-level windows"
Assert-True ($nativeSourceText -match 'IsWindowVisible') "window audit filters to visible top-level windows"

$terminalSettingsPath = Join-Path $repoRoot "UserProfile\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$terminalSettings = Get-Content -LiteralPath $terminalSettingsPath -Raw | ConvertFrom-Json
Assert-Equal $true ([bool]$terminalSettings.copyOnSelect) "Windows Terminal copies selected text automatically"
Assert-True (@($terminalSettings.keybindings | Where-Object { $null -eq $_.id -and $_.keys -eq "ctrl+c" }).Count -eq 1) "Windows Terminal unbinds Ctrl+C so terminal applications receive it"
Assert-True (@($terminalSettings.keybindings | Where-Object { $null -eq $_.id -and $_.keys -eq "ctrl+v" }).Count -eq 1) "Windows Terminal unbinds Ctrl+V so terminal applications receive it"
Assert-True (@($terminalSettings.keybindings | Where-Object { $_.id -eq "Terminal.CopyToClipboard" -and $_.keys -eq "ctrl+shift+c" }).Count -eq 1) "Windows Terminal keeps Ctrl+Shift+C copy"
Assert-True (@($terminalSettings.keybindings | Where-Object { $_.id -eq "Terminal.PasteFromClipboard" -and $_.keys -eq "ctrl+shift+v" }).Count -eq 1) "Windows Terminal keeps Ctrl+Shift+V paste"

$glazeNormalText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.glzr\glazewm\config.yaml") -Raw
$glazeWorkText = Get-Content -LiteralPath (Join-Path $repoRoot "UserProfile\.glzr\glazewm\custom_work_config.yaml") -Raw
Assert-True ($glazeNormalText -match 'bindings:\s*\["lwin\+shift\+m",\s*"rwin\+shift\+m"\]') "Normal profile keeps Raw Accel on Super+Shift+M"
Assert-True ($glazeWorkText -match 'bindings:\s*\["lwin\+shift\+m",\s*"rwin\+shift\+m"\]') "Work profile keeps Raw Accel on Super+Shift+M"
Assert-True ($glazeNormalText -notmatch 'bindings:\s*\["alt\+shift\+m",\s*"lwin\+shift\+m",\s*"rwin\+shift\+m"\]') "Normal profile does not capture Alt+Shift+M for Raw Accel"
Assert-True ($glazeNormalText -match 'bindings:\s*\["alt\+ctrl\+shift\+m"\]') "Normal scripts menu remains on Alt+Ctrl+Shift+M"
Assert-True ($glazeNormalText -match 'window_process:\s*\{ regex: "\^rawaccel') "Raw Accel launches floating and centered in Normal profile"
Assert-True ($glazeNormalText -notmatch 'desktop-worker') "Normal profile has no WGDot desktop worker"
Assert-True ($glazeWorkText -notmatch 'desktop-worker') "Work profile has no WGDot desktop worker"
Assert-True ($glazeNormalText -match 'bindings:\s*\["alt\+shift\+c"\]') "Normal profile keeps Awtarchy Alt+Shift+C SpeedCrunch"
Assert-True ($glazeNormalText -match 'bindings:\s*\["lwin\+shift\+c",\s*"rwin\+shift\+c"\]') "Normal profile keeps Awtarchy Super+Shift+C SpeedCrunch"
Assert-True ($glazeNormalText -match '(?ms)cursor_jump:\s*\r?\n\s+enabled:\s*true\r?\n\s+trigger:\s*"monitor_focus"') "Normal profile jumps cursor on monitor focus"
Assert-True ($glazeWorkText -match '(?ms)cursor_jump:\s*\r?\n\s+enabled:\s*true\r?\n\s+trigger:\s*"monitor_focus"') "Work profile jumps cursor on monitor focus"
Assert-True ($glazeNormalText -notmatch '(?ms)- name: "1"\r?\n\s+display_name: "1: Flame"\r?\n\s+keep_alive:\s*true') "normal GlazeWM workspace 1 is not pinned alive"
Assert-True ($glazeNormalText -notmatch 'yasb-quick-launch\.ps1|flow-launcher\.ps1') "Normal GlazeWM has no launcher relay scripts"
Assert-True ($glazeWorkText -notmatch 'yasb-quick-launch\.ps1|flow-launcher\.ps1') "Work GlazeWM has no launcher relay scripts"
Assert-True ($glazeNormalText -notmatch '\.ps1') "Normal GlazeWM has no PowerShell script-file runtime dependency"
Assert-True ($glazeWorkText -notmatch '\.ps1') "Work GlazeWM has no PowerShell script-file runtime dependency"
Assert-True ($glazeNormalText -match 'wgdotw\.exe rawaccel-toggle') "Normal GlazeWM uses the scoped compiled RawAccel toggle"
Assert-True ($glazeWorkText -match 'wgdotw\.exe rawaccel-toggle') "Work GlazeWM uses the scoped compiled RawAccel toggle"
Assert-True ($glazeNormalText -notmatch 'mouse-mode-toggle|name:\s*"mouse"|lwin\+alt\+m|rwin\+alt\+m') "Normal GlazeWM contains no retired mouse mode"
Assert-True ($glazeWorkText -notmatch 'mouse-mode-toggle|name:\s*"mouse"|lwin\+alt\+m|rwin\+alt\+m') "Work GlazeWM contains no retired mouse mode"
Assert-True ($glazeNormalText -match 'focus_follows_cursor:\s*true') "Normal GlazeWM defaults focus_follows_cursor to true"
Assert-True ($glazeWorkText -match 'focus_follows_cursor:\s*false') "Work GlazeWM keeps focus_follows_cursor false"
Assert-True ($glazeWorkText -match 'wgdotw\.exe bar-autohide-toggle') "Work GlazeWM uses the scoped compiled auto-hide helper"
Assert-True ($glazeNormalText -match 'wgdotw\.exe theme-window-toggle') "Normal GlazeWM uses the windowless theme-window toggle"
Assert-True ($glazeWorkText -match 'wgdotw\.exe theme-window-toggle') "Work GlazeWM uses the windowless theme-window toggle"
Assert-True ($glazeNormalText -match 'bindings:\s*\["alt\+p",\s*"lwin\+d",\s*"rwin\+d"\]') "Normal GlazeWM owns Alt+P and Super+D for the compiled launcher"
Assert-True ($glazeWorkText -match 'bindings:\s*\["alt\+p",\s*"lwin\+d",\s*"rwin\+d"\]') "Work GlazeWM owns Alt+P and Super+D for the compiled launcher"
Assert-True ($glazeWorkText -notmatch 'FlowLauncher/Flow\.Launcher\.exe') "Work launcher hotkeys do not depend on Flow Launcher"
foreach ($text in @($glazeNormalText, $glazeWorkText)) {
    Assert-True ($text -notmatch '(?i)flameshot\.exe') "GlazeWM leaves Flameshot activation to Flameshot itself"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+shift\+x",\s*"rwin\+shift\+x"\]') "GlazeWM does not capture Flameshot Super+Shift+X"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+alt\+s",\s*"rwin\+alt\+s"\]') "GlazeWM does not capture the retired Super+Alt+S Flameshot chord"
    Assert-True ($text -notmatch 'win\+shift\+f') "old Win+Shift+F Flameshot bind is removed"
    Assert-True ($text -notmatch '(?i)wgdotw?\.exe\s+(?:quick-launch|flow-open|eartrumpet-mixer(?:\s|$)|clipboard-anchor(?:\s|$)|clipboard-history(?:\s|$)|flameshot-gui|display-settings)') "GlazeWM does not route native-capable actions through WGDot"
    Assert-True ($text -notmatch 'bindings:\s*\["alt\+v",\s*"lwin\+v",\s*"rwin\+v"\]') "GlazeWM leaves Alt+V and Super+V to EarTrumpet/Windows"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+c",\s*"rwin\+c"\]') "retired Super+C Clipboard History override stays absent"
    Assert-True ($text -notmatch 'clipboard-anchor') "retired Clipboard History hotkey handoff stays absent"
    Assert-True ($text -match 'bindings:\s*\["lwin\+p",\s*"rwin\+p"\]') "GlazeWM owns Super+P for the compiled Awtarchy-style power surface"
    Assert-True ($text -match 'wgdotw\.exe power-menu') "GlazeWM routes Super+P through the approved windowless compiled power helper"
    Assert-True ($text -notmatch 'name:\s*"mouse"') "retired mouse binding mode stays removed"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+alt\+m",\s*"rwin\+alt\+m"\]') "retired Win+Alt+M mouse binding stays removed"
    Assert-True ($text -notmatch 'wgdotw\.exe mouse-mode-toggle') "retired WGDot mouse helper stays out of GlazeWM"
    Assert-True ($text -match 'bindings:\s*\["lwin\+ctrl\+m",\s*"rwin\+ctrl\+m"\]') "Super+Ctrl+M opens Windows display settings"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+shift\+s",\s*"rwin\+shift\+s"\]') "Super+Shift+S remains native Windows Snipping Tool"
    Assert-True ($text -match 'bindings:\s*\["alt\+ctrl\+shift\+r"\]') "Alt+Ctrl+Shift+R reloads GlazeWM"
    Assert-True ($text -match 'bindings:\s*\["alt\+ctrl\+b"\]') "Alt+Ctrl+B toggles coordinated YASB auto-hide and the GlazeWM top gap"
    Assert-True ($text -match 'wgdotw\.exe bar-autohide-toggle') "bar visibility binding uses the compiled coordinated auto-hide helper"
    Assert-True ($text -notmatch 'yasbc toggle-bar') "GlazeWM does not use the unsafe hard-hide YASB command"
    Assert-True ($text -match 'inner_gap:\s*"5px"') "GlazeWM uses the requested 5px inner gap"
    Assert-True ($text -match 'top:\s*"35px"') "GlazeWM reserves the requested 35px top gap"
    Assert-True ($text -match 'color:\s*"#a1a1a1"') "GlazeWM focused border is theme-neutral"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+t",\s*"rwin\+alt\+t"\]') "Super+Alt+T theme picker exists"
    Assert-True ($text -match 'bindings:\s*\["alt\+t",\s*"lwin\+t",\s*"rwin\+t"\]') "global Alt+T and Super+T toggle tiling"
    $noaltBlock = [regex]::Match($text, '(?ms)^  - name: "noalt"\r?\n.*?(?=^  # VM mode|^  - name: "vm")').Value
    Assert-True ($noaltBlock -match 'bindings:\s*\["lwin\+t",\s*"rwin\+t"\]') "noalt keeps Super+T tiling"
    Assert-True ($noaltBlock -match 'bindings:\s*\["lwin\+alt\+t",\s*"rwin\+alt\+t"\]') "noalt keeps Super+Alt+T themes"
    Assert-True ($noaltBlock -notmatch 'bindings:\s*\["alt\+t"\]') "noalt does not capture plain Alt+T"
    Assert-True ($noaltBlock -notmatch 'bindings:\s*\["lwin\+v",\s*"rwin\+v"\]') "noalt leaves native Super+V Clipboard History uncaptured"
    Assert-True ($noaltBlock -notmatch 'bindings:\s*\["alt\+v"\]') "noalt leaves EarTrumpet Alt+V uncaptured by GlazeWM"
    Assert-True ($noaltBlock -match 'bindings:\s*\["lwin\+d",\s*"rwin\+d"\]') "noalt keeps Super+D compiled launcher"
    Assert-True ($noaltBlock -notmatch 'bindings:\s*\["alt\+p"\]') "noalt does not capture plain Alt+P"
    Assert-True ($text -match 'wgdotw\.exe theme-window-toggle') "theme shortcut uses the windowless compiled theme toggle"
    Assert-True ($text -match 'window_title:\s*\{ equals: "Win Glaze Themes" \}') "theme selector has a dedicated floating title rule"
    Assert-True ($text -match 'name:\s*"noalt"') "GlazeWM noalt mode remains available with selective shell-hotkey filtering"
    Assert-True ($text -match 'wm-enable-binding-mode --name noalt') "noalt mode transitions are native GlazeWM commands"
    Assert-True ($text -match 'commands:\s*\["wm-toggle-pause"\]') "GlazeWM uses its real pause command"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+p",\s*"rwin\+alt\+p"\]') "Alt+Super+P toggles real GlazeWM pause"
    Assert-True ($text -match 'name:\s*"vm"') "GlazeWM has a VM binding mode"
    Assert-True ($text -match 'wm-enable-binding-mode --name vm') "VM mode transitions are native GlazeWM commands"
    Assert-True ($text -match 'wm-disable-binding-mode --name (?:noalt|vm)') "binding modes have native GlazeWM escape commands"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+v",\s*"rwin\+alt\+v"\]') "Win+Alt+V toggles/switches VM mode"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+alt\+s",\s*"rwin\+alt\+s"\]') "VM mode leaves retired Win+Alt+S Flameshot chord unbound"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+1",\s*"rwin\+alt\+1"\]') "VM mode keeps host workspace switching on Win+Alt+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+shift\+1",\s*"rwin\+alt\+shift\+1"\]') "VM mode keeps host move-to-workspace on Win+Alt+Shift+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+shift\+e",\s*"rwin\+shift\+e"\]') "Yazi uses both Windows keys for Win+Shift+E"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin",\s*"rwin"\]') "GlazeWM does not use ineffective bare-Super bindings"
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

$yasbComponent = $manifest.components | Where-Object { $_.id -eq "yasb" } | Select-Object -First 1
Assert-True ($null -ne $yasbComponent) "YASB managed component exists"
Assert-True ([bool]$yasbComponent.defaultNormal) "YASB dotfiles are enabled by default for Normal"
Assert-True ([bool]$yasbComponent.defaultWork) "YASB dotfiles are enabled by default for Work"
$yasbConfigFile = $yasbComponent.files | Where-Object { $_.id -eq "yasb-config" } | Select-Object -First 1
$yasbStylesFile = $yasbComponent.files | Where-Object { $_.id -eq "yasb-styles" } | Select-Object -First 1
Assert-Equal "UserProfile/.config/yasb/config.yaml" ([string]$yasbConfigFile.sourceByGlazeProfile.normal) "Normal deploys the managed YASB config"
Assert-Equal "UserProfile/.config/yasb/custom_work_config.yaml" ([string]$yasbConfigFile.sourceByGlazeProfile.work) "Work deploys the managed YASB config"
Assert-Equal "UserProfile/.config/yasb/styles.css" ([string]$yasbStylesFile.source) "Normal and Work share the corrected managed YASB stylesheet"
Assert-Equal "%USERPROFILE%\.config\yasb\styles.css" ([string]$yasbStylesFile.destination) "corrected YASB stylesheet deploys to the live Windows dotfile path"

$managedDesktopRuntimeFiles = @(
    Join-Path $repoRoot "UserProfile/.glzr/glazewm/config.yaml"
    Join-Path $repoRoot "UserProfile/.glzr/glazewm/custom_work_config.yaml"
    Join-Path $repoRoot "UserProfile/.config/yasb/config.yaml"
    Join-Path $repoRoot "UserProfile/.config/yasb/custom_work_config.yaml"
)
foreach ($managedDesktopRuntimeFile in $managedDesktopRuntimeFiles) {
    $managedDesktopRuntimeText = Get-Content -Raw -LiteralPath $managedDesktopRuntimeFile
    Assert-True ($managedDesktopRuntimeText -notmatch '\.ps1') "managed desktop runtime config contains no PowerShell script-file dependency: $managedDesktopRuntimeFile"
    Assert-True ($managedDesktopRuntimeText -notmatch '(?i)wgdotw?\.exe\s+(?:quick-launch|flow-open|eartrumpet-mixer(?:\s|$)|clipboard-anchor(?:\s|$)|clipboard-history(?:\s|$)|flameshot-gui|display-settings)') "managed desktop config does not route native-capable actions through WGDot: $managedDesktopRuntimeFile"
}

Write-Host "WGDot tests passed." -ForegroundColor Green
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
Assert-True ($nativeSourceText -notmatch 'ApplyFlowLauncherAltP') "retired WGDot Flow Launcher Alt+P integration stays removed"
Assert-True ($nativeSourceText -notmatch 'command == "quick-launch"|command == "flow-open"') "retired launcher relay commands stay removed"
Assert-True ($nativeSourceText -match 'if \(command == "launcher"\) return LauncherFromArgs') "native runtime exposes the approved compiled launcher"
Assert-True ($nativeSourceText -match 'LauncherLocation') "compiled launcher has context-aware placement logic"
Assert-True ($nativeSourceText -match 'YasbAutoHideEnabled') "compiled launcher centers when YASB auto-hide is active"
Assert-True ($nativeSourceText -match 'ForegroundWindowFillsScreen') "compiled launcher detects fullscreen/borderless foreground windows"
Assert-True ($nativeSourceText -match 'const int launcherBarGap = 1;') "launcher keeps only a 1px gap below the 28px YASB bar"
Assert-True ($nativeSourceText -match 'int belowBarY = screen\.Bounds\.Top \+ 28 \+ launcherBarGap;') "bar and hotkey launcher placement share the tight below-bar Y position"
Assert-True ($nativeSourceText -match 'Environment\.SpecialFolder\.Programs') "compiled launcher indexes user Start Menu applications"
Assert-True ($nativeSourceText -match 'Environment\.SpecialFolder\.CommonPrograms') "compiled launcher indexes common Start Menu applications"
Assert-True ($nativeSourceText -notmatch 'ApplyEarTrumpetMixerSuperV') "WGDot no longer manages EarTrumpet's mixer hotkey"
Assert-True ($nativeSourceText -match 'static string RequireGlazeWmExe\(\)') "runtime helpers require the resolved GlazeWM executable path"
Assert-True ($nativeSourceText -notmatch 'command == "mouse-mode-(?:toggle|disable|hook)"') "retired mouse-mode commands stay undispatched"
Assert-True ($nativeSourceText -notmatch 'static int MouseModeToggle\(|static int MouseModeHook\(|static IntPtr MouseModeHookCallback\(') "retired mouse-mode runtime implementation stays removed"
Assert-True ($nativeSourceText -match 'SignalMouseModeHookStop') "runtime replacement can still stop a legacy mouse hook from an older build"
Assert-True ($nativeSourceText -match 'ApplyClassicContextMenu') "native runtime manages classic context menu"
Assert-True ($nativeSourceText -match 'DeleteRegistryKeyIfOriginallyAbsentAndEmpty') "native tweak rollback prunes only WGDot-created empty registry keys"
Assert-True ($nativeSourceText -notmatch 'DeleteSubKeyTree\(clsid') "classic context-menu rollback does not delete unknown pre-WGDot CLSID state"
Assert-True ($nativeSourceText -match 'base64-bytes') "registry rollback preserves binary and REG_NONE values losslessly"
Assert-True ($nativeSourceText -match 'RegistryKeyWasAbsentInSnapshot') "registry rollback tracks pre-WGDot key existence"
Assert-True ($nativeSourceText -match 'ApplyOopsCursor') "native runtime manages optional cursor install"
Assert-True ($nativeSourceText -match 'undergroundwires/privacy\.sexy/releases/latest') "privacy.sexy uses official latest GitHub release"
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
Assert-True ($nativeBootstrapText -match 'curl\.exe HTTPS transport failed; trying Windows PowerShell \.NET WebClient') "native bootstrap has a managed-PC HTTPS fallback when curl Schannel fails"
Assert-True ($nativeBootstrapText -match 'New-Object Net\.WebClient') "native bootstrap fallback uses the in-box .NET WebClient"
Assert-True ($nativeBootstrapText -match 'WGDOT_FORCE_POWERSHELL_DOWNLOAD') "CI can force the bootstrap WebClient transport"
Assert-True ($nativeBootstrapText -notmatch '(?i)Set-ExecutionPolicy|-ExecutionPolicy\s+(Bypass|Unrestricted)') "bootstrap transport fallback does not alter or bypass PowerShell execution policy"
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
    Assert-True ($text -notmatch '(?i)flameshot\.exe') "GlazeWM leaves Flameshot activation to Flameshot itself"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+shift\+x",\s*"rwin\+shift\+x"\]') "GlazeWM does not capture Flameshot Super+Shift+X"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+alt\+s",\s*"rwin\+alt\+s"\]') "GlazeWM does not capture the retired Super+Alt+S Flameshot chord"
    Assert-True ($text -notmatch 'win\+shift\+f') "old Win+Shift+F Flameshot bind is removed"
    Assert-True ($text -notmatch '(?i)wgdotw?\.exe\s+(?:quick-launch|flow-open|eartrumpet-mixer(?:\s|$)|clipboard-anchor(?:\s|$)|clipboard-history(?:\s|$)|flameshot-gui|display-settings)') "GlazeWM does not route native-capable actions through WGDot"
    Assert-True ($text -notmatch 'bindings:\s*\["alt\+v",\s*"lwin\+v",\s*"rwin\+v"\]') "GlazeWM leaves Alt+V and Super+V to EarTrumpet/Windows"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+c",\s*"rwin\+c"\]') "retired Super+C Clipboard History override stays absent"
    Assert-True ($text -notmatch 'clipboard-anchor') "retired Clipboard History hotkey handoff stays absent"
    Assert-True ($text -match 'name:\s*"noalt"') "GlazeWM noalt mode is restored"
    Assert-True ($text -match 'wm-enable-binding-mode --name noalt') "noalt mode transitions are native GlazeWM commands"
    Assert-True ($text -match 'commands:\s*\["wm-toggle-pause"\]') "GlazeWM real pause command is present"
    Assert-True ($text -match 'name:\s*"vm"') "GlazeWM has a VM binding mode"
    Assert-True ($text -match 'wm-enable-binding-mode --name vm') "VM mode transitions are native GlazeWM commands"
    Assert-True ($text -match 'wm-disable-binding-mode --name (?:noalt|vm)') "binding modes have native escape commands"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+v",\s*"rwin\+alt\+v"\]') "Win+Alt+V toggles/switches VM mode"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin\+alt\+s",\s*"rwin\+alt\+s"\]') "VM mode leaves retired Win+Alt+S Flameshot chord unbound"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+1",\s*"rwin\+alt\+1"\]') "VM mode keeps host workspace switching on Win+Alt+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+alt\+shift\+1",\s*"rwin\+alt\+shift\+1"\]') "VM mode keeps host move-to-workspace on Win+Alt+Shift+number"
    Assert-True ($text -match 'bindings:\s*\["lwin\+shift\+e",\s*"rwin\+shift\+e"\]') "Yazi uses both Windows keys for Win+Shift+E"
    Assert-True ($text -notmatch 'bindings:\s*\["lwin",\s*"rwin"\]') "GlazeWM does not use ineffective bare-Super bindings"
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

Assert-True ($nativeSourceText -match 'installed packages for available upgrades') "software reconcile reports long upgrade-scan progress"
Assert-True ($nativeSourceText -match 'Starting software batch: ') "software reconcile reports elevated batch work before waiting"
Assert-True ($nativeSourceText -match 'Administrator software batch finished\. Reading results') "software reconcile reports when elevated work returns"
Assert-True ($nativeSourceText -match 'Downloading updated WGDot runtime source') "runtime refresh reports network work"
Assert-True ($nativeSourceText -match 'Compiling updated WGDot runtime') "runtime refresh reports compilation work"
Assert-True ($nativeSourceText -match 'Running updated WGDot self-test') "runtime refresh reports self-test work"
Assert-True ($nativeBootstrapText -match 'Compiling WGDot native runtime') "bootstrap reports compile progress"
Assert-True ($nativeBootstrapText -match 'Running WGDot self-test') "bootstrap reports self-test progress"
Assert-True ($nativeBootstrapText -match 'Installing WGDot runtime') "bootstrap reports install progress"
Assert-True ($nativeBootstrapText -match 'Checking WinGet prerequisite') "bootstrap reports WinGet prerequisite work"

Assert-True ($nativeSourceText -match 'SOFTWARE\\glzr\.io\\GlazeWM') "GlazeWM startup detection reads the official installer registry key"
Assert-True ($nativeSourceText -match 'GetValue\("InstallDir"') "GlazeWM startup detection reads the official installer InstallDir value"
Assert-True ($nativeSourceText -match '"GlazeWM",[\s\S]*?"cli",[\s\S]*?"glazewm\.exe"') "GlazeWM startup detection covers the current official CLI install layout"

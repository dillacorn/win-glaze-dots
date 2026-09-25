$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([IO.Path]::GetTempPath()) ('wgdot-desktop-' + [guid]::NewGuid().ToString('N'))
$savedPath = $env:PATH
$savedRoot = $env:WGDOT_TEST_ROOT
$savedWindir = $env:WINDIR
$originalDirectory = [Environment]::CurrentDirectory
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }

$failures = New-Object 'System.Collections.Generic.List[string]'

function Check($name, [scriptblock]$test) {
    try {
        & $test
        Write-Host ('PASS: ' + $name)
    }
    catch {
        $failures.Add($name + ': ' + $_.Exception.Message)
        Write-Host ('FAIL: ' + $name + ': ' + $_.Exception.Message)
    }
}

function Require([bool]$condition, [string]$message) {
    if (-not $condition) { throw $message }
}

function Get-NativeMethod([string]$name) {
    return $script:native.GetMethod($name, [Reflection.BindingFlags]'Static,NonPublic')
}

function Invoke-Native([string]$name, [object[]]$arguments = @()) {
    $method = Get-NativeMethod $name
    if ($null -eq $method) { throw ('Missing native method: ' + $name) }

    $invokeArguments = @(
        foreach ($argument in $arguments) {
            if ($null -eq $argument) { $null }
            else { $argument.PSObject.BaseObject }
        }
    )

    try { return $method.Invoke($null, [object[]]$invokeArguments) }
    catch [Reflection.TargetInvocationException] { throw $_.Exception.InnerException }
}

try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    $env:WGDOT_TEST_ROOT = $temp

    $source = Join-Path $repo 'wgdot\wgdot-native.cs'
    $nativeSource = Get-Content -LiteralPath $source -Raw -Encoding UTF8
    $assembly = Join-Path $temp 'wgdot.exe'

    & $csc /nologo /target:exe "/out:$assembly" /r:System.Web.Extensions.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /r:System.Xml.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll $source
    Require ($LASTEXITCODE -eq 0) 'Native compilation failed'
    $script:native = [Reflection.Assembly]::LoadFile($assembly).GetType('WgdotNative')

    Check 'hybrid WGDot runtime exposes only approved custom helpers' {
        foreach ($name in @(
            'EnsureHiddenLauncher',
            'ThemeManagerFromArgs',
            'ThemeWindowToggle',
            'ClipboardHistoryOpen',
            'LauncherFromArgs',
            'YaziDragFromArgs',
            'PowerMenu',
            'BarAutoHideToggle',
            'GlazeWmBindingModeToggleFromArgs',
            'GlazeWmWindowBehaviorToggle',
            'RawAccelToggle'
        )) {
            Require ($null -ne (Get-NativeMethod $name)) ('Approved scoped native desktop helper is missing: ' + $name)
        }

        foreach ($name in @(
            'ShouldSurfaceDesktopHelperFailure',
            'ReportDesktopHelperFailure',
            'OpenFlowLauncher',
            'OpenYasbQuickLaunch',
            'OpenWindowsClipboardHistory',
            'OpenFlameshotGui',
            'OpenRawAccel',
            'OpenDisplaySettings',
            'GlazeWmReloadConfig',
            'GlazeWmIsPaused',
            'GlazeWmPauseStatus',
            'GlazeWmPauseToggle',
            'ThemeToggle',
            'OpenEarTrumpetMixer',
            'RestoreLegacyFlowHotkey',
            'ApplyFlowLauncherAltP'
        )) {
            Require ($null -eq (Get-NativeMethod $name)) ('Native-capable desktop helper must stay absent: ' + $name)
        }
    }

    Check 'Yazi native drag helper uses an explicit short-lived drag surface' {
        Require ($nativeSource -match 'if \(command == "yazi-drag"\) return YaziDragFromArgs') 'Yazi native drag command dispatch is missing'
        $surfaceBlock = [regex]::Match($nativeSource, '(?ms)sealed class YaziDragSurface : System\.Windows\.Forms\.Form.*?^    }\r?\n\r?\n    static int YaziDragFromArgs').Value
        $dragBlock = [regex]::Match($nativeSource, '(?ms)static int YaziDragFromArgs\(string\[\] args\).*?^    }').Value
        Require ($surfaceBlock -match 'dragLabel\.MouseDown \+= BeginFileDrag') 'Yazi drag surface is not directly draggable with Mouse1'
        Require ($surfaceBlock -match 'FindYasbTheme\(CurrentYasbThemeId\(\)\)') 'Yazi drag surface does not follow the current WGDot theme'
        Require ($surfaceBlock -match 'theme\.Background' -and $surfaceBlock -match 'theme\.Foreground' -and $surfaceBlock -match 'theme\.Active' -and $surfaceBlock -match 'theme\.Hover' -and $surfaceBlock -match 'theme\.Focus') 'Yazi drag surface is missing current-theme palette roles'
        Require ($surfaceBlock -match 'FormBorderStyle\.None') 'Yazi drag surface still exposes an unthemed native tool-window frame'
        Require ($surfaceBlock -match 'Opacity = 0\.0' -and $surfaceBlock -match 'Opacity = 0\.98') 'Yazi drag surface can flash before themed paint'
        Require ($surfaceBlock -match 'data\.SetFileDropList\(dropList\)') 'Yazi drag surface does not expose native file-drop data'
        Require ($surfaceBlock -match 'DoDragDrop') 'Yazi drag is not using native OLE/WinForms drag-drop'
        Require ($dragBlock -match 'Application\.Run\(new YaziDragSurface\(files\)\)') 'Yazi drag command does not run the dedicated drag surface'
        Require ($surfaceBlock -notmatch 'GetAsyncKeyState|PointInsideRect|Clipboard|keybd_event|SendKeys|SetWindowsHookEx') 'Yazi drag surface must not track terminal pointer escape, mutate clipboard, inject keys, or install hooks'

        $refreshBlock = [regex]::Match($nativeSource, '(?ms)static bool ShouldAutoRefreshRuntime\(string command\).*?^    }').Value
        Require ($refreshBlock -notmatch 'yazi-drag') 'Yazi drag must not trigger runtime/network refresh'

        $dragFile = Join-Path $temp 'drag-source.txt'
        Set-Content -LiteralPath $dragFile -Value 'x' -NoNewline
        $manifest = Join-Path ([IO.Path]::GetTempPath()) ('wgdot-yazi-drag-' + [guid]::NewGuid().ToString('N') + '.txt')
        try {
            Set-Content -LiteralPath $manifest -Value $dragFile -Encoding UTF8
            $paths = @(Invoke-Native 'LoadYaziDragPaths' @($manifest))
            Require ($paths.Count -eq 1) 'Yazi drag manifest did not return exactly one path'
            Require ([IO.Path]::GetFullPath([string]$paths[0]) -eq [IO.Path]::GetFullPath($dragFile)) 'Yazi drag manifest path changed unexpectedly'
        }
        finally {
            Remove-Item -LiteralPath $manifest -Force -ErrorAction SilentlyContinue
        }

        $outsideManifest = Join-Path $repo 'wgdot-yazi-drag-invalid.txt'
        $rejected = $false
        try { Invoke-Native 'NormalizeYaziDragListPath' @($outsideManifest) | Out-Null }
        catch { $rejected = $true }
        Require $rejected 'Yazi drag accepted a manifest outside the temporary directory'
    }

    Check 'windowless WGDot frontend preserves exact argument boundaries' {
        Invoke-Native 'EnsureHiddenLauncher'
        $wrapper = Join-Path $temp 'wgdot\bin\wgdotw.exe'
        Require (Test-Path -LiteralPath $wrapper -PathType Leaf) 'Windowless WGDot frontend was not compiled'
        Require ([Diagnostics.FileVersionInfo]::GetVersionInfo($wrapper).FileVersion -eq '2.0.0.0') 'Windowless WGDot frontend version is stale'

        $wrapperType = [Reflection.Assembly]::LoadFile($wrapper).GetType('WgdotHidden')
        $quote = $wrapperType.GetMethod('QuoteForwardedArgument', [Reflection.BindingFlags]'Static,NonPublic')
        Require ($null -ne $quote) 'Windowless WGDot argument quoting helper is missing'

        $cases = @(
            [pscustomobject]@{ Input = 'plain'; Expected = 'plain' }
            [pscustomobject]@{ Input = 'path with spaces'; Expected = '"path with spaces"' }
            [pscustomobject]@{ Input = 'embedded"quote'; Expected = '"embedded\"quote"' }
            [pscustomobject]@{ Input = 'ends with slash \'; Expected = '"ends with slash \\"' }
            [pscustomobject]@{ Input = ''; Expected = '""' }
        )
        foreach ($case in $cases) {
            $actual = [string]$quote.Invoke($null, [object[]]@([string]$case.Input))
            Require ($actual -ceq [string]$case.Expected) ('Windowless WGDot argument quoting changed for: ' + [string]$case.Input)
        }
    }

    Check 'retired mouse mode stays removed while legacy cleanup remains' {
        Require ($null -eq (Get-NativeMethod 'MouseModeToggle')) 'Retired MouseModeToggle implementation returned'
        Require ($null -eq (Get-NativeMethod 'MouseModeHook')) 'Retired MouseModeHook implementation returned'
        Require ($nativeSource -notmatch 'command == "mouse-mode-(?:toggle|disable|hook)"') 'Retired mouse-mode command dispatch returned'
        Require ($nativeSource -match 'SignalMouseModeHookStop') 'Legacy runtime cleanup can no longer stop an older mouse hook'
    }

    Check 'legacy runtime replacement stop signals are preserved' {
        foreach ($name in @('SignalIdleInhibitorStop', 'SignalMouseModeHookStop', 'SignalDesktopWorkerStop')) {
            Require ($null -ne (Get-NativeMethod $name)) ('Legacy cleanup signal is missing: ' + $name)
        }
        Require ($nativeSource -match 'Local\\WGDot\.IdleInhibitor') 'Legacy idle-inhibitor mutex identity changed'
        Require ($nativeSource -match 'Local\\WGDot\.MouseModeHook') 'Legacy mouse-mode mutex identity changed'
        Require ($nativeSource -match 'Local\\WGDot\.DesktopWorker') 'Legacy desktop-worker mutex identity changed'
    }

    Check 'Super+L remains development-only native testing support' {
        Require ($null -ne (Get-NativeMethod 'SuperLTestFromArgs')) 'super-l-test command implementation is missing'
        Require ($null -ne (Get-NativeMethod 'SuperLHookWorker')) 'super-l-hook worker implementation is missing'
    }

    $desktopRuntimeFiles = @(
        'UserProfile/.glzr/glazewm/config.yaml',
        'UserProfile/.glzr/glazewm/custom_work_config.yaml',
        'UserProfile/.config/yasb/config.yaml',
        'UserProfile/.config/yasb/custom_work_config.yaml'
    )

    Check 'managed desktop runtime obeys hybrid ownership boundary' {
        foreach ($relative in $desktopRuntimeFiles) {
            $path = Join-Path $repo ($relative -replace '/', '\')
            Require (Test-Path -LiteralPath $path -PathType Leaf) ('Missing managed desktop runtime file: ' + $relative)
            $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
            Require ($text -notmatch '\.ps1') ('Desktop runtime depends on a PowerShell script file: ' + $relative)
            Require ($text -notmatch '(?i)wgdotw?\.exe\s+(?:quick-launch|flow-open|eartrumpet-mixer(?:\s|$)|clipboard-anchor(?:\s|$)|clipboard-history(?:\s|$)|flameshot-gui|display-settings)') ('Native-capable action routed through WGDot in: ' + $relative)
        }

        $normalGlaze = Get-Content -LiteralPath (Join-Path $repo 'UserProfile\.glzr\glazewm\config.yaml') -Raw -Encoding UTF8
        $workGlaze = Get-Content -LiteralPath (Join-Path $repo 'UserProfile\.glzr\glazewm\custom_work_config.yaml') -Raw -Encoding UTF8
        $normalYasb = Get-Content -LiteralPath (Join-Path $repo 'UserProfile\.config\yasb\config.yaml') -Raw -Encoding UTF8
        $workYasb = Get-Content -LiteralPath (Join-Path $repo 'UserProfile\.config\yasb\custom_work_config.yaml') -Raw -Encoding UTF8
        foreach ($text in @($normalGlaze, $workGlaze, $normalYasb, $workYasb)) {
            Require ($text -notmatch '\.ps1') 'Normal and Work desktop runtime configs must contain zero .ps1 references'
        }
    }

    Check 'GlazeWM owns modes pause and desktop launch paths directly' {
        foreach ($relative in @(
            'UserProfile/.glzr/glazewm/config.yaml',
            'UserProfile/.glzr/glazewm/custom_work_config.yaml'
        )) {
            $text = Get-Content -LiteralPath (Join-Path $repo ($relative -replace '/', '\')) -Raw -Encoding UTF8
            Require ($text -match 'wm-enable-binding-mode --name noalt') ('NoAlt native transition missing: ' + $relative)
            Require ($text -match 'wm-enable-binding-mode --name vm') ('VM native transition missing: ' + $relative)
            Require ($text -notmatch 'name:\s*"mouse"') ('Retired mouse binding mode returned: ' + $relative)
            Require ($text -notmatch 'wgdotw\.exe mouse-mode-toggle') ('Retired mouse helper returned: ' + $relative)
            Require ($text -notmatch 'bindings:\s*\["lwin\+alt\+m",\s*"rwin\+alt\+m"\]') ('Retired Super+Alt+M mouse binding returned: ' + $relative)
            Require ($text -match 'wm-disable-binding-mode --name') ('Native mode escape missing: ' + $relative)
            Require ($text -match 'wm-toggle-pause') ('Native pause binding missing: ' + $relative)
            Require ($text -notmatch '(?i)flameshot\.exe') ('GlazeWM must leave Flameshot activation to Flameshot itself: ' + $relative)
            Require ($text -match 'wgdotw\.exe theme-window-toggle') ('Windowless theme toggle dispatch missing: ' + $relative)
            Require ($text -match 'wgdotw\.exe bar-autohide-toggle') ('Compiled coordinated auto-hide implementation missing: ' + $relative)
            Require ($text -match 'wgdotw\.exe rawaccel-toggle') ('Scoped RawAccel toggle missing: ' + $relative)
            Require ($text -match 'wgdotw\.exe power-menu') ('Compiled Awtarchy-style power surface missing: ' + $relative)
            Require ($text -match 'bindings:\s*\["lwin\+p",\s*"rwin\+p"\]') ('Super+P compiled power binding missing: ' + $relative)
            Require ($text -match 'wgdotw\.exe launcher hotkey') ('Compiled Awtarchy-style launcher missing: ' + $relative)
            Require ($text -match '%LOCALAPPDATA%\\wgdot\\bin\\wgdotw\.exe.*launcher hotkey') ('Launcher helper path is not deterministic: ' + $relative)
            Require ($text -match 'bindings:\s*\["alt\+p",\s*"lwin\+d",\s*"rwin\+d"\]') ('Global Alt+P/Super+D launcher binding missing: ' + $relative)
            Require ($text -match 'bindings:\s*\["lwin\+shift\+m",\s*"rwin\+shift\+m"\]') ('Super+Shift+M RawAccel binding missing: ' + $relative)
            Require ($text -notmatch 'bindings:\s*\["alt\+shift\+m"') ('RawAccel must not capture Alt+Shift+M: ' + $relative)
            Require ($text -notmatch 'wgdotw?\.exe\s+(?:quick-launch|flow-open|eartrumpet-mixer(?:\s|$)|clipboard-anchor(?:\s|$)|clipboard-history(?:\s|$)|flameshot-gui|display-settings)') ('Native-capable action routed through WGDot: ' + $relative)
        }
    }

    Check 'GlazeWM focus follows cursor differs by profile intentionally' {
        $normal = Get-Content -LiteralPath (Join-Path $repo 'UserProfile\.glzr\glazewm\config.yaml') -Raw -Encoding UTF8
        $work = Get-Content -LiteralPath (Join-Path $repo 'UserProfile\.glzr\glazewm\custom_work_config.yaml') -Raw -Encoding UTF8
        Require ($normal -match 'focus_follows_cursor:\s*true') 'Normal profile must default focus_follows_cursor to true'
        Require ($work -match 'focus_follows_cursor:\s*false') 'Work profile must keep focus_follows_cursor false'
    }

    Check 'YASB owns native widget integrations' {
        foreach ($relative in @(
            'UserProfile/.config/yasb/config.yaml',
            'UserProfile/.config/yasb/custom_work_config.yaml'
        )) {
            $text = Get-Content -LiteralPath (Join-Path $repo ($relative -replace '/', '\')) -Raw -Encoding UTF8
            Require ($text -match 'yasb\.custom\.CustomWidget') ('YASB custom power button missing: ' + $relative)
            Require ($text -match 'wgdotw\.exe\s+eartrumpet-mixer-toggle') ('YASB EarTrumpet mixer toggle bridge missing: ' + $relative)
            Require ($text -notmatch 'shell:AppsFolder.*EarTrumpet') ('YASB must not use direct AppsFolder activation for EarTrumpet mixer toggling: ' + $relative)
            Require ($text -match 'on_left:\s*"exec wgdotw\.exe power-menu"') ('Power icon left click does not open the compiled power surface: ' + $relative)
            Require ($text -match 'on_right:\s*"exec wgdotw\.exe power-menu"') ('Power icon right click does not open the compiled power surface: ' + $relative)
            Require ($text -match 'class_name:\s*"awtarchy-launcher"') ('Compiled launcher bar control missing: ' + $relative)
            Require ($text -match 'on_left:\s*"exec wgdotw\.exe launcher bar"') ('Launcher button does not open the bar-relative compiled surface: ' + $relative)
            Require ($text -match 'wgdotw\.exe theme-window-toggle') ('Quick Settings theme-window toggle missing: ' + $relative)
            Require ($text -match 'wgdotw\.exe glazewm-window-behavior-toggle') ('Quick Settings floating-window toggle missing: ' + $relative)
            Require ($text -match '(?m)^\s+columns:\s*2\s*$') ('Quick Settings must use two evenly filled columns: ' + $relative)
            Require ($text -match '(?m)^\s+label_position:\s*"inline"\s*$') ('Quick Settings labels must render inline with icons: ' + $relative)
            Require ($text -match 'wgdotw\.exe clipboard-history-open') ('Clipboard History bar-only native Win+V helper missing: ' + $relative)
            Require ($text -notmatch 'idle_inhibitor|idle-inhibitor-(?:status|toggle|worker)') ('Retired idle inhibitor returned: ' + $relative)
            $wifiBlock = [regex]::Match($text, '(?ms)^  wifi:\r?\n.*?(?=^  bluetooth:)').Value
            $bluetoothBlock = [regex]::Match($text, '(?ms)^  bluetooth:\r?\n.*?(?=^  systray:)').Value
            Require ($wifiBlock -match 'on_left:\s*"exec explorer\.exe ms-settings:network-status"') ('Native Windows Network surface missing: ' + $relative)
            Require ($bluetoothBlock -match 'on_left:\s*"exec explorer\.exe ms-settings:bluetooth"') ('Native Windows Bluetooth surface missing: ' + $relative)
            Require ($wifiBlock -notmatch 'on_left:\s*"toggle_menu"') ('Rejected Wi-Fi/Ethernet mini menu returned: ' + $relative)
            Require ($bluetoothBlock -notmatch 'on_left:\s*"toggle_menu"') ('Rejected Bluetooth mini menu returned: ' + $relative)
            Require ($text -match 'on_left:\s*"disable_binding_mode"') ('Binding-mode label does not disable the active mode: ' + $relative)
            Require ($text -match 'on_right:\s*"disable_binding_mode"') ('Binding-mode label right click does not disable the active mode: ' + $relative)
            Require ($text -match 'on_middle:\s*"do_nothing"') ('Binding-mode label middle click must do nothing: ' + $relative)
            Require ($text -notmatch 'next_binding_mode') ('Binding-mode label must not cycle modes: ' + $relative)
            Require ($text -notmatch 'wgdotw\.exe mouse-mode-toggle|workspace_mouse') ('Retired mouse-mode YASB runtime returned: ' + $relative)
            Require ($text -match 'glazewm\.binding_mode\.GlazewmBindingModeWidget') ('Native binding-mode widget missing: ' + $relative)
            Require ($text -notmatch 'keys:\s*"f24"') ('Synthetic F24 Quick Launch relay returned: ' + $relative)
            Require ($text -match 'binding_modes_to_cycle_through:\s*\["none",\s*"noalt",\s*"vm"\]') ('YASB binding-mode widget does not expose only noalt/vm: ' + $relative)
            Require ($text -notmatch 'workspace_move_hub|workspace-move-hub|workspace_move_group|workspace-move-grouper') ('Retired workspace hub returned: ' + $relative)
            Require ($text -match 'glazewm\.exe command move-workspace --direction left') ('Workspace mover arrows missing: ' + $relative)
            Require ($text -notmatch 'border_color:\s*None') ('Invalid null popup border_color returned: ' + $relative)
            Require ($text -notmatch 'cmd\.exe /c start ms-settings') ('YASB settings callback spawns cmd.exe: ' + $relative)
            Require ($text -notmatch 'glazewm-pause-status|glazewm-pause-toggle') ('Retired pause helper reference returned: ' + $relative)
        }
    }

    Check 'Flow Launcher stays retired' {
        Require ($nativeSource -notmatch 'ApplyFlowLauncherAltP|RestoreLegacyFlowHotkey') 'Retired Flow hotkey implementation remains'
        Require ($nativeSource -match 'result\.Packages\.RemoveAll\(x => String\.Equals\(x, "Flow-Launcher\.Flow-Launcher"') 'Saved selections do not keep the retired Flow package'
        Require ($nativeSource -match 'result\.Tweaks\.RemoveAll\(x => String\.Equals\(x, "flow-launcher-alt-p"') 'Saved selections retire the old Flow hotkey tweak'
    }

    Check 'launcher bindings use the scoped compiled surface without relay scripts' {
        $normal = Get-Content -LiteralPath (Join-Path $repo 'UserProfile\.glzr\glazewm\config.yaml') -Raw -Encoding UTF8
        $work = Get-Content -LiteralPath (Join-Path $repo 'UserProfile\.glzr\glazewm\custom_work_config.yaml') -Raw -Encoding UTF8
        foreach ($text in @($normal, $work)) {
            Require ($text -notmatch 'flow-launcher\.ps1|yasb-quick-launch\.ps1') 'Launcher relay script returned to GlazeWM'
            Require ($text -match 'wgdotw\.exe launcher hotkey') 'Compiled launcher hotkey surface is missing'
            Require ($text -match 'bindings:\s*\["alt\+p",\s*"lwin\+d",\s*"rwin\+d"\]') 'Alt+P/Super+D compiled launcher binding is missing'
        }
        Require ($work -notmatch 'shell-exec %LOCALAPPDATA%/FlowLauncher/Flow\.Launcher\.exe') 'Work launcher still defaults to Flow Launcher'
        Require ($nativeSource -match 'if \(command == "launcher"\) return LauncherFromArgs') 'Native compiled launcher command is missing'
        Require ($nativeSource -match 'LauncherLocation') 'Launcher placement logic is missing'
        Require ($nativeSource -match 'YasbAutoHideEnabled') 'Launcher auto-hide placement override is missing'
        Require ($nativeSource -match 'ForegroundWindowFillsScreen') 'Launcher fullscreen placement override is missing'
    }

    Check 'EarTrumpet and Clipboard keyboard ownership stays native' {
        Require ($null -eq (Get-NativeMethod 'ApplyEarTrumpetMixerSuperV')) 'Retired EarTrumpet Super+V settings rewrite returned'
        Require ($nativeSource -notmatch 'command == "clipboard-anchor"') 'Retired Clipboard History hotkey handoff returned'
        Require ($nativeSource -match 'command == "clipboard-history-open"') 'Bar-only Clipboard History helper is missing'
        foreach ($relative in @(
            'UserProfile/.glzr/glazewm/config.yaml',
            'UserProfile/.glzr/glazewm/custom_work_config.yaml'
        )) {
            $text = Get-Content -LiteralPath (Join-Path $repo ($relative -replace '/', '\')) -Raw -Encoding UTF8
            Require ($text -notmatch 'EarTrumpet_1sdd7yawvg6ne!EarTrumpet') ('GlazeWM still launches EarTrumpet directly: ' + $relative)
            Require ($text -notmatch 'bindings:\s*\["alt\+v",\s*"lwin\+v",\s*"rwin\+v"\]') ('GlazeWM still captures Alt+V/Super+V: ' + $relative)
            Require ($text -notmatch 'bindings:\s*\["lwin\+c",\s*"rwin\+c"\]') ('Retired Super+C Clipboard binding returned: ' + $relative)
        }
    }

    Check 'legacy YASB startup cleanup recognizes only the old direct executable command' {
        Require ([bool](Invoke-Native 'IsLegacyYasbStartupCommand' @('"C:\Program Files\YASB\yasb.exe"'))) 'Old WGDot command was missed'
        Require (-not [bool](Invoke-Native 'IsLegacyYasbStartupCommand' @('cmd.exe /c yasb.exe'))) 'Custom command was accepted'
        Require (-not [bool](Invoke-Native 'IsLegacyYasbStartupCommand' @('"C:\YASB\yasb.exe" --custom'))) 'User arguments were accepted'
        Require (-not [bool](Invoke-Native 'IsLegacyYasbStartupCommand' @('yasb.exe'))) 'Unidentified relative command was accepted'
    }

    Check 'bootstrap propagates failure of required WinGet setup' {
        $fakeWindows = Join-Path $temp 'windows'
        $compilerDir = Join-Path $fakeWindows 'Microsoft.NET\Framework64\v4.0.30319'
        New-Item -ItemType Directory -Path $compilerDir -Force | Out-Null

        $workerSource = Join-Path $temp 'worker.cs'
        'class Worker { static int Main(string[] args) { return args[0] == "ensure-winget" ? 23 : 0; } }' | Set-Content $workerSource
        $worker = Join-Path $temp 'worker.exe'
        & $csc /nologo /target:exe "/out:$worker" $workerSource
        Require ($LASTEXITCODE -eq 0) 'Worker fixture compilation failed'

        $compilerSource = Join-Path $temp 'compiler.cs'
        @'
using System;
using System.IO;
class Compiler {
    static int Main(string[] args) {
        foreach (string arg in args) if (arg.StartsWith("/out:")) {
            File.Copy(Environment.GetEnvironmentVariable("WGDOT_FIXTURE_WORKER"), arg.Substring(5), true);
            return 0;
        }
        return 64;
    }
}
'@ | Set-Content $compilerSource
        & $csc /nologo /target:exe "/out:$(Join-Path $compilerDir 'csc.exe')" $compilerSource
        Require ($LASTEXITCODE -eq 0) 'Compiler fixture compilation failed'

        Copy-Item (Join-Path $repo 'wgdot\bootstrap.cmd') (Join-Path $temp 'bootstrap.cmd')
        Copy-Item $source (Join-Path $temp 'wgdot-native.cs')
        $env:WGDOT_FIXTURE_WORKER = $worker
        $env:WINDIR = $fakeWindows
        & $env:ComSpec /d /c "`"$(Join-Path $temp 'bootstrap.cmd')`""
        Require ($LASTEXITCODE -eq 23) ('Required setup failed but bootstrap returned ' + $LASTEXITCODE)
        $env:WINDIR = $savedWindir
    }
}
finally {
    $env:PATH = $savedPath
    $env:WGDOT_TEST_ROOT = $savedRoot
    $env:WINDIR = $savedWindir
    Remove-Item Env:WGDOT_FIXTURE_WORKER -ErrorAction SilentlyContinue
    [Environment]::CurrentDirectory = $originalDirectory
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
Write-Host 'Desktop integration contracts passed. Interactive Windows behavior is not covered.'

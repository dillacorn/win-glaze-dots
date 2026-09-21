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

    Check 'retired WGDot desktop helper methods are absent' {
        $retired = @(
            'ShouldSurfaceDesktopHelperFailure',
            'ReportDesktopHelperFailure',
            'EnsureHiddenLauncher',
            'ThemeManagerFromArgs',
            'ThemeManager',
            'ApplyYasbTheme',
            'BuildYasbThemeCss',
            'ApplyWindowsTerminalTheme',
            'IdleInhibitorStatus',
            'IdleInhibitorToggle',
            'IdleInhibitorWorker',
            'OpenFlowLauncher',
            'OpenYasbQuickLaunch',
            'OpenWindowsClipboardHistory',
            'OpenFlameshotGui',
            'OpenRawAccel',
            'OpenDisplaySettings',
            'BarAutoHideToggle',
            'MouseModeToggle',
            'MouseModeSwitchFromArgs',
            'GlazeWmBindingModeToggleFromArgs',
            'GlazeWmBindingModeSetFromArgs',
            'GlazeWmReloadConfig',
            'GlazeWmIsPaused',
            'GlazeWmPauseStatus',
            'GlazeWmPauseToggle',
            'ThemeToggle',
            'PowerMenu',
            'OpenEarTrumpetMixer',
            'RestoreLegacyFlowHotkey',
            'ApplyFlowLauncherAltP'
        )
        foreach ($name in $retired) {
            Require ($null -eq (Get-NativeMethod $name)) ('Retired native desktop helper remains: ' + $name)
        }
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
        'UserProfile/.config/yasb/custom_work_config.yaml',
        'UserProfile/.config/win-glaze/scripts/theme-switcher.ps1',
        'UserProfile/.config/win-glaze/scripts/bar-autohide.ps1',
        'UserProfile/.config/win-glaze/scripts/idle-inhibitor.ps1',
        'UserProfile/.config/win-glaze/scripts/rawaccel-toggle.ps1'
    )

    Check 'managed desktop runtime files are WGDot-independent' {
        foreach ($relative in $desktopRuntimeFiles) {
            $path = Join-Path $repo ($relative -replace '/', '\')
            Require (Test-Path -LiteralPath $path -PathType Leaf) ('Missing managed desktop runtime file: ' + $relative)
            $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
            Require ($text -notmatch '(?i)(?:wgdotw?|%LOCALAPPDATA%\\wgdot\\bin\\wgdot\.exe)') ('WGDot runtime dependency found in: ' + $relative)
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
            Require ($text -match 'wm-disable-binding-mode --name') ('Native mode escape missing: ' + $relative)
            Require ($text -match 'wm-toggle-pause') ('Native pause binding missing: ' + $relative)
            Require ($text -match 'flameshot\.exe gui') ('Direct Flameshot launch missing: ' + $relative)
            Require ($text -match 'theme-switcher\.ps1') ('Standalone theme switcher launch missing: ' + $relative)
            Require ($text -match 'bar-autohide\.ps1') ('Standalone bar auto-hide launch missing: ' + $relative)
        }
    }

    Check 'YASB owns native widget integrations' {
        foreach ($relative in @(
            'UserProfile/.config/yasb/config.yaml',
            'UserProfile/.config/yasb/custom_work_config.yaml'
        )) {
            $text = Get-Content -LiteralPath (Join-Path $repo ($relative -replace '/', '\')) -Raw -Encoding UTF8
            Require ($text -match 'yasb\.power_menu\.PowerMenuWidget') ('Native power menu missing: ' + $relative)
            Require ($text -match 'glazewm\.binding_mode\.GlazewmBindingModeWidget') ('Native binding-mode widget missing: ' + $relative)
            Require ($text -notmatch 'keys:\s*"f24"') ('Synthetic F24 Quick Launch relay returned: ' + $relative)
            Require ($text -notmatch 'glazewm-pause-status|glazewm-pause-toggle') ('Retired pause helper reference returned: ' + $relative)
        }
    }

    Check 'Flow launcher migration no longer owns Alt+P globally' {
        Require ($nativeSource -notmatch 'ApplyFlowLauncherAltP|RestoreLegacyFlowHotkey') 'Retired Flow hotkey implementation remains'
        Require ($nativeSource -match 'result\.Tweaks\.RemoveAll\(x => String\.Equals\(x, "flow-launcher-alt-p"') 'Saved selections no longer retire the old Flow hotkey tweak'
    }

    Check 'launcher bindings avoid relay scripts and synthetic keys' {
        $normal = Get-Content -LiteralPath (Join-Path $repo 'UserProfile\.glzr\glazewm\config.yaml') -Raw -Encoding UTF8
        $work = Get-Content -LiteralPath (Join-Path $repo 'UserProfile\.glzr\glazewm\custom_work_config.yaml') -Raw -Encoding UTF8
        foreach ($text in @($normal, $work)) {
            Require ($text -notmatch 'flow-launcher\.ps1|yasb-quick-launch\.ps1') 'Launcher relay script returned to GlazeWM'
        }
        Require ($work -match 'shell-exec %LOCALAPPDATA%/FlowLauncher/Flow\.Launcher\.exe') 'Work Alt+P no longer launches Flow directly'
        Require ($work -match 'bindings:\s*\["alt\+p"\]') 'Work Alt+P binding is missing'
        Require ($work -notmatch 'bindings:\s*\["lwin\+d",\s*"rwin\+d"\]') 'Work Super+D synthetic YASB relay returned'
    }

    Check 'EarTrumpet direct Super+V configuration remains management-time only' {
        Require ($null -ne (Get-NativeMethod 'ApplyEarTrumpetMixerSuperV')) 'EarTrumpet management integration is missing'
        Require ($nativeSource -match 'eartrumpet-mixer-super-v') 'EarTrumpet direct-hotkey tweak ID is missing'
        Require ($nativeSource -notmatch 'OpenEarTrumpetMixer') 'Retired EarTrumpet synthetic runtime bridge remains'
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

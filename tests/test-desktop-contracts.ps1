$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$repo = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([IO.Path]::GetTempPath()) ('wgdot-desktop-' + [guid]::NewGuid().ToString('N'))
$savedPath = $env:PATH
$savedRoot = $env:WGDOT_TEST_ROOT
$savedResponse = $env:WGDOT_FIXTURE_RESPONSE
$savedWindir = $env:WINDIR
$originalDirectory = [Environment]::CurrentDirectory
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
$failures = New-Object 'System.Collections.Generic.List[string]'
function Check($name, [scriptblock]$test) {
    try { & $test; Write-Host ('PASS: ' + $name) }
    catch { $failures.Add($name + ': ' + $_.Exception.Message); Write-Host ('FAIL: ' + $name + ': ' + $_.Exception.Message) }
}
function Require([bool]$condition, [string]$message) { if (-not $condition) { throw $message } }
function Invoke-Native([string]$name, [object[]]$arguments = @()) {
    $method = $script:native.GetMethod($name, [Reflection.BindingFlags]'Static,NonPublic')
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
function Expect-Failure([scriptblock]$action, [string]$expected) {
    $message = ''
    try { & $action | Out-Null } catch { $message = $_.Exception.Message }
    Require ($message -like ('*' + $expected + '*')) ('Expected failure containing ' + $expected + ', got: ' + $message)
}
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    $env:WGDOT_TEST_ROOT = $temp
    $source = Join-Path $repo 'wgdot\wgdot-native.cs'
    $assembly = Join-Path $temp 'wgdot.exe'
    & $csc /nologo /target:exe "/out:$assembly" /r:System.Web.Extensions.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /r:System.Xml.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll $source
    Require ($LASTEXITCODE -eq 0) 'Native compilation failed'
    $script:native = [Reflection.Assembly]::LoadFile($assembly).GetType('WgdotNative')
    $fakeSource = Join-Path $temp 'glazewm.cs'
    @'
using System;
class FakeGlaze {
    static int Main(string[] args) {
        string command = String.Join(" ", args);
        if (command != "query paused" &&
            command != "query binding-modes" &&
            command != "command wm-toggle-pause" &&
            command != "command wm-disable-binding-mode --name mouse" &&
            command != "command wm-enable-binding-mode --name mouse") return 64;
        Console.WriteLine(Environment.GetEnvironmentVariable("WGDOT_FIXTURE_RESPONSE"));
        return 0;
    }
}
'@ | Set-Content -LiteralPath $fakeSource -Encoding UTF8
    & $csc /nologo /target:exe "/out:$(Join-Path $temp 'glazewm.exe')" $fakeSource
    Require ($LASTEXITCODE -eq 0) 'IPC fixture compilation failed'
    $env:PATH = $temp + ';' + $savedPath
    [Environment]::CurrentDirectory = $temp
    Check 'hidden launcher and clipboard helpers surface failures' {
        Require ([bool](Invoke-Native 'ShouldSurfaceDesktopHelperFailure' @('quick-launch'))) 'Quick Launch failure stayed hidden'
        Require ([bool](Invoke-Native 'ShouldSurfaceDesktopHelperFailure' @('clipboard-history'))) 'Clipboard failure stayed hidden'
        Require ([bool](Invoke-Native 'ShouldSurfaceDesktopHelperFailure' @('mouse-mode-toggle'))) 'Mouse-mode toggle failure stayed hidden'
        Require ([bool](Invoke-Native 'ShouldSurfaceDesktopHelperFailure' @('mouse-mode-disable'))) 'Mouse-mode escape failure stayed hidden'
        Require (-not [bool](Invoke-Native 'ShouldSurfaceDesktopHelperFailure' @('status'))) 'Normal status command should not show desktop error UI'
    }
    Check 'GlazeWM rejected command is not treated as success even with exit zero' {
        $env:WGDOT_FIXTURE_RESPONSE = '{"clientMessage":"command wm-toggle-pause","data":null,"error":"fixture denied","success":false}'
        Expect-Failure { Invoke-Native 'GlazeWmPauseToggle' } 'fixture denied'
    }
    Check 'unknown pause state is not silently treated as running' {
        $env:WGDOT_FIXTURE_RESPONSE = '{"clientMessage":"query paused","data":null,"error":"fixture disconnected","success":false}'
        Expect-Failure { Invoke-Native 'GlazeWmIsPaused' } 'fixture disconnected'
    }
    Check 'malformed pause data fails closed' {
        $env:WGDOT_FIXTURE_RESPONSE = '{"clientMessage":"query paused","data":{},"error":null,"success":true}'
        Expect-Failure { Invoke-Native 'GlazeWmIsPaused' } 'pause'
    }
    Check 'real GlazeWM bool pause payload is understood in both states' {
        $env:WGDOT_FIXTURE_RESPONSE = '{"clientMessage":"query paused","data":true,"error":null,"success":true}'
        Require ([bool](Invoke-Native 'GlazeWmIsPaused')) 'Paused was lost'
        $env:WGDOT_FIXTURE_RESPONSE = '{"clientMessage":"query paused","data":false,"error":null,"success":true}'
        Require (-not [bool](Invoke-Native 'GlazeWmIsPaused')) 'Running was lost'
    }
    Check 'binding-mode query reads the real GlazeWM response shape' {
        $env:WGDOT_FIXTURE_RESPONSE = '{"clientMessage":"query binding-modes","data":{"bindingModes":[{"name":"mouse","keybindings":[]}]},"error":null,"success":true}'
        Require ([bool](Invoke-Native 'GlazeWmBindingModeActive' @('mouse'))) 'Active mouse mode was missed'
        Require (-not [bool](Invoke-Native 'GlazeWmBindingModeActive' @('vm'))) 'Inactive VM mode was reported active'
    }
    Check 'binding-mode IPC rejection fails closed' {
        $env:WGDOT_FIXTURE_RESPONSE = '{"clientMessage":"query binding-modes","data":null,"error":"fixture mode query denied","success":false}'
        Expect-Failure { Invoke-Native 'GlazeWmBindingModeActive' @('mouse') } 'fixture mode query denied'
        $env:WGDOT_FIXTURE_RESPONSE = '{"clientMessage":"command wm-disable-binding-mode --name mouse","data":null,"error":"fixture mode disable denied","success":false}'
        Expect-Failure { Invoke-Native 'MouseModeDisable' } 'fixture mode disable denied'
    }
    Check 'Flow migration restores only WGDot-owned Alt+P and preserves unrelated settings' {
        $settings = New-Object 'System.Collections.Generic.Dictionary[string,object]'
        $settings['Hotkey'] = 'Alt + P'; $settings['Theme'] = 'keep-me'
        $original = New-Object 'System.Collections.Generic.Dictionary[string,object]'
        $original['exists'] = $true; $original['value'] = 'Ctrl + Space'
        Require ([bool](Invoke-Native 'RestoreLegacyFlowHotkey' @($settings, $original))) 'Owned shortcut was not retired'
        Require ($settings['Hotkey'] -eq 'Ctrl + Space' -and $settings['Theme'] -eq 'keep-me') 'Settings were not preserved'
        $settings['Hotkey'] = 'Ctrl + K'
        Require (-not [bool](Invoke-Native 'RestoreLegacyFlowHotkey' @($settings, $original))) 'User-edited shortcut changed'
        $settings['Hotkey'] = 'Alt + P'
        Require (-not [bool](Invoke-Native 'RestoreLegacyFlowHotkey' @($settings, $null))) 'Unowned shortcut changed'
        $original['value'] = 'Alt + P'
        Require (-not [bool](Invoke-Native 'RestoreLegacyFlowHotkey' @($settings, $original))) 'Conflicting original was accepted'
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
} finally {
    $env:PATH = $savedPath
    $env:WGDOT_TEST_ROOT = $savedRoot
    $env:WGDOT_FIXTURE_RESPONSE = $savedResponse
    $env:WINDIR = $savedWindir
    Remove-Item Env:WGDOT_FIXTURE_WORKER -ErrorAction SilentlyContinue
    [Environment]::CurrentDirectory = $originalDirectory
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
Write-Host 'Desktop integration contracts passed. Interactive Windows behavior is not covered.'

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
    try { return $method.Invoke($null, $arguments) }
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
        if (command != "query paused" && command != "command wm-toggle-pause") return 64;
        Console.WriteLine(Environment.GetEnvironmentVariable("WGDOT_FIXTURE_RESPONSE"));
        return 0;
    }
}
'@ | Set-Content -LiteralPath $fakeSource -Encoding UTF8
    & $csc /nologo /target:exe "/out:$(Join-Path $temp 'glazewm.exe')" $fakeSource
    Require ($LASTEXITCODE -eq 0) 'IPC fixture compilation failed'
    $env:PATH = $temp + ';' + $savedPath
    [Environment]::CurrentDirectory = $temp
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

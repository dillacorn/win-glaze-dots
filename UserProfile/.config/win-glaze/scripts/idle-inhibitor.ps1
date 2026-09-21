param(
    [ValidateSet('toggle','status','worker','stop')]
    [string]$Mode = 'toggle'
)

$ErrorActionPreference = 'Stop'
$mutexName = 'Local\WinGlazeIdleInhibitor'
$stopName = 'Local\WinGlazeIdleInhibitorStop'

function Test-IdleInhibitor {
    try {
        $m = [Threading.Mutex]::OpenExisting($mutexName)
        $m.Dispose()
        return $true
    } catch {
        return $false
    }
}

if ($Mode -eq 'status') {
    $active = Test-IdleInhibitor
    if ($active) {
        Write-Output '{"icon":"\uf06e","active":true,"tooltip":"Keep Awake: activated - click to deactivate"}'
    } else {
        Write-Output '{"icon":"\uf070","active":false,"tooltip":"Idle inhibitor: deactivated - click to activate Keep Awake"}'
    }
    return
}

if ($Mode -eq 'stop' -or ($Mode -eq 'toggle' -and (Test-IdleInhibitor))) {
    try {
        $stop = [Threading.EventWaitHandle]::OpenExisting($stopName)
        $stop.Set() | Out-Null
        $stop.Dispose()
    } catch {}
    return
}

if ($Mode -eq 'toggle') {
    Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList @(
        '-NoLogo',
        '-NoProfile',
        '-WindowStyle', 'Hidden',
        '-File', ('"' + $PSCommandPath + '"'),
        'worker'
    ) | Out-Null
    return
}

if ($Mode -eq 'worker') {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WinGlazePower {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
}
'@

    $created = $false
    $mutex = New-Object Threading.Mutex($true, $mutexName, [ref]$created)
    if (-not $created) {
        $mutex.Dispose()
        return
    }

    $stopEvent = New-Object Threading.EventWaitHandle(
        $false,
        [Threading.EventResetMode]::ManualReset,
        $stopName
    )

    try {
        $ES_CONTINUOUS = [uint32]0x80000000
        $ES_SYSTEM_REQUIRED = [uint32]0x00000001
        $ES_DISPLAY_REQUIRED = [uint32]0x00000002
        $result = [WinGlazePower]::SetThreadExecutionState(
            $ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED -bor $ES_DISPLAY_REQUIRED
        )
        if ($result -eq 0) { throw 'Windows rejected the idle-inhibitor request.' }
        $stopEvent.WaitOne() | Out-Null
    }
    finally {
        [WinGlazePower]::SetThreadExecutionState([uint32]0x80000000) | Out-Null
        $stopEvent.Dispose()
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
}

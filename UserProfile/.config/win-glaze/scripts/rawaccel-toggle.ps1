$ErrorActionPreference = 'Stop'

$running = Get-Process -Name rawaccel -ErrorAction SilentlyContinue
if ($running) {
    $running | Stop-Process
    return
}

$candidates = @(
    (Get-Command 'rawaccel.exe' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    (Join-Path $env:LOCALAPPDATA 'RawAccel\rawaccel.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\RawAccel\rawaccel.exe'),
    (Join-Path $env:ProgramFiles 'RawAccel\rawaccel.exe')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

$exe = $candidates | Select-Object -First 1
if (-not $exe) { throw 'RawAccel GUI executable was not found.' }

Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe)

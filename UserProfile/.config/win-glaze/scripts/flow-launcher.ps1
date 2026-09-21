$ErrorActionPreference = 'Stop'

$programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
$candidates = @(
    (Get-Command 'Flow.Launcher.exe' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    (Join-Path $env:LOCALAPPDATA 'FlowLauncher\Flow.Launcher.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\FlowLauncher\Flow.Launcher.exe'),
    (Join-Path $env:ProgramFiles 'FlowLauncher\Flow.Launcher.exe'),
    $(if ($programFilesX86) { Join-Path $programFilesX86 'FlowLauncher\Flow.Launcher.exe' })
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

$exe = $candidates | Select-Object -First 1
if (-not $exe) { throw 'Flow Launcher executable was not found.' }

Start-Process -FilePath $exe

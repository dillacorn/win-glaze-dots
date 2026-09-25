$ErrorActionPreference = "Stop"

$bootstrap = Join-Path $env:TEMP "wgdot-bootstrap.cmd"

Invoke-WebRequest -UseBasicParsing `
    "https://raw.githubusercontent.com/dillacorn/win-glaze-dots/main/wgdot/bootstrap.cmd" `
    -OutFile $bootstrap

& $bootstrap

if ($LASTEXITCODE -ne 0) {
    throw "WGDot bootstrap failed with exit code $LASTEXITCODE."
}

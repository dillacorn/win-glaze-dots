$ErrorActionPreference = "Stop"

$root = Join-Path $env:LOCALAPPDATA "wgdot"
$bootstrap = Join-Path $root "bootstrap.cmd"
New-Item -ItemType Directory -Path $root -Force | Out-Null

try {
    Invoke-WebRequest -UseBasicParsing `
        "https://raw.githubusercontent.com/dillacorn/win-glaze-dots/main/wgdot/bootstrap.cmd" `
        -OutFile $bootstrap

    & $bootstrap
    $code = $LASTEXITCODE

    if ($code -ne 0) {
        throw "WGDot bootstrap failed with exit code $code."
    }
}
finally {
    Remove-Item -LiteralPath $bootstrap -Force -ErrorAction SilentlyContinue
}

$ErrorActionPreference = "Stop"

Write-Host "==> Rust version"
rustc -Vv
cargo -V

Write-Host "==> Python version"
python --version

Write-Host "==> Flutter version"
flutter --version

Write-Host "==> Enable Windows desktop"
flutter config --enable-windows-desktop

Write-Host "==> Build RustDesk Windows (Flutter)"
python .\build.py --portable --hwcodec --flutter --vram
if ($LASTEXITCODE -ne 0) {
    throw "RustDesk build failed with exit code $LASTEXITCODE."
}

$serverHost = ([string]$env:RUSTDESK_HOST).Trim()
if (-not [string]::IsNullOrWhiteSpace($serverHost)) {
    $clientPath = Join-Path $PWD 'flutter\build\windows\x64\runner\Release\rustdesk.exe'
    if (-not (Test-Path $clientPath -PathType Leaf)) {
        throw "Built RustDesk client was not found: $clientPath"
    }

    $clientBytes = [IO.File]::ReadAllBytes($clientPath)
    $hostBytes = [Text.Encoding]::UTF8.GetBytes($serverHost)
    $hostFound = $false
    for ($offset = 0; $offset -le $clientBytes.Length - $hostBytes.Length; $offset++) {
        $matches = $true
        for ($index = 0; $index -lt $hostBytes.Length; $index++) {
            if ($clientBytes[$offset + $index] -ne $hostBytes[$index]) {
                $matches = $false
                break
            }
        }
        if ($matches) {
            $hostFound = $true
            break
        }
    }

    if (-not $hostFound) {
        throw "The built RustDesk client does not contain the configured self-hosted server. Refusing to package it."
    }

    Write-Host "Verified that the built RustDesk client contains the configured self-hosted server."
}

Write-Host "==> Build completed"

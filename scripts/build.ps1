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
    $clientLibraryPath = Join-Path $PWD 'flutter\build\windows\x64\runner\Release\librustdesk.dll'
    if (-not (Test-Path $clientLibraryPath -PathType Leaf)) {
        throw "Built RustDesk library was not found: $clientLibraryPath"
    }

    $clientBytes = [IO.File]::ReadAllBytes($clientLibraryPath)
    $hostBytes = [Text.Encoding]::UTF8.GetBytes($serverHost)
    $hostFound = $false
    $offset = 0
    while ($offset -le $clientBytes.Length - $hostBytes.Length) {
        $offset = [Array]::IndexOf($clientBytes, $hostBytes[0], $offset)
        if ($offset -lt 0 -or $offset -gt $clientBytes.Length - $hostBytes.Length) {
            break
        }

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
        $offset++
    }

    if (-not $hostFound) {
        throw "The built RustDesk library does not contain the configured self-hosted server. Refusing to package it."
    }

    Write-Host "Verified that the packaged RustDesk library contains the configured self-hosted server."
}

Write-Host "==> Build completed"

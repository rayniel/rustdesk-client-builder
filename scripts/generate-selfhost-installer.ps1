$ErrorActionPreference = "Stop"

$installer = Get-ChildItem -Path rustdesk -Filter "rustdesk-*-install.exe" -File | Select-Object -First 1
if (-not $installer) {
    throw "RustDesk installer was not found."
}
if ([string]::IsNullOrWhiteSpace($env:RUSTDESK_CONFIG)) {
    throw "RUSTDESK_CONFIG is empty."
}

$makeNsis = Get-Command makensis.exe -ErrorAction SilentlyContinue
if (-not $makeNsis) {
    throw "NSIS compiler (makensis.exe) was not found."
}

$setupName = $installer.Name -replace '-install\.exe$', '-selfhosted-setup.exe'
New-Item -ItemType Directory -Force -Path dist | Out-Null

$nsi = @'
Unicode true
Name "RustDesk Self-Hosted Setup"
OutFile "dist\__SETUP_NAME__"
RequestExecutionLevel admin

Section
  SetOutPath "$TEMP\RustDeskSelfHostedSetup"
  File "/oname=rustdesk-installer.exe" "rustdesk\__INSTALLER_NAME__"
  ExecWait '"$TEMP\RustDeskSelfHostedSetup\rustdesk-installer.exe" --silent-install' $0
  StrCmp $0 0 import_config install_failed

  import_config:
  IfFileExists "$PROGRAMFILES\RustDesk\rustdesk.exe" 0 client_missing
  ExecWait '"$PROGRAMFILES\RustDesk\rustdesk.exe" --config "__RUSTDESK_CONFIG__"' $0
  StrCmp $0 0 cleanup config_failed

  cleanup:
  Delete "$TEMP\RustDeskSelfHostedSetup\rustdesk-installer.exe"
  RMDir "$TEMP\RustDeskSelfHostedSetup"
  Goto done

  install_failed:
  MessageBox MB_ICONSTOP|MB_OK "RustDesk installation failed (exit code: $0)."
  Abort

  client_missing:
  MessageBox MB_ICONSTOP|MB_OK "RustDesk was installed, but rustdesk.exe was not found."
  Abort

  config_failed:
  MessageBox MB_ICONSTOP|MB_OK "RustDesk was installed, but the self-hosted configuration could not be imported (exit code: $0)."
  Abort

  done:
SectionEnd
'@

$nsiPath = "selfhosted-setup.nsi"
Set-Content -Path $nsiPath -Value ($nsi.Replace('__SETUP_NAME__', $setupName).Replace('__INSTALLER_NAME__', $installer.Name).Replace('__RUSTDESK_CONFIG__', $env:RUSTDESK_CONFIG)) -Encoding ASCII

try {
    & $makeNsis.Source /V2 $nsiPath
    if ($LASTEXITCODE -ne 0) {
        throw "NSIS compilation failed with exit code $LASTEXITCODE."
    }
} finally {
    Remove-Item -Path $nsiPath -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path "dist\$setupName" -PathType Leaf)) {
    throw "Self-hosted installer was not created: dist\$setupName"
}

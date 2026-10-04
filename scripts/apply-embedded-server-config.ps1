$ErrorActionPreference = "Stop"

function Escape-RustString {
    param([string]$Value)

    return $Value.Replace('\', '\\').Replace('"', '\"')
}

$serverHost = ([string]$env:RUSTDESK_HOST).Trim()
$publicKey = ([string]$env:RUSTDESK_KEY).Trim()

if ([string]::IsNullOrWhiteSpace($serverHost) -and [string]::IsNullOrWhiteSpace($publicKey)) {
    Write-Host "No self-hosted secrets supplied; retaining RustDesk upstream defaults."
    exit 0
}

if ([string]::IsNullOrWhiteSpace($serverHost) -or [string]::IsNullOrWhiteSpace($publicKey)) {
    throw "Embedded self-hosted builds require both RUSTDESK_HOST and RUSTDESK_KEY."
}

$configPath = Join-Path $PWD 'rustdesk\libs\hbb_common\src\config.rs'
if (-not (Test-Path $configPath -PathType Leaf)) {
    throw "RustDesk shared configuration source was not found: $configPath"
}

$source = Get-Content -Path $configPath -Raw
$serverReplacement = 'pub const RENDEZVOUS_SERVERS: &[&str] = &["' + (Escape-RustString $serverHost) + '"];'
$keyReplacement = 'pub const RS_PUB_KEY: &str = "' + (Escape-RustString $publicKey) + '";'
$exeServerReplacement = 'pub static ref EXE_RENDEZVOUS_SERVER: RwLock<String> = RwLock::new("' + (Escape-RustString $serverHost) + '".to_owned());'

$updated = [regex]::Replace(
    $source,
    'pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[[^\r\n]*\];',
    $serverReplacement,
    1
)
if ($updated -eq $source) {
    throw "Unable to locate the RustDesk RENDEZVOUS_SERVERS constant. The upstream source layout changed."
}

$updatedWithKey = [regex]::Replace(
    $updated,
    'pub const RS_PUB_KEY: &str = "[^"\r\n]*";',
    $keyReplacement,
    1
)
if ($updatedWithKey -eq $updated) {
    throw "Unable to locate the RustDesk RS_PUB_KEY constant. The upstream source layout changed."
}

$updatedWithExeServer = [regex]::Replace(
    $updatedWithKey,
    'pub static ref EXE_RENDEZVOUS_SERVER: RwLock<String> = Default::default\(\);',
    $exeServerReplacement,
    1
)
if ($updatedWithExeServer -eq $updatedWithKey) {
    throw "Unable to locate the RustDesk EXE_RENDEZVOUS_SERVER default. The upstream source layout changed."
}

Set-Content -Path $configPath -Value $updatedWithExeServer -Encoding UTF8 -NoNewline

if ((Select-String -Path $configPath -SimpleMatch $serverReplacement).Count -ne 1 -or
    (Select-String -Path $configPath -SimpleMatch $keyReplacement).Count -ne 1 -or
    (Select-String -Path $configPath -SimpleMatch $exeServerReplacement).Count -ne 1) {
    throw "Embedded self-hosted configuration verification failed."
}

Write-Host "Embedded a self-hosted server and public key into RustDesk source."

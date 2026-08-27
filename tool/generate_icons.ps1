# Genera tutte le icone (Android / iOS / Windows / Web) da assets/icon/LaCantina.png
#
#   powershell -ExecutionPolicy Bypass -File tool/generate_icons.ps1
#
# L'immagine sorgente ha gia' un ampio margine interno attorno al camion e uno
# sfondo azzurro sfumato: le icone "maskable" (web) e adattive (Android) usano
# quindi l'immagine a tutto campo (ratio 1.0), cosi' sotto qualsiasi maschera
# (cerchio / squircle) si vede solo l'azzurro ai bordi, mai del bianco.
#
# flutter_launcher_icons da solo avvolge il foreground Android in un <inset 16%>
# (che lascerebbe intravedere lo sfondo): lo script rimuove quell'inset dopo.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root     = Split-Path $PSScriptRoot -Parent
$src      = Join-Path $root "assets\icon\LaCantina.png"
$iconDir  = Join-Path $root "assets\icon"
$webIcons = Join-Path $root "web\icons"
$bgHex    = "#63C0FD"   # colore d'angolo dello sfondo sfumato (fallback)

$bg = [System.Drawing.ColorTranslator]::FromHtml($bgHex)

function New-Icon {
    param([string]$OutPath, [int]$Canvas, [double]$ContentRatio, [System.Drawing.Color]$Background)
    $orig = [System.Drawing.Image]::FromFile($src)
    $bmp  = New-Object System.Drawing.Bitmap($Canvas, $Canvas, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g    = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode  = 'HighQualityBicubic'
    $g.SmoothingMode      = 'HighQuality'
    $g.PixelOffsetMode    = 'HighQuality'
    $g.CompositingQuality = 'HighQuality'
    $g.Clear($Background)
    $target = [int][math]::Round($Canvas * $ContentRatio)
    $offset = [int][math]::Round(($Canvas - $target) / 2)
    $g.DrawImage($orig, (New-Object System.Drawing.Rectangle($offset, $offset, $target, $target)))
    $g.Dispose()
    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose(); $orig.Dispose()
    Write-Host "  $OutPath"
}

Write-Host "1/3  foreground adattivo Android (bordo azzurro pieno = nessuna cucitura)"
# Il camion occupa ~0.76 di larghezza (mezza-estensione ~0.38 dal centro).
# La maschera a cerchio di Android garantisce visibile solo il cerchio da 66/108
# = raggio ~0.305. 0.72 => 0.38*0.72 = 0.27 < 0.305: il camion sta tutto dentro
# qualsiasi maschera. Il bordo e' riempito con lo stesso azzurro dello sfondo
# adattivo -> nessuna cucitura, nessun bianco.
New-Icon (Join-Path $iconDir "LaCantina-adaptive-fg.png") 1024 0.72 $bg

Write-Host "2/3  flutter_launcher_icons"
Push-Location $root
dart run flutter_launcher_icons
Pop-Location

Write-Host "3/3  maskable web + favicon 64px + rimozione inset Android"
# 0.80: 0.38*0.80 = 0.30, ben dentro la safe-zone maskable dell'80% (raggio 0.40).
New-Icon (Join-Path $webIcons "Icon-maskable-192.png") 192 0.80 $bg
New-Icon (Join-Path $webIcons "Icon-maskable-512.png") 512 0.80 $bg
New-Icon (Join-Path $root "web\favicon.png")            64  1.0 ([System.Drawing.Color]::Transparent)

$xml = Join-Path $root "android\app\src\main\res\mipmap-anydpi-v26\ic_launcher.xml"
$xmlBody = @'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
'@
[System.IO.File]::WriteAllText($xml, $xmlBody, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  patched $xml (inset rimosso)"

Write-Host "Fatto. Ricorda: flutter build web"

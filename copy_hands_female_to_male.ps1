# Script para copiar archivos de 'female*hands*' a su versión 'male'
$targetDir = "C:\Users\Asus\ProyectoJuegoDating\frontend\assets\images\OCTOPLAYER\Avatar\body"

if (-not (Test-Path $targetDir)) {
    Write-Error "El directorio no existe: $targetDir"
    exit 1
}

$files = Get-ChildItem -Path $targetDir -Filter "*female*hand*.png"

if ($files.Count -eq 0) {
    Write-Host "No se encontraron archivos female de manos en $targetDir"
    exit 0
}

Write-Host "Encontrados $($files.Count) archivos. Copiando a versión male..."

foreach ($file in $files) {
    $maleName = $file.Name -replace '^female', 'male'
    $destination = Join-Path $targetDir $maleName
    Copy-Item -Path $file.FullName -Destination $destination -Force
    Write-Host "Copiado: $($file.Name) -> $maleName"
}

Write-Host "¡Proceso completado con éxito! Se copiaron $($files.Count) archivos."

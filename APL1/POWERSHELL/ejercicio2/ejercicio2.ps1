#!/usr/bin/pwsh

<#
.SYNOPSIS
    Script de normalización de texto.
.DESCRIPTION
    Este script corrige mayúsculas, signos de puntuación, espacios y comillas en un archivo de texto.
.PARAMETER archivo
    Ruta del archivo .txt de entrada que se desea procesar.
.PARAMETER salida
    Ruta del archivo donde se guardará el resultado (Opcional).
.EXAMPLE
    ./ejercicio2.ps1 -archivo "notas.txt" -salida "limpio.txt"
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$archivo,

    [Parameter(Mandatory=$false)]
    [string]$salida,

    [Parameter(Mandatory=$false)]
    [switch]$help
)

if ($help -or $PSBoundParameters.Count -eq 0) {
    Write-Host @"

MODO DE USO:
  ./ejercicio2.ps1 -archivo <ruta> [-salida <ruta>] [-help]

PARÁMETROS:
  -archivo    Ruta del archivo de texto a procesar (Obligatorio).
  -salida     Ruta del archivo donde se guardará el resultado (Opcional).
              Si no se informa, el resultado se muestra por pantalla.
  -help       Muestra este mensaje de ayuda.

EJEMPLOS:
  ./ejercicio2.ps1 -archivo "test.txt"
  ./ejercicio2.ps1 -archivo "entrada.txt" -salida "resultado.txt"

"@ -ForegroundColor Yellow
    exit
}

if (-not $archivo) {
    Write-Host "Error: El parámetro -archivo es obligatorio." -ForegroundColor Red
    Write-Host "Use -help para ver el modo de uso."
    exit 1
}

if (-not (Test-Path $archivo)) {
    Write-Host "Error: El archivo '$archivo' no existe." -ForegroundColor Red
    exit 1
}

$texto = Get-Content -Path $archivo -Raw
Write-Host "Texto original:"
Write-Host "$texto"

#4.2 Eliminar Espacios al principoio y final de una linea
$texto = $texto -replace '\n[ \t]+', "`n"
$texto = $texto -replace '[ \t]+\n', "`n"

#1.1 Cada parrafo termine con un . ! ?
$texto = $texto -replace '([^.!?\s])\n', ('$1.' + "`n")

#3 Signos de Exclamacion e interrogacion
$texto = [regex]::Replace($texto, '([^.,;:¡¿?!\n]+)([!?])', {
	param($t)
	$frase = $t.Value.Trim()
	if($frase.EndsWith('?') -and -not $frase.StartsWith('¿')) {
		return "¿" + $frase
	}
	if($frase.EndsWith('!') -and -not $frase.StartsWith('¡')) {
		return "¡" + $frase
	}
	return $frase
})

#1.2 Eliminar espacios innecesarios antes de los signos de puntuacion
#1.3 Unico espacio luego de signo de puntuacion
$texto = $texto -replace '[ \t]*([.,;:!?]+)[ \t]*', '$1 '

#2.2 Convertir el pronombre "yo" a mayuscula
$texto = $texto -replace '\byo\b', 'Yo'

#4.1 Eliminar Espacios consecutivos
$texto = $texto -replace '([ \t])+', '$1'

#5.1 Unificar Comillas
$texto = $texto -replace "'", '"'

#5.2 Puntos suspensivos 
$texto = $texto -replace '[ \t]*\.\.\.+', '... '

#Eliminar Otros Caracteres consecutivos
$texto = $texto -replace '([,;:?!¿¡])+', '$1'

#2.1 Convertir a mayuscula
$texto = [regex]::Replace($texto, '(^|\n|[.!?])([\s¿¡"]*)([a-z])', {
    param($t)
    $t.Groups[1].Value + $t.Groups[2].Value + $t.Groups[3].Value.ToUpper()
})
$texto = [regex]::Replace($texto, '(^|[¿¡])\s*([a-z])', {
	param($t)
	$t.Groups[1].Value + $t.Groups[2].Value.ToUpper() 
})
#$texto = [regex]::Replace($texto, '([?!.]\s+)([a-z])', {
#	param($t)
#	$t.Groups[1].Value + $t.Groups[2].Value.ToUpper() 
#})

$texto = $texto.Trim()

if ($PSBoundParameters.ContainsKey('salida')) {
    $texto | Out-File -FilePath $salida -Encoding utf8
    Write-Host "Proceso finalizado. Resultado guardado en: $salida" -ForegroundColor Green
} else {
    Write-Host "`n--- RESULTADO DEL PROCESAMIENTO ---`n" -ForegroundColor Cyan
    Write-Host $texto
}
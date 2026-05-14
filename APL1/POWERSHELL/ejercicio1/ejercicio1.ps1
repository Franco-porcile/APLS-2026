<#
.SYNOPSIS
    Manejo de archivos CSV, manejo de parámetros y salida por pantalla

.DESCRIPTION
    lee registros de un archivo CSV y realiza operaciones simples de filtros, suma
    y cuentas sobre los campos del mismo.

.PARAMETER Archivo
    Ruta del archivo CSV (relativa o absoluta).

.PARAMETER Filtro
    Nombre del campo por el cual filtrar.

.PARAMETER Buscar
    Patrón de texto a buscar en el campo de filtro.

.PARAMETER Contar
    Contar la cantidad de registros.
    Es un switch, por lo que su ausencia indica que no se desea contar.
    Presente como parámetro al ejecutar → $true
    No presente → $false

.PARAMETER Sumar
    Nombre del campo numérico a sumar.

.EXAMPLE
    ./ejercicio1.ps1 -Archivo censo.csv -Sumar Poblacion

.NOTES
# Integrantes :
# - Nombre Apellido: Porcile Franco
# - Nombre Apellido: Graneros Brian Ariel
# - Nombre Apellido: Avella Mateo
# - Nombre Apellido: Zapata Santiago

#>

param(
    [Parameter(Mandatory=$true, HelpMessage="Ruta del archivo CSV")]
    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "El archivo '$_' no existe."
        }
        return $true
    })]
    [string]$Archivo,

    [Parameter(HelpMessage="Nombre del campo para filtrar")]
    [string]$Filtro,

    [Parameter(HelpMessage="Patrón de texto a buscar en el filtro")]
    [string]$Buscar,

    [Parameter(HelpMessage="Contar registros")]
    [switch]$Contar,

    [Parameter(HelpMessage="Nombre del campo numérico a sumar")]
    [string]$Sumar
)

function Mostrar-Encabezado {
    param($archivo, $filtro, $buscar, $operacion, $campo)
    Write-Host "Archivo: $archivo"
    if ($filtro) {
        Write-Host "Campo filtrado: $filtro | Campo buscado: '$buscar'"
    }
    Write-Host "Operacion: $operacion"
    if ($campo) { Write-Host "Campo: $campo" }
}

function Filtrar-Datos {
    param($Datos, $Filtro, $Buscar)
    if ($Filtro -and $Buscar) {
        return @($Datos | Where-Object { $_.$Filtro -match $Buscar })
    }
    return $Datos
}

function Validar-Parametros {
    param($Contar, $Sumar, $Filtro, $Buscar)
    if ($Contar -and $Sumar) {
        Write-Host "No se puede usar -Contar y -Sumar al mismo tiempo." -ForegroundColor Red
        exit 1
    }
    if (-not $Contar -and -not $Sumar) {
        Write-Host "Debe indicar una operacion: -Contar o -Sumar <campo>." -ForegroundColor Red
        exit 1
    }
    if ($Filtro -and -not $Buscar) {
        Write-Host "Si usa -Filtro debe indicar tambien -Buscar." -ForegroundColor Red
        exit 1
    }
    if ($Buscar -and -not $Filtro) {
        Write-Host "No puede usar -Buscar sin usar -Filtro." -ForegroundColor Red
        exit 1
    }
}

function Validar-Campos {
    param($Filtro, $Sumar, $Encabezados)
    if ($Filtro -and $Filtro -notin $Encabezados) {
        Write-Host "El campo de filtro '$Filtro' no existe en el archivo." -ForegroundColor Red
        exit 1
    }
    if ($Sumar -and $Sumar -notin $Encabezados) {
        Write-Host "El campo de suma '$Sumar' no existe en el archivo." -ForegroundColor Red
        exit 1
    }
}


function Contar-Registros {
    param($Datos)
    return @($Datos).Count
}

function Sumar-Campo {
    param($Datos, $Campo)
    return ($Datos | Measure-Object -Property $Campo -Sum).Sum
}

function Main {
    Validar-Parametros -Contar:$Contar -Sumar:$Sumar -Filtro $Filtro -Buscar $Buscar

    try {
        $datos = Import-Csv -Path $Archivo -ErrorAction Stop
        $encabezados = $datos[0].PSObject.Properties.Name

        Validar-Campos -Filtro $Filtro -Sumar $Sumar -Encabezados $encabezados

        $datos = Filtrar-Datos -Datos $datos -Filtro $Filtro -Buscar $Buscar

        if ($Contar) {
            $resultado = Contar-Registros -Datos $datos
            Mostrar-Encabezado $Archivo $Filtro $Buscar "Contar" ""
            Write-Host "Resultado: $resultado registros"
        }
        else {
            $resultado = Sumar-Campo -Datos $datos -Campo $Sumar
            Mostrar-Encabezado $Archivo $Filtro $Buscar "Sumar" $Sumar
            Write-Host "Resultado: $resultado"
        }
    }
    catch {
        Write-Host "No se pudo procesar el archivo: $_" -ForegroundColor Red
        exit 1
    }
}



Main
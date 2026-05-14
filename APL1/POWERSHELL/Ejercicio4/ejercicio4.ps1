#!/usr/bin/env pwsh

# Integrantes :
# - Nombre Apellido: Porcile Franco
# - Nombre Apellido: Graneros Brian Ariel
# - Nombre Apellido: Avella Mateo
# - Nombre Apellido: Zapata Santiago

<#
.SYNOPSIS
    Monitorea un directorio en segundo plano y registra archivos que contengan palabras clave.

.DESCRIPTION
    Este script se ejecuta como demonio en segundo plano utilizando FileSystemWatcher.
    Monitorea un directorio y sus subdirectorios, y registra en un archivo de log cada vez
    que detecta un archivo que contiene alguna de las palabras clave indicadas.

    La búsqueda de palabras clave no distingue entre mayúsculas y minúsculas.

    Al iniciar, procesa primero los archivos ya existentes en el directorio y en sus
    subdirectorios. Luego queda esperando nuevos archivos o modificaciones.

    No se permite ejecutar más de un demonio sobre el mismo directorio.
    Para finalizar un demonio iniciado previamente, se debe ejecutar el script nuevamente
    con el parámetro -kill y el mismo directorio.

.PARAMETER directorio
    Ruta del directorio a monitorear.
    Puede ser una ruta relativa, absoluta o contener espacios.

.PARAMETER palabras
    Lista de palabras clave a buscar dentro de los archivos.
    Ejemplo:
    ./ejercicio4.ps1 -directorio "./descargas" -palabras "password" "account" "unlam" -log "./log.txt"

.PARAMETER log
    Archivo donde se registrarán las detecciones realizadas por el demonio.

.PARAMETER kill
    Interruptor utilizado para finalizar el demonio previamente iniciado para el directorio indicado.
    Solo puede utilizarse junto con -directorio.

.EXAMPLE
    Get-Help ./ejercicio4.ps1

.EXAMPLE
    ./ejercicio4.ps1 -directorio "../descargas" -palabras "password" "account" "unlam" -log "log.txt"

.EXAMPLE
    ./ejercicio4.ps1 -directorio "../documentos" -palabras "virtualizacion" "cloud" "storage" -log "../registro.txt"

.EXAMPLE
    ./ejercicio4.ps1 -directorio "../descargas" -kill
#>

[CmdletBinding(DefaultParameterSetName="Iniciar")]
Param(
    [Parameter(
        Mandatory=$true,
        Position=0,
        ParameterSetName="Iniciar"
    )]
    [Parameter(
        Mandatory=$true,
        Position=0,
        ParameterSetName="Detener"
    )]
    [ValidateScript({
        if (Test-Path $_ -PathType Container) {
            $true
        }
        else {
            throw "El directorio '$_' no es valido."
        }
    })]
    [string]$directorio,

    [Parameter(
        Mandatory=$true,
        ParameterSetName="Iniciar"
    )]
    [ValidateNotNullOrEmpty()]
    [string[]]$palabras,

    [Parameter(
        Mandatory=$true,
        ParameterSetName="Iniciar"
    )]
    [ValidateScript({
        $padre = Split-Path $_ -Parent

        if ([string]::IsNullOrWhiteSpace($padre)) {
            $true
        }
        elseif (Test-Path $padre -PathType Container) {
            $true
        }
        else {
            throw "El directorio donde se quiere crear el log no existe: '$padre'"
        }
    })]
    [string]$log,

    [Parameter(
        Mandatory=$true,
        ParameterSetName="Detener"
    )]
    [switch]$kill,

    [Parameter(
        Mandatory=$false,
        ParameterSetName="Iniciar",
        DontShow=$true
    )]
    [switch]$demonioInterno,

    [Parameter(
        Mandatory=$false,
        ParameterSetName="Iniciar",
        ValueFromRemainingArguments=$true,
        DontShow=$true
    )]
    [string[]]$palabrasRestantes
)

if ($palabrasRestantes -and $palabrasRestantes.Count -gt 0) {
    $palabras += $palabrasRestantes
}

function Get-RutaAbsoluta {
    param([string]$Path)

    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Get-HashDirectorio {
    param([string]$Path)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Path.ToLower())
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash($bytes)

    return (($hashBytes | ForEach-Object { $_.ToString("x2") }) -join "")
}

function Get-ArchivoEstado {
    param([string]$Path)

    $directorioResuelto = (Resolve-Path $Path).Path
    $hash = Get-HashDirectorio -Path $directorioResuelto

    return Join-Path ([System.IO.Path]::GetTempPath()) "ejercicio4_$hash.json"
}

function Test-ProcesoActivo {
    param([int]$ProcessId)

    try {
        $proceso = Get-Process -Id $ProcessId -ErrorAction Stop
        return $null -ne $proceso
    }
    catch {
        return $false
    }
}

function Write-LogMensaje {
    param(
        [string]$ArchivoLog,
        [string]$Mensaje
    )

    $fecha = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $ArchivoLog -Value "[$fecha] $Mensaje"
}

function Write-LogDeteccion {
    param(
        [string]$ArchivoLog,
        [string]$Operacion,
        [string]$Archivo,
        [long]$Tamanio,
        [string[]]$Coincidencias
    )

    $fecha = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $palabrasEncontradas = $Coincidencias -join ", "

    $linea = "[$fecha] operacion=$Operacion archivo=`"$Archivo`" tamanio=$Tamanio bytes palabras=`"$palabrasEncontradas`""

    Add-Content -Path $ArchivoLog -Value $linea
}

function Write-LogError {
    param(
        [string]$ArchivoLog,
        [string]$Mensaje
    )

    $fecha = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $ArchivoLog -Value "[$fecha] ERROR $Mensaje"
}

function Wait-ArchivoDisponible {
    param(
        [string]$Path,
        [int]$Reintentos = 10
    )

    for ($i = 1; $i -le $Reintentos; $i++) {
        try {
            $stream = [System.IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
            $stream.Close()
            return $true
        }
        catch {
            Start-Sleep -Milliseconds 300
        }
    }

    return $false
}

function Test-ArchivoContienePalabras {
    param(
        [string]$Path,
        [string[]]$Palabras
    )

    $coincidencias = @()

    try {
        $contenido = Get-Content -Path $Path -Raw -ErrorAction Stop

        foreach ($palabra in $Palabras) {
            if ($contenido -match [regex]::Escape($palabra)) {
                $coincidencias += $palabra
            }
        }
    }
    catch {
        throw "No se pudo leer el archivo '$Path'. Detalle: $($_.Exception.Message)"
    }

    return $coincidencias
}

function Procesar-Archivo {
    param(
        [string]$Path,
        [string]$Operacion,
        [string[]]$Palabras,
        [string]$ArchivoLog
    )

    try {
        if (-not (Test-Path $Path -PathType Leaf)) {
            return
        }

        if (-not (Wait-ArchivoDisponible -Path $Path)) {
            Write-LogError -ArchivoLog $ArchivoLog -Mensaje "El archivo '$Path' no estuvo disponible para lectura."
            return
        }

        $coincidencias = Test-ArchivoContienePalabras -Path $Path -Palabras $Palabras

        if ($coincidencias.Count -gt 0) {
            $item = Get-Item -Path $Path -ErrorAction Stop

            Write-LogDeteccion `
                -ArchivoLog $ArchivoLog `
                -Operacion $Operacion `
                -Archivo $item.FullName `
                -Tamanio $item.Length `
                -Coincidencias $coincidencias
        }
    }
    catch {
        Write-LogError -ArchivoLog $ArchivoLog -Mensaje $_.Exception.Message
    }
}

function Start-Demonio {
    param(
        [string]$Directorio,
        [string[]]$Palabras,
        [string]$ArchivoLog
    )

    $sourceCreated = "Ejercicio4.Created.$PID"
    $sourceChanged = "Ejercicio4.Changed.$PID"
    $sourceRenamed = "Ejercicio4.Renamed.$PID"

    $eventosProcesados = @{}
    $archivosCreadosRecientemente = @{}

    try {
        $directorioResuelto = (Resolve-Path $Directorio).Path
        $archivoLogResuelto = Get-RutaAbsoluta -Path $ArchivoLog

        if (-not (Test-Path $archivoLogResuelto)) {
            New-Item -Path $archivoLogResuelto -ItemType File -Force | Out-Null
        }

        Write-LogMensaje -ArchivoLog $archivoLogResuelto -Mensaje "Demonio iniciado para el directorio '$directorioResuelto'."

        Get-ChildItem -Path $directorioResuelto -File -Recurse -ErrorAction Stop | ForEach-Object {
            Procesar-Archivo `
                -Path $_.FullName `
                -Operacion "Existente" `
                -Palabras $Palabras `
                -ArchivoLog $archivoLogResuelto
        }

        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $directorioResuelto
        $watcher.Filter = "*"
        $watcher.IncludeSubdirectories = $true
        $watcher.EnableRaisingEvents = $true

        Register-ObjectEvent `
            -InputObject $watcher `
            -EventName Created `
            -SourceIdentifier $sourceCreated | Out-Null

        Register-ObjectEvent `
            -InputObject $watcher `
            -EventName Changed `
            -SourceIdentifier $sourceChanged | Out-Null

        Register-ObjectEvent `
            -InputObject $watcher `
            -EventName Renamed `
            -SourceIdentifier $sourceRenamed | Out-Null

        while ($true) {
            $evento = Wait-Event -Timeout 2

            if ($null -ne $evento) {
                $path = $evento.SourceEventArgs.FullPath
                $tipo = $evento.SourceEventArgs.ChangeType.ToString()
                $ahora = Get-Date

                if (Test-Path $path -PathType Container) {
                    Remove-Event -EventIdentifier $evento.EventIdentifier -ErrorAction SilentlyContinue
                    continue
                }

                if ($tipo -eq "Created") {
                    $archivosCreadosRecientemente[$path] = $ahora
                }

                if ($tipo -eq "Changed" -and $archivosCreadosRecientemente.ContainsKey($path)) {
                    $diferenciaCreacion = ($ahora - $archivosCreadosRecientemente[$path]).TotalSeconds

                    if ($diferenciaCreacion -lt 3) {
                        Remove-Event -EventIdentifier $evento.EventIdentifier -ErrorAction SilentlyContinue
                        continue
                    }
                }

                if (Test-Path $path -PathType Leaf) {
                    $item = Get-Item -Path $path -ErrorAction SilentlyContinue

                    if ($null -ne $item) {
                        $claveEvento = "$($item.FullName)|$($item.Length)|$($item.LastWriteTimeUtc.Ticks)"

                        if ($eventosProcesados.ContainsKey($claveEvento)) {
                            $diferencia = ($ahora - $eventosProcesados[$claveEvento]).TotalSeconds

                            if ($diferencia -lt 2) {
                                Remove-Event -EventIdentifier $evento.EventIdentifier -ErrorAction SilentlyContinue
                                continue
                            }
                        }

                        $eventosProcesados[$claveEvento] = $ahora
                    }
                }

                Procesar-Archivo `
                    -Path $path `
                    -Operacion $tipo `
                    -Palabras $Palabras `
                    -ArchivoLog $archivoLogResuelto

                Remove-Event -EventIdentifier $evento.EventIdentifier -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        try {
            Write-LogError -ArchivoLog $ArchivoLog -Mensaje "El demonio finalizo por error: $($_.Exception.Message)"
        }
        catch {}

        exit 1
    }
    finally {
        Unregister-Event -SourceIdentifier $sourceCreated -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $sourceChanged -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $sourceRenamed -ErrorAction SilentlyContinue

        if ($null -ne $watcher) {
            $watcher.Dispose()
        }
    }
}

function Iniciar-ProcesoDemonio {
    param(
        [string]$Directorio,
        [string[]]$Palabras,
        [string]$ArchivoLog,
        [string]$ArchivoEstado
    )

    $directorioResuelto = (Resolve-Path $Directorio).Path
    $archivoLogResuelto = Get-RutaAbsoluta -Path $ArchivoLog
    $script = $PSCommandPath

    $ejecutablePowerShell = (Get-Process -Id $PID).Path

    if ([string]::IsNullOrWhiteSpace($ejecutablePowerShell)) {
        $ejecutablePowerShell = "pwsh"
    }

    $argumentos = @(
        "-NoProfile",
        "-File",
        $script,
        "-directorio",
        $directorioResuelto,
        "-palabras"
    )

    $argumentos += $Palabras

    $argumentos += @(
        "-log",
        $archivoLogResuelto,
        "-demonioInterno"
    )

    $proceso = Start-Process `
        -FilePath $ejecutablePowerShell `
        -ArgumentList $argumentos `
        -PassThru

    $estado = [PSCustomObject]@{
        Pid = $proceso.Id
        Directorio = $directorioResuelto
        Log = $archivoLogResuelto
        FechaInicio = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    $estado | ConvertTo-Json | Out-File -FilePath $ArchivoEstado -Encoding UTF8 -Force

    Write-Host "Demonio iniciado correctamente."
    Write-Host "Directorio monitoreado: $directorioResuelto"
    Write-Host "PID: $($proceso.Id)"
    Write-Host "Archivo de log: $archivoLogResuelto"
}

function Detener-Demonio {
    param(
        [string]$ArchivoEstado
    )

    if (-not (Test-Path $ArchivoEstado)) {
        Write-Warning "No hay un demonio registrado para el directorio indicado."
        exit 1
    }

    try {
        $estado = Get-Content -Path $ArchivoEstado -Raw | ConvertFrom-Json
        $pidDemonio = [int]$estado.Pid

        if (-not (Test-ProcesoActivo -ProcessId $pidDemonio)) {
            Remove-Item -Path $ArchivoEstado -Force -ErrorAction SilentlyContinue
            Write-Warning "El demonio registrado ya no estaba en ejecucion. Se limpio el archivo de control."
            exit 1
        }

        Stop-Process -Id $pidDemonio -Force -ErrorAction Stop
        Remove-Item -Path $ArchivoEstado -Force -ErrorAction SilentlyContinue

        Write-Host "Demonio finalizado correctamente."
        Write-Host "Directorio monitoreado: $($estado.Directorio)"
        Write-Host "PID detenido: $pidDemonio"
    }
    catch {
        Write-Warning "No se pudo finalizar el demonio: $($_.Exception.Message)"
        exit 1
    }
}

try {
    $directorioResuelto = (Resolve-Path $directorio).Path
    $archivoEstado = Get-ArchivoEstado -Path $directorioResuelto

    if ($kill) {
        Detener-Demonio -ArchivoEstado $archivoEstado
        exit 0
    }

    if ($demonioInterno) {
        Start-Demonio -Directorio $directorioResuelto -Palabras $palabras -ArchivoLog $log
        exit 0
    }

    if (Test-Path $archivoEstado) {
        $estado = Get-Content -Path $archivoEstado -Raw | ConvertFrom-Json
        $pidExistente = [int]$estado.Pid

        if (Test-ProcesoActivo -ProcessId $pidExistente) {
            Write-Warning "Ya existe un demonio ejecutandose para el directorio '$directorioResuelto'."
            Write-Warning "PID actual: $pidExistente"
            Write-Warning "Para detenerlo ejecute: ./ejercicio4.ps1 -directorio `"$directorioResuelto`" -kill"
            exit 1
        }
        else {
            Remove-Item -Path $archivoEstado -Force -ErrorAction SilentlyContinue
        }
    }

    Iniciar-ProcesoDemonio `
        -Directorio $directorioResuelto `
        -Palabras $palabras `
        -ArchivoLog $log `
        -ArchivoEstado $archivoEstado

    exit 0
}
catch {
    Write-Warning "Ocurrio un error: $($_.Exception.Message)"
    exit 1
}
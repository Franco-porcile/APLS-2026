# Integrantes : 
# - Nombre Apellido: Porcile Franco 
# - Nombre Apellido: Graneros Brian Ariel
# - Nombre Apellido: Avella Mateo
# - Nombre Apellido: Zapata Santiago

<#
.SYNOPSIS
    Consulta información detallada de los personajes de la serie Rick and Morty a través de su API oficial.

.DESCRIPTION
    Este script permite buscar personajes por su ID, por su nombre o utilizando ambos criterios en la misma ejecución. 
    Implementa un sistema de caché local para optimizar las consultas y reducir el tráfico de red, almacenando los resultados de forma persistente.

.PARAMETER id
    Uno o más IDs de personajes (enteros). Se pueden pasar como una lista separada por comas.
    Ejemplo: -id 1, 2, 5

.PARAMETER nombre
    Uno o más nombres de personajes (strings). Se pueden pasar como una lista separada por comas.
    Ejemplo: -nombre "Rick", "Morty"

.PARAMETER clear
    Interruptor (switch) que limpia los archivos de caché (kv.csv y cache.jsonl). 
    Esta opción es exclusiva y no puede ser utilizada junto con parámetros de búsqueda.

.EXAMPLE
    PS C:\> ./ejercicio5.ps1 -id 1, 2, 3
    Busca y muestra la información de los personajes con IDs 1, 2 y 3.

.EXAMPLE
    PS C:\> ./ejercicio5.ps1 -nombre "Rick", "Morty", "Summer"
    Busca todos los personajes cuyos nombres coincidan con los términos proporcionados.

.EXAMPLE
    PS C:\> ./ejercicio5.ps1 -nombre "Beth" -id 10, 20
    Realiza una búsqueda combinada por nombre e ID.

.EXAMPLE
    PS C:\> ./ejercicio5.ps1 -clear
    Reinicia el sistema de caché eliminando los archivos locales.

.NOTES
    - Los resultados de los personajes se guardan en 'cache.jsonl'.
    - Las relaciones de búsqueda por nombre se almacenan en 'kv.csv'.
    - Si un ID o nombre no existe o la API no está disponible, el script informará el error por pantalla.
    - Los parámetros de búsqueda aceptan arrays nativos de PowerShell.
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false, ParameterSetName="Busqueda")]
    [int[]]$id,

    [Parameter(Mandatory=$false, ParameterSetName="Busqueda")]
    [String[]]$nombre,

    [Parameter(Mandatory=$false, ParameterSetName="Clear")]
    [switch]$clear
)

# Vi algo de que puede ser jsonl (porque tiene un json por linea)
# pero no se si es valido
$ARCHIVO_CACHE = $PSScriptRoot + "/cache.jsonl"
$ARCHIVO_KV = $PSScriptRoot + "/kv.csv"

function Write-Personajes {
    param([System.Object[]]$array)
    $array | ForEach-Object {
        # Optimizar para no usar tantos writes
        Write-Host "-----------------------"
        Write-Host "Character info:"
        Write-Host "Id: $($_.Id)"
        Write-Host "Name: $($_.Name)"
        Write-Host "Status: $($_.Status)"
        Write-Host "Species: $($_.Species)"
        Write-Host "Gender: $($_.Gender)"
        Write-Host "Origin: $($_.Origin)"
        Write-Host "Location: $($_.Location)"
        Write-Host "Episodes: $($_.Episodes)"
    }
}

function Get-ObjetosPersonajes {
    param([System.Object[]]$array)
    $personajes = $array | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.id
            Name = $_.name
            Status = $_.status
            Species = $_.species
            Gender = $_.gender
            Origin = $_.origin.name
            Location = $_.location.name
            Episodes = $_.episode.Count
        }
    }
    return $personajes
}

function Find-IdApi {
    Param(
        [int[]]$ids
    )
    try {
        $uriBase = "https://rickandmortyapi.com/api/character/"
        $uri = $uriBase + ($ids | Join-String -Separator ',')
        Write-Host "Find-IdApi: Consultando API para ids: " $ids
        ## Si usase Invoke-WebRequest tengo que pasarlo a json con ConvertFrom-Json, pero Invoke-RestMethod ya lo hace automáticamente
        $response = Invoke-RestMethod -Uri $uri -Method Get
    }
    catch {
        Write-Warning "Error en Find-IdApi para ids: $ids  -  $($_.Exception.Message)"
        return @()
    }

    return Get-ObjetosPersonajes -array $response
}

function Find-NombreApi {
    Param(
        [String]$name
    )
    $array = @()
    try {
        $uribase = "https://rickandmortyapi.com/api/character/?name="
        $uri = $uribase + $name
        Write-Host "Find-NombreApi: Consultando API para nombre: " $name
        while ($null -ne $uri) {
            $response = Invoke-RestMethod -Uri $uri -Method Get
            $array += Get-ObjetosPersonajes $response.results
            $uri = $response.info.next
        }
    }
    catch {
        Write-Warning "Error en Find-NombreApi para nombre: $name  -  $($_.Exception.Message)"
    }


    return $array
}

function Get-Cache {
    Param(
        [int[]]$ids
    )
    $resultados = @()
    $resultados += Get-Content $ARCHIVO_CACHE | ForEach-Object {
        $_ |
        ConvertFrom-Json |
        Where-Object {$ids -contains $_.Id}
    }
    return $resultados
}

# Existe un formato CliXml que es optimo para estas cosas
# pero para mantenerlo en linea con el de bash uso json por lineas
function Add-Cache {
    Param(
        [System.Object[]]$array
    )
    $array | ForEach-Object {
        $_ | ConvertTo-Json -Compress | Out-File -Append -FilePath $ARCHIVO_CACHE
    }
    (Get-Content $ARCHIVO_CACHE) | Sort-Object -Unique | Out-File $ARCHIVO_CACHE
}

function Get-Kv {
    Param(
        [String]$name
    )
    # Obtengo desde el Csv los ids de ese nombre
    $ids = Get-Content $ARCHIVO_KV 
    | ConvertFrom-Csv -Delimiter ';' -Header "nombre", "ids"
    | Where-Object nombre -eq $name
    | Select-Object -ExpandProperty ids
    
    if (!$ids) {
        return @()
    }

    # Conviero los ids de string a enteros
    $ids = ($ids) -split ',' | ForEach-Object { $_ -as [int] }
    return Get-Cache -ids $ids
}

function Add-Kv {
    Param(
        [String]$name,
        [System.Object[]]$array
    )
    $ids = ($array | Select-Object -ExpandProperty Id) -join ','
    $registroKv = "$name;$ids"
    $registroKv | Out-File -Append -FilePath $ARCHIVO_KV
    Add-Cache -array $array
}

function Clear-Cache {
    Remove-Item $ARCHIVO_CACHE -Force -ErrorAction SilentlyContinue
    Remove-Item $ARCHIVO_KV -Force -ErrorAction SilentlyContinue
}

function Find-NombreIndividual {
    Param(
        [String]$name
    )
    $cache = Get-Kv -name $name
    if($cache) {
        Write-Host "Find-NombreIndividual: CACHE HIT for name: " $name
        return $cache
    }

    Write-Host "Find-NombreIndividual: CACHE MISS for name: " $name
    $resultadoApi = Find-NombreApi -name $name
    
    if ($resultadoApi.Count -gt 0) {
        Add-Kv -name $name -array $resultadoApi
        return $resultadoApi
    }

    Write-Host "Find-NombreIndividual: No se encontraron resultados para el nombre: " $name
    return @()
}

function Find-Nombres {
    Param(
        [String[]]$names
    )
    $array = @()
    $names | ForEach-Object {
        $resultado = Find-NombreIndividual -name $_
        if ($null -ne $resultado) {
            $array += $resultado
        }
    }
    return $array
}

function Find-Ids {
    Param(
        [int[]]$ids
    )
    
    $cache = Get-Cache -ids $ids
    
    if ($cache.Count -eq $ids.Count) {
        Write-Host "Find-Ids: CACHE HIT for ids: " $ids
        return $cache
    }

    $array = @()
    $array += $cache

    $idsObtenidos = $cache | Select-Object -ExpandProperty Id
    $idsFaltantes = $ids | Where-Object { $_ -notin  $idsObtenidos }
    
    if($idsObtenidos){
        Write-Host "Find-Ids: CACHE HIT for ids: " $idsObtenidos
    }
    Write-Host "Find-Ids: CACHE MISS for ids: " $idsFaltantes
    
    $resultadoApi = Find-IdApi -ids $idsFaltantes
    if ($resultadoApi) {
        Add-Cache -array $resultadoApi
        $array += $resultadoApi
    }
    else {
        Write-Host "Find-Ids: No se encontraron resultados para los ids: " $idsFaltantes
    }
    
    return $array
}


##### MAIN

if ($clear) {
    Clear-Cache
    Write-Host "Cache reiniciada"
    exit 0
}

# Inicializo los archivos de cache y kv
if (-not (Test-Path $ARCHIVO_CACHE)) {
    New-Item -Path $ARCHIVO_CACHE -ItemType File -Force | Out-Null
}

Write-Host "Archivo Cache: $ARCHIVO_CACHE"

if (-not (Test-Path $ARCHIVO_KV)) {
    New-Item -Path $ARCHIVO_KV -ItemType File -Force | Out-Null
}

Write-Host "Archivo Clave-Valor: $ARCHIVO_KV"


$array = @()

# Logica de busqueda
try {
    if ($id) {
        $array += Find-Ids -ids $id
    }

    if ($nombre) {
        $array += Find-Nombres -names $nombre
    }

    if($array.Count -gt 0) {
        Write-Personajes -array $array
    }
    else {
        Write-Host "No se encontraron resultados para los criterios de busqueda proporcionados."
    }
}
catch {
    Write-Warning "Ocurrio un error durante la busqueda: $($_.Exception.Message)"
    exit 1
}


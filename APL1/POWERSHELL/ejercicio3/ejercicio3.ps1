### PREGUNTAR A LOS PROFES SI ESTA BIEN QUE MUERA AL ENCONTRAR DIRECTORIOS SIN PERMISO O 
### MEJOR QUE CONTINUE. Y SI CONTINUA SI ES MEJOR MOSTRARLOS POR PANTALLA O DIRECTAMENTE
### IGNORARLOS.

# Integrantes : 
# - Nombre Apellido: Porcile Franco 
# - Nombre Apellido: Graneros Brian Ariel
# - Nombre Apellido: Avella Mateo
# - Nombre Apellido: Zapata Santiago

<#
.SYNOPSIS
    Busca archivos duplicados (por nombre y tamaño) de forma recursiva en el directorio especificado.
.DESCRIPTION
    Este script analiza un directorio (y sus subdirectorios) y lista aquellos archivos que coinciden en 
    nombre y tamaño, detallando sus ubicaciones. 
    En caso de no existir el directorio fallara su validacion.
    En caso de ocurrir un error en la busqueda recursiva se lanza un error y se retorna 1.
    IMPORTANTE: Si no se tiene permiso de lectura sobre algun directorio, se lanza un error.
.PARAMETER directorio
    Ruta del directorio a analizar, debe ser valido y poder leerse.
    Puede ser pasado por pipeline o como argumento.
.EXAMPLE
    Get-Help ./ejercicio3.ps1

    *** Esto ***
.EXAMPLE
    ./ejercicio3.ps1 -directorio "home/mateo"
    
    archivo: ejercicio3.sh
    directorio: /home/user/apl
    directorio: /home/user/apl/final
    directorio: /home/user/apl/final/final

.EXAMPLE
    Get-ChildItem -Path /home/mateo/virtua/ -Filter *APL* | Select-Object -ExpandProperty FullName | ./ejercicio3.ps1

    archivo: Hola.txt
    directorio: /home/mateo/virtua/APL1/powershell/ejercicio3
    directorio: /home/mateo/virtua/APL1/powershell/ejercicio3/duplicado
    directorio: /home/mateo/virtua/APL1/powershell/ejercicio3/duplicado/duplicado

.EXAMPLE
    ./ejercicio3.ps1 -directorio ../../../../

    archivo: common.h
    directorio: /home/mateo/sysop/inventario_supermercado
    directorio: /home/mateo/sysop/inventario_supermercado_old
#>
Param(
    [Parameter(Mandatory=$true,
            Position=0,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
    [ValidateScript({
        if(Test-Path $_ -PathType Container) {$true}
        else {throw "El directorio '$_' no es valido."}
    })]
    [string]$directorio
)

function Get-ArchivosDuplicados {
    param ([string]$Path)
    try {
        $duplicados = Get-ChildItem -Path $Path -Recurse -File -ErrorAction Stop
                | Select-Object -Property Name, Length, Directory 
                | Group-Object -Property Name, Length -CaseSensitive 
                | Where-Object {$_.Count -gt 1}
        
        if($null -eq $duplicados) {
            Write-Host "No se encontraron archivos duplicados."
            return
        }

        foreach ($grupo in $duplicados) {
            Write-Host;
            Write-Host "archivo:" $grupo.Group[0].Name;
            foreach ($archivo in $grupo.Group) {
                Write-Host "directorio:" $archivo.Directory.ToString()
            }
        }
    }
    catch {
        Write-Warning "Ocurrio un error al leer los directorios/archivos: $($_.Exception.Message)"
        exit 1 # Para que $? sea false
    }
}

Get-ArchivosDuplicados -Path $directorio
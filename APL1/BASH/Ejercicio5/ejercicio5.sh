#!/bin/bash
# Integrantes : 
# - Nombre Apellido: Porcile Franco 
# - Nombre Apellido: Graneros Brian Ariel
# - Nombre Apellido: Avella Mateo
# - Nombre Apellido: Zapata Santiago

# chmod +x ./ejercicio5.sh
# usage: ./ejercicio5.sh -n Johnny | grep -B 2 -A 6 Johnny
# usage: ./ejercicio5.sh -n rick | grep -c "Character info:" Cantidad encontrada
# usage: verlo funcionando con algun sniffer para ver llamadas a la red?
# usage: find /tmp -name "*ejercicio5.json" 2> /dev/null verificar que no quede basura. Agregar "| xargs rm -f" para limpiarlos a mano.
script_dir=$(readlink -f "$0" | sed 's/\/[^/]*$//')
kv_file="$script_dir/kv.csv"
cache_file="$script_dir/cache.jsonl"
tmp_json="/tmp/${$}_ejercicio5.json"

ayuda() {
    echo "Uso: $0 [-i/--id \"<id1,id2,...>\"] [-n/--nombre \"<nombre1,nombre2,...>\"] [-c] [-h]"
    echo ""
    echo "Descripción:"
    echo "  Este script consulta información detallada de los personajes de la serie"
    echo "  Rick and Morty a través de su API oficial. Implementa un sistema de"
    echo "  caché local para optimizar las consultas y reducir el tráfico de red."
    echo "  Permite buscar por ID, por nombre o ambos."
    echo ""
    echo "Requisitos:"
    echo "  - El script requiere 'jq' para procesar JSON."
    echo "  Para instalar 'jq' en Ubuntu: sudo apt-get install jq"
    echo "  - El script utiliza 'wget' para realizar las consultas a la API."
    echo "  Para instalar 'wget' en Ubuntu: sudo apt-get install wget" 
    echo ""
    echo "Opciones:"
    echo "  -h, --help      Muestra este mensaje de ayuda y finaliza el script."
    echo "  -i, --id        Uno o más IDs de personajes separados por comas (ej: 1,2,5). Entre comillas."
    echo "  -n, --nombre    Uno o más nombres de personajes separados por comas. Entre comillas."
    echo "  -c, --clear     Limpia los archivos de caché (kv.csv y cache.json). Esta opción es exclusiva y no puede ser utilizada junto con otras opciones."
    echo ""
    echo "Ejemplos:"
    echo "  Búsqueda por ID:"
    echo "    $0 -i \"1,2,3\""
    echo ""
    echo "  Búsqueda por nombre (soporta múltiples nombres):"
    echo "    $0 --nombre \"Rick, Morty, Summer\""
    echo ""
    echo "  Búsqueda combinada:"
    echo "    $0 -n \"Beth\" -i \"10,20\""
    echo ""
    echo "  Limpiar el sistema de caché:"
    echo "    $0 --clear"
    echo ""
    echo "Notas:"
    echo "  - Los resultados se guardan en '$PWD/cache.jsonl' para evitar re-consultar la API."
    echo "  - Las relaciones de búsqueda por nombre se almacenan en '$PWD/kv.csv'."
    echo "  - Si un ID o nombre no existe, el script informará el error por pantalla."
}

manejador_fin() {
    echo "Programa interrumpido, limpiando archivos temporales..." >&2
    rm -f "$tmp_json"
    exit 0
}

obtener_json_personajes() {
    cat | jq -c '{
        id, 
        name, 
        status, 
        species, 
        gender, 
        origin: .origin.name, 
        location: .location.name, 
        episodes: (.episode | length)
    }'
}

mostrar_personaje() {
    echo "-----------------------"
    echo "Character info:"
    # Uso interpolacion para mostrar los datos en 1 sola llamada a jq. Fundamental el raw (-r) para no mostrar comillas.
    echo "$1" | jq -r '
        "Id: \(.id)",
        "Name: \(.name)",
        "Status: \(.status)",
        "Species: \(.species)",
        "Gender: \(.gender)",
        "Origin: \(.origin)",
        "Location: \(.location)",
        "Episodes: \(.episodes)"
    '
}

mostrar_todos() {
    local json=$(cat "$1" | grep -v '^$' | sort -u) # Elimino lineas vacias y quito duplicados
    
    if [ -z "$json" ]; then
        echo "No se encontraron personajes para mostrar." >&2
        return
    fi
    
    while read -r linea; do
        mostrar_personaje "$linea"
    done <<< "$json"
}

buscar_nombre_api() {
    local nombre="$1"
    echo "Buscando en API por nombre: $nombre" >&2
    next_request="https://rickandmortyapi.com/api/character/?name=$nombre"
    json=""
    
    while [[ "$next_request" != "null" ]]; 
    do
        echo "Haciendo request a: $next_request" >&2
        response=$(wget --timeout=5 -qO- $next_request)
        
        if [ $? -ne 0 ] || [ -z "$response" ]; then
            echo "Aviso: No se pudo obtener información de la API para el Nombre '$nombre'. Puede que no exista o haya un problema de red." >&2
            return 1
        fi

        json+="$(echo "$response" | jq -c '.results[]' | obtener_json_personajes)"$'\n'
        next_request=$(echo "$response" | jq '.info.next' | tr -d '\"')
    done

    echo "$json"
}

buscar_id_api() {
    local id="$1"
    echo "Buscando en API por ID: $id" >&2
    json=$(wget --timeout=5 -qO- "https://rickandmortyapi.com/api/character/$id")
    
    if [ $? -ne 0 ] || [ -z "$json" ]; then
        echo "Aviso: No se pudo obtener información de la API para el ID '$id'. Puede que no exista o haya un problema de red." >&2
        return 1
    fi
    
    if [[ "$json" == "["* ]]; then
        echo "$json" | jq -c '.[]' | obtener_json_personajes
    else
        echo "$json" | obtener_json_personajes
    fi
}

get_cache() {
    MIS_IDS="$1"
    jq -c --arg input "$MIS_IDS" '($input | split(",") | map(tonumber)) as $ids 
        | select(.id as $actual | $ids 
        | any(. == $actual))' "$cache_file"
}

put_cache() {
    personajes="$1"
    echo "$personajes" >> "$cache_file"
    sort -u "$cache_file" -o "$cache_file"
}

get_kv() {
    nombre="$1"
    ids=$(grep -i "^$nombre;" "$kv_file" | head -n 1 | sed 's/^[^;]*;//')
    get_cache "$ids"
}

put_kv() {
    nombre="$1"
    json="$2"
    ids=$(echo "$json" | jq '.id' | paste -sd ",") # Guardo los ids con formato: x,y,z
    echo "$nombre;$ids" >> "$kv_file"
    put_cache "$json"
}

clear_cache() {
    rm -f "$kv_file" "$cache_file"
}

buscar_nombre_individual() { # Si no esta en cache, busca todo en la api
    local nombre="$1"
    resultado_cache=$(get_kv "$nombre")

    if [ -z "$resultado_cache" ]; then
        echo "buscar_nombre: CACHE MISS for name: $nombre" >&2
        resultado_api=$(buscar_nombre_api "$nombre")
        put_kv "$nombre" "$resultado_api"
        echo "$resultado_api"
    else
        echo "buscar_nombre: CACHE HIT for name: $nombre" >&2
        echo "$resultado_cache"
    fi
}

buscar_nombres() { # Busca individualmente porque la API no permite buscar por varios.
    local nombres=$(echo "$1" | sed 's/ //g')
    IFS=',' read -r -a nombres_array <<< "$nombres"
    json=""
    for nombre in "${nombres_array[@]}"; do
        json+="$(buscar_nombre_individual "$nombre")"$'\n'
    done
    echo "$json"
}

buscar_ids() { # Lo que no este en cache, lo busca en la api. El resto lo obtiene desde la cache.
    local ids="$1"
    resultado_cache=$(get_cache "$ids")
    
    IFS=',' read -r -a ids_array <<< "$ids"

    ids_faltantes=()
    for id in "${ids_array[@]}"; do
        if ! echo "$resultado_cache" | grep "id\":$id," ; then
            ids_faltantes+=("$id")
        fi
    done
    
    if [ -n "$ids_faltantes" ]; then
        ids_faltantes=$(echo "${ids_faltantes[@]}" | tr ' ' ',')
        ids_obtenidos=$(echo "$resultado_cache" | jq '.id' | paste -sd ",")

        echo "buscar_id: CACHE HIT for IDs: $ids_obtenidos - CACHE MISS for IDs: $ids_faltantes" >&2

        resultado_api=$(buscar_id_api "$ids_faltantes")
        put_cache "$resultado_api"
        resultado_cache="$resultado_cache"$'\n'"$resultado_api"
        resultado_cache=$(echo "$resultado_cache" | sort -u)
    else
        echo "buscar_id: CACHE HIT for IDs: $ids" >&2
    fi

    echo "$resultado_cache"
}

##### ##### ##### #####

##### OPCIONES #####

options=$(getopt -o i:n:ch --l id:,nombre:,clear,help -- "$@" 2> /dev/null)
if [ "$?" != "0" ]; then # Si el getopt devuelve distinto de cero, alguna opcion es incorrecta
    echo 'Opciones incorrectas, use -h o --help para mas informacion.' >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo 'Error: Debe proporcionar al menos una opción. Use -h o --help para mas información.' >&2
    exit 1
fi

eval set -- "$options"
FLAG_ID=0
FLAG_NOMBRE=0
FLAG_CLEAR=0
IDS=""
NOMBRES=""

while true
do
    case "$1" in
        -i | --id)
            FLAG_ID=1
            IDS="$2"
            shift 2

            ;;
        -n | --nombre)
            FLAG_NOMBRE=1
            NOMBRES="$2"
            shift 2

            ;;
        -c | --clear)
            FLAG_CLEAR=1
            shift

            ;;
        -h | --help)
            ayuda
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Error - opcion invalida: $1"
            exit 1
            ;;
    esac
done
    
##### VALIDACIONES #####
if [[ $FLAG_ID -ne 1 && $FLAG_NOMBRE -ne 1 && $FLAG_CLEAR -ne 1 ]]; then
    echo "Error: Debe proporcionar al menos una opción de busqueda (-i/--id y/o -n/--nombre) o -c/--clear"
    exit 1
fi

if [[ $FLAG_ID -eq 1 && -z $IDS ]]; then
    echo "Error: La opción --id requiere un argumento"
    exit 1
fi

if [[ $FLAG_NOMBRE -eq 1 && -z $NOMBRES ]]; then
    echo "Error: La opción --nombre requiere un argumento"
    exit 1
fi

if [[ $FLAG_CLEAR -eq 1 ]]; then
    if [[ $FLAG_ID -eq 1 || $FLAG_NOMBRE -eq 1 ]]; then
        echo "Error: La opción -c/--clear no se puede usar junto con otras opciones"
        exit 1
    fi
    clear_cache
    echo "Cache reiniciada correctamente."
    exit 0
fi

if [[ $FLAG_ID -eq 1 && $IDS  =~ [^0-9,] ]]; then
    echo "Error: Los IDs deben ser números enteros positivos separados por comas"
    exit 1
fi


##### INICIALIZACION CACHE Y TRAP #####

echo "Archivo Clave-Valor: $kv_file" >&2
echo "Archivo Cache: $cache_file" >&2

trap manejador_fin SIGINT SIGTERM SIGHUP

if [ ! -f "$kv_file" ]; then
    touch "$kv_file"
fi

if [ ! -f "$cache_file" ]; then
    touch "$cache_file"
fi

##### EJECUCION#####

if [[ $FLAG_NOMBRE -eq 1 ]]; then
    buscar_nombres "$NOMBRES" >> "$tmp_json"
fi

if [[ $FLAG_ID -eq 1 ]]; then
    buscar_ids "$IDS" >> "$tmp_json"
fi

mostrar_todos "$tmp_json"
rm -f "$tmp_json"
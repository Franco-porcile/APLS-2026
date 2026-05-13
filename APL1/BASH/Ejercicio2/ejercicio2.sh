#!/bin/bash
# Integrantes : 
# - Nombre Apellido: Porcile Franco 
# - Nombre Apellido: Graneros Brian Ariel
# - Nombre Apellido: Avella Mateo
# - Nombre Apellido: Zapata Santiago


##### FUNCIONES ##### 

procesar_todo() {
    local ARCHIVO_A_PROCESAR="$1"
    
    # Ejecutamos un solo proceso de sed pasándole todas las expresiones encadenadas con -e
    # 1. Reemplaza múltiples espacios por uno solo.
    # 2. Elimina espacios al inicio y al final de cada línea (trim).
    # 3. Convierte la primera letra de cada línea a mayúscula, respetando caracteres no alfabéticos al inicio.
    # 4. Reemplaza "yo" por "Yo" solo cuando es una palabra completa.
    # 5. Reemplaza comillas simples por dobles y reduce secuencias de puntos a tres.
    # 6. Reduce múltiples signos de interrogación o exclamación a uno solo.
    # 7/8. Asegura que cada pregunta comience con "¿" y cada exclamación con "¡".
    # 9/10. Asegura que cada pregunta termine con "?" y cada exclamación con "!".
    # 11. Asegura un espacio después de cada signo de puntuación
    # 12. Elimina espacios antes de signos y signos de cierre
    # 13. Elimina espacios antes de signos de apertura
    # 14. Mayúcula la primer letra después de un cambio de oración.
    # 15. Asegura que cada línea termine con un signo de puntuación adecuado.
    # FUNDAMENTAL: El orden de las expresiones es importante para evitar conflictos entre ellas.

    sed -E \
        -e 's/ +/ /g' \
        -e 's/^ +//g; s/ +$//g'\
        -e 's/^([^a-zA-Z]*)([a-z])/\1\U\2/' \
        -e 's/\byo\b/Yo/g' \
        -e 's/'\''/"/g; s/(\.{2,})/.../g' \
        -e 's/([¿?¡!])[¿?¡!]+/\1/g' \
        -e ':pregunta; s/(^|[!.,;:?] +)([^¡!.,;:¿?]*\?)/\1¿\2/ ; tpregunta' \
        -e ':exclamacion; s/(^|[!.,;:?] +)([^¡!.,;:¿?]*!)/\1¡\2/ ; texclamacion' \
        -e 's/(¿[^?.,!:;]*)($|[.,;:!])/\1?/g' \
        -e 's/(¡[^?.,!:;]*)($|[.,;:?])/\1!/g' \
        -e 's/([.,;:?!])([^ ])/\1 \2/g' \
        -e 's/ +([.,;:?!])/\1/g' \
        -e 's/([¿¡]) +/\1/g' \
        -e 's/([.?!] *[¿¡]*)([a-z])/\1\U\2/g' \
        -e 's/(¿[^?]*)$/\1?/; s/(¡[^!]*)$/\1!/; s/([^.?!])$/\1./' \
        "$ARCHIVO_A_PROCESAR"
}

ayuda() {
    echo "Uso: $0 -a <archivo_entrada> [-s <archivo_salida>]"
    echo ""
    echo "Descripción:"
    echo "  Este script lee un texto sin formato y le aplica una serie de arreglos"
    echo "  automáticos para adecuarlo a las convenciones del idioma español."
    echo "  Corrige puntuación, uso de mayúsculas, signos de interrogación/exclamación"
    echo "  y problemas de espaciado."
    echo ""
    echo "Opciones:"
    echo "  -h, --help       Muestra este mensaje de ayuda y finaliza el script."
    echo "  -a, --archivo    Ruta del archivo de texto de entrada que se desea procesar (Requerido)."
    echo "  -s, --salida     Ruta del archivo de salida donde se guardará el resultado."
    echo "                   Si no se especifica, el texto corregido se mostrará por pantalla (Opcional)."
    echo ""
    echo "Ejemplos:"
    echo "  Mostrar por pantalla:"
    echo "    $0 -a borrador.txt"
    echo ""
    echo "  Guardar en un nuevo archivo:"
    echo "    $0 -a borrador.txt -s texto_final.txt"
    echo "    $0 --archivo borrador.txt --salida texto_final.txt"
    echo ""
    echo "  El orden de los parámetros es indistinto:"
    echo "    $0 -s texto_final.txt -a borrador.txt"
}

##### ##### ##### #####

##### OPCIONES #####

options=$(getopt -o a:s:h --l archivo:,salida:,help -- "$@" 2> /dev/null)
if [ "$?" != "0" ] # Si el getopt devuelve distinto de cero, alguna opcion es incorrecta
then
    echo 'Opciones incorrectas, use -h o --help para mas informacion.' >&2
    exit 1
fi

eval set -- "$options"
ARCHIVO=""
SALIDA=""
FLAG_SALIDA=false

while true
do
    case "$1" in # switch ($1) { 
        -a | --archivo)
            ARCHIVO="$2"
            shift 2

            ;;
        -s | --salida)
            SALIDA="$2"
            FLAG_SALIDA=true
            shift 2

            ;;
        -h | --help)
            ayuda
            exit 0
            ;;
        --) # case "--":
            shift
            break
            ;;
        *) # default: 
            echo "error"
            exit 1
            ;;
    esac
done

##### VALIDACIONES #####

if [ -n "$ARCHIVO" ]; then
    if [ -f "$ARCHIVO" ]; then
        echo "Archivo de entrada '$ARCHIVO' es valido" > /dev/null
    else
        echo "Error: El archivo de entrada '$ARCHIVO' no se pudo encontrar o no es válido" >&2
        exit 1
    fi
else
    echo "Error: No se ha especificado un archivo de entrada" >&2
    exit 1
fi

if [ "$FLAG_SALIDA" = true ] ; then
    if [[ ! -d "$SALIDA" ]] && [[ "$SALIDA" =~ \.(txt|csv|log|md)$ ]]; then
        echo "Archivo de salida '$SALIDA' creado correctamente" > /dev/null
    else
        echo "Error: El archivo de salida '$SALIDA' no es valido" >&2
        exit 1
    fi
fi

##### PROCESAMIENTO #####

if [ "$FLAG_SALIDA" = true ] ; then
    procesar_todo "$ARCHIVO" > "$SALIDA"
else
    procesar_todo "$ARCHIVO"
fi
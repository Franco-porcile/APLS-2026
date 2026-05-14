#!/bin/bash
set -e

function mostrar_ayuda() {
	echo "Uso: $0 [opciones]"
	echo ""
	echo "Descripción: "
	echo "Este script busca archivos duplicados basandose en el nombre y el tamaño, listando sus rutas absolutas."
	echo ""
	echo "Opciones: "
	echo "-d --directorio   Ruta del directorio a analizar. (Por defecto: Directorio actual)."
	echo "-h --help         Proporciona ayuda para el uso del script."
}

DIRECTORIO="."

while getopts ":d:-:h" opt; do
	case $opt in
		d) DIRECTORIO="$OPTARG" ;;
		h) mostrar_ayuda; exit 0 ;;
		-)
			case "${OPTARG}" in
				directorio)
					if [[ -z "${!OPTIND}" || "${!OPTIND}" == -* ]]; then
						echo "Error: La opción --${OPTARG} requiere un argumento."
						mostrar_ayuda
						exit 1
					fi
					DIRECTORIO="${!OPTIND}";
					((OPTIND++))
				;;
				help) mostrar_ayuda; exit 0 ;;
				*) echo "Opción inválida: --${OPTARG}"; mostrar_ayuda; exit 1 ;;
			esac
		;;
		:) echo "La opción -${OPTARG} requiere un argumento."; mostrar_ayuda; exit 1 ;;
		\?) echo "Opción inválida: -${OPTARG}"; mostrar_ayuda; exit 1 ;;
	esac
done

shift $((OPTIND -1));

if [[ ! -d "$DIRECTORIO" ]]; then
	echo "Error: El directorio '$DIRECTORIO' no existe o no es válido."
	exit 1
fi

DIRECTORIO=$(readlink -f "$DIRECTORIO");

echo "El directorio a analizar es: $DIRECTORIO"

find "$DIRECTORIO" -type f -printf "%f\037%s\037%p\0" | awk '
BEGIN {
	FS = "\037";
	RS = "\0";
}
{
	key = $1 "-" $2;
	if(archivos[key] == "") {
		archivos[key] = $3;
	}
	else {
		duplicados[key] = $1;
		archivos[key] = archivos[key] "\037" $3;
	}
}
END {
	if(length(duplicados) > 0) {
		for(d in duplicados) {
			printf("archivo: %s\n", duplicados[d]);
			n = split(archivos[d], directorios, "\037");
			for(i=1; i<n+1; i++) {
				sub(/\/[^\/]+$/, "", directorios[i])
				printf("directorio %d: %s\n", i, directorios[i]);
			}
			printf("\n");
		}
	} else {
		printf("No se encontraron archivos duplicados.\n");
	}
}'

#!/bin/bash
# Integrantes : 
# - Nombre Apellido: Porcile Franco 
# - Nombre Apellido: Graneros Brian Ariel
# - Nombre Apellido: Avella Mateo
# - Nombre Apellido: Zapata Santiago

mostrar_ayuda() {
  echo "Uso:"
  echo "  ./ejercicio1.sh -a archivo.csv [-f campo -b texto] (-c | -s campo)"
  echo ""
  echo "Descripcion:"
  echo "  Lee un archivo CSV y permite contar registros o sumar un campo numerico."
  echo ""
  echo "Parametros:"
  echo "  -a, --archivo   Archivo CSV de entrada"
  echo "  -f, --filtro    Nombre del campo usado para filtrar"
  echo "  -b, --buscar    Texto a buscar dentro del campo filtro"
  echo "  -c, --contar    Cuenta registros"
  echo "  -s, --sumar     Nombre del campo numerico a sumar"
  echo "  -h, --help      Muestra esta ayuda"
}

obtener_columna() {
  local campo_buscado="$1"
  local encabezado="$2"

  echo "$encabezado" | awk -v campo="$campo_buscado" '
    BEGIN {
      FPAT = "([^,]*)|(\"([^\"]|\"\")*\")"
    }
    {
      for (i = 1; i <= NF; i++) {
        valor = $i
        gsub(/^"|"$/, "", valor)

        if (valor == campo) {
          print i
          exit
        }
      }
    }
  '
}


main() {
  local ARCHIVO=""
  local FILTRO=""
  local BUSCAR=""
  local CONTAR=0
  local SUMAR=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            mostrar_ayuda
            exit 0
            ;;
        -a|--archivo)
            if [[ -z "$2" || "$2" == -* ]]; then
            echo "Error: -a/--archivo requiere una ruta de archivo."
            exit 1
            fi
            ARCHIVO="$2"
            shift 2
            ;;
        -f|--filtro)
            if [[ -z "$2" || "$2" == -* ]]; then
            echo "Error: -f/--filtro requiere un nombre de campo."
            exit 1
            fi
            FILTRO="$2"
            shift 2
            ;;
        -b|--buscar)
            if [[ -z "$2" || "$2" == -* ]]; then
            echo "Error: -b/--buscar requiere un texto a buscar."
            exit 1
            fi
            BUSCAR="$2"
            shift 2
            ;;
        -c|--contar)
            CONTAR=1
            shift
            ;;
        -s|--sumar)
            if [[ -z "$2" || "$2" == -* ]]; then
            echo "Error: -s/--sumar requiere un nombre de campo."
            exit 1
            fi
            SUMAR="$2"
            shift 2
            ;;
        *)
          echo "Error: parametro desconocido: $1"
          mostrar_ayuda
          exit 1
          ;;
    esac
  done

  if [[ -z "$ARCHIVO" ]]; then
    echo "Error: debe indicar un archivo con -a o --archivo."
    exit 1
  fi

  if [[ ! -f "$ARCHIVO" ]]; then
    echo "Error: el archivo indicado no existe: $ARCHIVO"
    exit 1
  fi

  if [[ "$CONTAR" -eq 1 && -n "$SUMAR" ]]; then
    echo "Error: no puede usar -c y -s al mismo tiempo."
    exit 1
  fi

  if [[ "$CONTAR" -eq 0 && -z "$SUMAR" ]]; then
    echo "Error: debe indicar una operacion: -c para contar o -s campo para sumar."
    exit 1
  fi

  if [[ -n "$FILTRO" && -z "$BUSCAR" ]]; then
    echo "Error: si usa -f debe indicar tambien -b."
    exit 1
  fi

  if [[ -z "$FILTRO" && -n "$BUSCAR" ]]; then
    echo "Error: no puede usar -b sin usar -f."
    exit 1
  fi

  ENCABEZADO=$(head -n 1 "$ARCHIVO")

  COLUMNA_FILTRO=""

  if [[ -n "$FILTRO" ]]; then
    COLUMNA_FILTRO=$(obtener_columna "$FILTRO" "$ENCABEZADO")

    if [[ -z "$COLUMNA_FILTRO" ]]; then
      echo "Error: el campo de filtro '$FILTRO' no existe en el archivo."
      exit 1
    fi
  fi

  COLUMNA_SUMA=""

  if [[ -n "$SUMAR" ]]; then
    COLUMNA_SUMA=$(obtener_columna "$SUMAR" "$ENCABEZADO")

    if [[ -z "$COLUMNA_SUMA" ]]; then
      echo "Error: el campo de suma '$SUMAR' no existe en el archivo."
      exit 1
    fi
  fi

if [[ "$CONTAR" -eq 1 ]]; then
  if [[ -n "$FILTRO" ]]; then
    RESULTADO=$(awk -v columna="$COLUMNA_FILTRO" -v buscar="$BUSCAR" '
      BEGIN {
        FPAT = "([^,]*)|(\"([^\"]|\"\")*\")"
      }
      NR > 1 {
        valor = $columna
        gsub(/^"|"$/, "", valor)

        if (valor ~ buscar) {
          contador++
        }
      }
      END {
        print contador + 0
      }
    ' "$ARCHIVO")
  else
    RESULTADO=$(awk '
      NR > 1 {
        contador++
      }
      END {
        print contador + 0
      }
    ' "$ARCHIVO")
  fi

  echo "Resultado: $RESULTADO"
fi
if [[ -n "$SUMAR" ]]; then
  if [[ -n "$FILTRO" ]]; then
    RESULTADO=$(awk -v columna_filtro="$COLUMNA_FILTRO" -v buscar="$BUSCAR" -v columna_suma="$COLUMNA_SUMA" '
      BEGIN {
        FPAT = "([^,]*)|(\"([^\"]|\"\")*\")"
      }
      NR > 1 {
        valor_filtro = $columna_filtro
        valor_suma = $columna_suma

        gsub(/^"|"$/, "", valor_filtro)
        gsub(/^"|"$/, "", valor_suma)

        if (valor_filtro ~ buscar) {
          suma += valor_suma
        }
      }
      END {
        print suma + 0
      }
    ' "$ARCHIVO")
  else
    RESULTADO=$(awk -v columna_suma="$COLUMNA_SUMA" '
      BEGIN {
        FPAT = "([^,]*)|(\"([^\"]|\"\")*\")"
      }
      NR > 1 {
        valor_suma = $columna_suma
        gsub(/^"|"$/, "", valor_suma)
        suma += valor_suma
      }
      END {
        print suma + 0
      }
    ' "$ARCHIVO")
  fi

  echo "Resultado: $RESULTADO"
fi
}

main "$@"
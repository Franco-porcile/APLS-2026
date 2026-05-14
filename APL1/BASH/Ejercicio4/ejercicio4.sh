#!/bin/bash
# Integrantes :
# - Nombre Apellido: Porcile Franco
# - Nombre Apellido: Graneros Brian Ariel
# - Nombre Apellido: Avella Mateo
# - Nombre Apellido: Zapata Santiago

mostrar_ayuda() {
  echo "Uso:"
  echo "  ./ejercicio4.sh -d <directorio> --palabras p1,p2,p3 [-l <log>]"
  echo "  ./ejercicio4.sh -d <directorio> --kill"
  echo ""
  echo "Descripcion:"
  echo "  Demonio que monitorea un directorio y registra en un log cada vez que un"
  echo "  archivo contiene alguna de las palabras clave (sin distinguir mayus/minus)."
  echo ""
  echo "Parametros:"
  echo "  -d, --directorio  Directorio a monitorear (obligatorio)"
  echo "  -p, --palabras    Palabras clave separadas por coma"
  echo "  -l, --log         Archivo o directorio de log (default: <directorio>/demonio.log)"
  echo "  -k, --kill        Finaliza el demonio del directorio indicado"
  echo "  -h, --help        Muestra esta ayuda"
}

procesar_archivo() {
  local archivo="$1" patron="$2" log="$3" operacion="$4"
  [[ ! -f "$archivo" ]] && return
  if grep -iqE "$patron" "$archivo" 2>/dev/null; then
    local tamano fecha
    tamano=$(stat -c %s "$archivo" 2>/dev/null)
    fecha=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$fecha] operacion=${operacion} archivo=${archivo} tamano=${tamano}B" >> "$log"
  fi
}

DIRECTORIO=""
PALABRAS=""
LOG=""
KILL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      mostrar_ayuda
      exit 0
      ;;
    -d|--directorio)
      if [[ -z "$2" || "$2" == -* ]]; then
        echo "Error: -d/--directorio requiere una ruta."
        exit 1
      fi
      DIRECTORIO="$2"
      shift 2
      ;;
    -p|--palabras)
      if [[ -z "$2" || "$2" == -* ]]; then
        echo "Error: -p/--palabras requiere palabras separadas por coma."
        exit 1
      fi
      PALABRAS="$2"
      shift 2
      ;;
    -l|--log)
      if [[ -z "$2" || "$2" == -* ]]; then
        echo "Error: -l/--log requiere una ruta."
        exit 1
      fi
      LOG="$2"
      shift 2
      ;;
    -k|--kill)
      KILL=1
      shift
      ;;
    *)
      echo "Error: parametro desconocido: $1"
      mostrar_ayuda
      exit 1
      ;;
  esac
done

if [[ -z "$DIRECTORIO" ]]; then
  echo "Error: debe indicar un directorio con -d."
  exit 1
fi

if [[ ! -d "$DIRECTORIO" ]]; then
  echo "Error: el directorio no existe: $DIRECTORIO"
  exit 1
fi

DIR_ABS=$(realpath "$DIRECTORIO")
HASH=$(echo -n "$DIR_ABS" | md5sum | awk '{print $1}')
PID_FILE="/tmp/demonio_${HASH}.pid"

if [[ "$KILL" -eq 1 ]]; then
  if [[ ! -f "$PID_FILE" ]]; then
    echo "Error: no hay demonio activo para '$DIR_ABS'."
    exit 1
  fi
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null
    # El daemon limpia su propio PID file via trap EXIT
    echo "Demonio detenido (PID $PID) para '$DIR_ABS'."
  else
    echo "El demonio ya no estaba activo. Limpiando."
    rm -f "$PID_FILE" 2>/dev/null
  fi
  exit 0
fi

if [[ -z "$PALABRAS" ]]; then
  echo "Error: debe indicar palabras clave con --palabras."
  exit 1
fi

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Error: ya hay un demonio activo para '$DIR_ABS' (PID $(cat "$PID_FILE"))."
  exit 1
fi

if ! command -v inotifywait >/dev/null 2>&1; then
  echo "Error: 'inotifywait' no esta instalado. Instalar el paquete inotify-tools."
  exit 1
fi

if [[ -z "$LOG" ]]; then
  LOG="${DIR_ABS}/demonio.log"
elif [[ -d "$LOG" ]]; then
  LOG="${LOG}/demonio.log"
fi
case "$LOG" in
  /*) ;;
  *) LOG="$(pwd)/$LOG" ;;
esac

PATRON=$(echo "$PALABRAS" | sed 's/,/|/g')

(
  echo $BASHPID > "$PID_FILE"
  trap 'rm -f "$PID_FILE"' EXIT
  trap 'pkill -P $BASHPID 2>/dev/null; exit 0' TERM INT

  for archivo in "$DIR_ABS"/*; do
    [[ -f "$archivo" ]] && procesar_archivo "$archivo" "$PATRON" "$LOG" "INITIAL_SCAN"
  done

  while IFS='|' read -r evento archivo; do
    [[ -z "$archivo" ]] && continue
    [[ -f "$archivo" ]] && procesar_archivo "$archivo" "$PATRON" "$LOG" "$evento"
  done < <(inotifywait -m -q -e close_write -e moved_to --format '%e|%w%f' "$DIR_ABS")
) </dev/null >/dev/null 2>&1 &
disown

sleep 0.3
if [[ -f "$PID_FILE" ]]; then
  echo "Demonio iniciado para '$DIR_ABS' (PID $(cat "$PID_FILE"))."
  echo "Log: $LOG"
else
  echo "Error: el demonio no pudo iniciarse."
  exit 1
fi

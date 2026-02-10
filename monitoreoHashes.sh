#!/bin/bash

# ===== CONFIGURACIÓN =====
CONFIG="configArchivosPrueba.json"
HASHES_BASE="hashes_base.json"
LOG_DIR="logs"
FECHA=$(date +%F)
LOG_FILE="$LOG_DIR/log_hashes_$FECHA.json"

mkdir -p "$LOG_DIR"

# ===== VERIFICAR DEPENDENCIAS =====
if ! command -v jq &> /dev/null; then
    echo "Error: jq no está instalado"
    exit 1
fi

SCRIPT_PATH="$(readlink -f "$0")"
CRON_SCHEDULE="*/3 * * * *"
CRON_CMD="$CRON_SCHEDULE $SCRIPT_PATH"

if ! crontab -l 2>/dev/null | grep -F "$SCRIPT_PATH" > /dev/null; then
    (
        crontab -l 2>/dev/null
        echo "$CRON_CMD"
    ) | crontab -
fi

# ===== LEER ARCHIVOS DEL CONFIG =====
ARCHIVOS=$(jq -r '.archivos[]' "$CONFIG")

# ===== SI NO EXISTE HASHES_BASE, CREARLO =====
if [ ! -f "$HASHES_BASE" ]; then
    echo "{}" > "$HASHES_BASE"
    for archivo in $ARCHIVOS; do
        if [ -f "$archivo" ]; then
            hash=$(sha256sum "$archivo" | awk '{print $1}')
            jq --arg ruta "$archivo" --arg hash "$hash" \
               '. + {($ruta): $hash}' "$HASHES_BASE" > tmp.json && mv tmp.json "$HASHES_BASE"
        fi
    done
    echo "Archivo hashes_base.json creado. Ejecuta nuevamente el script."
    exit 0
fi

# ===== VARIABLES DE CONTROL =====
TOTAL=0
SIN_CAMBIOS=0
MODIFICADOS=0
ALERTA=false
DETALLES="[]"

# ===== PROCESAR CADA ARCHIVO =====
for archivo in $ARCHIVOS; do
    TOTAL=$((TOTAL + 1))

    if [ ! -f "$archivo" ]; then
        estado="no_existe"
        hash_actual="null"
        hash_esperado="null"
    else
        hash_actual=$(sha256sum "$archivo" | awk '{print $1}')
        hash_esperado=$(jq -r --arg ruta "$archivo" '.[$ruta] // empty' "$HASHES_BASE")

        if [ "$hash_actual" = "$hash_esperado" ]; then
            estado="sin_cambios"
            SIN_CAMBIOS=$((SIN_CAMBIOS + 1))
        else
            estado="modificado"
            MODIFICADOS=$((MODIFICADOS + 1))
            ALERTA=true
        fi
    fi

    DETALLES=$(jq --arg ruta "$archivo" \
                  --arg actual "$hash_actual" \
                  --arg esperado "$hash_esperado" \
                  --arg estado "$estado" \
                  '. + [{
                      ruta: $ruta,
                      sha256_actual: $actual,
                      sha256_esperado: $esperado,
                      estado: $estado
                  }]' <<< "$DETALLES")
done

# ===== ESTADO FINAL =====
if [ "$ALERTA" = true ]; then
    ESTADO_FINAL="completado_con_alertas"
else
    ESTADO_FINAL="completado_sin_alertas"
fi

# ===== CREAR LOG JSON =====
jq -n \
  --arg fecha "$FECHA" \
  --arg operacion "verificacion_hashes" \
  --argjson archivos "$DETALLES" \
  --argjson total "$TOTAL" \
  --argjson sin "$SIN_CAMBIOS" \
  --argjson mod "$MODIFICADOS" \
  --argjson alerta "$ALERTA" \
  --arg estado "$ESTADO_FINAL" \
'{
  fecha: $fecha,
  operacion: $operacion,
  archivos: $archivos,
  resumen: {
    total_verificados: $total,
    sin_cambios: $sin,
    modificados: $mod
  },
  alerta: $alerta,
  estado_final: $estado
}' > "$LOG_FILE"

echo "Verificación completada. Log generado en $LOG_FILE"
echo "Ejecución: $(date)" >> logs/debug_cron.txts

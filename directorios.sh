#!/bin/bash

# CONFIGURACIÓN
DIR_PROYECTO="$HOME/proyecto"
DIR_RESPALDOS="$HOME/respaldos"
FECHA=$(date +%F)

ARCHIVO_RESPALDO="$DIR_RESPALDOS/proyecto_${FECHA}.tar.gz"
BITACORA="$DIR_RESPALDOS/bitacora_respaldo_${FECHA}.json"

# VERIFICAR DIRECTORIOS
if [ ! -d "$DIR_PROYECTO" ]; then
    echo "No existe el directorio ~/proyecto"
    exit 1
fi

mkdir -p "$DIR_RESPALDOS"

# CREAR RESPALDO
INICIO=$(date +%s%3N)
tar -czf "$ARCHIVO_RESPALDO" -C "$DIR_PROYECTO" .

if [ $? -eq 0 ]; then
    ESTADO="exitoso"
    TAMANO=$(stat -c%s "$ARCHIVO_RESPALDO" 2>/dev/null)
else
    ESTADO="fallido"
    TAMANO=0
fi

FIN=$(date +%s%3N)
DURACION_MS=$((FIN - INICIO))
DURACION=$(LC_NUMERIC=C awk "BEGIN {printf \"%.1f\", $DURACION_MS/1000}")

# ELIMINAR RESPALDOS > 7 DÍAS
RESPALDOS_ELIMINADOS=()

for archivo in $(find "$DIR_RESPALDOS" -name "proyecto_*.tar.gz" -mtime +6 2>/dev/null); do
    if [ "$archivo" != "$ARCHIVO_RESPALDO" ]; then
        nombre=$(basename "$archivo")
        rm "$archivo"
        RESPALDOS_ELIMINADOS+=("\"$nombre\"")
    fi
done

# Convertir array a formato JSON simple
LISTA_ELIMINADOS=$(IFS=,; echo "${RESPALDOS_ELIMINADOS[*]}")

# ESTADO FINAL
if [ "$ESTADO" = "exitoso" ]; then
    ESTADO_FINAL="completado"
else
    ESTADO_FINAL="fallido"
fi

# CREAR BITÁCORA JSON
cat > "$BITACORA" <<EOF
{
  "fecha": "$FECHA",
  "operacion": "respaldo_proyecto",
  "respaldo_generado": {
    "archivo": "$(basename "$ARCHIVO_RESPALDO")",
    "ruta": "$ARCHIVO_RESPALDO",
    "tamano_bytes": $TAMANO,
    "estado": "$ESTADO",
    "duracion_seg": $DURACION
  },
  "respaldos_eliminados": [ $LISTA_ELIMINADOS ],
  "estado_final": "$ESTADO_FINAL"
}
EOF

echo "Respaldo terminado."
echo "Bitácora generada en $BITACORA"

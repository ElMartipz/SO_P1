#!/bin/bash

ARCHIVO_SERVICIOS="servicios.json"
USUARIO="so2025II"
HOST="pacifico.izt.uam.mx"
LLAVE_SSH="./so_llave"

FECHA=$(date '+%Y-%m-%d')
ARCHIVO_LOG="log_servicios_${FECHA}.json"

# Leer servicios desde JSON
SERVICIOS=$(jq -r '.servicios[]' "$ARCHIVO_SERVICIOS")

TOTAL=0
ACTIVO=0
INACTIVO=0
NO_CONECTADO=0
ERROR=0

VERIFICACIONES=""

for servicio in $SERVICIOS; do
    TOTAL=$((TOTAL + 1))
    INICIO=$(date +%s%3N)
    CHECKED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    estado="error"
    detalle="no se pudo verificar"
    metodo="none"

    # Verificar conexión
    if ! ssh -i "$LLAVE_SSH" -o BatchMode=yes -o ConnectTimeout=5 \
        "$USUARIO@$HOST" "exit" 2>/dev/null; then

        estado="no_conectado"
        detalle="fallo de conexión SSH"

    else
        # 1. systemctl
        salida=$(ssh -i "$LLAVE_SSH" "$USUARIO@$HOST" \
            "systemctl is-active $servicio 2>/dev/null")

        if [[ "$salida" == "active" ]]; then
            estado="activo"
            detalle="active"
            metodo="systemctl"
        elif [[ "$salida" == "inactive" || "$salida" == "failed" ]]; then
            estado="inactivo"
            detalle="$salida"
            metodo="systemctl"
        else
            # 2. service
            salida=$(ssh -i "$LLAVE_SSH" "$USUARIO@$HOST" \
                "service $servicio status 2>/dev/null | head -n 1")

            if echo "$salida" | grep -qi "running"; then
                estado="activo"
                detalle="running"
                metodo="service"
            else
                # 3. ps
                procesos=$(ssh -i "$LLAVE_SSH" "$USUARIO@$HOST" \
                    "ps aux | grep -i $servicio | grep -v grep | wc -l")

                if [[ "$procesos" -gt 0 ]]; then
                    estado="activo"
                    detalle="$procesos procesos encontrados"
                    metodo="ps"
                else
                    estado="inactivo"
                    detalle="sin procesos coincidentes"
                    metodo="ps"
                fi
            fi
        fi
    fi

    FIN=$(date +%s%3N)
    DURACION=$((FIN - INICIO))

    case "$estado" in
        activo) ACTIVO=$((ACTIVO + 1)) ;;
        inactivo) INACTIVO=$((INACTIVO + 1)) ;;
        no_conectado) NO_CONECTADO=$((NO_CONECTADO + 1)) ;;
        *) ERROR=$((ERROR + 1)) ;;
    esac

    VERIFICACIONES+=$(cat << EOF
    {
      "servicio": "$servicio",
      "metodo": "$metodo",
      "estado": "$estado",
      "detalle": "$detalle",
      "checked_at": "$CHECKED_AT",
      "duracion_ms": $DURACION
    },
EOF
)
done

# Quitar última coma
VERIFICACIONES=$(echo "$VERIFICACIONES" | sed '$ s/,$//')

# Crear JSON final
cat > "$ARCHIVO_LOG" << EOF
{
  "fecha": "$FECHA",
  "host": "$HOST",
  "resumen": {
    "total": $TOTAL,
    "activo": $ACTIVO,
    "inactivo": $INACTIVO,
    "no_conectado": $NO_CONECTADO,
    "error": $ERROR
  },
  "verificaciones": [
$VERIFICACIONES
  ]
}
EOF

echo "Monitoreo finalizado. Resultado en $ARCHIVO_LOG"

#!/bin/bash

# Variables de configuración
DIR_PROYECTO="$HOME/proyecto"
DIR_RESPALDOS="$HOME/respaldos"
FECHA=$(date '+%Y-%m-%d')
ARCHIVO_RESPALDO="$DIR_RESPALDOS/proyecto_${FECHA}.tar.gz"
ARCHIVO_BITACORA="$DIR_RESPALDOS/bitacora_respaldo_${FECHA}.json"

# Variables para resultados
INICIO_SEGUNDOS=0
DURACION=0
TAMANO_BYTES=0
ESTADO_RESPALDO=""
ESTADO_FINAL=""
ARCHIVOS_ELIMINADOS=()  # Array en bash

# ============================================================================
# 1. VERIFICAR DIRECTORIO PROYECTO
# ============================================================================
echo "=== VERIFICANDO DIRECTORIOS ==="

if [[ ! -d "$DIR_PROYECTO" ]]; then
    echo "❌ ERROR: No existe el directorio $DIR_PROYECTO"
    echo "   Crea el directorio con: mkdir -p $DIR_PROYECTO"
    exit 1
fi
echo "✅ Directorio proyecto encontrado: $DIR_PROYECTO"

# ============================================================================
# 2. VERIFICAR/CREAR DIRECTORIO RESPALDOS
# ============================================================================
if [[ ! -d "$DIR_RESPALDOS" ]]; then
    echo "⚠️  Directorio respaldos no existe. Creando..."
    mkdir -p "$DIR_RESPALDOS"
    
    if [[ $? -ne 0 ]]; then
        echo "❌ ERROR: No se pudo crear $DIR_RESPALDOS"
        exit 1
    fi
    echo "✅ Directorio respaldos creado: $DIR_RESPALDOS"
else
    echo "✅ Directorio respaldos encontrado: $DIR_RESPALDOS"
fi

# ============================================================================
# 3. VERIFICAR PERMISOS (opcional pero recomendado)
# ============================================================================
if [[ ! -w "$DIR_RESPALDOS" ]]; then
    echo "❌ ERROR: Sin permisos de escritura en $DIR_RESPALDOS"
    exit 1
fi
echo "✅ Permisos de escritura OK"

echo ""
echo "✅ Todas las verificaciones pasaron."
echo "========================================="

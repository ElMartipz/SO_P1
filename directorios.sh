#!/bin/bash

# ============================================================================
# CONFIGURACIÓN
# ============================================================================
DIR_PROYECTO="$HOME/proyecto"
DIR_RESPALDOS="$HOME/respaldos"
FECHA=$(date '+%Y-%m-%d')
ARCHIVO_RESPALDO="$DIR_RESPALDOS/proyecto_${FECHA}.tar.gz"
ARCHIVO_BITACORA="$DIR_RESPALDOS/bitacora_respaldo_${FECHA}.json"

# Variables para resultados
INICIO=0
FIN=0
DURACION=0
TAMANO_BYTES=0
ESTADO_RESPALDO=""
ESTADO_FINAL=""
ARCHIVOS_ELIMINADOS=()  # Array en bash

# ============================================================================
# 1. VERIFICACIÓN DE DIRECTORIOS
# ============================================================================
echo "=== VERIFICANDO DIRECTORIOS ==="

# Verificar que ~/proyecto existe
if [[ ! -d "$DIR_PROYECTO" ]]; then
    echo "❌ ERROR: No existe el directorio $DIR_PROYECTO"
    echo "   Crea el directorio con: mkdir -p $DIR_PROYECTO"
    exit 1
fi
echo "✅ Directorio proyecto encontrado: $DIR_PROYECTO"

# Verificar/Crear ~/respaldos
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

# Verificar permisos de escritura
if [[ ! -w "$DIR_RESPALDOS" ]]; then
    echo "❌ ERROR: Sin permisos de escritura en $DIR_RESPALDOS"
    exit 1
fi
echo "✅ Permisos OK"

echo ""
echo "✅ Todas las verificaciones pasaron."
echo "========================================="

# ============================================================================
# 2. CREAR RESPALDO COMPRIMIDO
# ============================================================================
echo ""
echo "=== CREANDO RESPALDO ==="
echo "Origen:      $DIR_PROYECTO"
echo "Destino:     $ARCHIVO_RESPALDO"

# Iniciar cronómetro
INICIO=$(date +%s.%N)

# Crear respaldo con verificación de éxito
if tar czf "$ARCHIVO_RESPALDO" -C "$DIR_PROYECTO" . 2>/dev/null; then
    ESTADO_RESPALDO="exitoso"
    echo "✅ Respaldo creado exitosamente"
    
    # Obtener tamaño del archivo generado
    if [[ -f "$ARCHIVO_RESPALDO" ]]; then
        # Usar wc -c (más portable) o stat si disponible
        if command -v stat &>/dev/null; then
            TAMANO_BYTES=$(stat -c%s "$ARCHIVO_RESPALDO" 2>/dev/null || echo "0")
        else
            TAMANO_BYTES=$(wc -c < "$ARCHIVO_RESPALDO" 2>/dev/null | tr -d ' ')
        fi
        echo "   Tamaño:      $TAMANO_BYTES bytes"
    else
        TAMANO_BYTES=0
        echo "⚠️  Archivo creado pero no encontrado"
    fi
else
    ESTADO_RESPALDO="fallido"
    TAMANO_BYTES=0
    echo "❌ ERROR: Falló la creación del respaldo"
    
    # Limpiar archivo parcial si existe
    if [[ -f "$ARCHIVO_RESPALDO" ]]; then
        rm "$ARCHIVO_RESPALDO"
        echo "   Archivo parcial eliminado"
    fi
fi

# Calcular duración
FIN=$(date +%s.%N)
if command -v bc &>/dev/null; then
    DURACION=$(echo "scale=3; $FIN - $INICIO" | bc 2>/dev/null || echo "0")
else
    # Fallback si bc no está instalado
    DURACION=$(( $(date +%s) - $(date -d "@$INICIO" +%s) ))
fi
echo "   Duración:    ${DURACION} segundos"
echo "   Estado:      $ESTADO_RESPALDO"

# ============================================================================
# 3. PREPARAR JSON DEL RESPALDO GENERADO
# ============================================================================
echo ""
echo "=== PREPARANDO JSON DEL RESPALDO ==="

# Crear JSON parcial del respaldo (sin cerrar)
RESPALDO_JSON=$(cat << EOF
{
  "fecha": "$FECHA",
  "operacion": "respaldo_proyecto",
  "respaldo_generado": {
    "archivo": "$(basename "$ARCHIVO_RESPALDO")",
    "ruta": "$ARCHIVO_RESPALDO",
    "tamano_bytes": $TAMANO_BYTES,
    "estado": "$ESTADO_RESPALDO",
    "duracion_seg": $DURACION
  }
EOF
)

echo "JSON parcial del respaldo preparado."

# ============================================================================
# 4. BUSCAR Y ELIMINAR ARCHIVOS ANTIGUOS (>7 DÍAS)
# ============================================================================
echo ""
echo "=== BUSCANDO ARCHIVOS ANTIGUOS (>7 días) ==="

# Buscar archivos proyecto_*.tar.gz con más de 7 días
# maxdepth 1: solo en carpeta principal, no subcarpetas
#ARCHIVOS_ANTIGUOS=$(find "$DIR_RESPALDOS" -maxdepth 1 -name "proyecto_*.tar.gz" -mtime +7 2>/dev/null)
ARCHIVOS_ANTIGUOS=$(find "$DIR_RESPALDOS" -maxdepth 1 -name "proyecto_*.tar.gz" -mtime +1 2>/dev/null)
# ARCHIVOS_ANTIGUOS=$(find "$DIR_RESPALDOS" -maxdepth 1 -name "proyecto_*.tar.gz" -mtime +0 2>/dev/null)
#ARCHIVOS_ANTIGUOS=$(find "$DIR_RESPALDOS" -maxdepth 1 -name "proyecto_*.tar.gz" -amin +1 2>/dev/null)

# Convertir a array
mapfile -t ARCHIVOS_ELIMINADOS_TMP <<< "$ARCHIVOS_ANTIGUOS"

# Filtrar array (eliminar líneas vacías y el archivo actual)
ARCHIVOS_ELIMINADOS=()
for archivo in "${ARCHIVOS_ELIMINADOS_TMP[@]}"; do
    # Verificar que no está vacío y no es el archivo recién creado
    if [[ -n "$archivo" ]] && [[ "$archivo" != "$ARCHIVO_RESPALDO" ]]; then
        ARCHIVOS_ELIMINADOS+=("$archivo")
    fi
done

# Mostrar y eliminar archivos antiguos
if [[ ${#ARCHIVOS_ELIMINADOS[@]} -gt 0 ]]; then
    echo "Encontrados ${#ARCHIVOS_ELIMINADOS[@]} archivos antiguos:"
    
    for archivo in "${ARCHIVOS_ELIMINADOS[@]}"; do
        nombre_archivo=$(basename "$archivo")
        echo "   ❌ $nombre_archivo"
        
        # Eliminar archivo
        if rm "$archivo" 2>/dev/null; then
            echo "     ✅ Eliminado"
        else
            echo "     ⚠️  No se pudo eliminar (¿permisos?)"
        fi
    done
else
    echo "✅ No hay archivos antiguos para eliminar"
fi

# ============================================================================
# 5. PREPARAR JSON DE ARCHIVOS ELIMINADOS
# ============================================================================
echo ""
echo "=== PREPARANDO JSON DE ARCHIVOS ELIMINADOS ==="

# Crear array JSON de nombres de archivos eliminados
ELIMINADOS_JSON=""
for ((i=0; i<${#ARCHIVOS_ELIMINADOS[@]}; i++)); do
    archivo="${ARCHIVOS_ELIMINADOS[i]}"
    nombre=$(basename "$archivo")
    
    # Agregar al JSON (con coma si no es el primero)
    if [[ $i -gt 0 ]]; then
        ELIMINADOS_JSON="$ELIMINADOS_JSON,"
    fi
    ELIMINADOS_JSON="$ELIMINADOS_JSON\"$nombre\""
done

# Si no hay archivos eliminados, array vacío
ELIMINADOS_JSON="${ELIMINADOS_JSON:-}"  # Permite string vacío

echo "JSON de eliminados preparado: [$ELIMINADOS_JSON]"

# ============================================================================
# 6. DETERMINAR ESTADO FINAL
# ============================================================================
if [[ "$ESTADO_RESPALDO" == "exitoso" ]]; then
    ESTADO_FINAL="completado"
else
    ESTADO_FINAL="fallido"
fi

echo ""
echo "Estado final: $ESTADO_FINAL"

# ============================================================================
# 7. CREAR ARCHIVO BITÁCORA JSON
# ============================================================================
echo ""
echo "=== CREANDO BITÁCORA JSON ==="

# Crear JSON completo
cat > "$ARCHIVO_BITACORA" << EOF
$RESPALDO_JSON,
  "respaldos_eliminados": [ $ELIMINADOS_JSON ],
  "estado_final": "$ESTADO_FINAL"
}
EOF

# Verificar que el JSON es válido
if command -v jq &>/dev/null; then
    if jq . "$ARCHIVO_BITACORA" &>/dev/null; then
        echo "✅ Bitácora JSON creada exitosamente"
        echo "   Ruta: $ARCHIVO_BITACORA"
    else
        echo "⚠️  Bitácora creada pero JSON podría tener errores"
        echo "   Ruta: $ARCHIVO_BITACORA"
    fi
else
    echo "✅ Bitácora creada: $ARCHIVO_BITACORA"
    echo "   Instala 'jq' para validar JSON: sudo apt install jq"
fi

# ============================================================================
# 8. RESUMEN FINAL
# ============================================================================
echo ""
echo "========================================="
echo "✅ RESPALDO AUTOMÁTICO COMPLETADO"
echo "========================================="
echo "Resumen:"
echo "  Estado respaldo:    $ESTADO_RESPALDO"
echo "  Estado final:       $ESTADO_FINAL"
echo "  Archivos eliminados: ${#ARCHIVOS_ELIMINADOS[@]}"
echo "  Duración total:     ${DURACION} segundos"
echo "  Bitácora:           $ARCHIVO_BITACORA"
echo "  Respaldo:           $ARCHIVO_RESPALDO"
echo "========================================="
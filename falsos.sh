#!/bin/bash
# preparar_prueba.sh - Crear archivos falsamente antiguos

echo "=== PREPARANDO ARCHIVOS ANTIGUOS FALSOS ==="

DIR_RESPALDOS="$HOME/respaldos"
mkdir -p "$DIR_RESPALDOS"

# Crear contenido para respaldar
mkdir -p ~/proyecto
echo "Contenido de prueba" > ~/proyecto/test.txt

# 1. Archivo de "hace 8 días" (será eliminado con +7)
echo "Creando archivo de hace 8 días..."
touch -d "8 days ago" "$DIR_RESPALDOS/proyecto_2026-01-29.tar.gz"
echo "Contenido falso" > "$DIR_RESPALDOS/proyecto_2026-01-29.tar.gz"

# 2. Archivo de "hace 2 días" (NO será eliminado con +7, SÍ con +0)
echo "Creando archivo de hace 2 días..."
touch -d "2 days ago" "$DIR_RESPALDOS/proyecto_2026-02-04.tar.gz"
echo "Contenido falso" > "$DIR_RESPALDOS/proyecto_2026-02-04.tar.gz"

# 3. Archivo de "ayer" (NO será eliminado con +7, SÍ con +1)
echo "Creando archivo de ayer..."
touch -d "yesterday" "$DIR_RESPALDOS/proyecto_2026-02-05.tar.gz"
echo "Contenido falso" > "$DIR_RESPALDOS/proyecto_2026-02-05.tar.gz"

echo ""
echo "=== ARCHIVOS CREADOS ==="
for f in "$DIR_RESPALDOS"/proyecto_*.tar.gz; do
    echo "$(basename $f) - Modificado: $(stat -c %y $f 2>/dev/null || echo "?")"
done
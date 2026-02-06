#!/bin/bash

#Variables de configuracion
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
#!/bin/bash

# Función para obtener el nombre del juego usando la API de GameTDB
get_game_name() {
  local serial="$1"
  local url="https://www.gametdb.com/api/GetGame.php?type=PS3&serial=$serial"
  local response=$(curl -s "$url")
  
  # Imprimir la respuesta completa de la API para depuración
  echo "Response from GameTDB for serial $serial: $response" # Línea de depuración completa
  
  # Extraer el nombre del juego
  local game_name=$(echo "$response" | grep -oPm1 "(?<=<title>)[^<]+")
  if [ -z "$game_name" ]; then
    echo "No game name found for serial $serial"
  else
    echo "Game name found: $game_name"
  fi
  echo "$game_name"
}

# Directorio de origen donde se encuentran los juegos de rpcs3
rpcs3_game_dir="$HOME/.config/rpcs3/dev_hdd0/game"

# Directorio de destino donde se crearán los enlaces simbólicos en RetroPie
retropie_roms_dir="$HOME/RetroPie/roms/ps3"

# Iterar sobre cada subdirectorio en el directorio de juegos de rpcs3
for game_dir in "$rpcs3_game_dir"/*; do
  if [ -d "$game_dir" ]; then
    # Obtener el serial del juego (nombre del subdirectorio)
    serial=$(basename "$game_dir")
    
    # Verificar que el serial no contenga caracteres inesperados
    if [[ "$serial" =~ [^a-zA-Z0-9_] ]]; then
      echo "Serial inválido: $serial"
      continue
    fi

    # Obtener el nombre del juego usando la API de GameTDB
    game_name=$(get_game_name "$serial")

    # Si no se encuentra el nombre del juego, usar el serial como nombre
    if [ -z "$game_name" ]; then
      echo "No se encontró el nombre del juego para el serial $serial. Usando el serial como nombre." # Línea de depuración
      game_name=$serial
    fi

    # Crear el nombre del enlace simbólico
    symlink_name="$retropie_roms_dir/${game_name// /_}.PS3/PS3_GAME"

    # Crear el directorio destino si no existe
    mkdir -p "$(dirname "$symlink_name")"

    # Crear el enlace simbólico
    ln -sf "$game_dir" "$symlink_name"
    
    echo "Enlace simbólico creado: $symlink_name -> $game_dir"
  fi
done

echo "Todos los enlaces simbólicos se han creado correctamente."

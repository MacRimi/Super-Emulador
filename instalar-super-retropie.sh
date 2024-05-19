#!/bin/bash

# Asegurarse de que el script se ejecute con permisos de superusuario
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecute este script como root."
  exit 1
fi

# Función para comprobar si el volumen lógico está usando todo el espacio disponible
check_volume() {
  local LV_PATH=$(lvscan | grep "ACTIVE" | awk '{print $4}' | tr -d "'")
  if [ -z "$LV_PATH" ]; then
    echo "No se pudo determinar la ruta del volumen lógico. Asegúrate de que el volumen lógico está activo."
    exit 1
  fi

  local FREE_SPACE=$(vgdisplay | grep "Free  PE / Size" | awk '{print $5}')
  if [ "$FREE_SPACE" -gt 0 ]; then
    return 1
  else
    return 0
  fi
}

# Función para extender el volumen lógico
extend_volume() {
  local LV_PATH=$(lvscan | grep "ACTIVE" | awk '{print $4}' | tr -d "'")
  echo "Extendiendo el volumen lógico..."
  lvextend -l +100%FREE "$LV_PATH"
  if [ $? -ne 0 ]; then
    echo "Error al extender el volumen lógico."
    exit 1
  fi

  echo "Redimensionando el sistema de archivos..."
  resize2fs "$LV_PATH"
  if [ $? -ne 0 ]; then
    echo "Error al redimensionar el sistema de archivos."
    exit 1
  fi

  echo "El volumen lógico y el sistema de archivos se han extendido correctamente."
}

# Función para instalar RetroPie
install_retropie() {
  # Verificar si expect está instalado, si no, instalarlo
  if ! command -v expect &> /dev/null; then
    echo "El paquete expect no está instalado. Instalándolo..."
    apt-get update
    apt-get install -y expect
  fi

  # Descargar el script bootstrap.sh
  wget -q https://raw.githubusercontent.com/MizterB/RetroPie-Setup-Ubuntu/master/bootstrap.sh

  # Ejecutar el script bootstrap.sh
  bash ./bootstrap.sh

  # Simular presionar Enter para aceptar el disclaimer y continuar con la instalación (usando expect)
  expect << EOF
  spawn sudo ./RetroPie-Setup-Ubuntu/retropie_setup_ubuntu.sh
  expect {
      "Press any key to continue" { send "\r"; exp_continue }
      "RetroPie Setup" { send "\r"; exp_continue }
      "Exit" { send "\r" }
  }
EOF

  # Reboot del sistema
  reboot
}

# Función para mostrar el menú y capturar la selección del usuario
show_menu() {
  while true; do
    opciones=$(dialog --checklist "Seleccione los scripts a ejecutar:" 20 60 2 \
        1 "Instalar RetroPie" off \
        2 "Extender disco a su máxima capacidad" off 3>&1 1>&2 2>&3 3>&-)

    respuesta=$?

    if [[ $respuesta -eq 1 || $respuesta -eq 255 ]]; then
        clear
        echo "Instalación cancelada o salida del script."
        exit 1
    fi

    # Confirmar la selección
    dialog --yesno "¿Desea continuar con la instalación de los scripts seleccionados?" 10 60 3>&1 1>&2 2>&3 3>&-
    if [[ $? -eq 0 ]]; then
        break
    fi
  done

  clear
  for opcion in $opciones; do
    case $opcion in
        1)
            if ! check_volume; then
                dialog --yesno "El volumen de instalación no está usando toda la capacidad del disco, esto podría ocasionar que pudieras quedarte sin espacio pronto. ¿Quieres expandir la capacidad del disco y luego instalar RetroPie?" 10 60
                if [[ $? -eq 0 ]]; then
                    extend_volume
                fi
            fi
            echo "Instalando RetroPie..."
            install_retropie
            ;;
        2)
            echo "Extendiendo disco a su máxima capacidad..."
            extend_volume
            ;;
    esac
  done
}

# Inicio del script
check_volume
show_menu

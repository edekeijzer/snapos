#!/bin/bash

set -e

for arg in "$@"
do
	case "${arg}" in
		--add-audio)

      SNAPOS_OVERLAY_NAME=$(sed -n 's/^BR2_SNAPOS_OVERLAY_NAME=\"\(.*\)\"$/\1/p' ${BR2_CONFIG})

      if grep -q "^BR2_SNAPOS_OVERLAY=y" ${BR2_CONFIG} ; then
        # If overlay is specified in config, comment dtparam=audio line
        sed -i -e 's/^\(dtparam=audio=.*$\)/# \1/' "${BINARIES_DIR}/rpi-firmware/config.txt"
        # If any dtoverlay line for currently specified is present, uncomment it
        if grep -q "^#*\s*dtoverlay=${SNAPOS_OVERLAY_NAME}\s*$" "${BINARIES_DIR}/rpi-firmware/config.txt" ; then
          sed -i -e "s/^#\s*\(dtoverlay=${SNAPOS_OVERLAY_NAME}\)\s*/\1/" "${BINARIES_DIR}/rpi-firmware/config.txt"
        else
          # If not present, add the line
          echo -e "\ndtoverlay=${SNAPOS_OVERLAY_NAME}" >> "${BINARIES_DIR}/rpi-firmware/config.txt"
        fi
      else
        # If no overlay is specified in config, check if dtparam=audio is available
        # in any form and uncomment it and set to on
        if grep -q "^#*\s*dtparam=audio=.*$" "${BINARIES_DIR}/rpi-firmware/config.txt" ; then
          sed -i -e 's/^.*\(dtparam=audio=\).*$/\1on/' "${BINARIES_DIR}/rpi-firmware/config.txt"
        else
          # If no dtparam=audio line is available, just add it
          echo -e "\ndtparam=audio=on" >> "${BINARIES_DIR}/rpi-firmware/config.txt"
        fi
        # Replace any present config line for the specified overlay file
        sed -i -e "s/^\(dtoverlay=${SNAPOS_OVERLAY_NAME}\)/# \1/" "${BINARIES_DIR}/rpi-firmware/config.txt"
      fi
		;;
		--speedup-boot)
		if ! grep -qE '^bootcode_delay=' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
			echo "Setting boot delays to 0"
			cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

# Speed up boot
bootcode_delay=0
boot_delay=0
boot_delay_ms=0
disable_splash=1
__EOF__
		fi
		;;
	esac

done

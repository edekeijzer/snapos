#!/bin/sh

set -u
set -e

for arg in "$@"
do
  case "${arg}" in
    --add-wlan0)
    if ! grep -qE '^iface wlan0' "${TARGET_DIR}/etc/network/interfaces"; then

      SNAPOS_WIFI_SSID=$(sed -n 's/^BR2_SNAPOS_WIFI_SSID=\"\(.*\)\"$/\1/p' ${BR2_CONFIG})
      SNAPOS_WIFI_KEY=$(sed -n 's/^BR2_SNAPOS_WIFI_KEY=\"\(.*\)\"$/\1/p' ${BR2_CONFIG})

      if grep -q "^BR2_SNAPOS_WIFI_AP=y" ${BR2_CONFIG} ; then
        SNAPOS_WIFI_IP=$(sed -n 's/^BR2_SNAPOS_WIFI_IP=\"\(.*\)\"$/\1/p' ${BR2_CONFIG})
        SNAPOS_WIFI_NETMASK=$(sed -n 's/^BR2_SNAPOS_WIFI_NETMASK=\"\(.*\)\"$/\1/p' ${BR2_CONFIG})
        echo "Adding wlan0 to /etc/network/interfaces."
        cat << __EOF__ >> "${TARGET_DIR}/etc/network/interfaces"

auto wlan0
iface wlan0 inet static
    address ${SNAPOS_WIFI_IP}
    netmask ${SNAPOS_WIFI_NETMASK}
    pre-up wpa_supplicant -B -D nl80211 -i wlan0 -c /etc/wpa_supplicant.conf
    post-down killall -q wpa_supplicant
    wait-delay 15
__EOF__

        echo "Adding SSID and PSK to /etc/wpa_supplicant.conf."
        cat << __EOF__ >> "${TARGET_DIR}/etc/wpa_supplicant.conf"
ctrl_interface=/run/wpa_supplicant
fast_reauth=1
update_config=1
ap_scan=2

network={
    ssid="${SNAPOS_WIFI_SSID}"
    psk="${SNAPOS_WIFI_KEY}"
    mode=2
    key_mgmt=WPA-PSK
    proto=RSN
    pairwise=CCMP
}
__EOF__
      else
        echo "Adding wlan0 to /etc/network/interfaces."
        cat << __EOF__ >> "${TARGET_DIR}/etc/network/interfaces"

auto wlan0
iface wlan0 inet dhcp
    pre-up wpa_supplicant -B -D nl80211 -i wlan0 -c /etc/wpa_supplicant.conf
    post-down killall -q wpa_supplicant
    wait-delay 15
__EOF__
        echo "Adding SSID and PSK to /etc/wpa_supplicant.conf."
        cat << __EOF__ >> "${TARGET_DIR}/etc/wpa_supplicant.conf"
ctrl_interface=/run/wpa_supplicant
fast_reauth=1
update_config=1
ap_scan=1

network={
    ssid="${BR2_SNAPOS_WIFI_SSID}"
    psk="${BR2_SNAPOS_WIFI_KEY}"
}
__EOF__
      fi
    fi
    ;;
    --mount-boot)
    if ! grep -qE '^/dev/mmcblk0p1' "${TARGET_DIR}/etc/fstab"; then
      mkdir -p "${TARGET_DIR}/boot"
      echo "Adding mount point for /boot to /etc/fstab."
      cat << __EOF__ >> "${TARGET_DIR}/etc/fstab"
/dev/mmcblk0p1  /boot    vfat  defaults  0  2
__EOF__
    fi
    ;;
    --raise-volume)
    if grep -qE '^ENV{ppercent}:=\"75%\"' "${TARGET_DIR}/usr/share/alsa/init/default"; then
      echo "Raising alsa default volume to 100%."
      sed -i -e 's/ENV{ppercent}:="75%"/ENV{ppercent}:="100%"/g' "${TARGET_DIR}/usr/share/alsa/init/default"
      sed -i -e 's/ENV{pvolume}:="-20dB"/ENV{pvolume}:="4dB"/g' "${TARGET_DIR}/usr/share/alsa/init/default"
    fi
    ;;
  esac

done

SNAPOS_OVERLAY_NAME=$(sed -n 's/^BR2_SNAPOS_OVERLAY_NAME=\"\(.*\)\"$/\1/p' ${BR2_CONFIG})

if grep -q "^BR2_SNAPOS_OVERLAY=y" ${BR2_CONFIG} ; then
  sed -i -e 's/^\(dtparam=audio=.*$\)/# \1/' "${BINARIES_DIR}/rpi-firmware/config.txt"
  if grep -q "^#*\s*dtoverlay=${SNAPOS_OVERLAY_NAME}" "${BINARIES_DIR}/rpi-firmware/config.txt" ; then
    sed -i -e "s/^#\s*\(dtoverlay=${SNAPOS_OVERLAY_NAME}\)/\1/" "${BINARIES_DIR}/rpi-firmware/config.txt"
  else
    echo "dtoverlay=${SNAPOS_OVERLAY_NAME}" >> "${BINARIES_DIR}/rpi-firmware/config.txt"
  fi
else
  sed -i -e 's/^.*\(dtparam=audio=\).*$/\1on/' "${BINARIES_DIR}/rpi-firmware/config.txt"
  sed -i -e "s/^\(dtoverlay=${SNAPOS_OVERLAY_NAME}\)/# \1/" "${BINARIES_DIR}/rpi-firmware/config.txt"
fi

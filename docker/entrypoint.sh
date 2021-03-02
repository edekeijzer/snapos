#!/usr/bin/env bash

BUILDROOT_REPO=${BUILDROOT_REPO:-'git://git.buildroot.net/buildroot'}
BUILDROOT_VERSION=${BUILDROOT_VERSION:-'2020.11.x'}

SNAPOS_REPO=${SNAPCAST_REPO:-'git://github.com/edekeijzer/snapos'}
SNAPOS_VERSION=${SNAPCAST_VERSION:-'master'}
sync_git () {
    pushd $2 >/dev/null
    git pull 2>/dev/null || git clone "$1" "$2"
    if [ ! -z "$3" ] ; then
      echo "Switching to branch $3"
      git checkout "$3"
    fi
    popd >/dev/null
}

copy_file () {
  MYFILE="${1:-sdcard.img}"
  IMAGEDIR="${1:-/image}"
  if [ -e "$/buildroot/output/image/${MYFILE}" ] ; then
    cp "/buildroot/output/image/${MYFILE}" "${IMAGEDIR%/*}/${MYFILE%.*}-$(date +%y%m%d_%H%M)${MYFILE##*.}"
  else
    [ "$MYFILE" == "zImage" ] && MYCOMMAND="make linux" || MYCOMMAND="make"
    echo "File ${MYFILE} not found, please run \"${MYCOMMAND}\" first!"
  fi
}

make_defconfig () {
  pushd /buildroot >/dev/null
  case $1 in
    raspberrypi0w)
      DEFCONFIG="snapos_rpi0w_defconfig"
    ;;
    raspberrypi1)
      DEFCONFIG="snapos_rpi1_defconfig"
    ;;
    raspberrypi2)
      DEFCONFIG="snapos_rpi2_defconfig"
    ;;
    raspberrypi3)
      DEFCONFIG="snapos_rpi3_defconfig"
    ;;
    raspberrypi4)
      DEFCONFIG="snapos_rpi4_defconfig"
    ;;
    *)
      echo "Unknown type: $1"
      exit 1
    ;;
  esac
  make BR2_EXTERNAL=/snapos/buildroot-external/ $DEFCONFIG
  popd >/dev/null
}

check_dir () {
  if [ -e "/{1}/.empty" ] ; then
    echo "File .empty found in directory ${1}, cannot continue"
    exit 1
  else
    echo "Output directory ${1} appears to be mounted"
  fi
}

show_help () {
  echo "This should be implemented"
}

case $1 in
  check)
    [ $(ls -1 /buildroot | wc -l) -eq 0 ] && echo "Directory /buildroot is empty" || echo "Files found in directory /buildroot"
    [ $(ls -1 /snapos | wc -l) -eq 0 ] && echo "Directory /snapos is empty" || echo "Files found in directory /snapos"
    check_dir "/image"
  ;;
  git)
    if [ "$2" != "snapos" ] ; then
      sync_git $BUILDROOT_REPO "/buildroot" $BUILDROOT_VERSION
    fi
    if [ "$2" != "buildroot" ] ; then
      sync_git $SNAPOS_REPO "/snapos" $SNAPOS_VERSION
    fi
  ;;
  defconfig)
    if [ -z "$2" ] ; then
      echo "Please specify a device to set up the defconfig for"
      exit 1
    else
      make_defconfig $2
    fi
  ;;
  copy)
    check_dir "/image" || exit 1
    copy_sdcard "/image"
  ;;
  all)
    echo "Checking prerequisite"
    check_dir "/image" || exit 1
    echo "Fetching sources, please return in a few minutes to do some configuration - press any key to continue or wait 15 seconds"
    timeout 15s bash -c read
    $0 git || exit 1
    $0 defconfig $2 || exit 1
    $0 make menuconfig
    echo "Pour yourself a drink, this will take a while - press any key to continue or wait 15 seconds"
    timeout 15s bash -c read
    $0 make
    $0 copy
  ;;
  help)
    show_help
  ;;
  *)
    if [ $(ls -1 | wc -l) -eq 0 ] ; then
      echo "Empty directory found, cloning first"
      sync_git $BUILDROOT_REPO "/buildroot" $BUILDROOT_VERSION
      sync_git $SNAPOS_REPO "/snapos" $SNAPOS_VERSION
    fi
    pushd /buildroot >/dev/null
    echo "Command: $*"
    eval "FORCE_UNSAFE_CONFIGURE=1 $*"
    popd >/dev/null
  ;;
esac

exit $?

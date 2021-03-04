#!/usr/bin/env bash

BUILDROOT_REPO=${BUILDROOT_REPO:-'git://git.buildroot.net/buildroot'}
BUILDROOT_VERSION=${BUILDROOT_VERSION:-'master'}

SNAPOS_REPO=${SNAPCAST_REPO:-'git://github.com/edekeijzer/snapos'}
SNAPOS_VERSION=${SNAPCAST_VERSION:-'master'}

export BR2_CCACHE_DIR="/ccache"
export BR2_DL_DIR="/download"

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
  OUTPUT_DIR="${1:-/image}"
  MYFILE="${2:-sdcard.img}"
  if [ -e "/buildroot/output/images/${MYFILE}" ] ; then
    echo "Copying ${MYFILE} from container to ${MYFILE}-$(date +%y%m%d_%H%M)"
    cp "/buildroot/output/images/${MYFILE}" "${OUTPUT_DIR%}/${MYFILE}-$(date +%y%m%d_%H%M)"
    cp "/buildroot/output/images/${MYFILE}" "${OUTPUT_DIR%/*}/${MYFILE%.*}-$(date +%y%m%d_%H%M)${MYFILE##*.}"
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
  if [ -e "/{1}/.snapos-empty" ] ; then
    echo "File .snapos-empty found in directory ${1}, cannot continue"
    false
  else
    echo "Output directory ${1} appears to be mounted"
  fi
}

show_help () {
  cat << __EOF__
Usage: docker run --rm -it -e BUILDROOT_VERSION="2020.11.x" -v $PWD:/image -v $PWD/download:/download -v $PWD/ccache:/ccache -v $PWD/snapos:/snapos -v $PWD/buildroot:/buildroot snapos-builder:0.2
Possible commands:

help - show this help

check - check if /buildroot and /snapos contain some data (TODO: check if repo with right version is present) and if /image has a volume from the host mounted to it

git [buildroot|snapos] - without the second option, clone/pull both repos, otherwise just do the one specified

defconfig <board name> - apply a defconfig to the buildroot repo. Possible values: raspberrypi0w, raspberrypi1, raspberrypi2, raspberrypi3, raspberrypi4

copy [filename] - copy a file from the created images to the /image directory. If no name is specified, copy sdcard.img (which can be flashed onto an SD card)

all <board name> - all of the above. Check image dir, fetch sources from git, apply defconfig for <board name>, then allow you to do some specific settings for your environment. After that, fetch sources, build a toolchain, a kernel and the rest of the system and then copy the file to the directory mounted to /image.


Any other command will be executed as-is, so if you'd just want to enter a shell inside the container to try some things, enter 'bash' as a command. The working dir is /buildroot, so you can execute any buildroot command directly as well.
__EOF__
}

case $1 in
  check)
    FAULT=0
    if [ $(ls -1 /buildroot | wc -l) -eq 0 ] ; then 
      echo "Directory /buildroot is empty" >&2
      FAULT=1
    else
      pushd /buildroot >/dev/null
      if [ "$(git remote get-url --all origin)" == "${BUILDROOT_REPO}" ] ; then
        echo "Buildroot repo found in directory /buildroot"
      else
        echo "Found files in /buildroot, but not the correct repo" >&2
        FAULT=1
      fi
      popd >/dev/null
    fi
    if [ $(ls -1 /snapos | wc -l) -eq 0 ] ; then
      echo "Directory /snapos is empty" >&2
      FAULT=1
    else
      pushd /snapos >/dev/null
      if [ "$(git remote get-url --all origin)" == "${SNAPOS_REPO}" ] ; then
        echo "SnapOS repo found in directory /snapos"
      else
        echo "Found files in /snapos, but not the correct repo, $(git remote get-url --all origin) does not equal ${SNAPOS_REPO}" >&2
        FAULT=1
      fi
      popd >/dev/null
    fi
    check_dir "/image" || FAULT=1
    [ $FAULT -gt 0 ] && exit 1
  ;;
  git)
    if [ -z "$2" ] || [ "$2" == "buildroot" ] ; then
      sync_git $BUILDROOT_REPO "/buildroot" $BUILDROOT_VERSION
    fi
    if [ -z "$2" ] || [ "$2" != "snapos" ] ; then
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
    copy_file "/image" "${2}"
  ;;
  all)
    echo "Checking prerequisite"
    check_dir "/image" || exit 1
    echo "Fetching sources, please return in a few minutes to do some configuration"
    $0 git || exit 1
    $0 defconfig $2 || exit 1
    $0 make menuconfig
    echo "Pour yourself a drink, this will take a while"
    $0 make source
    $0 make uclibc
    $0 make toolchain
    $0 make linux
    $0 make busybox
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
    # This is needed to use buildroot as root.
    eval "FORCE_UNSAFE_CONFIGURE=1 $*"
    popd >/dev/null
  ;;
esac

exit $?

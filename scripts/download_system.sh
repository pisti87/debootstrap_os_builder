#!/bin/bash
set -euo pipefail

########################################
# Project root
########################################
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/.config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: .config not found! Run config.sh first."
    exit 1
fi

source "$CONFIG_FILE"

########################################
# Logging
########################################
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/system_$(date +%F_%H-%M-%S).log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1 #exec > >(tee -a "$LOG_DIR/bootstrap.log") 2>&1

# Változók ellenőrzése / Variables checking
: "${CHROOT_DIR:?CHROOT_DIR not set in .config}"
: "${DISTRO_COMPAT_VERSION:?DISTRO_COMPAT_VERSION not set}"
: "${DISTRO_NAME:?$DISTRO_NAME not set}"
: "${DISTRO_VERSION:?$DISTRO_VERSION not set}"
: "${KERNEL_VERSION:?KERNEL_VERSION not set}"
: "${KERNEL_FLAVOUR:?KERNEL_FLAVOUR not set}"
: "${SYSTEM_ROOT:?SYSTEM_ROOT not set}"
: "${ARCH:?ARCH not set}"
: "${LIVE_USER:?LIVE_USER not set}"
: "${DEBOOTSTRAP_VARIANT:?DEBOOTSTRAP_VARIANT not set}"
: "${DEBOOTSTRAP_COMPONENTS:?DEBOOTSTRAP_COMPONENTS not set}"
: "${DEVUAN_MIRROR_DEFAULT:?DEVUAN_MIRROR_DEFAULT not set}"
: "${BOOT_MODE:?BOOT_MODE not set}"

SUITE="$DISTRO_COMPAT_VERSION"
COMPONENTS="$DEBOOTSTRAP_COMPONENTS"
MIRROR="$DEVUAN_MIRROR_DEFAULT"

########################################
# Csomaglista (BASE)
########################################
BASE_INCLUDE="
adwaita-icon-theme 
hicolor-icon-theme
gnome-icon-theme
alsa-utils
apulse
apt
ca-certificates
curl
dbus
dbus-x11
dunst
evince
ffmpeg
firmware-atheros
firmware-b43-installer
firmware-iwlwifi
firmware-linux-nonfree
firmware-realtek
firmware-linux-nonfree
gawk
geany
gettext
grub-pc
gvfs
gtk2-engines-murrine 
gtk2-engines-pixbuf
initramfs-tools
locales-all
libgl1-mesa-dri
libglu1-mesa
libglx-mesa0
librsvg2-common
libva-glx2
lxappearance
lxappearance-obconf
lxinput
lxpanel
lxpolkit
lxrandr
lxtask
lxterminal
mesa-utils
mesa-vulkan-drivers
netbase
network-manager
ntfs-3g
udevil
uuid-runtime
usb-modeswitch
usbutils
uuid-runtime
sudo
simplescreenrecorder
squashfs-tools
tzdata
vim
wget
wireless-tools
wireless-regdb
wpasupplicant
zenity
ifupdown
iproute2
procps 
xserver-xorg
xinit
xscreensaver
xserver-xorg
xserver-xorg-core
xserver-xorg-input-synaptics
xserver-xorg-video-all
xserver-xorg-video-intel
zstd
"

LIVE_INCLUDE="
live-boot
live-tools
live-config
linux-image-$ARCH
"

########################################
# Összevonás INCLUDES változóba
########################################
# -------------------------------------------------
# LIVE vs CUSTOM mód
# -------------------------------------------------
if [[ "$BOOT_MODE" == "custom" ]]; then
    echo ">>> CUSTOM mód: saját kernel és initrd készül"
INCLUDES="$BASE_INCLUDE"
else
INCLUDES="$BASE_INCLUDE $LIVE_INCLUDE"
fi

# CSV formátum (debootstrap --include)
INCLUDES="$(echo "$INCLUDES" | sed 's/[ \t]*#.*//' | sed '/^$/d' | tr '\n' ',' | sed 's/,$//')"

echo "INCLUDES kész:"
echo "$INCLUDES"

########################################
# Könyvtár előkészítés
########################################
echo ">>> SYSTEM_ROOT előkészítés: $SYSTEM_ROOT"
if [ "$(ls -A "$SYSTEM_ROOT")" ]; then
    echo "Korábbi system root törlése..."
echo "Unmountolás..."
umount -lf "$SYSTEM_ROOT/dev/pts" || true
umount -lf "$SYSTEM_ROOT/dev" || true
umount -lf "$SYSTEM_ROOT/proc" || true
umount -lf "$SYSTEM_ROOT/sys" || true
    rm -rf "$SYSTEM_ROOT"
    mkdir -p "$SYSTEM_ROOT"
fi
mkdir -p "$SYSTEM_ROOT"

#####################################################
echo "DISTRO_COMPAT_VERSION = $DISTRO_COMPAT_VERSION"
echo "ARCH = $ARCH"
echo "MIRROR = $MIRROR"
####################################################

########################################
# Debootstrap
########################################
echo ">>> Debootstrap indítása..."
if ! command -v debootstrap >/dev/null 2>&1; then
    echo "HIBA: debootstrap nincs telepítve!"
    exit 1
fi
set +e
debootstrap \
  --arch="$ARCH" \
  --variant="$DEBOOTSTRAP_VARIANT" \
  --components="$COMPONENTS" \
  --include="$INCLUDES" \
  "$SUITE" \
  "$SYSTEM_ROOT" \
  "$MIRROR"

DEBOOTSTRAP_RC=$?
set -e

########################################
# Chroot mountok
########################################
echo "Chroot mountok..."
for d in dev dev/pts proc sys; do 
    mkdir -p "$SYSTEM_ROOT/$d"
done

#######################################
#nem vagyok benne biztos hogy szükséges e a mount előtti rész
mountpoint -q "$SYSTEM_ROOT/dev"     || mount --bind /dev     "$SYSTEM_ROOT/dev"
mountpoint -q "$SYSTEM_ROOT/dev/pts" || mount --bind /dev/pts "$SYSTEM_ROOT/dev/pts"
mountpoint -q "$SYSTEM_ROOT/proc"    || mount --bind /proc    "$SYSTEM_ROOT/proc"
mountpoint -q "$SYSTEM_ROOT/sys"     || mount --bind /sys     "$SYSTEM_ROOT/sys"

chroot "$SYSTEM_ROOT" dpkg --configure -a || true
chroot "$SYSTEM_ROOT" apt-get update -y
chroot "$SYSTEM_ROOT" apt-get -f install -y

echo ">>> Bootstrap kész"

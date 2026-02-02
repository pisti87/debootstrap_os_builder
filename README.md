# debootstrap_os_builder
Test-phase project for building an operating system using debootstrap. Currently supports amd64 architecture. It currently does not yet includes a Puppy-based persistence save. Planned support for Raspberry Pi and Orange Pi as smartphone alternatives. Modular and open to modification with author credit. Thanks to Kulusz and Antonio for their help.



boot_mode=liveboot testing and okay
   .config file 
```
   # ==============================================configuration
# Automatikusan generált fájl – NE szerkeszd kézzel
# Automatically generated – DO NOT EDIT
# ==============================================
# --- Project ---
PROJECT_DIR="/mnt/sda1/teszt16"
SCRIPT_DIR="/mnt/sda1/teszt16/scripts"


# --- System ---
DISTRO_NAME="Devuan"
DISTRO_COMPAT_VERSION="excalibur"
DISTRO_VERSION="6"
ARCH="amd64"
KARCH="amd64"

# --- Kernel ---
KERNEL_VERSION="system"
KERNEL_FLAVOUR="system"
PAE_KERNEL="no"

# --- Boot ---
BOOT_MODE="liveboot"

# --- Paths ---
CHROOT="/mnt/sda1/teszt16/chroot"
CHROOT_DIR="/mnt/sda1/teszt16/chroot"
SYSTEM_ROOT="/mnt/sda1/teszt16/chroot/downloads/system"
KERNEL_ROOT="/mnt/sda1/teszt16/chroot/downloads/kernel"
BUILD_DIR="/mnt/sda1/teszt16/chroot/build"
BUILD_KERNEL="/mnt/sda1/teszt16/chroot/build/kernel"
BUILD_SYSTEM="/mnt/sda1/teszt16/chroot/build/system"
BUILD_INITRD="/mnt/sda1/teszt16/chroot/build/initrd"
DISTRO_CONFIG="/mnt/sda1/teszt16/chroot/DISTRO_CONFIG"
CONFIG_ROOT="/mnt/sda1/teszt16/chroot/DISTRO_CONFIG/excalibur_system_system"
OUTPUT_DIR="/mnt/sda1/teszt16/chroot/output"
ISO_DIR="/mnt/sda1/teszt16/ISO"

# --- Build defaults ---
_LOCALE="hu"
LIVE_USER="live"
APT_NO_RECOMMENDS="true"
APT_NO_SUGGESTS="true"

# --- Debootstrap ---
#DEBOOTSTRAP_VARIANT="minbase"
DEBOOTSTRAP_VARIANT="buildd"

DEBOOTSTRAP_COMPONENTS="main,contrib,non-free,non-free-firmware"
DEVUAN_MIRROR_DEFAULT="https://mirror.ungleich.ch/mirror/packages/devuan/merged"
#DEVUAN_MIRROR_DEFAULT="http://deb.debian.org/debian"
# --- Live ---
LIVE_DIR_NAME="live"
INITRD_NAME="initrd.img"
VMLINUX_NAME="vmlinuz"

# --- Version ---
WOOF_VERSION="9"

# --- Boot mód kiválasztása ---
# liveboot = a letöltött rendszer kernel+initrd-jét használjuk
# custom   = saját kernel + saját initrd
#BOOT_MODE="liveboot"
#BOOT_MODE="custom"
#BOOT_MODE="liveboot

#Ez minden mást vezérel:
#make_initrd.sh
#make_iso.sh
```

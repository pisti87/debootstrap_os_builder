#!/bin/bash
set -euo pipefail

########################################
# Rendszer (építő) konfiguráció betöltése / Load build system configuration
########################################
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/.config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: .config not found! Run config.sh first."
    exit 1
fi

# Csak a szükséges változók betöltése / Load only required variables
source "$CONFIG_FILE"

: "${CHROOT_DIR:?CHROOT_DIR nincs beállítva a rendszer .config-ban / not set in .config}"
: "${DISTRO_COMPAT_VERSION:?DISTRO_COMPAT_VERSION nincs beállítva / not set}"
: "${KERNEL_VERSION:?KERNEL_VERSION nincs beállítva / not set}"
: "${KERNEL_FLAVOUR:?KERNEL_FLAVOUR nincs beállítva / not set}"
: "${KERNEL_ROOT:?KERNEL_ROOT nincs beállítva / not set}"
: "${BUILD_KERNEL:?BUILD_KERNEL nincs beállítva / not set}"
: "${DISTRO_CONFIG:?DISTRO_CONFIG nincs beállítva / not set}"

########################################
# Kernel build környezet / Kernel build environment
########################################
export ARCH=x86_64
#export ARCH=$ARCH
export CROSS_COMPILE=

KERNEL_SRC="$KERNEL_ROOT/linux-$KERNEL_VERSION"
BUILD_DIR="$BUILD_KERNEL"

# Ellenőrzés: kernel forrás létezik-e / Check kernel source exists
#if [[ ! -d "$KERNEL_SRC" ]]; then
if [[ -n "${KERNEL_CFG:-}" && -f "$KERNEL_CFG" ]]; then
    echo "Hiba: kernel forrás könyvtár nem létezik / kernel source not found: $KERNEL_SRC"
    exit 1
fi

if [[ ! -f "$KERNEL_SRC/Makefile" ]]; then
    echo "Hiba: kernel forrás hibás (Makefile hiányzik) / kernel Makefile missing: $KERNEL_SRC"
    exit 1
fi

mkdir -p "$BUILD_DIR"

echo "=============================================="
echo " Kernel fordítás / Kernel build"
echo "=============================================="
echo "Kernel verzió / Version : $KERNEL_VERSION"
echo "Kernel flavour / Flavour: $KERNEL_FLAVOUR"
echo "Forrás / Source         : $KERNEL_SRC"
echo "Kimenet / Output        : $BUILD_DIR"
echo ""

cd "$KERNEL_SRC"

########################################
# Alap kernel konfiguráció / Base kernel config
########################################
if [[ ! -f .config ]]; then
    echo "Alap defconfig létrehozása / Creating base defconfig..."
    make defconfig
fi


# CONFIG_ROOT a config.sh-ból jön, biztosan definiált
KCFG_DIR="$CONFIG_ROOT"
KERNEL_CFG="$KCFG_DIR/kernel_config.cfg"
# Biztonsági mentés a jelenlegi kernel configról / Backup current config
cp -f .config .config.backup

# restore the bacup file
# Visszaállítható a kernel eredeti configja, ha szükséges / Restore original config if needed
# mv -f .config.backup .config

########################################
# Kernel config merge (csak a kernelre!) / Merge kernel config
########################################


#if [[ -f "$KERNEL_CFG" ]]; then
#    echo "Kernel config merge a $KERNEL_CFG alapján / Merging kernel config from $KERNEL_CFG..."
#    # Az első 4 sor átugrása, Kulusz scriptje alapján / skip first 4 lines
#    tail -n +5 "$KERNEL_CFG" >> .config
#else
#    echo "Nincs kernel config merge fájl / No kernel config merge file found."
#fi

########################################
# Konfig frissítés / Update kernel config
########################################
echo "Kernel konfiguráció frissítése / Updating kernel config..."
yes "" | make menuconfig

########################################
# Kernel fordítás / Kernel compilation
########################################
echo "Kernel fordítása / Compiling kernel..."
make -j"$(nproc)"

########################################
# Modulok telepítése / Install kernel modules
########################################
#echo "Modulok telepítése / Installing kernel modules..."
#MODULES_OUT="$BUILD_DIR/modules"
#make modules_install INSTALL_MOD_PATH="$MODULES_OUT"

########################################
# Kernel image / Kernel image
########################################
VMLINUX_SRC="arch/x86/boot/bzImage"
VMLINUX_DST="$BUILD_DIR/vmlinuz"

if [[ ! -f "$VMLINUX_SRC" ]]; then
    echo "Hiba: kernel image nem található / kernel image not found: $VMLINUX_SRC"
    exit 1
fi

cp -f "$VMLINUX_SRC" "$VMLINUX_DST"

########################################
# Kész / Done
########################################
echo ""
echo "Kernel fordítás kész / Kernel build completed!"
echo "vmlinuz: $VMLINUX_DST"
echo ""


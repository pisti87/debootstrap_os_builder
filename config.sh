#!/bin/bash
set -euo pipefail

#############################################
# Puppy build system
# Konfigurációs előkészítő script
#############################################
SKIP_CONFIG=0 # .config betöltése

#############################################
# Projekt gyökér meghatározása
# Project root detection
#############################################
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CONFIG_FILE="$DIR/.config"

#############################################
# Build verzió
# Build version
#############################################
BUILD_VERSION=9
WOOF_VERSION="$BUILD_VERSION"

#############################################
# Könyvtárstruktúra (ABSZOLÚT, KÖZPONTI)
# Directory structure (absolute, central)
#############################################

# Projekt könyvtár
# Project directory
PROJECT_DIR="$DIR"

# Script könyvtár
# Script directory
SCRIPT_DIR="$PROJECT_DIR/scripts"

# Chroot gyökér
# Chroot root
CHROOT="$PROJECT_DIR/chroot"
CHROOT_DIR="$CHROOT"

# Letöltések
# Downloads
SYSTEM_ROOT="$CHROOT/downloads/system"
KERNEL_ROOT="$CHROOT/downloads/kernel"

# Build kimenetek
# Build outputs
BUILD_DIR="$CHROOT/build"
BUILD_KERNEL="$BUILD_DIR/kernel"
BUILD_SYSTEM="$BUILD_DIR/system"
BUILD_INITRD="$BUILD_DIR/initrd"

# Distro specifikus kernel configok
# Distro specific kernel configs
DISTRO_CONFIG="$CHROOT/DISTRO_CONFIG"

# ISO kimenet
# ISO output
ISO_DIR="$PROJECT_DIR/ISO"

# Végső kimenet
# Final output
OUTPUT_DIR="$CHROOT/output"

#############################################
# Build alapértelmezések
# Build defaults
#############################################
_LOCALE="hu"
LIVE_USER="live"

APT_NO_RECOMMENDS="true"
APT_NO_SUGGESTS="true"

#############################################
# Debootstrap alapértelmezések
# Debootstrap defaults
#############################################
DEBOOTSTRAP_VARIANT="minbase"
DEBOOTSTRAP_COMPONENTS="main,contrib,non-free,non-free-firmware"
DEVUAN_MIRROR_DEFAULT="https://mirror.ungleich.ch/mirror/packages/devuan/merged"

#############################################
# Live rendszer alap változók
# Live system defaults
#############################################
LIVE_DIR_NAME="live"
INITRD_NAME="initrd.img"
VMLINUX_NAME="vmlinuz"

#############################################
# Root jogosultság ellenőrzése
# Root privilege check
#############################################
if [[ "$(id -u)" -ne 0 ]]; then
    echo "HIBA: root jogosultság szükséges"
    echo "ERROR: must be run as root"
    exit 1
fi

#############################################
# Könyvtárak létrehozása
# Create directory structure
#############################################
echo "*** Könyvtárstruktúra létrehozása / Creating directories ***"

mkdir -p \
    "$SCRIPT_DIR" \
    "$CHROOT" \
    "$SYSTEM_ROOT" \
    "$KERNEL_ROOT" \
    "$BUILD_KERNEL" \
    "$BUILD_SYSTEM" \
    "$BUILD_INITRD" \
    "$DISTRO_CONFIG" \
    "$OUTPUT_DIR" \
    "$ISO_DIR"

#############################################
# Elérési utak visszajelzése (KÖTELEZŐ)
# Path echo (MANDATORY)
#############################################

echo "=============================================="
echo " Projekt elérési utak / Project paths"
echo "----------------------------------------------"
echo "PROJECT_DIR   : $PROJECT_DIR"
echo "SCRIPT_DIR    : $SCRIPT_DIR"
echo "CHROOT        : $CHROOT"
echo "SYSTEM_ROOT   : $SYSTEM_ROOT"
echo "KERNEL_ROOT   : $KERNEL_ROOT"
echo "BUILD_DIR     : $BUILD_DIR"
echo "DISTRO_CONFIG : $DISTRO_CONFIG"
echo "ISO_DIR       : $ISO_DIR"
echo "=============================================="
echo ""

#############################################
# Meglévő .config kezelése – új logika
#############################################
if [[ -f "$CONFIG_FILE" ]]; then
    echo "Meglévő konfiguráció található: $CONFIG_FILE"
    read -rp "Felülírjam? (i/n): " OW
    if [[ "$OW" != "i" ]]; then
        echo "Konfiguráció megtartva."
        while true; do
            read -rp "Folytatjuk a build folyamatot a meglévő konfigurációval? (ok/exit): " CONT
            case "$CONT" in
                ok)
                    echo "Folytatás a meglévő konfigurációval..."
                    SKIP_CONFIG=1
                    break
                    ;;
                exit)
                    echo "Kilépés a felhasználó által. Semmi nem történik."
                    exit 0
                    ;;
                *)
                    echo "Csak 'ok' vagy 'exit' adható meg!"
                    ;;
            esac
        done
    fi
fi

#############################################
# Felhasználói konfiguráció
# User configuration
#############################################
if [[ "$SKIP_CONFIG" -eq 0 ]]; then
echo "*** Rendszer konfiguráció ***"

read -rp "Distro neve (pl. Devuan): " DISTRO_NAME
read -rp "Distro kompatibilitás (daedalus/excalibur): " DISTRO_COMPAT_VERSION
read -rp "Distro verzió (pl. 6): " DISTRO_VERSION
read -rp "Architektúra (amd64): " ARCH

echo
echo "*** Kernel konfiguráció ***"

#############################################
# Architektúra → kernel arch
# Architecture → kernel arch
#############################################
PAE_KERNEL="no"
KARCH=""
case "$ARCH" in
    i386|i486|i586|i686) KARCH="686" ;;
    amd64)              KARCH="amd64" ;;
    arm64|aarch64)      KARCH="arm64" ;;
    *)
        echo "Ismeretlen architektúra: $ARCH"
        exit 1
        ;;
esac

#############################################
# BOOT MODE kiválasztása
#############################################
echo
echo "*** Boot mód kiválasztása ***"
echo "  liveboot = letöltött rendszer kernel + initrd"
echo "  custom   = saját kernel + saját initrd"

while true; do
    read -rp "BOOT_MODE (liveboot/custom): " BOOT_MODE
    case "$BOOT_MODE" in
        liveboot|custom)
            break
            ;;
        *)
            echo "HIBA: csak 'liveboot' vagy 'custom' adható meg!"
            ;;
    esac
done

#############################################
# Kernel konfiguráció BOOT_MODE szerint
#############################################

if [[ "$BOOT_MODE" == "custom" ]]; then
    echo
    echo "*** Custom kernel konfiguráció ***"

    read -rp "Kernel verzió (pl. 6.18.1): " KERNEL_VERSION

    echo "Elérhető flavourök:"
    echo "  huge | pae | zen"
    read -rp "Kernel flavour: " KERNEL_FLAVOUR

    # PAE csak 32 bitnél értelmes
    if [[ "$ARCH" =~ ^i[3-6]86$ ]]; then
        while true; do
            read -rp "PAE kernel? (yes/no): " PAE_KERNEL
            case "$PAE_KERNEL" in
                yes|no) break ;;
                *) echo "Csak yes vagy no!" ;;
            esac
        done
    fi

else
    # liveboot esetén nincs saját kernel
    KERNEL_VERSION="system"
    KERNEL_FLAVOUR="system"
    PAE_KERNEL="no"
fi


#############################################
# Kernel config gyökér
# Kernel config root
#############################################
CONFIG_ROOT="$DISTRO_CONFIG/${DISTRO_COMPAT_VERSION}_${KERNEL_VERSION}_${KERNEL_FLAVOUR}"
mkdir -p "$CONFIG_ROOT"

#############################################
# .config fájl létrehozása
# Create .config file
#############################################


cat > "$CONFIG_FILE" << EOF
# ==============================================configuration
# Automatikusan generált fájl – NE szerkeszd kézzel
# Automatically generated – DO NOT EDIT
# ==============================================
# --- Project ---
PROJECT_DIR="$PROJECT_DIR"
SCRIPT_DIR="$SCRIPT_DIR"

# --- System ---
DISTRO_NAME="$DISTRO_NAME"
DISTRO_COMPAT_VERSION="$DISTRO_COMPAT_VERSION"
DISTRO_VERSION="$DISTRO_VERSION"
ARCH="$ARCH"
KARCH="$KARCH"

# --- Kernel ---
KERNEL_VERSION="$KERNEL_VERSION"
KERNEL_FLAVOUR="$KERNEL_FLAVOUR"
PAE_KERNEL="$PAE_KERNEL"

# --- Boot ---
BOOT_MODE="$BOOT_MODE"

# --- Paths ---
CHROOT="$CHROOT"
CHROOT_DIR="$CHROOT_DIR"
SYSTEM_ROOT="$SYSTEM_ROOT"
KERNEL_ROOT="$KERNEL_ROOT"
BUILD_DIR="$BUILD_DIR"
BUILD_KERNEL="$BUILD_KERNEL"
BUILD_SYSTEM="$BUILD_SYSTEM"
BUILD_INITRD="$BUILD_INITRD"
DISTRO_CONFIG="$DISTRO_CONFIG"
CONFIG_ROOT="$CONFIG_ROOT"
OUTPUT_DIR="$OUTPUT_DIR"
ISO_DIR="$ISO_DIR"

# --- Build defaults ---
_LOCALE="$_LOCALE"
LIVE_USER="$LIVE_USER"
APT_NO_RECOMMENDS="$APT_NO_RECOMMENDS"
APT_NO_SUGGESTS="$APT_NO_SUGGESTS"

# --- Debootstrap ---
DEBOOTSTRAP_VARIANT="$DEBOOTSTRAP_VARIANT"
DEBOOTSTRAP_COMPONENTS="$DEBOOTSTRAP_COMPONENTS"
DEVUAN_MIRROR_DEFAULT="$DEVUAN_MIRROR_DEFAULT"

# --- Live ---
LIVE_DIR_NAME="$LIVE_DIR_NAME"
INITRD_NAME="$INITRD_NAME"
VMLINUX_NAME="$VMLINUX_NAME"

# --- Version ---
WOOF_VERSION="$WOOF_VERSION"

# --- Boot mód kiválasztása ---
# liveboot = a letöltött rendszer kernel+initrd-jét használjuk
# custom   = saját kernel + saját initrd
#BOOT_MODE="liveboot"
#BOOT_MODE="custom"

EOF

#############################################
# Kész
#############################################
echo
echo "Konfiguráció elkészült: $CONFIG_FILE"
echo "BOOT_MODE = $BOOT_MODE"
echo "Kernel config könyvtár: $CONFIG_ROOT"
echo
else
    echo "Konfigurációs lépések kihagyva – meglévő .config betöltése."
    source "$CONFIG_FILE"
fi

#!/bin/bash
set -euo pipefail

#############################################
# Kernel forrás letöltő script
# Kernel source download script
#############################################

#############################################
# Konfiguráció betöltése
# Load build configuration
#############################################

CONFIG_FILE="$(cd "$(dirname "$0")/.." && pwd)/.config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "HIBA: .config nem található!"
    echo "ERROR: .config not found! Run config.sh first."
    exit 1
fi

source "$CONFIG_FILE"

#############################################
# Kötelező változók ellenőrzése
# Required variables check
#############################################

: "${KERNEL_VERSION:?KERNEL_VERSION nincs beállítva}"
: "${KERNEL_ROOT:?KERNEL_ROOT nincs beállítva}"
: "${PROJECT_DIR:?PROJECT_DIR nincs beállítva}"

#############################################
# Kernel verzió → kernel.org branch
# Kernel version → kernel.org branch
#
# Példa / Example:
# 6.18.3 → v6.x
#############################################

KERNEL_MAJOR="${KERNEL_VERSION%%.*}"
KERNEL_BRANCH="v${KERNEL_MAJOR}.x"

KERNEL_TARBALL="linux-${KERNEL_VERSION}.tar.xz"
KERNEL_URL="https://www.kernel.org/pub/linux/kernel/${KERNEL_BRANCH}/${KERNEL_TARBALL}"

#############################################
# Könyvtárak
# Directories
#############################################

SRC_DIR="$KERNEL_ROOT/linux-$KERNEL_VERSION"

echo "=============================================="
echo " Kernel letöltés / Kernel download"
echo "----------------------------------------------"
echo "Kernel verzió : $KERNEL_VERSION"
echo "Kernel branch : $KERNEL_BRANCH"
echo "Forrás URL    : $KERNEL_URL"
echo "Cél könyvtár  : $SRC_DIR"
echo "=============================================="
echo ""

mkdir -p "$KERNEL_ROOT"

#############################################
# Régi forrás eltávolítása (VÉDETT)
# Remove old source (SAFE)
#############################################

if [[ -d "$SRC_DIR" ]]; then
    echo "Régi kernel forrás törlése:"
    echo "  $SRC_DIR"
    if [[ "$SRC_DIR" == "$KERNEL_ROOT"/linux-* ]]; then
        rm -rf "$SRC_DIR"
    else
        echo "HIBA: veszélyes törlés megakadályozva!"
        exit 1
    fi
fi

cd "$KERNEL_ROOT"

#############################################
# Letöltés
# Download
#############################################

echo "Kernel letöltése..."
if ! wget -q --show-progress "$KERNEL_URL"; then
    echo "HIBA: kernel nem érhető el:"
    echo "  $KERNEL_URL"
    exit 1
fi

#############################################
# Kicsomagolás
# Extract
#############################################

echo "Kicsomagolás..."
tar -xf "$KERNEL_TARBALL"
rm -f "$KERNEL_TARBALL"

#############################################
# Ellenőrzés
# Verification
#############################################

if [[ ! -f "$SRC_DIR/Makefile" ]]; then
    echo "HIBA: kernel forrás hibás (Makefile hiányzik)"
    exit 1
fi

#############################################
# Kész
#############################################

echo ""
echo "Kernel forrás sikeresen letöltve!"
echo "Forrás könyvtár:"
echo "  $SRC_DIR"
echo ""

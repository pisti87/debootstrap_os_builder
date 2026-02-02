#!/bin/bash
set -euo pipefail

# -------------------------------------------------
# Projekt gyökér / Project root
# -------------------------------------------------
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/.config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: .config not found! Run config.sh first."
    exit 1
fi
source "$CONFIG_FILE"

# -------------------------------------------------
# Logging
# -------------------------------------------------
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/make_squashfs_$(date +%F_%H-%M-%S).log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

# -------------------------------------------------
# Változók / Variables
# -------------------------------------------------
: "${SYSTEM_ROOT:?SYSTEM_ROOT nincs beállítva}"
: "${BUILD_SYSTEM:?BUILD_SYSTEM nincs beállítva}"

# -------------------------------------------------
# Forrás és kimenet könyvtár / Source and output directories
# -------------------------------------------------
SYSTEM_SRC="$SYSTEM_ROOT"
OUTDIR="$BUILD_SYSTEM"
SFS="$OUTDIR/filesystem.squashfs"

# -------------------------------------------------
# Ellenőrzések / Checks
# -------------------------------------------------
echo "ARCH      = ${ARCH:-unknown}"
echo "SYSTEM    = $SYSTEM_SRC"
echo "OUTPUT    = $SFS"

if [[ ! -d "$SYSTEM_SRC" ]]; then
    echo "HIBA: SYSTEM_ROOT nem létezik: $SYSTEM_SRC"
    exit 1
fi

if [[ "$SYSTEM_SRC" == "/" ]]; then
    echo "HIBA: SYSTEM_ROOT nem lehet /"
    exit 1
fi

# -------------------------------------------------
# Könyvtár előkészítés / Prepare directories
# -------------------------------------------------
mkdir -p "$OUTDIR"
rm -f "$SFS"

echo "=============================================="
echo " filesystem.squashfs készítése / Creating filesystem.squashfs"
echo " Forrás / Source:  $SYSTEM_SRC"
echo " Kimenet / Output: $SFS"
echo "=============================================="

# -------------------------------------------------
# SquashFS build / Build SquashFS
# -------------------------------------------------
mksquashfs "$SYSTEM_SRC" "$SFS" \
  -comp xz \
  -noappend \
  -wildcards \
  -e \
    var/cache/apt \
    var/lib/apt/lists \
    etc/machine-id

# -------------------------------------------------
# Kész / Done
# -------------------------------------------------
echo ""
echo "KÉSZ filesystem.squashfs / SquashFS build completed!"
echo "Méret / Size:"
du -h "$SFS"
echo "=============================================="

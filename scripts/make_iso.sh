#!/bin/bash
set -euo pipefail

# -------------------------------------------------
# Project root
# -------------------------------------------------
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/.config"

[[ -f "$CONFIG_FILE" ]] || { echo "ERROR: .config not found"; exit 1; }
source "$CONFIG_FILE"

# -------------------------------------------------
# Logging
# -------------------------------------------------
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/iso_$(date +%F_%H-%M-%S).log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================"
echo " ISO build indult"
echo " BOOT_MODE = $BOOT_MODE"
echo " ARCH      = $ARCH"
echo "========================================"

# -------------------------------------------------
# Kötelező változók
# -------------------------------------------------
: "${DISTRO_NAME:?}"
: "${DISTRO_VERSION:?}"
: "${ARCH:?}"
: "${BOOT_MODE:?}"
: "${SYSTEM_ROOT:?}"
: "${BUILD_SYSTEM:?}"
: "${CHROOT:?}"

# -------------------------------------------------
# Host ellenőrzés
# -------------------------------------------------
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "HIBA: hiányzó host parancs: $1"
        exit 1
    }
}

require_cmd grub-mkrescue
require_cmd grub-mkstandalone
require_cmd xorriso
require_cmd lsinitramfs

# -------------------------------------------------
# ISO utak
# -------------------------------------------------
ISO_WORK="$CHROOT/iso"
OUT="$PROJECT_DIR/ISO"
ISO_NAME="${DISTRO_NAME}-${DISTRO_VERSION}-${ARCH}.iso"
SFS="$BUILD_SYSTEM/filesystem.squashfs"

# -------------------------------------------------
# Előkészítés
# -------------------------------------------------
rm -rf "$ISO_WORK"
mkdir -p "$ISO_WORK"/{boot/grub,EFI/BOOT,live}

# -------------------------------------------------
# Kernel + initrd kiválasztása
# -------------------------------------------------
if [[ "$BOOT_MODE" == "liveboot" ]]; then
    echo ">>> LIVEBOOT mód – rendszer kernel"

    ls "$SYSTEM_ROOT"/boot/vmlinuz-* >/dev/null 2>&1 || {
        echo "HIBA: liveboot mód, de nincs kernel a rendszerben"
        exit 1
    }

    KERNEL_BASENAME="$(basename "$(ls "$SYSTEM_ROOT"/boot/vmlinuz-* | sort -V | tail -n1)")"
    VMLINUX="$SYSTEM_ROOT/boot/$KERNEL_BASENAME"
    INITRD_IMG="$SYSTEM_ROOT/boot/initrd.img-${KERNEL_BASENAME#vmlinuz-}"

    [[ -f "$INITRD_IMG" ]] || {
        echo "HIBA: initrd nem található ehhez a kernelhez!"
        exit 1
    }

#    if ! lsinitramfs "$INITRD_IMG" | grep -q live-boot; then
#        echo "HIBA: initrd nem tartalmaz live-boot-ot"
#        exit 1
#
#    fi

elif [[ "$BOOT_MODE" == "custom" ]]; then
    echo ">>> CUSTOM mód – builder kernel"

    VMLINUX="$BUILD_KERNEL/vmlinuz"
    INITRD_IMG="$BUILD_INITRD/initrd.img"

else
    echo "HIBA: ismeretlen BOOT_MODE=$BOOT_MODE"
    exit 1
fi

# -------------------------------------------------
# Ellenőrzések
# -------------------------------------------------
for f in "$VMLINUX" "$INITRD_IMG" "$SFS"; do
    [[ -f "$f" ]] || { echo "HIBA: hiányzó fájl: $f"; exit 1; }
done

# -------------------------------------------------
# Fájlok másolása (HELYES ÚTVONAL!)
# -------------------------------------------------
cp "$VMLINUX"    "$ISO_WORK/vmlinuz"
cp "$INITRD_IMG" "$ISO_WORK/initrd"
cp "$SFS"        "$ISO_WORK/live/filesystem.squashfs"

# -------------------------------------------------
# GRUB config (live-boot kompatibilis)
# -------------------------------------------------
cat > "$ISO_WORK/boot/grub/grub.cfg" <<EOF
set default=0
set timeout=5

menuentry "${DISTRO_NAME} ${DISTRO_VERSION} Live" {
    linux /vmlinuz boot=live components persistence swap quiet rootdelay=5
    initrd /initrd
}
EOF

# -------------------------------------------------
# EFI
# -------------------------------------------------
case "$ARCH" in
  amd64|x86_64)
    EFI_TARGET="x86_64-efi"
    EFI_BOOT="BOOTX64.EFI"
    ;;
  *)
    echo "HIBA: nem támogatott EFI arch: $ARCH"
    exit 1
    ;;
esac

grub-mkstandalone \
  -O "$EFI_TARGET" \
  -o "$ISO_WORK/EFI/BOOT/$EFI_BOOT" \
  "boot/grub/grub.cfg=$ISO_WORK/boot/grub/grub.cfg"

# -------------------------------------------------
# ISO készítés
# -------------------------------------------------
mkdir -p "$OUT"

grub-mkrescue \
  -o "$OUT/$ISO_NAME" \
  "$ISO_WORK" \
  --compress=xz

# -------------------------------------------------
# MD5
# -------------------------------------------------
(
  cd "$OUT"
  md5sum "$ISO_NAME" > "${ISO_NAME}.md5"
)

echo "========================================"
echo " ISO KÉSZ"
echo "  $OUT/$ISO_NAME"
echo " MD5 KÉSZ"
echo "${ISO_NAME}.md5"
echo " Log: $LOG_FILE"
echo "========================================"

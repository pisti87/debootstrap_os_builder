#!/bin/bash
set -euo pipefail

# -------------------------------------------------
# Project root / Projekt gyökér
# -------------------------------------------------
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/.config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: .config not found! Run config.sh first."
    exit 1
fi

# Csak a szükséges változók betöltése / Load only required variables
source "$CONFIG_FILE"

: "${CHROOT_DIR:?CHROOT_DIR not set in .config}"
: "${DISTRO_COMPAT_VERSION:?DISTRO_COMPAT_VERSION not set}"
: "${KERNEL_VERSION:?KERNEL_VERSION not set}"
: "${KERNEL_FLAVOUR:?KERNEL_FLAVOUR not set}"

# -------------------------------------------------
# Kernel modulok útvonal / Kernel modules path
# -------------------------------------------------
KERNEL_MODULES="$SYSTEM_ROOT/lib/modules/$KERNEL_VERSION"
echo "Kernel verzió / Kernel version: $KERNEL_VERSION"

# -------------------------------------------------
# INITRD útvonalak / Initrd paths
# -------------------------------------------------
OUT="$BUILD_DIR/initrd"
WORK="$OUT/work"
INITRD="$OUT/initrd.img"

# -------------------------------------------------
# Könyvtárstruktúra / Prepare directory structure
# -------------------------------------------------
rm -rf "$OUT"/*
mkdir -p "$WORK"/{bin,sbin,etc,proc,sys,dev,run,mnt,lower,upper,work,newroot,lib}

# -------------------------------------------------
# Moduláris kernel detektálása / Detect modular kernel
# -------------------------------------------------
if [ -d "$KERNEL_MODULES" ]; then
    echo ">>> Moduláris kernel / Modular kernel detected"
    MODULAR="yes"
else
    echo ">>> Nem moduláris kernel / Non-modular kernel"
    MODULAR="no"
fi

echo "$MODULAR" > "$WORK/etc/modular"

# -------------------------------------------------
# BUSYBOX telepítése / Install BusyBox
# -------------------------------------------------
BUSYBOX_BIN="$(command -v busybox)" || {
    echo "HIBA: busybox nem található! / BusyBox not found!"
    exit 1
}

cp -p "$BUSYBOX_BIN" "$WORK/bin/busybox"
chmod +x "$WORK/bin/busybox"

# létrehozzuk a legfontosabb linkeket / symlinks
for i in sh mount umount switch_root mkdir echo ls cat grep sleep modprobe; do
    ln -sf busybox "$WORK/bin/$i"
done

# -------------------------------------------------
# Kernel modulok másolása (ha moduláris) / Copy kernel modules if modular
# -------------------------------------------------
if [ "$MODULAR" = "yes" ]; then
    echo "Kernel modulok másolása... / Copying kernel modules..."
    mkdir -p "$WORK/lib/modules"
    cp -a "$KERNEL_MODULES" "$WORK/lib/modules/"
fi

# -------------------------------------------------
# INIT script létrehozása / Create init script
# -------------------------------------------------
cat > "$WORK/init" << 'EOF'
#!/bin/sh
set -e

echo "=== Puppy-style initrd ==="

# -------------------------------------------------
# Alap mountok / Basic mounts
# -------------------------------------------------
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /run

mkdir -p /mnt /lower /upper /work /newroot /pdrv /psave

MODULAR="$(cat /etc/modular 2>/dev/null)"

# -------------------------------------------------
# Modulok betöltése / Load kernel modules
# -------------------------------------------------
if [ "$MODULAR" = "yes" ]; then
    for m in loop squashfs overlay ext4 vfat nvme sd_mod usb_storage usbhid hid_generic; do
        modprobe "$m" 2>/dev/null || true
    done
fi

# -------------------------------------------------
# ROOTFS keresése (probe → select) / ROOTFS searching
# -------------------------------------------------
echo "Searching live/filesystem.squashfs..."
ROOTFS_FOUND=0

for d in /dev/sd[a-z]* /dev/nvme* /dev/mmcblk* /dev/sr0; do
    [ -b "$d" ] || continue

    mount "$d" /mnt 2>/dev/null || continue

    if [ -f /mnt/live/filesystem.squashfs ]; then
        echo "Rootfs found on $d"
        SAVEDEV="$d"
        umount /mnt        # probe → unmount
        ROOTFS_FOUND=1 #kérdés kell-e ide
        break
    fi

    umount /mnt
done

[ "$ROOTFS_FOUND" -eq 1 ] || { echo "NO ROOTFS found"; exec sh; }

# -------------------------------------------------
# SquashFS mount → lower  (mount filesystem)
# -------------------------------------------------
mount "$ROOTDEV" /mnt
mount -t squashfs /mnt/live/filesystem.squashfs /lower
umount /mnt

# -------------------------------------------------
# Mentés keresés / Find save overlay
# -------------------------------------------------
SAVEDEV=""
for d in /dev/sd[a-z]* /dev/nvme* /dev/mmcblk*; do
    mount "$d" /mnt 2>/dev/null || continue
    if [ -d /mnt/save ]; then
        SAVEDEV="$d"
        umount /mnt       # probe → unmount
        break
    fi
    umount /mnt
done

if [ -n "$SAVEDEV" ]; then
    echo "Save found on $SAVEDEV"
    mount "$SAVEDEV" /mnt
    mount --bind /mnt/save/upper /upper
    mount --bind /mnt/save/work /work
else
    echo "No save → tmpfs"
    mount -t tmpfs -o size=512M tmpfs /upper
    mount -t tmpfs -o size=512M tmpfs /work
fi

# -------------------------------------------------
# Overlay mount
# -------------------------------------------------
mount -t overlay overlay \
    -o lowerdir=/lower,upperdir=/upper,workdir=/work \
    /newroot || exec sh

# -------------------------------------------------
# SWITCH ROOT
# -------------------------------------------------
mount --move /dev /newroot/dev
mount --move /proc /newroot/proc
mount --move /sys /newroot/sys

exec switch_root /newroot /sbin/init
EOF

chmod +x "$WORK/init"

# -------------------------------------------------
# INITRD készítés / Create initrd
# -------------------------------------------------
(
    cd "$WORK"
    find . | cpio -o -H newc | gzip -9
) > "$INITRD"

echo "Initrd kész / Initrd ready: $INITRD"

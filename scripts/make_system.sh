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
    exec > >(tee -a "$LOG_FILE") 2>&1

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

########################################
# Here configuring the systems
########################################





########################################
# B43 firmware (opcionális)
########################################
SITE="https://sources.openwrt.org"

echo "B43 firmware keresése..."
B43_PKG="$(wget -q -O- "$SITE" | awk -F'<|>' '/\-wl\-.*[0-9]\.tar/{print $3}' | tail -1)"

if [ -n "$B43_PKG" ]; then
    echo "B43 firmware letöltése: $B43_PKG"
    wget -q "$SITE/$B43_PKG" -P "$SYSTEM_ROOT"
    tar -xf "$SYSTEM_ROOT/$B43_PKG" -C "$SYSTEM_ROOT"
    FILE="$(find "$SYSTEM_ROOT"/bro* -name '*apsta*' | sed "s|$SYSTEM_ROOT||")"
    chroot "$SYSTEM_ROOT" b43-fwcutter -w /lib/firmware "$FILE"
fi



###########################
# Chroot phase
########################################
chroot $SYSTEM_ROOT /bin/bash << 'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
dpkg --configure -a || true
apt-get update -y
apt-get upgrade -y || true
dpkg --configure -a || true
apt-get -f install -y

mkdir -p /home/live/.config

apt-get -f install   # Ha hiányzó függőségek vannak, ezt megoldja

apt-get update
apt-get upgrade -y

apt-get install -y \
  fonts-dejavu \
  fonts-noto-core \
  thonny \
  gpicview \
  vlc \
  chromium \
  thunderbird \
  mount \
  gparted \
  htop \
  gxmessage \
  gtk-chtheme \
  hardinfo
#    xfce4 \
#  xfce4-appfinder \
#  xfce4-panel \
#  xfce4-session \
#  xfce4-settings \
#  xfce4-terminal \
#  lightdm \
#  lightdm-gtk-greeter

# install phosh + gdm3
echo "[*] Phosh + GDM3 telepítése..."
apt install -y phosh gdm3

apt-get update
apt-get -y upgrade

########################################
# User: live user
########################################
useradd -m -s /bin/bash live
passwd -d live
usermod -aG sudo live
echo "live ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/live
chmod 440 /etc/sudoers.d/live
########################################
# User: live user (NO PASSWORD)
########################################
passwd -d root



# phosh autologin
cat > /etc/gdm3/custom.conf <<'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=live
WaylandEnable=true
DefaultSession=phosh

[security]

[xdmcp]
GDM

# phosh session
mkdir -p /var/lib/AccountsService/users
cat > /var/lib/AccountsService/users/live <<'SESSION'
[User]
Session=phosh
XSession=phosh
SESSION

chmod 600 /var/lib/AccountsService/users/live

# gdm alapértelmezés
# gdm default display manager
ln -sf /lib/systemd/system/gdm3.service \
      /etc/systemd/system/display-manager.service

# lightdm tiltás (ha létezne)
rm -f /etc/systemd/system/display-manager.service.d/lightdm.conf 2>/dev/null || true



#chmod +x /home/live/.config/autostart
chown -R live:live /home/live/.config

########################################
# Hostname & hosts
########################################
echo "phosh" > /etc/hostname
cat > /etc/hosts <<'HOSTS'
127.0.0.1 localhost
127.0.1.1 phosh
HOSTS

########################################
# setup lang settings
########################################
#cat > /etc/environment <<'EOB'
#LANG=hu_HU.UTF-8
#LANGUAGE=hu_HU.UTF-8
#LC_ALL=hu_HU.UTF-8
#LC_CTYPE=hu_HU.UTF-8
#EOB

########################################
# Cleanup
########################################
apt-get clean
# Clean up temporary .deb files
rm -f /var/cache/apt/archives/*.deb
rm -f /var/cache/apt/archives/partial/*.deb
# remove databases
rm -rf /var/lib/apt/lists/*merged*
rm -rf /debootstrap
rm -rf /var/lib/apt/lists/*
rm -f /maemo-keyring_2023.1+m7_all.deb

########################################
#  fixing start-stop-daemon
########################################
if [ -f /sbin/start-stop-daemon.REAL ]; then
  mv -f /sbin/start-stop-daemon.REAL /sbin/start-stop-daemon
fi

ln -fs "/proc/mounts" "/etc/mtab"
update-initramfs -u || true
EOF

cat > "$SYSTEM_ROOT/etc/environment" <<'EOF'
LANG=hu_HU.UTF-8
LANGUAGE=hu_HU.UTF-8
LC_ALL=hu_HU.UTF-8
LC_CTYPE=hu_HU.UTF-8
EOF

########################################
# Background
########################################
mkdir -p "$SYSTEM_ROOT/usr/share/backgrounds"
find "$SYSTEM_ROOT/usr/share/backgrounds" -mindepth 1 -delete
WALLPAPER_NAME="wallpaper4.png"
WALLPAPER_FINAL_NAME="DEFAULT-Wallpaper.jpg"
#WALLPAPER_URL="https://drive.google.com/uc?export=download&id=176zmyoG91N36BDaviqzTPL4ET-bpS6Wl"
WALLPAPER_URL="https://drive.google.com/file/d/19s-owYIz9PKaokG4IaIYH9XcTlL8a-to/view?usp=drive_link"
wget -O "$PROJECT_DIR/$WALLPAPER_NAME" "$WALLPAPER_URL"

cp "$PROJECT_DIR/$WALLPAPER_NAME" \
   "$SYSTEM_ROOT/usr/share/backgrounds/$WALLPAPER_FINAL_NAME"

rm -f "$PROJECT_DIR/$WALLPAPER_NAME"


cat > "$SYSTEM_ROOT/usr/share/gdm/greeter/autostart/orca-autostart.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Orca screen reader
Exec=orca --disable main-window,splash-window --enable speech,braille
NoDisplay=true
AutostartCondition=GSettings org.gnome.desktop.a11y.applications screen-reader-enabled
X-GNOME-AutoRestart=true
EOF
cat > "$SYSTEM_ROOT/usr/share/xdg-desktop-portal/phosh-portals.conf" <<'EOF'
[Desktop Entry]
[preferred]
default=phosh;gtk;
org.freedesktop.impl.portal.Access=phosh-shell;
org.freedesktop.impl.portal.Background=DEFAULT-Wallpaper.jpg;
org.freedesktop.impl.portal.Clipboard=none;
org.freedesktop.impl.portal.InputCapture=none;
org.freedesktop.impl.portal.RemoteDesktop=none;
org.freedesktop.impl.portal.ScreenCast=wlr;
org.freedesktop.impl.portal.Screenshot=gtk;wlr;
org.freedesktop.impl.portal.Secret=gnome-keyring;
EOF

cat > "$SYSTEM_ROOT/usr/share/wayland-sessions/phosh-desktop" <<'EOF'
[Desktop Entry]
Name=Phosh
Comment=Phone Shell
Comment=This session logs you into Phosh
Exec=phosh-session
Type=Application
DesktopNames=Phosh;GNOME;
EOF


cat > "$SYSTEM_ROOT/usr/lib/os-release" <<'EOF'
PRETTY_NAME="Devuan GNU/Linux 6 (excalibur)"
NAME="Devuan GNU/Linux"
VERSION_ID="6"
VERSION="6 (excalibur)"
VERSION_CODENAME="excalibur"
ID=devuan
ID_LIKE=debian
HOME_URL="https://www.devuan.org/"
SUPPORT_URL="https://devuan.org/os/community"
BUG_REPORT_URL="https://bugs.devuan.org/"

EOF




: <<'COMMENT'

COMMENT
echo "KÉSZ az alap rendszer"



########################################
# Későbbi fejlesztések
########################################

#persistence.conf példa
#🔹 frugal + savefile
#🔹 gdm3 profil
#🔹 teljes skin




########################################
# Unmount
########################################
echo "Unmountolás..."

umount -lf "$SYSTEM_ROOT/dev/pts" || true
umount -lf "$SYSTEM_ROOT/dev"     || true
umount -lf "$SYSTEM_ROOT/proc"    || true
umount -lf "$SYSTEM_ROOT/sys"     || true

########################################
# Kész
########################################
echo "========================================"
echo " KÉSZ $DISTRO_NAME $DISTRO_COMPAT_VERSION $DISTRO_VERSION Elkészült"
echo " Útvonal: $SYSTEM_ROOT"
echo " Log: $LOG_FILE"
echo "========================================"

#!/bin/bash

set -e
set -o pipefail

# -------------------------------------------------
# Projekt gyökér / Project root
# -------------------------------------------------
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

SCRIPT_DIR="$DIR/scripts"

# -------------------------------------------------
# Logging
# -------------------------------------------------
START_TIME="$(date +"%Y-%m-%d_%H-%M-%S")"
LOG_DIR="$DIR/logs"
LOG_FILE="$LOG_DIR/build_$START_TIME.log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

#Build starting
#Project dir
#Log files
echo "================================================="
echo " Build indítva: $START_TIME"
echo " Projekt könyvtár: $DIR"
echo " Log fájl: $LOG_FILE"
echo "================================================="
echo

# -------------------------------------------------
# Step runner
# -------------------------------------------------
run_step() {
    local NAME="$1"
    local SCRIPT="$2"
    local STEP_START STEP_END

#Error: Script not found
    if [[ ! -f "$SCRIPT" ]]; then
        echo "!!! HIBA: Script nem található: $SCRIPT"
        exit 1
    fi

#Error: Script notrunning
    if [[ ! -x "$SCRIPT" ]]; then
        echo "!!! HIBA: Script nem futtatható: $SCRIPT"
        echo "    Tipp: chmod +x $SCRIPT"
        exit 1
    fi

#Error: Syntact error the script
    if ! bash -n "$SCRIPT"; then
        echo "!!! HIBA: Szintaktikai hiba a scriptben: $SCRIPT"
        exit 1
    fi

#Build starting
    STEP_START="$(date +"%Y-%m-%d %H:%M:%S")"
    echo ">>> [$NAME] INDUL: $STEP_START"
    echo "    Script: $SCRIPT"

    bash "$SCRIPT"

    STEP_END="$(date +"%Y-%m-%d %H:%M:%S")"
    echo "<<< [$NAME] VÉGE:  $STEP_END"
    echo
}

# -------------------------------------------------
# Config futtatása (interaktív) / Run 1 step the config.sh
# -------------------------------------------------
if [[ -f "$DIR/config.sh" ]]; then
    echo ">>> [CONFIG] Konfiguráció futtatása: config.sh"
    bash "$DIR/config.sh"
    echo "<<< [CONFIG] Konfiguráció kész"
    echo
else
# config.sh not found
    echo "!!! HIBA: config.sh nem található!"
    exit 1
fi
# -------------------------------------------------
# .config betöltése (változók) / .config loading (variables)
# -------------------------------------------------
if [[ -f "$DIR/.config" ]]; then
    echo ">>> [CONFIG] .config betöltése"
    source "$DIR/.config"
    echo "<<< [CONFIG] .config betöltve"
    echo
else
    echo "!!! HIBA: .config nem található!"
    exit 1
fi

: "${BOOT_MODE:?BOOT_MODE nincs beállítva a config.sh-ban}"

echo ">>> BOOT_MODE = $BOOT_MODE"
echo

# -------------------------------------------------
# Build lépések (most nem kell) / Build steps 
# -------------------------------------------------
#run_step "System patch (host előfeltétel)" "$SCRIPT_DIR/system_patch.sh"

# -------------------------------------------------
# Kernel / initrd csak CUSTOM módban
# -------------------------------------------------
if [[ "$BOOT_MODE" == "custom" ]]; then
    echo ">>> CUSTOM mód: saját kernel és initrd készül"

    echo ">>> [MEGERŐSÍTÉS] Kernel patch fájl ellenőrzése"
    read -p "A kernel patch fájl biztosan a helyén van? (y/n): " ANSWER
    echo "Felhasználói válasz: $ANSWER"

    if [[ ! "$ANSWER" =~ ^[yY]$ ]]; then
        echo "MEGSZAKÍTVA felhasználó által: $(date +"%Y-%m-%d %H:%M:%S")"
        exit 1
    fi
    echo

    run_step "Kernel letöltés" "$SCRIPT_DIR/download_kernel.sh"

    run_step "Kernel build" "$SCRIPT_DIR/make_kernel.sh"
else
    echo ">>> LIVEBOOT mód: kernel és initrd lépések kihagyva"
    echo
fi

# -------------------------------------------------
# System build (mindig kell)
# -------------------------------------------------
run_step "System letöltés" "$SCRIPT_DIR/download_system.sh"
run_step "System letöltés" "$SCRIPT_DIR/make_system.sh"

run_step "SquashFS készítés" "$SCRIPT_DIR/make_squashfs.sh"

# -------------------------------------------------
# Initrd csak CUSTOM módban
# -------------------------------------------------
if [[ "$BOOT_MODE" == "custom" ]]; then
    run_step "Initrd készítés" "$SCRIPT_DIR/make_initrd.sh"

else
    echo ">>> LIVEBOOT mód: initrd készítés kihagyva"
    echo
fi

# -------------------------------------------------
# ISO
# -------------------------------------------------
run_step "ISO készítés" "$SCRIPT_DIR/make_iso.sh"

echo "================================================="
echo " Build SIKERESEN BEFEJEZVE: $(date +"%Y-%m-%d %H:%M:%S")"
echo "================================================="

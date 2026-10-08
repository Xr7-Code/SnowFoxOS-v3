#!/bin/bash
# ============================================================
#  SnowFoxOS v3 — TUI Installer
#  Runs on first boot of the installer ISO.
#  Handles: disk selection, partitioning, base install,
#           then hands off to auto-install.sh (install.sh).
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

# ── Colors & helpers ─────────────────────────────────────────
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${PURPLE}${BOLD}[SnowFox]${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()    { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}[FAILED]${RESET} $1"; exit 1; }

REPO_DIR="/opt/SnowFoxOS-v3"
MOUNT_TARGET="/mnt/snowfox-install"

# ── Wait for system to settle ────────────────────────────────
sleep 2
clear

# ── Welcome screen ───────────────────────────────────────────
dialog --colors \
    --backtitle "SnowFoxOS v3 Installer" \
    --title "Welcome" \
    --msgbox "\n\Z5\ZbSnowFoxOS v3\Zn\n\nA lean, privacy-oriented i3 desktop\nbased on Debian 12.\n\nThis installer will:\n  • Partition your disk\n  • Install a minimal Debian 12 base\n  • Configure SnowFoxOS automatically\n\n\Z1WARNING:\Zn All data on the selected disk\nwill be permanently deleted.\n\nPress ENTER to continue." \
    20 60

# ── Keyboard layout ──────────────────────────────────────────
KB_CHOICE=$(dialog --colors \
    --backtitle "SnowFoxOS v3 Installer" \
    --title "Keyboard Layout" \
    --menu "\nSelect your keyboard layout:" \
    15 50 6 \
    "de" "German" \
    "de_AT" "German (Austria)" \
    "us" "English (US)" \
    "gb" "English (UK)" \
    "fr" "French" \
    "es" "Spanish" \
    3>&1 1>&2 2>&3) || { clear; echo "Installer cancelled."; exit 0; }

# Apply keyboard layout immediately
loadkeys "$KB_CHOICE" 2>/dev/null || loadkeys us 2>/dev/null || true

# ── Username & Password ──────────────────────────────────────
while true; do
    NEW_USER=$(dialog --colors \
        --backtitle "SnowFoxOS v3 Installer" \
        --title "User Account" \
        --inputbox "\nEnter username (lowercase, no spaces):" \
        10 50 \
        3>&1 1>&2 2>&3) || { clear; echo "Installer cancelled."; exit 0; }

    # Validate: lowercase letters, digits, hyphens only
    if [[ "$NEW_USER" =~ ^[a-z][a-z0-9-]{1,30}$ ]]; then
        break
    else
        dialog --colors \
            --backtitle "SnowFoxOS v3 Installer" \
            --title "Invalid Username" \
            --msgbox "\nUsername must:\n  • Start with a lowercase letter\n  • Contain only a-z, 0-9, or -\n  • Be 2–31 characters long" \
            12 45
    fi
done

while true; do
    NEW_PASS=$(dialog --colors \
        --backtitle "SnowFoxOS v3 Installer" \
        --title "Password" \
        --passwordbox "\nEnter password for '$NEW_USER':" \
        10 50 \
        3>&1 1>&2 2>&3) || { clear; echo "Installer cancelled."; exit 0; }

    NEW_PASS2=$(dialog --colors \
        --backtitle "SnowFoxOS v3 Installer" \
        --title "Password" \
        --passwordbox "\nConfirm password:" \
        10 50 \
        3>&1 1>&2 2>&3) || { clear; echo "Installer cancelled."; exit 0; }

    if [[ "$NEW_PASS" == "$NEW_PASS2" && -n "$NEW_PASS" ]]; then
        break
    else
        dialog --colors \
            --backtitle "SnowFoxOS v3 Installer" \
            --title "Password Mismatch" \
            --msgbox "\nPasswords do not match or are empty.\nPlease try again." \
            10 45
    fi
done

# ── Hostname ─────────────────────────────────────────────────
NEW_HOSTNAME=$(dialog --colors \
    --backtitle "SnowFoxOS v3 Installer" \
    --title "Hostname" \
    --inputbox "\nEnter hostname for this machine:" \
    10 50 "snowfox" \
    3>&1 1>&2 2>&3) || NEW_HOSTNAME="snowfox"

[[ -z "$NEW_HOSTNAME" ]] && NEW_HOSTNAME="snowfox"

# ── Disk selection ───────────────────────────────────────────
# Build list of available disks (skip loop, ram, live devices)
DISK_LIST=()
while IFS= read -r disk; do
    DEV="/dev/$disk"
    SIZE=$(lsblk -dno SIZE "$DEV" 2>/dev/null || echo "?")
    MODEL=$(lsblk -dno MODEL "$DEV" 2>/dev/null | xargs || echo "Unknown")
    DISK_LIST+=("$DEV" "$SIZE — $MODEL")
done < <(lsblk -dno NAME | grep -E '^(sd|nvme|vd)' | sort)

[[ ${#DISK_LIST[@]} -eq 0 ]] && error "No suitable disks found."

TARGET_DISK=$(dialog --colors \
    --backtitle "SnowFoxOS v3 Installer" \
    --title "Select Installation Disk" \
    --menu "\n\Z1All data on the selected disk will be erased!\Zn\n\nAvailable disks:" \
    20 65 8 \
    "${DISK_LIST[@]}" \
    3>&1 1>&2 2>&3) || { clear; echo "Installer cancelled."; exit 0; }

# ── Partition layout ─────────────────────────────────────────
PART_SCHEME=$(dialog --colors \
    --backtitle "SnowFoxOS v3 Installer" \
    --title "Partition Layout" \
    --menu "\nSelect partition layout for $TARGET_DISK:" \
    18 65 4 \
    "auto_gpt"    "GPT + EFI (recommended, modern hardware)" \
    "auto_mbr"    "MBR (legacy BIOS, older hardware)" \
    "auto_gpt_home" "GPT + EFI + separate /home partition" \
    3>&1 1>&2 2>&3) || { clear; echo "Installer cancelled."; exit 0; }

# ── Final confirmation ───────────────────────────────────────
DISK_SIZE=$(lsblk -dno SIZE "$TARGET_DISK" 2>/dev/null || echo "?")
DISK_MODEL=$(lsblk -dno MODEL "$TARGET_DISK" 2>/dev/null | xargs || echo "Unknown")

dialog --colors \
    --backtitle "SnowFoxOS v3 Installer" \
    --title "Confirm Installation" \
    --yesno "\n\Z1LAST WARNING — This will erase:\Zn\n\n  Disk  : $TARGET_DISK\n  Size  : $DISK_SIZE\n  Model : $DISK_MODEL\n\n  User     : $NEW_USER\n  Hostname : $NEW_HOSTNAME\n  Layout   : $PART_SCHEME\n\nContinue?" \
    18 60 || { clear; echo "Installer cancelled."; exit 0; }

# ── Partitioning ─────────────────────────────────────────────
clear
echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${PURPLE}${BOLD}  Partitioning $TARGET_DISK...${RESET}"
echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# Wipe existing partition table
wipefs -a "$TARGET_DISK" 2>/dev/null || true
sgdisk --zap-all "$TARGET_DISK" 2>/dev/null || true
sleep 1

case "$PART_SCHEME" in
    auto_gpt)
        # GPT: 512MB EFI + rest root
        parted -s "$TARGET_DISK" \
            mklabel gpt \
            mkpart ESP fat32 1MiB 513MiB \
            set 1 esp on \
            mkpart primary ext4 513MiB 100%

        partprobe "$TARGET_DISK"
        sleep 2

        # Determine partition device names (nvme uses p1/p2, sda uses 1/2)
        if [[ "$TARGET_DISK" =~ nvme ]]; then
            EFI_PART="${TARGET_DISK}p1"
            ROOT_PART="${TARGET_DISK}p2"
        else
            EFI_PART="${TARGET_DISK}1"
            ROOT_PART="${TARGET_DISK}2"
        fi

        mkfs.fat -F32 -n EFI "$EFI_PART"
        mkfs.ext4 -L snowfox "$ROOT_PART"

        mkdir -p "$MOUNT_TARGET"
        mount "$ROOT_PART" "$MOUNT_TARGET"
        mkdir -p "$MOUNT_TARGET/boot/efi"
        mount "$EFI_PART" "$MOUNT_TARGET/boot/efi"

        FSTAB_EFI="UUID=$(blkid -s UUID -o value $EFI_PART)  /boot/efi  vfat  defaults  0  2"
        FSTAB_ROOT="UUID=$(blkid -s UUID -o value $ROOT_PART)  /  ext4  defaults,noatime  0  1"
        ;;

    auto_mbr)
        # MBR: 1MB BIOS boot gap + rest root
        parted -s "$TARGET_DISK" \
            mklabel msdos \
            mkpart primary ext4 1MiB 100% \
            set 1 boot on

        partprobe "$TARGET_DISK"
        sleep 2

        if [[ "$TARGET_DISK" =~ nvme ]]; then
            ROOT_PART="${TARGET_DISK}p1"
        else
            ROOT_PART="${TARGET_DISK}1"
        fi

        EFI_PART=""
        mkfs.ext4 -L snowfox "$ROOT_PART"

        mkdir -p "$MOUNT_TARGET"
        mount "$ROOT_PART" "$MOUNT_TARGET"

        FSTAB_ROOT="UUID=$(blkid -s UUID -o value $ROOT_PART)  /  ext4  defaults,noatime  0  1"
        FSTAB_EFI=""
        ;;

    auto_gpt_home)
        # GPT: 512MB EFI + 40GB root + rest home
        DISK_BYTES=$(lsblk -dno SIZE --bytes "$TARGET_DISK" 2>/dev/null || echo 0)
        # Only offer separate /home if disk is larger than ~60GB
        if [[ "$DISK_BYTES" -lt 64000000000 ]]; then
            warn "Disk too small for separate /home — using single root partition"
            PART_SCHEME="auto_gpt"
        fi

        parted -s "$TARGET_DISK" \
            mklabel gpt \
            mkpart ESP fat32 1MiB 513MiB \
            set 1 esp on \
            mkpart primary ext4 513MiB 40737MiB \
            mkpart primary ext4 40737MiB 100%

        partprobe "$TARGET_DISK"
        sleep 2

        if [[ "$TARGET_DISK" =~ nvme ]]; then
            EFI_PART="${TARGET_DISK}p1"
            ROOT_PART="${TARGET_DISK}p2"
            HOME_PART="${TARGET_DISK}p3"
        else
            EFI_PART="${TARGET_DISK}1"
            ROOT_PART="${TARGET_DISK}2"
            HOME_PART="${TARGET_DISK}3"
        fi

        mkfs.fat -F32 -n EFI "$EFI_PART"
        mkfs.ext4 -L snowfox "$ROOT_PART"
        mkfs.ext4 -L home    "$HOME_PART"

        mkdir -p "$MOUNT_TARGET"
        mount "$ROOT_PART" "$MOUNT_TARGET"
        mkdir -p "$MOUNT_TARGET/boot/efi"
        mkdir -p "$MOUNT_TARGET/home"
        mount "$EFI_PART"  "$MOUNT_TARGET/boot/efi"
        mount "$HOME_PART" "$MOUNT_TARGET/home"

        FSTAB_EFI="UUID=$(blkid -s UUID -o value $EFI_PART)   /boot/efi  vfat  defaults         0  2"
        FSTAB_ROOT="UUID=$(blkid -s UUID -o value $ROOT_PART)  /          ext4  defaults,noatime  0  1"
        FSTAB_HOME="UUID=$(blkid -s UUID -o value $HOME_PART)  /home      ext4  defaults,noatime  0  2"
        ;;
esac

success "Disk partitioned and mounted at $MOUNT_TARGET"

# ── Install Debian base system ────────────────────────────────
echo -e "\n${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${PURPLE}${BOLD}  Installing Debian 12 base system...${RESET}"
echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
info "This step installs the minimal Debian base — takes 1–3 minutes."

debootstrap \
    --arch=amd64 \
    --components=main,contrib,non-free,non-free-firmware \
    --include=sudo,locales,git,curl,wget,ca-certificates,gnupg,network-manager \
    bookworm \
    "$MOUNT_TARGET" \
    http://deb.debian.org/debian/

success "Debian 12 base installed"

# ── Configure base system ─────────────────────────────────────
info "Configuring base system..."

# fstab
{
    echo "$FSTAB_ROOT"
    [[ -n "${FSTAB_EFI:-}" ]]  && echo "$FSTAB_EFI"
    [[ -n "${FSTAB_HOME:-}" ]] && echo "$FSTAB_HOME"
    echo "tmpfs  /tmp  tmpfs  defaults,noatime,size=4G,mode=1777  0  0"
} > "$MOUNT_TARGET/etc/fstab"

# hostname
echo "$NEW_HOSTNAME" > "$MOUNT_TARGET/etc/hostname"
cat > "$MOUNT_TARGET/etc/hosts" << HOSTEOF
127.0.0.1   localhost
127.0.1.1   $NEW_HOSTNAME
::1         localhost ip6-localhost ip6-loopback
HOSTEOF

# apt sources
cat > "$MOUNT_TARGET/etc/apt/sources.list" << 'SRCEOF'
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
SRCEOF

success "Base system configured"

# ── Create user ───────────────────────────────────────────────
info "Creating user: $NEW_USER"

chroot "$MOUNT_TARGET" useradd -m -s /bin/bash -G sudo,video,audio,input,render,tty "$NEW_USER"
echo "$NEW_USER:$NEW_PASS" | chroot "$MOUNT_TARGET" chpasswd
# Root password same as user for emergency access
echo "root:$NEW_PASS" | chroot "$MOUNT_TARGET" chpasswd

success "User $NEW_USER created"

# ── Copy SnowFoxOS repo into installed system ─────────────────
info "Copying SnowFoxOS-v3 repo to installed system..."
mkdir -p "$MOUNT_TARGET/home/$NEW_USER"
cp -r "$REPO_DIR" "$MOUNT_TARGET/home/$NEW_USER/SnowFoxOS-v3"
chroot "$MOUNT_TARGET" chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/SnowFoxOS-v3"
success "Repo copied to /home/$NEW_USER/SnowFoxOS-v3"

# ── Copy auto-install script ──────────────────────────────────
cp /usr/local/bin/snowfox-auto-install "$MOUNT_TARGET/usr/local/bin/snowfox-auto-install"
chmod +x "$MOUNT_TARGET/usr/local/bin/snowfox-auto-install"

# ── Install GRUB ─────────────────────────────────────────────
echo -e "\n${PURPLE}${BOLD}  Installing bootloader...${RESET}"

# Bind mounts for chroot
mount --bind /dev     "$MOUNT_TARGET/dev"
mount --bind /dev/pts "$MOUNT_TARGET/dev/pts"
mount --bind /proc    "$MOUNT_TARGET/proc"
mount --bind /sys     "$MOUNT_TARGET/sys"
mount --bind /run     "$MOUNT_TARGET/run"

# Copy apt cache from live system to speed up chroot apt
mkdir -p "$MOUNT_TARGET/var/cache/apt/archives"
cp /var/cache/apt/archives/*.deb "$MOUNT_TARGET/var/cache/apt/archives/" 2>/dev/null || true

if [[ "$PART_SCHEME" == "auto_mbr" ]]; then
    chroot "$MOUNT_TARGET" bash -c "
        apt-get install -y grub-pc 2>/dev/null
        grub-install --target=i386-pc $TARGET_DISK
        update-grub
    "
else
    chroot "$MOUNT_TARGET" bash -c "
        apt-get install -y grub-efi-amd64 grub-efi-amd64-signed shim-signed 2>/dev/null
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=SnowFoxOS
        update-grub
    "
fi

success "Bootloader installed"

# ── Set keyboard layout in installed system ───────────────────
chroot "$MOUNT_TARGET" bash -c "
    apt-get install -y console-setup keyboard-configuration 2>/dev/null || true
" 2>/dev/null || true

cat > "$MOUNT_TARGET/etc/default/keyboard" << KBEOF
XKBMODEL=\"pc105\"
XKBLAYOUT=\"$KB_CHOICE\"
XKBVARIANT=\"\"
XKBOPTIONS=\"\"
BACKSPACE=\"guess\"
KBEOF

# ── Write firstboot service (runs install.sh on first login) ──
cat > "$MOUNT_TARGET/etc/systemd/system/snowfox-firstboot.service" << FBEOF
[Unit]
Description=SnowFoxOS First Boot Installer
After=network-online.target
Wants=network-online.target
ConditionPathExists=/home/$NEW_USER/SnowFoxOS-v3/install.sh

[Service]
Type=oneshot
ExecStart=/usr/local/bin/snowfox-auto-install $NEW_USER
StandardInput=tty
StandardOutput=journal+console
StandardError=journal+console
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
FBEOF

chroot "$MOUNT_TARGET" systemctl enable snowfox-firstboot.service 2>/dev/null || true

# ── Unmount ───────────────────────────────────────────────────
info "Finalizing..."
sync

umount "$MOUNT_TARGET/dev/pts" 2>/dev/null || true
umount "$MOUNT_TARGET/dev"     2>/dev/null || true
umount "$MOUNT_TARGET/proc"    2>/dev/null || true
umount "$MOUNT_TARGET/sys"     2>/dev/null || true
umount "$MOUNT_TARGET/run"     2>/dev/null || true

[[ -n "${HOME_PART:-}" ]] && umount "$MOUNT_TARGET/home"     2>/dev/null || true
[[ -n "${EFI_PART:-}" ]]  && umount "$MOUNT_TARGET/boot/efi" 2>/dev/null || true
umount "$MOUNT_TARGET" 2>/dev/null || true

# ── Done ─────────────────────────────────────────────────────
clear
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   SnowFoxOS v3 installed successfully!   ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "  User     : ${BOLD}$NEW_USER${RESET}"
echo -e "  Hostname : ${BOLD}$NEW_HOSTNAME${RESET}"
echo -e "  Disk     : ${BOLD}$TARGET_DISK${RESET}"
echo ""
echo -e "${ORANGE}${BOLD}  On first boot, SnowFoxOS will finish configuring"
echo -e "  the desktop automatically. This takes 3–12 minutes"
echo -e "  depending on your hardware and internet speed.${RESET}"
echo ""
echo -e "${PURPLE}${BOLD}  Remove the USB drive and press ENTER to reboot.${RESET}"
read -r

reboot

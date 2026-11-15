#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — Kernel and Drivers Setup
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

source "$SCRIPT_DIR/lib/utils.sh"

# iso-gpu: fail fast with exit 75
if [[ "${SNOWFOX_PHASE:-full}" == "iso-gpu" ]]; then
    if [[ "${SNOWFOX_NETWORK:-online}" == "offline" ]] || \
       ! curl -fsS --head --max-time 15 \
           "${DEBIAN_MIRROR:-https://deb.debian.org/debian}/dists/bookworm/Release" \
           >/dev/null 2>&1; then
        warn "Network unavailable — keeping the stock Debian kernel (exit 75)"
        install -d -m 0755 /var/lib/snowfox
        touch /var/lib/snowfox/firstboot-pending 2>/dev/null || true
        return 75 2>/dev/null || exit 75
    fi
fi

if [[ "${SNOWFOX_PHASE:-full}" == "full" ]]; then
    info "Configuring system locales (de_AT, en_US)..."
    apt-get install -y locales
    sed -i 's/^# *de_AT.UTF-8 UTF-8/de_AT.UTF-8 UTF-8/' /etc/locale.gen
    sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    grep -q "^de_AT.UTF-8 UTF-8" /etc/locale.gen || echo "de_AT.UTF-8 UTF-8" >> /etc/locale.gen
    grep -q "^en_US.UTF-8 UTF-8" /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    update-locale LANG=de_AT.UTF-8
    success "Locales set (de_AT.UTF-8, en_US.UTF-8)"
else
    info "ISO phase: keeping installer-selected locale"
fi

info "Checking CPU & system compatibility..."
USE_XANMOD=false
grep -q "avx2" /proc/cpuinfo && USE_XANMOD=true \
    || warn "CPU does not support AVX2 — using standard Debian kernel"

if lspci 2>/dev/null | grep -qi "AMD" && \
   [[ "$(cat /sys/class/dmi/id/product_name 2>/dev/null)" =~ "EliteDesk" ]]; then
    cat > /etc/udev/rules.d/99-xhci-raven-fix.rules <<'EOF'
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x15e0", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x15e1", ATTR{power/control}="on"
EOF
    success "Raven xHCI udev rule installed"
fi

info "Installing DKMS tools..."
wait_apt
apt-get install -y --no-install-recommends dkms libdw-dev clang lld llvm
success "DKMS tools installed"

if $USE_XANMOD; then
    info "Installing XanMod LTS kernel..."
    dpkg --configure -a 2>/dev/null || true
    apt-get -f install -y 2>/dev/null || true
    mkdir -p /etc/apt/keyrings
    if wget -qO - https://dl.xanmod.org/archive.key \
        | gpg --dearmor --yes -o /etc/apt/keyrings/xanmod-archive-keyring.gpg; then
        echo "deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org bookworm main" \
            > /etc/apt/sources.list.d/xanmod-release.list
        wait_apt; apt-get update -qq; wait_apt
        DEBIAN_FRONTEND=noninteractive apt-get install -y linux-xanmod-lts-x64v3 \
            && success "XanMod LTS kernel installed (active after reboot)" \
            || { warn "XanMod failed — falling back to Debian kernel"; USE_XANMOD=false; }
    else
        warn "XanMod GPG key download failed — falling back to Debian kernel"
        USE_XANMOD=false
    fi
fi

if ! $USE_XANMOD; then
    info "Installing standard Debian kernel (compatible with older hardware)..."
    apt-get install -y linux-image-amd64 linux-headers-amd64 firmware-linux
    success "Standard Debian kernel installed"
fi

# GRUB: fallback preserved via GRUB_DEFAULT=0 + timeout=3
if [[ -f /etc/default/grub ]]; then
    GRUB_PARAMS="quiet splash pci=noaer usbcore.autosuspend=-1"
    lspci 2>/dev/null | grep -qi nvidia && GRUB_PARAMS="$GRUB_PARAMS nvidia-drm.modeset=1"
    lspci 2>/dev/null | grep -qi amd    && GRUB_PARAMS="$GRUB_PARAMS iommu=pt amdgpu.noretry=0"
    $USE_XANMOD || GRUB_PARAMS="$GRUB_PARAMS acpi_osi=Linux"

    sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_PARAMS\"|" /etc/default/grub
    sed -i 's|^GRUB_DEFAULT=.*|GRUB_DEFAULT=0|' /etc/default/grub
    sed -i 's|^GRUB_TIMEOUT=.*|GRUB_TIMEOUT=3|' /etc/default/grub
fi
update-grub 2>/dev/null || true
success "Boot configuration updated (fallback entry preserved)"

apt-get install -y firmware-misc-nonfree 2>/dev/null || true

if lsusb 2>/dev/null | grep -qi "fritz\|0bda\|2357"; then
    modprobe mt76x2u 2>/dev/null \
        && success "Fritz USB AC 860 driver loaded" \
        || warn "Fritz USB driver not found — verify after reboot"
fi

cat > /etc/udev/rules.d/70-usb-wlan-power.rules <<'EOF'
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="057c", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", DRIVER=="mt76x2u", ATTR{power/control}="on"
EOF

if lspci -k 2>/dev/null | grep -qi "RTL8821CE"; then
    cat > /etc/modprobe.d/rtw88.conf <<'EOF'
options rtw88_core disable_lps_deep=y
options rtw88_pci disable_aspm=y
EOF
    modprobe rtw88_8821ce 2>/dev/null \
        && success "rtw88_8821ce module loaded" \
        || warn "rtw88_8821ce module not found — verify after reboot"
    echo "rtw88_8821ce" > /etc/modules-load.d/rtw88-8821ce.conf
fi

if grep -qi "AuthenticAMD" /proc/cpuinfo; then
    apt-get install -y amd64-microcode
    success "AMD CPU microcode installed"
else
    apt-get install -y intel-microcode
    success "Intel CPU microcode installed"
fi

step "2/10 — Hardware analysis & drivers"

GPU_INFO=$(lspci 2>/dev/null | grep -iE 'vga|3d|display')
HAS_NVIDIA=false; HAS_AMD=false; HAS_INTEL=false
echo "$GPU_INFO" | grep -qi "nvidia" && HAS_NVIDIA=true
echo "$GPU_INFO" | grep -qi "amd"    && HAS_AMD=true
echo "$GPU_INFO" | grep -qi "intel"  && HAS_INTEL=true

if $HAS_NVIDIA; then
    info "NVIDIA GPU detected — installing drivers via CUDA repo..."
    apt-get install -y clang-19 lld-19 2>/dev/null \
        || apt-get install -y clang lld || true
    for alt in clang clang++ lld ld.lld; do
        [[ -x "/usr/bin/${alt}-19" ]] && \
            update-alternatives --install "/usr/bin/$alt" "$alt" "/usr/bin/${alt}-19" 100 2>/dev/null || true
    done

    if curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub \
        | gpg --dearmor > /usr/share/keyrings/nvidia-cuda-keyring.gpg 2>/dev/null; then
        echo "deb [signed-by=/usr/share/keyrings/nvidia-cuda-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /" \
            > /etc/apt/sources.list.d/nvidia-cuda.list
        cat > /etc/apt/preferences.d/nvidia-cuda <<'EOF'
Package: cuda-drivers* nvidia-* libcuda* libnvidia-*
Pin: origin "developer.download.nvidia.com"
Pin-Priority: 900

Package: *
Pin: release o=Debian
Pin-Priority: 500
EOF
        wait_apt; apt-get update -qq
        apt-get purge -y nvidia-driver nvidia-kernel-dkms 2>/dev/null || true
        wait_apt
        apt-get install -y \
            cuda-drivers-580 \
            libvulkan1 libvulkan1:i386 \
            nvidia-vulkan-icd nvidia-vulkan-icd:i386 \
            vulkan-tools \
            libgl1-mesa-dri libgl1-mesa-dri:i386 \
            libnvidia-encode1 2>/dev/null || true
    fi

    if $HAS_AMD; then
        cat > /etc/modprobe.d/amdgpu.conf <<'EOF'
options amdgpu bpc=8
options amdgpu dc=1 dcfeaturemask=0x8
options amdgpu dpm=1
options amdgpu audio=0
options amdgpu runpm=0
EOF
        success "amdgpu hybrid freeze fix installed"
    fi

    CURRENT_KERNEL=$(ls /lib/modules 2>/dev/null | sort -V | tail -1)
    NVIDIA_VER=$(ls /var/lib/dkms/nvidia/ 2>/dev/null | sort -V | tail -1)
    if [[ -n "$CURRENT_KERNEL" && -n "$NVIDIA_VER" ]]; then
        apt-get install -y "linux-headers-${CURRENT_KERNEL}" 2>/dev/null \
            || warn "Kernel headers not found — DKMS may fail"
        dkms install nvidia/"$NVIDIA_VER" -k "$CURRENT_KERNEL" 2>/dev/null \
            || warn "DKMS build failed — after reboot: sudo dkms autoinstall"
    fi
    success "NVIDIA stack installed"

elif $HAS_AMD; then
    apt-get install -y \
        firmware-amd-graphics \
        mesa-vulkan-drivers mesa-vulkan-drivers:i386 \
        mesa-va-drivers mesa-va-drivers:i386 \
        libvulkan1 libvulkan1:i386 \
        vulkan-tools \
        libgl1-mesa-dri libgl1-mesa-dri:i386
    cat > /etc/modprobe.d/amdgpu.conf <<'EOF'
options amdgpu bpc=8
options amdgpu dc=1
options amdgpu dpm=1
EOF
    success "AMD stack installed"

elif $HAS_INTEL; then
    apt-get install -y \
        intel-media-va-driver-non-free \
        i965-va-driver \
        libva-drm2 libva-x11-2 vainfo \
        libvulkan1 libvulkan1:i386 \
        vulkan-tools \
        mesa-vulkan-drivers mesa-vulkan-drivers:i386 \
        libgl1-mesa-dri libgl1-mesa-dri:i386 \
        libosmesa6 2>/dev/null || true
    success "Intel stack installed"
fi

IS_LAPTOP=false
CHASSIS=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo 0)
[[ "$CHASSIS" =~ ^(8|9|10|14)$ ]] && IS_LAPTOP=true
compgen -G "/sys/class/power_supply/BAT*" >/dev/null && IS_LAPTOP=true
export IS_LAPTOP

if $IS_LAPTOP; then
    apt-get install -y tlp tlp-rdw thermald xserver-xorg-input-libinput
    systemd_safe enable tlp
    systemd_safe enable thermald
fi

success "GPU drivers configured"

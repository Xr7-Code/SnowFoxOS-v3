#!/bin/bash
# ============================================================
#  SnowFoxOS v3.0 — Kernel and Drivers Setup
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

# Load utilities (assumes SCRIPT_DIR is set before sourcing)
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables from main script (assumed to be sourced/exported):
# TARGET_USER, SCRIPT_DIR, IS_LAPTOP, HAS_NVIDIA, HAS_AMD, HAS_INTEL

info "Configuring system locales (de_AT, en_US)..."
apt-get install -y locales
sed -i 's/^# *de_AT.UTF-8 UTF-8/de_AT.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
grep -q "^de_AT.UTF-8 UTF-8" /etc/locale.gen || echo "de_AT.UTF-8 UTF-8" >> /etc/locale.gen
grep -q "^en_US.UTF-8 UTF-8" /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=de_AT.UTF-8
success "Locales set (de_AT.UTF-8, en_US.UTF-8)"

info "Checking CPU & system compatibility..."
DMI_SYS=$(cat /sys/class/dmi/id/product_name 2>/dev/null)

if ! grep -q "avx2" /proc/cpuinfo; then
    warn "CPU does not support AVX2 — using standard Debian kernel"
    USE_XANMOD=false
else
    USE_XANMOD=true
fi

# HP EliteDesk AMD Raven/Renoir xHCI USB Fix
if lspci | grep -qi "AMD" && [[ "$DMI_SYS" =~ "EliteDesk" ]]; then
    info "HP EliteDesk AMD detected — applying Raven xHCI PM fix (XanMod allowed)..."
    cat > /etc/udev/rules.d/99-xhci-raven-fix.rules << 'EOF'
# SnowFoxOS — Disable PCI runtime suspend for AMD Raven/Renoir xHCI host controllers
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x15e0", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x15e1", ATTR{power/control}="on"
EOF
    success "Raven xHCI udev rule installed (/etc/udev/rules.d/99-xhci-raven-fix.rules)"
fi

info "Installing DKMS tools..."
apt-get install -y --no-install-recommends dkms libdw-dev clang lld llvm
success "DKMS tools installed"

if $USE_XANMOD; then
    info "Installing XanMod LTS kernel..."
    dpkg --configure -a 2>/dev/null || true
    apt-get -f install -y 2>/dev/null || true

    mkdir -p /etc/apt/keyrings
    wget -qO - https://dl.xanmod.org/archive.key \
        | gpg --dearmor --yes -o /etc/apt/keyrings/xanmod-archive-keyring.gpg

    echo "deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org bookworm main" \
        > /etc/apt/sources.list.d/xanmod-release.list

    wait_apt
    apt-get update -qq
    wait_apt

    DEBIAN_FRONTEND=noninteractive apt-get install -y linux-xanmod-lts-x64v3
    XANMOD_EXIT=$?

    if [[ $XANMOD_EXIT -eq 0 ]]; then
        success "XanMod LTS kernel installed (active after reboot)"
    else
        warn "XanMod failed (exit $XANMOD_EXIT) — using standard Debian kernel"
        USE_XANMOD=false
    fi
fi

if ! $USE_XANMOD; then
    info "Installing standard Debian kernel (compatible with older hardware)..."
    apt-get install -y linux-image-amd64 linux-headers-amd64 firmware-linux
    success "Standard Debian kernel installed"
fi

if [[ -f /etc/default/grub ]]; then
    # Base parameters against xHCI USB crash & PCIe AER loops on HP/AMD
    GRUB_PARAMS="quiet splash pci=noaer usbcore.autosuspend=-1"

    if lspci | grep -qi nvidia; then
        GRUB_PARAMS="$GRUB_PARAMS nvidia-drm.modeset=1"
    fi

    if lspci | grep -qi amd; then
        # Stability fix for AMD APU / xHCI controller
        GRUB_PARAMS="$GRUB_PARAMS iommu=pt amdgpu.noretry=0"
        info "AMD system detected: iommu=pt & xHCI fix applied"
    fi

    if ! $USE_XANMOD; then
        GRUB_PARAMS="$GRUB_PARAMS acpi_osi=Linux"
    fi

    sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_PARAMS\"/" /etc/default/grub
    sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
fi

if $USE_XANMOD; then
    XANMOD_VER=$(ls /lib/modules 2>/dev/null | grep xanmod-lts 2>/dev/null | sort -V | tail -1)
    if [[ -n "$XANMOD_VER" ]]; then
        grub-set-default "Advanced options for SnowFoxOS GNU/Linux>SnowFoxOS GNU/Linux, with Linux $XANMOD_VER" 2>/dev/null || true
    fi
fi

update-grub 2>/dev/null || true
success "Boot configuration updated"

apt-get install -y firmware-misc-nonfree 2>/dev/null || true
if lsusb 2>/dev/null | grep -qi "fritz\|0x0bda\|2357"; then
    modprobe mt76x2u 2>/dev/null && \
        success "Fritz USB AC 860 driver loaded" || \
        warn "Fritz USB driver not found — verify after reboot"
fi

cat > /etc/udev/rules.d/70-usb-wlan-power.rules << 'EOF'
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="057c", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", DRIVER=="mt76x2u", ATTR{power/control}="on"
EOF
success "USB-WLAN autosuspend fix installed"

if lspci -k 2>/dev/null | grep -qi "RTL8821CE"; then
    info "RTL8821CE WiFi chip detected — applying stability fix..."
    cat > /etc/modprobe.d/rtw88.conf << 'EOF'
options rtw88_core disable_lps_deep=y
options rtw88_pci disable_aspm=y
EOF
    success "RTL8821CE stability fix installed (disable_lps_deep, disable_aspm)"

    # Fix: the module name changed in the XanMod kernel
    # (underscore was removed) -> driver was not found.
    modprobe rtw88_8821ce 2>/dev/null && \
        success "rtw88_8821ce module loaded" || \
        warn "rtw88_8821ce module not found — verify after reboot"
    echo "rtw88_8821ce" > /etc/modules-load.d/rtw88-8821ce.conf

    # Fix: Realtek WiFi chip produced massive PCIe bus errors (AER),
    # which completely blocked the kernel when starting X11/i3.
    if [[ -f /etc/default/grub ]] && ! grep -q "pci=noaer" /etc/default/grub; then
        sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 pci=noaer"/' /etc/default/grub
        update-grub 2>/dev/null || true
        success "pci=noaer kernel parameter set (prevents freeze from Realtek PCIe errors)"
    fi
fi

step "2/10 — Hardware analysis & drivers"

# Hardware detection variables (HAS_NVIDIA, HAS_AMD, HAS_INTEL, IS_LAPTOP)
# are determined in the main install.sh or another module and exported.
# For this script, we recalculate GPU info to be self-contained for now.
CPU_INFO=$(grep -m1 "vendor_id" /proc/cpuinfo)
if echo "$CPU_INFO" | grep -qi "AuthenticAMD"; then
    apt-get install -y amd64-microcode
    success "AMD CPU microcode installed"
else
    apt-get install -y intel-microcode
    success "Intel CPU microcode installed"
fi

GPU_INFO=$(lspci | grep -iE 'vga|3d|display')
HAS_NVIDIA=false
HAS_AMD=false
HAS_INTEL=false
echo "$GPU_INFO" | grep -qi "nvidia" && HAS_NVIDIA=true
echo "$GPU_INFO" | grep -qi "amd"    && HAS_AMD=true
echo "$GPU_INFO" | grep -qi "intel"  && HAS_INTEL=true

if $HAS_NVIDIA; then
    info "NVIDIA GPU detected — installing drivers via CUDA repo..."

    apt-get install -y clang-19 lld-19 2>/dev/null || apt-get install -y clang lld || true
    update-alternatives --install /usr/bin/clang   clang   /usr/bin/clang-19  100 2>/dev/null || true
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-19 100 2>/dev/null || true
    update-alternatives --install /usr/bin/lld     lld     /usr/bin/lld-19    100 2>/dev/null || true
    update-alternatives --install /usr/bin/ld.lld  ld.lld  /usr/bin/lld-19    100 2>/dev/null || true
    update-alternatives --set clang  /usr/bin/clang-19  2>/dev/null || true
    update-alternatives --set lld    /usr/bin/lld-19    2>/dev/null || true
    update-alternatives --set ld.lld /usr/bin/lld-19    2>/dev/null || true

    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub \
        | gpg --dearmor | tee /usr/share/keyrings/nvidia-cuda-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/nvidia-cuda-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /" \
        | tee /etc/apt/sources.list.d/nvidia-cuda.list

    cat > /etc/apt/preferences.d/nvidia-cuda << 'EOF'
Package: cuda-drivers* nvidia-* libcuda* libnvidia-*
Pin: origin "developer.download.nvidia.com"
Pin-Priority: 900

Package: *
Pin: release o=Debian
Pin-Priority: 500
EOF

    wait_apt
    apt-get update -qq
    apt-get purge -y nvidia-driver nvidia-kernel-dkms 2>/dev/null || true
    wait_apt
    apt-get install -y \
        cuda-drivers-580 \
        libvulkan1 libvulkan1:i386 \
        nvidia-vulkan-icd nvidia-vulkan-icd:i386 \
        vulkan-tools \
        libgl1-mesa-dri libgl1-mesa-dri:i386 \
        libnvidia-encode1 2>/dev/null || true

    if $HAS_AMD; then
        info "AMD+NVIDIA hybrid detected — configuring freeze fix..."

        # Fix: dcfeaturemask=0x8 disables PSR (Panel Self Refresh)
        # PSR was the cause of all dma_fence_wait_timeout freezes on
        # AMD+NVIDIA hybrid systems. When waking from PSR, the fence
        # mechanism blocks the entire X11 server.
        # runpm=0 additionally disables Runtime Power Management.
        cat > /etc/modprobe.d/amdgpu.conf << 'EOF'
# SnowFoxOS — AMD GPU Configuration (Hybrid Fix)
# Fix: dcfeaturemask=0x8 disables PSR (Panel Self Refresh)
# prevents dma_fence_wait_timeout freeze on AMD+NVIDIA systems
options amdgpu bpc=8
options amdgpu dc=1 dcfeaturemask=0x8
options amdgpu dpm=1
options amdgpu audio=0
options amdgpu runpm=0
EOF
        success "amdgpu hybrid freeze fix installed (PSR disabled via dcfeaturemask=0x8)"
    fi

    # DKMS for active kernel (XanMod or standard)
    CURRENT_KERNEL=$(ls /lib/modules 2>/dev/null | sort -V | tail -1)
    NVIDIA_VER=$(ls /var/lib/dkms/nvidia/ 2>/dev/null | sort -V | tail -1)
    if [[ -n "$CURRENT_KERNEL" && -n "$NVIDIA_VER" ]]; then
        # Install kernel headers — without them every DKMS build fails silently
        info "Installing kernel headers for $CURRENT_KERNEL..."
        apt-get install -y "linux-headers-${CURRENT_KERNEL}" 2>/dev/null || \
            warn "Kernel headers not found in repo — DKMS build may fail"

        info "Building NVIDIA DKMS modules for $CURRENT_KERNEL..."
        dkms install nvidia/"$NVIDIA_VER" -k "$CURRENT_KERNEL" 2>/dev/null || \
            warn "DKMS build failed — after reboot: sudo dkms autoinstall"
        success "NVIDIA DKMS modules built"
    else
        warn "DKMS skipped (kernel: ${CURRENT_KERNEL:-?}, NVIDIA: ${NVIDIA_VER:-?})"
    fi

    success "NVIDIA stack installed"

elif $HAS_AMD; then
    info "AMD GPU detected — using Mesa..."
    apt-get install -y \
        firmware-amd-graphics \
        mesa-vulkan-drivers \
        mesa-vulkan-drivers:i386 \
        mesa-va-drivers \
        mesa-va-drivers:i386 \
        libvulkan1 libvulkan1:i386 \
        vulkan-tools \
        libgl1-mesa-dri libgl1-mesa-dri:i386

cat > /etc/modprobe.d/amdgpu.conf << 'EOF'
# SnowFoxOS — AMD GPU Configuration
options amdgpu bpc=8
options amdgpu dc=1 dcfeaturemask=0x8
options amdgpu dpm=1
options amdgpu audio=0
options amdgpu runpm=0
EOF
    success "AMD stack installed"

elif $HAS_INTEL; then
    info "Intel graphics detected..."
    # VA-API decoder (hardware video decoding)
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
[[ "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)" =~ ^(8|9|10|14)$ ]] && IS_LAPTOP=true
if $IS_LAPTOP; then
    info "Laptop detected: installing battery & touchpad tools..."
    apt-get install -y tlp tlp-rdw thermald xserver-xorg-input-libinput
    systemctl enable tlp thermald
    success "Laptop optimization complete"
fi

success "GPU drivers configured"

# SnowFoxOS v3 — ISO Builder

Builds a bootable installer ISO from the SnowFoxOS-v3 repo.

## Structure

```
iso-builder/
├── build-iso.sh                   # Main build script — run this
├── installer/
│   ├── tui-installer.sh           # TUI: disk selection, partitioning, debootstrap
│   └── auto-install.sh            # First-boot: calls install.sh unattended
└── live-build/
    └── hooks/
        └── 01-cache.sh            # Caches all base packages into the ISO
```

## Usage

```bash
# From the SnowFoxOS-v3 directory:
sudo bash iso-builder/build-iso.sh
```

Output: `SnowFoxOS-v3/SnowFoxOS-v3.iso`  
Build working directory: `/var/tmp/snowfox-iso-build/` (cleaned automatically)

## Flash to USB

```bash
sudo dd if=SnowFoxOS-v3.iso of=/dev/sdX bs=4M status=progress && sync
```

Replace `/dev/sdX` with your USB drive (check with `lsblk`).

---

## What happens during installation

### On the ISO (installer live system)

1. Boots directly into `tui-installer.sh`
2. Asks: keyboard layout, username, password, hostname, target disk, partition layout
3. Partitions the disk (GPT+EFI, MBR, or GPT+EFI+separate /home)
4. Runs `debootstrap` — installs minimal Debian 12 base (~1–3 min)
5. Installs GRUB bootloader
6. Copies the SnowFoxOS-v3 repo to `/home/<user>/SnowFoxOS-v3`
7. Registers `snowfox-firstboot.service` for first boot
8. Reboots

### On first boot (installed system)

1. `snowfox-firstboot.service` runs `auto-install.sh` automatically
2. `auto-install.sh` calls `install.sh` with all defaults pre-set
3. All base packages install from the ISO's apt cache (no re-download)
4. Hardware-specific components (XanMod, NVIDIA, Zen Browser) are downloaded live
5. Service disables itself — never runs again
6. System reboots into the finished SnowFoxOS desktop

---

## Defaults (unattended)

| Component              | Default  |
|------------------------|----------|
| Browser                | Zen Browser |
| File manager           | PCManFM  |
| Code editor            | Geany    |
| Mesh module            | Yes      |
| SnowFox Console Launcher | Yes    |
| bluetui                | Yes      |
| Steam                  | No (→ `snowfox stash`) |
| Ollama                 | No (→ `snowfox stash`) |
| GIMP                   | No (→ `snowfox stash`) |
| VSCodium               | No (→ `snowfox stash`) |
| OnlyOffice             | No (→ `snowfox stash`) |

---

## Estimated install times

| Hardware                        | Time         |
|---------------------------------|--------------|
| AMD / Intel (no NVIDIA)         | ~3–5 min     |
| NVIDIA (DKMS compilation)       | ~8–12 min    |
| Slow internet / HDD             | +2–5 min     |

Base packages are cached in the ISO — only hardware-specific
drivers and a few GitHub releases are downloaded live.

---

## ISO size

Approximately **1.5–2.5 GB** depending on included firmware packages.

## Requirements for building

- Debian 12 (SnowFoxOS) host
- `sudo` access
- Internet connection during build (packages are downloaded once into the ISO)
- ~8 GB free space in `/var/tmp/` during build

## Partition layouts

| Option | Description |
|--------|-------------|
| GPT + EFI | Modern hardware, UEFI boot (recommended) |
| MBR | Legacy BIOS, older hardware |
| GPT + EFI + separate /home | Requires >60 GB disk |

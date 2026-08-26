<div align="center">

<img src="assets/fuchs.png" width="120" alt="SnowFox Logo"/>

# SnowFoxOS v3

**A lean, privacy-oriented i3 desktop based on Debian 12**

![Version](https://img.shields.io/badge/version-v3-9B59B6?style=flat-square)
![Debian](https://img.shields.io/badge/base-Debian%2012-A81D33?style=flat-square&logo=debian&logoColor=white)
![i3](https://img.shields.io/badge/desktop-i3%2FX11-3a86ff?style=flat-square)
![License](https://img.shields.io/badge/license-SnowFox%20Public%20License-9B59B6?style=flat-square)

</div>

---

## What is SnowFoxOS?

SnowFoxOS is a single-script installer that transforms a minimal Debian 12 netinstall installation into a configured i3 desktop. It is not its own operating system — it is Debian 12 with a well-thought-out, privacy-focused setup that would otherwise require hours of manual configuration.

The installer automatically sets up around 10 steps: kernel, drivers, desktop environment, security configuration, CLI tools. The result is a system that is immediately usable and where the most important privacy and performance settings are already active.

**What SnowFoxOS is not:** A high-security system. Anyone who needs protection from state actors or active attackers should use Tails or Whonix.

---

## Screenshots

<div align="center">

**Desktop**

![Desktop](assets/SnowFox-Desktop.png)

**Tiling**

![Tiling](assets/SnowFox-Tiling.png)

**Floating**

![Floating](assets/SnowFox-Floating.png)

**Rofi App Launcher**

![Rofi](assets/SnowFox-Rofi.png)

</div>

---

## Why this project?

Most desktop Linux setups are either too complex for beginners or too compromising when it comes to privacy and performance. SnowFoxOS attempts a third way: a system that is sensibly configured out of the box, without the user needing to understand why.

The underlying conviction: a computer should belong to the user — not to the services they use. Concretely, that means no telemetry, no tracking, no dependency on cloud services for basic functions.

> *Your computer belongs to you. Not Microsoft. Not anyone else.*
> — Alexander Valentin Ludwig

That is a personal conviction, not a promise. Whether SnowFoxOS fulfills that for you is something you can verify yourself using the means described below.

---

## Security & Privacy

### What SnowFoxOS concretely does

**Kernel hardening** — the following sysctl values are set in `/etc/sysctl.d/99-snowfox-security.conf`:

```
kernel.kptr_restrict=2              # Hide kernel pointers from userspace
kernel.perf_event_paranoid=3        # Restrict performance events
kernel.unprivileged_bpf_disabled=1  # BPF for root only
net.core.bpf_jit_harden=2          # JIT spray protection
kernel.dmesg_restrict=1             # dmesg for root only
fs.protected_hardlinks=1            # Prevent hardlink attacks
fs.protected_symlinks=1             # Prevent symlink attacks
kernel.core_uses_pid=1              # Core dumps with PID
fs.suid_dumpable=0                  # No core dumps for SUID programs
```

**Network hardening** — in `/etc/sysctl.d/99-snowfox.conf`:

```
net.ipv4.conf.all.rp_filter=1               # Reverse path filtering
net.ipv4.conf.all.accept_redirects=0        # Reject ICMP redirects
net.ipv4.tcp_syncookies=1                   # SYN flood protection
net.ipv6.conf.all.use_tempaddr=2            # IPv6 privacy extensions
net.core.default_qdisc=fq                  # Fair queuing
net.ipv4.tcp_congestion_control=bbr        # BBR congestion control
```

**DNS-over-TLS** — `/etc/systemd/resolved.conf` is configured so that all DNS requests run encrypted via Cloudflare (1.1.1.1) and Quad9 (9.9.9.9). Verify with:

```bash
resolvectl status
# Shows: DNS over TLS: yes
```

**Firewall** — UFW with default-deny incoming, default-allow outgoing. SSH is disabled and removed from UFW. Check with:

```bash
sudo ufw status verbose
```

**SSH disabled:**

```bash
systemctl is-enabled ssh
# Output: disabled
```

### What you can verify yourself

Show active network connections:
```bash
snowfox audit
# Or directly:
ss -tulpn
```

DNS leak test:
```bash
# Enable Tor mode, then:
curl https://icanhazip.com
# Should show Tor exit IP, not your real IP
```

Check kernel parameters:
```bash
sysctl kernel.kptr_restrict
sysctl net.core.bpf_jit_harden
```

### Limits — what SnowFoxOS does not protect against

**X11 is structurally insecure.** Any running application can read the screen contents of all other applications under X11 and intercept keyboard input — without root privileges. This is not a SnowFoxOS problem but a fundamental X11 problem. Anyone who wants to avoid this needs Wayland.

**No AppArmor or SELinux.** Processes run without Mandatory Access Control. A compromised process has full user rights in its own home directory.

**`snowfox pass` is not a password manager.** It is a GPG-encrypted text file — without clipboard clearing, without brute-force protection, without memory protection. For sensitive passwords: KeePassXC or `pass`.

**No automatic security updates.** `snowfox update` must be run manually.

---

## Performance

### RAM measurement

The following measurement was taken with `smem` on an HP 250 G8 (Intel i5-1135G7, 8GB RAM), directly after startup with no open applications other than the desktop stack:

```bash
smem -tk -s pss -r | tail -1
# Result: ~177 MB PSS (Proportional Set Size)
```

PSS is the most accurate method — shared libraries are counted proportionally instead of double. The value from `free -h` is higher because it includes the page cache, which is immediately released when needed.

**Running processes during measurement:** Xorg, i3, polybar, picom, pipewire, wireplumber, dunst, lxpolkit, xsettingsd, nm-applet, clip-saver, xss-lock, dbus

| State | RAM (PSS) |
|---|---|
| Desktop stack idle | ~177 MB |
| + Kitty Terminal | ~200 MB |
| + Zen Browser (5 tabs) | ~900 MB – 1.3 GB |
| + Zen Browser (many tabs) | 1.5–2.5 GB |
| + OnlyOffice | +500 MB |
| + Steam in background | +300 MB |

For comparison (community benchmarks, `free -h` `used` value — not directly comparable with PSS):

| System | Idle RAM |
|---|---|
| Windows 11 | ~3.5 GB |
| Ubuntu (GNOME) | ~1.5 GB |
| KDE Plasma | ~900 MB |
| Arch Linux with i3 | ~400–500 MB |
| **SnowFoxOS (PSS)** | **~177 MB** |

> The comparison values for other systems come from community benchmarks and use `free -h` — a different measurement method than PSS. A direct comparison is therefore only partially possible. What can be said with certainty: SnowFoxOS is a lean system.

### What performance concretely means

**zram** replaces traditional swap — compressed swap in RAM with lz4, 50% RAM size, `PRIORITY=100`. `vm.swappiness=10` keeps data in RAM as long as possible.

**No display manager** — i3 starts directly from TTY1, no GDM/LightDM running in the background.

**Disabled services** during installation: `cups-browsed`, `avahi-daemon`, `ModemManager`, `colord`, `apt-daily`, `apt-daily-upgrade`, `NetworkManager-wait-online`.

**`fstab` with `noatime`** — no access timestamps written, reduces disk I/O.

---

## Features

- **i3 WM with Smart Dynamic Floating** — tiling window manager with smart gaps. Floating windows automatically receive a title bar, purple border, fixed size (`960x600`) and centering. Back to tiling: everything is automatically removed.
- **Polybar** — status bar with RAM, battery, network, volume, Bluetooth and system tray
- **Rofi** — app launcher with SnowFox theme
- **Kitty** — GPU-accelerated terminal with SnowFox color palette, JetBrainsMono Nerd Font, 0.95 transparency
- **Starship** — modern shell prompt with Git integration and SnowFox palette
- **picom** — compositor with rounded corners, soft shadows, fading animations
- **Zen Browser** — privacy-focused browser based on Firefox (optional)
- **PipeWire** — modern audio stack with WirePlumber
- **Dunst** — notification daemon, tuned to the SnowFox palette
- **Clip-Saver** — keeps clipboard contents active even after closing the source window (`clipnotify` + `xclip`, no history bloat)
- **fastfetch** — system info with SnowFox logo
- **zram** — compressed swap in RAM (lz4, 50%)
- **tlp** — battery optimization for laptops
- **earlyoom** — OOM protection against system freeze
- **ufw** — firewall, default-deny incoming
- **DNS-over-TLS** — via systemd-resolved, Cloudflare + Quad9
- **GPU detection** — automatic driver installation for AMD, NVIDIA, Intel, Hybrid
- **Automatic kernel fallback** — XanMod LTS (x64v3) on modern CPUs, standard Debian kernel as fallback when no AVX2
- **Hybrid GPU freeze fix** — PSR deactivation for AMD+NVIDIA dual-monitor setups
- **Dark mode** — SnowFox palette consistent across GTK2/3/4 and Qt
- **OnlyOffice** — Microsoft format compatibility (optional)
- **SnowFox Console Launcher** — game hub for Steam, GOG, Retro
- **Multiarch (i386)** — 32-bit support for Steam and older games
- **Smart Lock** — does not lock when video is playing or fullscreen is active, blurred wallpaper as background
- **Tor mode** — `snowfox tor on/off` with DNS protection, IPv6 deactivation, MAC randomization
<!-- - **Mesh network** — P2P communication via Reticulum without ISP (experimental) -->
- **Ollama** — local AI engine
- **`yt-dlp`** — video/audio without browser

---

## snowfox CLI

`snowfox` is the central control. All functions are accessible via a single command.

### System

| Command | Description |
|---|---|
| `snowfox status` | RAM, disk, uptime, GPU mode, mic/camera status, network |
| `snowfox battery` | Battery charge, power consumption, estimated runtime |
| `snowfox profile [name]` | Switch profile: balanced, performance, battery, privacy |
| `snowfox update` | System update including yt-dlp |
| `snowfox audit` | Active network connections with process and destination IP |

### Privacy & Hardware

| Command | Description |
|---|---|
| `snowfox tor on/off` | Tor mode with DNS protection and MAC randomization |
| `snowfox airmode on/off` | Disable all wireless interfaces |
| `snowfox kill mic` | Disable microphone at kernel level |
| `snowfox kill cam` | Disable webcam |
| `snowfox kill all` | Microphone + camera + wireless at once |
| `snowfox kill restore` | Reset all kill switches |
| `snowfox pass` | Local GPG-encrypted password storage |

### Media

| Command | Description |
|---|---|
| `snowfox stream [search/URL]` | Stream video/audio directly in mpv — no browser, no tracking |
| `snowfox download [search/URL]` | Download video or audio |
| `snowfox fetch <URL>` | High-speed download via 16 parallel connections |

### Tools

| Command | Description |
|---|---|
| `snowfox autostart [list\|enable\|disable]` | Manage autostart |
| `snowfox layout [tiling\|floating]` | Switch window mode |
| `snowfox webapp [add\|list\|open\|remove]` | Manage web apps |
| `snowfox network` | Network manager (nmtui) |
| `snowfox ai` | Local AI (Ollama) |
<!-- | `snowfox mesh` | P2P mesh network (Reticulum) | -->

### Node Modes

| Command | Description |
|---|---|
| `snowfox node console` | Game hub for Steam, GOG, Retro |
| `snowfox node server` | Server mode, minimal footprint |
| `snowfox node desktop` | Standard desktop mode |

### System Profiles

| Profile | CPU Governor | Swappiness | Network |
|---|---|---|---|
| `balanced` | schedutil | 10 | on |
| `performance` | performance | 10 | on |
| `battery` | powersave | 60 | on |
| `privacy` | schedutil | 10 | everything off |

### System Reset

| Command | Description |
|---|---|
| `snowfox reset` | Resets to minimal Debian state — deletes all data |

---

## Installation

**Prerequisite:** Fresh **Debian 12 (Bookworm) minimal installation** with a normal (non-root) user. Only Debian 12 is supported — Ubuntu, Mint, Kali and derivatives do not work.

### Step 1 — Install Debian 12 minimal

Download ISO: [debian.org/distrib/netinst](https://www.debian.org/distrib/netinst/)

During software selection, **deselect everything** — including the desktop. Leave only "Standard system utilities" or leave completely empty.

### Step 2 — Preparation

```bash
su -
apt-get install -y sudo git
usermod -aG sudo YOURUSERNAME
exit
exit
```

### Step 3 — Install

```bash
git clone https://github.com/Xr7-Code/SnowFoxOS-v3.git
cd SnowFoxOS-v3
chmod +x install.sh
sudo bash install.sh
```

The installer asks about optional packages. Duration depending on internet speed: **20–60 minutes**.

### Step 4 — Reboot

```bash
sudo reboot
```

i3 starts automatically from TTY1.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Super + Return` | Terminal (Kitty) |
| `Super + Tab` | Switch window |
| `Super + Space` | App launcher (Rofi) |
| `Super + E` | File manager (PCManFM) |
| `Super + N` | Network manager |
| `Super + W` | Wallpaper selector |
| `Super + P` | Display configuration |
| `Super + L` | Lock screen |
| `Super + Q` | Close window |
| `Super + F` | Toggle fullscreen |
| `Super + H / V` | Split horizontal / vertical |
| `Super + Shift + Space` | Floating toggle (auto size, auto border, centering) |
| `Super + 1–9` | Switch workspace |
| `Super + Shift + 1–9` | Move window to workspace |
| `Super + R` | Resize mode |
| `Super + Shift + R` | Reload i3 |
| `Super + Shift + E` | Power menu |
| `Print` | Screenshot |
| `Super + Print` | Area screenshot |

---

## Stack

| Component | Package |
|---|---|
| Window Manager | i3 |
| Status bar | polybar |
| App launcher | rofi |
| Terminal | kitty |
| Shell prompt | starship |
| Browser | zen-browser (optional) |
| Audio | pipewire + wireplumber |
| Compositor | picom |
| Notifications | dunst |
| Clipboard | clip-saver + clipnotify |
| File manager | pcmanfm |
| System info | fastfetch |
| Screen lock | i3lock + xss-lock (Smart Lock) |
| Media player | mpv + yt-dlp |
| Game launcher | SnowFox Console Launcher |
| Office | OnlyOffice (optional) |
| Battery | tlp |
| Firewall | ufw |
| OOM protection | earlyoom |
| Kernel | XanMod LTS (x64v3) with fallback |
| Bluetooth UI | bluetui |
| Cursor | Bibata-Modern-Classic |
| Night light | redshift |
| Screenshot | scrot |
| Brightness | brightnessctl |
| Media control | playerctl |
| Printer | cups |
| GTK theme | Arc-Dark + SnowFox overrides |
| Thermal | thermald |

---

## Limitations

### Hardware Requirements

**XanMod kernel requires AVX2** — Intel Haswell (2013) or newer, AMD Excavator (2015) or newer. The installer detects this automatically and falls back to the standard Debian kernel. Check:

```bash
grep avx2 /proc/cpuinfo | head -1
```

**NVIDIA: Maxwell (2014) or newer** — GTX 750 / GTX 900 series and newer, all RTX generations. Older cards are not supported.

**AMD + NVIDIA Hybrid** — the PSR freeze fix is applied automatically. If problems occur: check `amdgpu dcfeaturemask=0x8` in `/etc/modprobe.d/amdgpu.conf`.

### Known Issues

**Dual-monitor tray popups** may appear on the wrong monitor — known i3/GTK issue. Workaround: `Super + mouse click` to move.

**VirtualBox** injects Wayland variables into the environment which interferes with picom and other X11 tools. SnowFoxOS is designed for real hardware, not VMs.

**Debian 12 only** — Ubuntu, Mint, Kali and other derivatives are not supported.

---

## License

SnowFoxOS is released under the **SnowFox Public License v1.0**. See [LICENSE](LICENSE).

---

<div align="center">
<sub>Built by Alexander Valentin Ludwig (Xr7-Code) on Debian 12</sub>
</div>

<!--
I know it's hard to tell how mixed up you feel
Hoping what you need is behind every door
Each time you get hurt, I don't want you to change
Because everyone has hopes, you're human after all
The feeling sometimes, wishing you were someone else
Feeling as though you never belong
This feeling is not sadness, this feeling is not joy
I truly understand. Please, don't cry now

Please don't go, I want you to stay
I'm begging you please, please don't leave here
I don't want you to hate;
For all the hurt that you feel,
The world is just illusion, trying to change you

Being like you are
Well this is something else, who would comprehend?
But some that do, lay claim
Divine purpose blesses them
That's not what I believe, and it doesn't matter anyway
A part of your soul ties you to the next world
Or maybe to the last, but I'm still not sure
But what I do know, is to us the world is different
As we are to the world but I guess you would know that

Please don't go, I want you to stay
I'm begging you please, please don't leave here
I don't want you to hate for all the hurt that you feel
The world is just illusion trying to change you
Please don't go, I want you to stay
I'm begging you please, oh please don't leave here
I don't want you to change;
For all the hurt that you feel,
This world is just illusion, always trying to change you

Please don't go, I want you to stay
I'm begging you please, please don't leave here
I don't want you to hate for all the hurt that you feel
The world is just illusion trying to change you
Please don't go, I want you to stay
I'm begging you please, oh please don't leave here
I don't want you to change;
For all the hurt that you feel,
This world is just illusion, always trying to change you
-->

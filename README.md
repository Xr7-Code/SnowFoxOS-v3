<div align="center">

<img src="assets/fuchs.png" width="120" alt="SnowFox Logo"/>

# SnowFoxOS v3

**Ein schlankes, privacy-orientiertes i3-Desktop auf Basis von Debian 12**

![Version](https://img.shields.io/badge/version-v3-9B59B6?style=flat-square)
![Debian](https://img.shields.io/badge/base-Debian%2012-A81D33?style=flat-square&logo=debian&logoColor=white)
![i3](https://img.shields.io/badge/desktop-i3%2FX11-3a86ff?style=flat-square)
![License](https://img.shields.io/badge/license-SnowFox%20Public%20License-9B59B6?style=flat-square)

</div>

---

## Überblick

SnowFoxOS ist ein Ein-Script-Installer der eine minimale Debian 12 Installation in einen kontrollierten, performanten Desktop verwandelt. Kein Bloat, kein Display Manager, keine unnötigen Dienste — nur eine saubere i3-Umgebung vereint unter einem einzigen CLI-Tool: `snowfox`.

Der `snowfox`-Befehl ist das Herzstück des Systems. Er verwaltet alles: von Systemstatus und GPU-Wechsel über Hardware-Kill-Switches bis hin zu Media-Streaming — alles von einem Ort, alles lokal.

---

## Philosophie

Die meisten Betriebssysteme behandeln dich als Produkt. Sie sammeln deine Daten, verlangsamen deine Hardware mit jedem Update und sperren dich in Ökosysteme die du nie gewählt hast.

SnowFoxOS basiert auf einer anderen Überzeugung:

> *Dein Computer gehört dir. Nicht Microsoft. Niemandem sonst.*
> *Keine Telemetrie, keine Datenweitergabe im Hintergrund. Keine Werbung. Keine Abonnements.*
> *Du bist kein Produkt. Du bist keine Datei. Du bist ein Mensch.*
>
> — Alexander Valentin Ludwig

Dieses System ist für Menschen die ihre Hardware zurückhaben wollen. Es telefoniert nicht nach Hause. Es wird mit Updates nicht langsamer. Es verkauft deine Aufmerksamkeit nicht.

---

## Features

- **i3** — Tiling Window Manager mit Smart Gaps und flexiblen Floating-Regeln
- **Polybar** — Statusleiste mit CPU, RAM, Akku, Netzwerk, Lautstärke und System-Tray
- **Rofi** — schneller App-Launcher mit passendem Dark-Theme
- **Kitty** — GPU-beschleunigtes Terminal
- **Zen Browser** — privacy-fokussierter Browser auf Firefox-Basis, keine Telemetrie (optional)
- **PipeWire** — moderner Audio-Stack, PulseAudio entfernt
- **Dunst** — schlanker Notification-Daemon
- **Greenclip** — schlanker Clipboard-Manager ohne GTK-Overhead
- **fastfetch** — systeminfo mit SnowFox-Logo
- **zram** — komprimierter Swap im RAM (lz4, 50%), Swappiness auf 10 gesetzt
- **tlp** — automatische Akku-Optimierung, aktiv bei jedem Boot
- **earlyoom** — verhindert System-Freeze bei sehr geringem freiem RAM
- **ufw Firewall** — eingehende Verbindungen standardmäßig blockiert
- **DNS-over-TLS** — via systemd-resolved mit Cloudflare + Quad9, keine DNS-Leaks
- **GPU-Erkennung** — installiert automatisch die richtigen Treiber für AMD, NVIDIA oder Hybrid
- **Hybrid GPU Freeze Fix** — PSR-Deaktivierung via `dcfeaturemask=0x8` für stabile AMD+NVIDIA Dual-Monitor Setups
- **Dark Mode** — SnowFox Palette (GTK2/3/4 + Qt) out of the box, konsistent über alle Apps
- **OnlyOffice** — vollständige Microsoft-Format-Kompatibilität (optional im Installer)
- **SnowFox Console Launcher** — nativer Game-Launcher für Steam, GOG, Retro und eigene Spiele

---

## Performance

SnowFoxOS ist darauf ausgelegt nicht im Weg zu stehen und so wenig Ressourcen wie möglich zu verbrauchen.

- zram mit lz4-Kompression ersetzt traditionellen Swap — schneller und RAM-effizienter
- `vm.swappiness=10` hält Daten so lange wie möglich im RAM
- `tlp` optimiert CPU, USB und Festplatten-Powermanagement automatisch
- Unnötige System-Dienste werden beim Install deaktiviert (cups-browsed, avahi, ModemManager, colord, zeitgeist)
- Kein Display Manager — i3 startet direkt von TTY1
- Kein Compositor — kein picom, kein unnötiger GPU-Overhead im Idle

| Zustand | RAM (ungefähr) |
|---|---|
| Desktop ohne offene Apps | ~350–420 MB |
| + Zen Browser (1–5 Tabs) | ~900 MB – 1,3 GB |
| + Zen Browser (viele Tabs) | 1,5–2,5 GB |
| + OnlyOffice geöffnet | +500 MB |
| + Steam im Hintergrund | +300 MB |

Zum Vergleich:

| System | Idle RAM (ungefähr) |
|---|---|
| Windows 11 | ~3,5 GB |
| Ubuntu (GNOME) | ~1,5 GB |
| KDE Plasma | ~900 MB |
| Arch Linux mit i3 | ~400–500 MB |
| **SnowFoxOS** | **~350–420 MB** |

> **Hinweis:** Linux nutzt freien RAM automatisch als Dateisystem-Cache. Das ist normal und kein Problem — der Cache wird sofort freigegeben sobald ein Programm ihn braucht. `free -h` zeigt in der Spalte `verfügbar` den tatsächlich nutzbaren Speicher.

---

## snowfox CLI

`snowfox` ist die zentrale Steuerung von SnowFoxOS. Statt verstreuter Tools und Einstellungsmenüs ist alles über einen einzigen Befehl erreichbar — schnell, transparent und lokal.

### System

| Befehl | Beschreibung |
|---|---|
| `snowfox status` | RAM, Disk, Uptime, GPU-Modus, Mikro/Kamera-Status, Netzwerk |
| `snowfox battery` | Akkuladung, Energieverbrauch, geschätzte Laufzeit |
| `snowfox profile [name]` | System-Profil wechseln: balanced, performance, battery, privacy |
| `snowfox update` | System-Update inkl. yt-dlp |
| `snowfox audit` | Aktive Netzwerkverbindungen mit Prozess und Ziel-IP |

### Privacy & Hardware

| Befehl | Beschreibung |
|---|---|
| `snowfox airmode on/off` | Alle Funkschnittstellen deaktivieren — WLAN, Bluetooth, alles |
| `snowfox kill mic` | Mikrofon auf Kernel-Ebene deaktivieren |
| `snowfox kill cam` | Webcam deaktivieren |
| `snowfox kill all` | Mikrofon + Kamera + Funk auf einmal deaktivieren |
| `snowfox kill restore` | Alle Hardware-Kill-Switches zurücksetzen |
| `snowfox pass` | Lokaler verschlüsselter Passwort-Manager — keine Cloud, keine Synchronisierung |

### Media

| Befehl | Beschreibung |
|---|---|
| `snowfox stream [Suche/URL]` | Video/Audio suchen oder via URL direkt in mpv streamen — kein Browser, kein Tracking |
| `snowfox download [Suche/URL]` | Video oder Audio suchen oder via URL herunterladen |
| `snowfox fetch <URL>` | Highspeed Download einer Datei über 16 parallele Verbindungen |

### Tools & Konfiguration

| Befehl | Beschreibung |
|---|---|
| `snowfox autostart [list|enable|disable]` | Autostart-Programme verwalten |
| `snowfox layout [tiling|floating]` | Fenstermodus wechseln (i3) |
| `snowfox webapp [add|list|open|remove]` | WebApps erstellen und verwalten |
| `snowfox network` | Netzwerk-Manager (nmtui) |
| `snowfox ai` | Lokale KI (Ollama) |

### Node-Modi

SnowFoxOS kann auf drei verschiedene Arten als Node betrieben werden:

| Befehl | Beschreibung |
|---|---|
| `snowfox node console` | Startet den SnowFox Console Launcher — nativer Game-Hub für Steam, GOG, Retro und eigene Spiele |
| `snowfox node server` | Server-Modus — minimaler Footprint, optimiert für Dauerbetrieb |
| `snowfox node desktop` | Standard Desktop-Modus (Standard) |

### System-Profile

`snowfox profile` wechselt sofort zwischen vier Modi:

| Profil | CPU | Swappiness | Netzwerk |
|---|---|---|---|
| `balanced` | schedutil | 10 | an |
| `performance` | performance | 10 | an |
| `battery` | powersave | 60 | an |
| `privacy` | schedutil | 10 | alles aus |

### Warum `snowfox stream`?

Du könntest YouTube im Browser öffnen. Aber jedes Mal wenn du das tust, trackt Google dein Verhalten. Der Algorithmus ist darauf ausgelegt, dich auf der Plattform zu halten.

`snowfox stream` erlaubt es dir, direkt vom Terminal aus zu suchen und das Ergebnis in mpv abzuspielen — kein JavaScript, kein Tracking, keine Empfehlungen, kein Autoplay. Nur das Medium.

Deine Aufmerksamkeit gehört dir.

### System Reset

| Befehl | Beschreibung |
|---|---|
| `snowfox reset` | Setzt das System auf einen Debian-Minimalzustand zurück (löscht alle Daten!) |

---

## Installation

**Voraussetzung:** Eine frische **Debian 12 (Bookworm) minimal Installation** mit einem normalen (nicht-root) Benutzer.

### Schritt 1 — Debian 12 minimal installieren

Lade das Debian 12 Netinstall-ISO herunter: [debian.org/distrib/netinst](https://www.debian.org/distrib/netinst/)

Während der Installation bei der Software-Auswahl **alles abwählen** — auch den Desktop. Nur „Standard-Systemwerkzeuge" oder komplett leer lassen. Benutzername und Passwort sind frei wählbar.

### Schritt 2 — Vorbereitung

Nach dem ersten Boot als root anmelden und vorbereiten:

```bash
su -
apt-get install -y sudo git
usermod -aG sudo DEINBENUTZERNAME
exit   # root verlassen
exit   # Session beenden, neu einloggen
```

### Schritt 3 — Repo klonen & installieren

```bash
git clone https://github.com/Xr7-Code/SnowFoxOS-v3.git
cd SnowFoxOS-v3
chmod +x install.sh
sudo bash install.sh
```

Der Installer führt dich durch ca. 10 Schritte und fragt bei optionalen Paketen nach. Die gesamte Installation dauert je nach Internetgeschwindigkeit **20–60 Minuten**.

### Schritt 4 — Neustart

```bash
sudo reboot
```

Nach dem Neustart startet i3 automatisch von TTY1.

---

## Tastenkürzel

| Kürzel | Aktion |
|---|---|
| `Super + Return` | Terminal (Kitty) |
| `Super + Tab` | Fenster wechseln (Switcher) |
| `Super + Space` | App-Launcher (Rofi) |
| `Super + E` | Dateimanager (PCmanFM) |
| `Super + N` | Netzwerk-Manager |
| `Super + W` | Wallpaper-Selector |
| `Super + P` | Display-Konfiguration |
| `Super + L` | Bildschirm sperren |
| `Super + Q` | Fenster schließen |
| `Super + F` | Vollbild umschalten |
| `Super + H / V` | Split horizontal / vertikal |
| `Super + Shift + Space` | Floating umschalten |
| `Super + 1–5` | Workspace wechseln |
| `Super + Shift + 1–5` | Fenster zu Workspace verschieben |
| `Super + R` | Resize-Modus |
| `Super + Shift + R` | i3 neu laden |
| `Super + Shift + E` | Power-Menü |
| `Print` | Screenshot |
| `Super + Print` | Bereich-Screenshot |

---

## Stack

| Komponente | Paket |
|---|---|
| Window Manager | i3 |
| Statusleiste | polybar |
| App-Launcher | rofi |
| Terminal | kitty |
| Browser | zen-browser (optional) |
| Audio | pipewire + wireplumber |
| Compositor | — (kein picom, bewusst entfernt) |
| Benachrichtigungen | dunst |
| Clipboard | greenclip |
| Dateimanager | pcmanfm |
| System-Info | fastfetch |
| Bildschirmsperre | i3lock + xss-lock |
| Media Player | mpv + yt-dlp |
| Game Launcher | SnowFox Console Launcher |
| Office | OnlyOffice (optional) |
| Akku | tlp |
| Firewall | ufw |
| OOM-Schutz | earlyoom |
| Kernel | XanMod LTS (x64v3) |

---

## Bekannte Einschränkungen & Warnungen

> ⚠️ Bitte vor der Installation vollständig lesen.

### Kernel: AVX2 erforderlich

Der Installer installiert `linux-xanmod-lts-x64v3`. Dieser Kernel nutzt **AVX2-CPU-Instruktionen** die erst ab folgenden Generationen verfügbar sind:

- Intel: **Haswell (2013)** und neuer
- AMD: **Excavator (2015)** und neuer

Auf älteren CPUs **bootet das System nach dem Reboot nicht**. Prüfen mit:

```bash
grep avx2 /proc/cpuinfo
```

Zeigt der Befehl eine Ausgabe, ist AVX2 vorhanden.

### NVIDIA: Nur Maxwell (2014) und neuer

Der Installer installiert `cuda-drivers-580`. Unterstützt werden ausschließlich:

- GTX 750 / GTX 900-Serie und neuer (Maxwell+)
- RTX alle Generationen

Ältere Karten (GTX 600, GTX 500 und älter) werden **nicht unterstützt** und der Installer schlägt beim GPU-Schritt fehl.

### AMD + NVIDIA Hybrid (Dual-Monitor)

SnowFoxOS enthält einen Fix für den bekannten `dma_fence_wait_timeout` Freeze auf Hybrid-Systemen mit AMD und NVIDIA GPUs an separaten Monitoren. Der Fix deaktiviert PSR (Panel Self Refresh) via `amdgpu dcfeaturemask=0x8` und Runtime Power Management (`runpm=0`). Der Installer erkennt Hybrid-Systeme automatisch und wendet den Fix an.

### Ältere Systeme (vor 2013)

SnowFoxOS ist nicht für alte Hardware ausgelegt. Auf Systemen vor 2013 können folgende Probleme auftreten:

- Kernel bootet nicht (kein AVX2)
- NVIDIA-Treiber nicht kompatibel
- Zen Browser zu ressourcenintensiv

Für sehr alte Hardware empfehlen sich stattdessen **AntiX**, **BunsenLabs** oder **Void Linux** mit i3.

### Dual-Monitor & Tray-Popups

Auf Systemen mit mehreren Monitoren kann es vorkommen dass Tray-Popups (z.B. MEGASync, Blueman) nicht korrekt positioniert sind. Das ist ein bekanntes i3/GTK-Problem. Workaround: Popup mit `Super + Mausklick` manuell verschieben.

### Nur Debian 12

Der Installer funktioniert ausschließlich auf **Debian 12 Bookworm**. Ubuntu, Mint, Kali und andere Derivate werden nicht unterstützt.

---

## Lizenz

SnowFoxOS wird unter der **SnowFox Public License v1.0** veröffentlicht — einer eigenen Lizenz die auf der Überzeugung basiert dass Software Menschen dienen sollte, nicht sie ausnutzen. Siehe [LICENSE](LICENSE) für Details.

---

<div align="center">
<sub>Gebaut von Alexander Valentin Ludwig (Xr7-Code) auf Debian 12</sub>
</div>


<!--
Might I confide? Horror deep inside
Help me break free, eternity
What's one more scar?

Mirror mirror do you clearly see?
Who is that staring back at me?
Mirror mirror do you clearly show?
Lies, those eyes from the depths below?

Come now little child
There is something you must hide
Take away, all I say
This is the only way
Heed those dark souls of night
And the righteous ones of light
There's no grey, only day
Path, chosen there you stay

So smile, run the mile, no one can know
The pain, darkened stain never show

Far, far away, where the night claims the day
There's a flame burning low, quiet, sad, faint glow
When the music starts, fuel the fire in our hearts
Ignite the skies, no more of your lies
I'm on my way

Now we're singing la la la...
Singing la la la...
Mirror mirror, I'm on my way!

I will not be shaken
I'm not that child forsaken
Away, now you stay
This is my reck'ning day
Unleash the beast inside
Precious time, enjoy the ride
Can you see? This is me
The truth shall set you free

So smile, own the mile, breathe life a new
For the song, it plays on, filling you

Far, far away, where the night claims the day
There's a flame burning low, quiet, sad, faint glow
When the music starts, fuel the fire in our hearts
Ignite the skies, no more of your lies
I'm on my way

Scar
One more scar, one more scar
One more scar
One more scar, one more, two more, three?

Far, far away, where the night claims the day
There's a flame burning low, quiet, sad, faint glow
When the music starts, fuel the fire in our hearts
Ignite the skies, no more of your lies
I'm on my way

Now we're gonna sail, sail away on a sea ever grey
With the changing of tide, do not fear nor hide
Fire ablaze within, burning light through the dim
Break of dawn, night is almost gone
I'm on my way 
-->

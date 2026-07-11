# SnowFoxOS — System- & Fehlerprotokoll

Dieses Dokument dient zur Nachverfolgung von System-Optimierungen, behobenen Fehlern und offenen To-Dos während der Entwicklung von SnowFoxOS.

---

## 🟢 Erledigt & Gefixt

### 🖥️ X11, Display & Kernel
* **X11 / `startx` startete nur mit sudo**
  * *Ursache:* Der X-Server blockiert normalen Benutzern standardmäßig den Zugriff auf die physische Konsole (TTY).
  * *Lösung:* In `/etc/X11/Xwrapper.config` die Zeile `allowed_users=anybody` eingetragen.
* **System fror beim Starten von X11 / i3 komplett ein**
  * *Ursache:* Der Realtek-WLAN-Chip erzeugte massenhaft PCIe-Bus-Fehler (AER), was den Kernel blockierte.
  * *Lösung:* In `/etc/default/grub` den Kernel-Parameter `pci=noaer` hinzugefügt.
* **Fenster-Schatten & Transparenz haben komplett gefehlt**
  * *Ursache:* Picom ist wegen eines Syntaxfehlers in der Konfigurationsdatei abgestürzt.
  * *Lösung:* In der `~/.config/picom.conf` am Ende des `wintypes`-Blocks ein fehlendes Semikolon (;) ergänzt.

### 🌐 Netzwerk & Treiber
* **WLAN-Karte (`wlo1`) war komplett "nicht verfügbar"**
  * *Ursache:* Die alte Debian-Netzwerkkonfiguration (`ifupdown`) hat die Karte exklusiv blockiert.
  * *Lösung:* Einträge in `/etc/network/interfaces` auskommentiert und das Device an den NetworkManager übergeben.
* **WLAN-Treiber wurde im XanMod-Kernel nicht gefunden**
  * *Ursache:* Durch das Kernel-Update hat sich der Modulname geändert (Unterstrich fiel weg).
  * *Lösung:* Das Modul mit dem neuen Namen `rtw88_8821ce` geladen und abgesichert.

### 🎨 Look & Feel (Konsistenz)
* **Papirus-Ordner blieben blau statt violett**
  * *Ursache:* Dem System fehlte das Anpassungs-Skript und die Syntax des Befehls hatte sich geändert.
  * *Lösung:* Skript installiert und Ordnerfarbe mit `papirus-folders -t Papirus-Dark -C violet -u` umgestellt.
* **Bibata-Modern-Classic Cursor als Standard setzen**
  * *Ursache:* Das GitHub-Release wechselte das Archiv-Format von `.tar.gz` auf `.tar.xz`, weshalb der Download im Installer fehlschlug.
  * *Lösung:* Skript auf `.tar.xz` umgestellt, automatische Versionsermittlung via API eingebaut und nach `/usr/share/icons/` entpackt.

### 📦 Paket-Management & Performance
* **Bluetui lässt sich nicht korrekt installieren**
  * *Ursache:* Cargo-Build aus den Quellen brauchte zu viele Ressourcen; zudem liefert das Upstream-Repository keine Tarballs mehr, sondern direkt Binärdateien.
  * *Lösung:* Der Installer zieht jetzt das unkomprimierte `musl`-Binary direkt von GitHub, setzt Ausführungsrechte und aktiviert die Bluetooth-Dienste.
* **System-Sprache & X11-Eingabemethode für Steam**
  * *Ursache:* System-Locales fehlten auf OS-Ebene, was X11-Fehler (`XOpenIM() failed`) in Steam verursachte.
  * *Lösung:* `dpkg-reconfigure locales` ausgeführt (`de_AT` & `en_US`) und den Cache gesäubert.
* **Hohe Bootzeit analysiert & optimiert**
  * *Ursache:* BIOS-Initialisierung (`9.0s`) und `docker.service` (`1.4s`) bremsten den Systemstart aus.
  * *Lösung:* Docker für den Installer auf Semiautomatik (`docker.socket`) umgestellt. BIOS "Fast Boot" vorgemerkt.
* **Heimliche Hintergrund-Dienste entfernt**
  * *Ursache:* Desktop-Portale (`xdg`) und das GNOME-Protokoll (`zeitgeist`) fraßen im Leerlauf unnötig RAM.
  * *Lösung:* `zeitgeist` restlos deinstalliert. Die XDG-User-Dienste über systemd dauerhaft maskiert.
* **Diodon Clipboard-Manager entfernt**
  * *Ursache:* Diodon verbrauchte selbst im leeren Zustand knapp 64 MB RAM durch schwere GTK3-Bibliotheken.
  * *Lösung:* `diodon` per `apt purge` gelöscht, um Platz für ein minimalistisches Backend zu machen.

---

## ⏳ In Arbeit

* **Darkmode für ALLE Anwendungen erzwingen (Visuelle Konsistenz)**
  * *Status:* GTK3/GTK4-CSS-Konfigurationen sind fertiggestellt. Kitty-Hintergrund wird im Installer über einen `cat`-Block auf ein edles, ultradunkles OLED-Schwarz (`#11111b`) gesetzt, um Terminal-Inhalte besser abzuheben.
  * *GTK2-Fix:* Das Paket `gtk2-engines-murrine` wurde in die Paketliste von Schritt 3 aufgenommen, damit die `engine "murrine"`-Zuweisungen in der `~/.gtkrc-2.0.mine` greifen und alte 3D-Balken verschwinden.
* **Steam-Freezes beim Workspace-Wechsel**
  * *Status:* Dem neuen Minimalsystem fehlten die 64-Bit-Intel-Medientreiber und die Off-Screen-Rendering-Erweiterungen. Pakete wurden nachinstalliert (`intel-media-va-driver:amd64`, `libosmesa6`, etc.). *Test läuft aktuell nach Reboot.*
* **RAM-Langzeitanalyse nach Optimierungen**
  * *Status:* Der Leerlauf-RAM ist nach dem Entfernen von Ballast von 863 MB auf 773 MB gesunken (Netto ca. 450-500 MB). Verbrauch wird unter verschiedenen Workloads weiter beobachtet.

---

## ⚠️ To-Do

* **NVIDIA-Treiber-Build schlägt auf frischem System fehl / `nvidia-smi` fehlt**
  * *Problem:* Der automatisierte Installer setzt die GRUB-Flags (`nvidia-drm.modeset=1`), liefert für den XanMod-v3-Kernel aber nicht automatisch die passenden Kernel-Header mit. Dadurch bricht der DKMS-Treiberbuild im Hintergrund ab.
  * *Ansatz:* 
    1. Spezifische Kernel-Header (`linux-headers-$(uname -r)`) direkt nach dem ersten Boot manuell nachinstallieren.
    2. Treiber über `dkms autoinstall` oder Paket-Reinstall erzwingen.
    3. Home-Verzeichnisrechte wieder komplett für den User freigeben, um X11-Berechtigungsfehler abzufangen:
       `sudo chown -R xr7-code:xr7-code /home/xr7-code`
* **Glas-Gradients / 3D-Effekte in GTK2-Menüs entfernen**
  * *Problem:* Das Basistheme (Arc-Dark) erzwingt vorgerenderte Grafik-Assets bei Hover-Effekten, wodurch reine Farb-Overrides ignoriert werden.
  * *Ansatz:* Entweder die Assets im Theme-Ordner patchen oder ein gänzlich flaches Theme als Basis wählen.
* **Greenclip als schlanken Clipboard-Dienst einrichten**
  * *Problem:* Nach dem Diodon-Auswurf wird ein ressourcenschonender Ersatz für die Zwischenablage benötigt.
  * *Ansatz:* Greenclip-Daemon als reinen Hintergrund-Prozess (ohne schweres Rofi-Menü) in die i3-Konfiguration einbauen.
* **Fehlende Grafiktreiber & Bibliotheken prüfen**
  * *Problem:* Auf dem neuen Minimalsystem könnten im Vergleich zum alten PC noch weitere Bibliotheken fehlen.
  * *Ansatz:* Vergleichs-Skript schreiben oder Paketlisten abgleichen, falls nach dem Grafik-Fix noch Ruckler auftreten.
* **Unnötige / Doppelte Programme entfernen**
  * *Problem:* Systembereinigung (z. B. doppelte Terminals wie XTerm/UXTerm, falls Kitty genutzt wird), um das OS schlank zu halten.
  * *Ansatz:* Paketliste durchgehen, Duplikate identifizieren und via `apt purge` entfernen.
* **Polybar für dieses Gerät anpassen**
  * *Problem:* Netzwerkschnittstellen, Akku-Module oder Monitor-Namen passen noch nicht zur Hardware.
  * *Ansatz:* Die `config.ini` der Polybar auf die lokalen Gerätenamen (`wlo1`, `BAT0` etc.) prüfen.

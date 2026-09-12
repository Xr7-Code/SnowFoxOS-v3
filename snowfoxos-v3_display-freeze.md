SnowFoxOS v3 — Display Freeze Debugging Report

Datum: 10.–12. September 2026
System: SnowFoxOS v3, Debian 12, XanMod 6.18.50, NVIDIA RTX 3050 + AMD Ryzen 5 iGPU, Dual-Monitor PRIME-Setup

Worum geht es

Nach einer Neuinstallation von SnowFoxOS v3 traten auf einem AMD+NVIDIA Dual-Monitor-Setup sporadische Display-Freezes auf. Der AMD-Monitor (an der Motherboard-iGPU) fror ein, während der NVIDIA-Monitor weiterlief. In fortgeschrittenen Fällen eskalierte der Freeze auf beide Monitore, sudo reboot hängte sich auf, und nur ein harter Reset half.

v2.2 lief auf identischer Hardware stabil.

Was alles getestet und analysiert wurde
Frühe Fixes — bestätigt und sinnvoll

picom backend = "xrender" → auf "glx" gewechselt. xrender hat keine native Synchronisation mit dem NVIDIA-Treiber und verursachte Freezes beim Öffnen von Rofi-Menüs. Fix war korrekt und notwendig.

xdg-desktop-portal nicht gestartet → XDG_CURRENT_DESKTOP=i3 fehlte, Portal fand kein Backend, Zen Browser fragte org.freedesktop.ScreenSaver im Sekundentakt an und blockierte den D-Bus. Wurde gefixt — aber der Installer maskiert das Portal aktiv wieder, was alle Fixes zunichte macht.

PipeWire RTKit-Berechtigungen → harmlose Fehler, kein Einfluss auf Freezes.

org.freedesktop.secrets Timeout → harmlos, nur langsamer App-Start.

Was sinnlos war oder nichts gebracht hat

amdgpu sg_display=0 → Parameter gibt -1 zurück, ist für diese APU-Architektur im PRIME-Kontext nicht wirksam. Kein Effekt auf den Fence-Deadlock.

amd_iommu=on in GRUB → IOMMU läuft auf diesem Board automatisch, Parameter redundant.

hdcp=0 → adressiert nicht den richtigen Code-Pfad, kein Effekt.

xscreensaver als ScreenSaver-DBus-Service → Workaround für ein Problem das durch den maskierten Portal-Service verursacht wurde. Unnötig wenn Portal korrekt läuft.

Kernel-Bisect zwischen 6.18.40 und 6.18.50 → hat Zeit gekostet, war aber nicht die Hauptursache. Freezes traten auf beiden Versionen auf.

6.18.37 testen → nicht möglich weil NVIDIA DKMS-Modul nicht gebaut wurde.

infoframe -22 Fehler → zunächst als Hauptursache verdächtigt, erwies sich als harmlos. Tritt bei jedem Nicht-4K-HDMI-Monitor auf, ist keine Fehlfunktion.

NVreg_PreserveVideoMemoryAllocations=1 → in allen Versionen (v2.1, v2.2, v3) identisch gesetzt, also kein Regressionsauslöser.

picom komplett deaktivieren → Freezes traten weiterhin auf, also nicht der alleinige Auslöser. Allerdings verringerte picom mit fading = true die Stabilität deutlich — in v2.2 war fading = false.

Die eigentlichen Ursachen

Ursache 1 — xrandr --setprovideroutputsource 1 0 in der .xinitrc

In v3 wurde folgender Block neu eingeführt:

bash
if lspci | grep -qi nvidia && lspci | grep -qi amd; then
    xrandr --setprovideroutputsource 1 0
    xrandr --auto
fi

Mit dem ironischen Kommentar "verhindert dma_fence_wait_timeout Freeze". Er verursacht genau das Gegenteil: Er aktiviert explizit den Reverse-PRIME-Mechanismus bei dem NVIDIA rendert und AMD als Output-Slave fungiert. Jeder Frame-Buffer-Wechsel muss dann über beide GPUs synchronisiert werden. Das führt zu einem stillen Kernel-Deadlock in drm_atomic_nonblocking_commit — kein Fehler wird geloggt, der Kernel friert einfach ein.

In v2.1 und v2.2 existierte dieser Block nicht. Der AMD-Monitor wurde ohne explizites PRIME-Setup betrieben und musste nach dem Login über das Display-Menü (Super+P) eingerichtet werden — was der Nutzer als normal kannte.

Ursache 2 — xdg-desktop-portal wird aktiv maskiert

Im Performance-Script von v3:

bash
sudo -u "$TARGET_USER" systemctl --user mask xdg-desktop-portal.service \
    xdg-desktop-portal-gtk.service xdg-desktop-portal-gnome.service

Der Installer deaktiviert den Portal-Service dauerhaft als "Ballast". Für klassische GTK-Apps ist das harmlos — aber Zen Browser als Flatpak fragt aggressiv nach Portal-Services. Ohne Portal wiederholt der Browser die Anfragen im Sekundentakt, was den D-Bus-Session-Bus blockiert und als Verstärker für andere Instabilitäten wirkt.

Warum v2.2 stabil war
Kein xrandr --setprovideroutputsource in der .xinitrc
fading = false in picom — weniger Compositor-Last
Portal nicht maskiert (der Masking-Code kam erst in v3)
Identische nvidia.conf, identische amdgpu.conf

Der entscheidende Unterschied war eine einzige Zeile im .xinitrc-Template.

Was im Installer geändert werden muss
bash
# ENTFERNEN aus .xinitrc Template:
if lspci | grep -qi nvidia && lspci | grep -qi amd; then
    xrandr --setprovideroutputsource 1 0
    xrandr --auto
fi

# ENTFERNEN aus performance.sh:
sudo -u "$TARGET_USER" systemctl --user mask xdg-desktop-portal.service \
    xdg-desktop-portal-gtk.service xdg-desktop-portal-gnome.service

Zusätzlich empfohlen:

fading = false in der picom Default-Config
XDG_CURRENT_DESKTOP=i3 in .xinitrc setzen vor exec i3
dbus-update-activation-environment mit DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP erweitern
Wichtiger Hinweis — es ist eventuell noch nicht vorbei

Der xrandr --setprovideroutputsource Block war mit hoher Wahrscheinlichkeit der Hauptauslöser. Aber nach Wochen mit mehreren täglich auftretenden Freezes braucht es mehrere Tage stabilen Betriebs unter normaler Last um das sicher zu bestätigen.

Folgende Szenarien sind noch möglich:

Freezes treten seltener aber weiterhin auf → es gibt einen zweiten unabhängigen Auslöser
Das System bleibt stabil → der Fix ist vollständig
Freezes treten nur unter spezifischer Last auf (Gaming, Video-Rendering) → PRIME-Interaktion unter hoher GPU-Last als Restproblem

Der nächste Schritt ist einfach: Normal weiterarbeiten, Browser nutzen, Fensterwechsel machen — und beobachten. Wenn in den nächsten 48 Stunden kein Freeze auftritt, ist der Fix als bestätigt anzusehen.

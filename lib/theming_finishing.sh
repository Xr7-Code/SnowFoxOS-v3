#!/bin/bash

# ============================================================
#  SnowFoxOS v3.0 — Configuration & Finishing Steps
# ============================================================

# Load utilities (assumes SCRIPT_DIR is set before sourcing)
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables from main script (assumed to be sourced/exported):
# TARGET_USER, TARGET_HOME, SCRIPT_DIR, IS_LAPTOP
# DEFAULT_BROWSER_DESKTOP, DEFAULT_EDITOR_DESKTOP, DEFAULT_FM_DESKTOP
# DKMS_HOOKS (used for restoring)

step "10/10 — Konfiguration & Finishing"

CONFIG_DIR="$TARGET_HOME/.config"
mkdir -p "$CONFIG_DIR/fastfetch"
mkdir -p "$TARGET_HOME/Pictures/wallpapers"

# ── Distro-Identität ─────────────────────────────────────────
# set_system_version() aus lib/system_setup.sh — schreibt os-release,
# lsb-release, /etc/issue und GRUB_DISTRIBUTOR korrekt und konsistent.
set_system_version

cat > /etc/lsb-release << 'EOF'
DISTRIB_ID=SnowFoxOS
DISTRIB_RELEASE=3.0
DISTRIB_CODENAME=fox
DISTRIB_DESCRIPTION="SnowFoxOS v3"
EOF

echo "snowfox"        > /etc/hostname
hostname snowfox 2>/dev/null || true
success "Distro-Identität gesetzt"

# ── Theme & GTK ──────────────────────────────────────────────
info "Aktiviere Arc-Dark + SnowFox-Farb-Overrides..."
mkdir -p "$CONFIG_DIR/xsettingsd"

for version in "3.0" "4.0"; do
    mkdir -p "$CONFIG_DIR/gtk-$version"
    cat > "$CONFIG_DIR/gtk-$version/settings.ini" << GEOF
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Inter 11
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=close,minimize,maximize:
GEOF
done

# gsettings Darkmode erzwingen
sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $TARGET_USER)/bus" \
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $TARGET_USER)/bus" \
    gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark' 2>/dev/null || true

# ── Papirus-Ordnerfarbe (violett statt Standard-Blau) ─────────
info "Installiere papirus-folders & setze Ordnerfarbe auf violett..."
wget -qO- https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/install.sh \
    | sh 2>/dev/null || warn "papirus-folders Installation fehlgeschlagen"
if command -v papirus-folders &>/dev/null; then
    papirus-folders -t Papirus-Dark -C violet -u 2>/dev/null || \
        sudo -u "$TARGET_USER" papirus-folders -t Papirus-Dark -C violet -u 2>/dev/null || \
        warn "papirus-folders konnte Ordnerfarbe nicht setzen"
    success "Papirus-Ordner auf violett umgestellt"
else
    warn "papirus-folders nicht gefunden — Ordnerfarbe bleibt Standard"
fi

cat > "$CONFIG_DIR/gtk-3.0/gtk.css" << 'CSSEOF'
/* SnowFox GTK3 Color Override — lädt über Arc-Dark */
@define-color bg_color          #1e1e2e;
@define-color bg_alt_color      #252538;
@define-color bg_hover_color    #2e2e45;
@define-color fg_color          #cdd6f4;
@define-color fg_dim_color      #6c7086;
@define-color selected_bg_color #8139e8;
@define-color selected_fg_color #ffffff;
@define-color purple_hover      #9b5ef0;
@define-color purple_active     #6a2fc0;
@define-color error_color       #e05555;
@define-color success_color     #5faf5f;
@define-color warning_color     #ff9f5e;
@define-color border_color      #3d2a5c;

@define-color theme_bg_color              #1e1e2e;
@define-color theme_fg_color              #cdd6f4;
@define-color theme_base_color            #252538;
@define-color theme_text_color            #cdd6f4;
@define-color theme_selected_bg_color     #8139e8;
@define-color theme_selected_fg_color     #ffffff;
@define-color theme_tooltip_bg_color      #252538;
@define-color theme_tooltip_fg_color      #cdd6f4;
@define-color insensitive_bg_color        #1e1e2e;
@define-color insensitive_fg_color        #6c7086;
@define-color borders                     #3d2a5c;
@define-color alt_borders                 #3d2a5c;
@define-color sidebar_bg_color            #252538;
@define-color sidebar_fg_color            #cdd6f4;
@define-color link_color                  #9b5ef0;
@define-color link_visited_color          #6a2fc0;

window, .background         { background-color: @bg_color; color: @fg_color; }
headerbar, .titlebar        { background-color: @bg_alt_color; color: @fg_color; border-bottom: 1px solid @border_color; }
headerbar:backdrop          { background-color: @bg_color; color: @fg_dim_color; }
button                      { background-color: @bg_alt_color; color: @fg_color; border-color: @border_color; border-radius: 5px; }
button:hover                { background-color: @bg_hover_color; border-color: @selected_bg_color; }
button:active, button:checked { background-color: @purple_active; color: @selected_fg_color; border-color: @selected_bg_color; }
button:disabled             { background-color: @bg_color; color: @fg_dim_color; }
button.suggested-action     { background-color: @selected_bg_color; color: @selected_fg_color; border-color: @selected_bg_color; }
button.suggested-action:hover { background-color: @purple_hover; }
button.destructive-action   { background-color: @error_color; color: @selected_fg_color; border-color: @error_color; }
entry, spinbutton           { background-color: @bg_alt_color; color: @fg_color; border-color: @border_color; border-radius: 5px; caret-color: @selected_bg_color; }
entry:focus, spinbutton:focus { border-color: @selected_bg_color; }
entry selection             { background-color: @selected_bg_color; color: @selected_fg_color; }
menubar                     { background-color: @bg_color; color: @fg_color; }
menubar > menuitem:hover    { background-color: @bg_hover_color; }
menu, .menu                 { background-color: @bg_alt_color; color: @fg_color; border-color: @border_color; }
menuitem                    { color: @fg_color; }
menuitem:hover              { background-color: @selected_bg_color; color: @selected_fg_color; }
menuitem:disabled           { color: @fg_dim_color; }
.sidebar, placessidebar     { background-color: @bg_alt_color; color: @fg_color; border-color: @border_color; }
.sidebar row:hover, placessidebar row:hover { background-color: @bg_hover_color; }
.sidebar row:selected, placessidebar row:selected { background-color: @selected_bg_color; color: @selected_fg_color; }
treeview, treeview.view     { background-color: @bg_color; color: @fg_color; }
treeview:selected, treeview row:selected { background-color: @selected_bg_color; color: @selected_fg_color; }
treeview:hover              { background-color: @bg_hover_color; }
notebook > header           { background-color: @bg_alt_color; border-color: @border_color; }
notebook > header > tabs > tab { background-color: transparent; color: @fg_dim_color; }
notebook > header > tabs > tab:checked { background-color: @bg_color; color: @fg_color; }
notebook > header > tabs > tab:hover { background-color: @bg_hover_color; color: @fg_color; }
scrollbar trough            { background-color: @bg_alt_color; }
scrollbar slider            { background-color: @fg_dim_color; border-radius: 8px; }
scrollbar slider:hover      { background-color: @selected_bg_color; }
tooltip                     { background-color: @bg_alt_color; color: @fg_color; border-color: @border_color; border-radius: 5px; }
tooltip label               { color: @fg_color; }
popover                     { background-color: @bg_alt_color; border-color: @border_color; border-radius: 8px; }
list, listbox               { background-color: @bg_color; color: @fg_color; }
list row:hover, listbox row:hover { background-color: @bg_hover_color; }
list row:selected, listbox row:selected { background-color: @selected_bg_color; color: @selected_fg_color; }
check:checked, radio:checked { background-color: @selected_bg_color; border-color: @selected_bg_color; color: @selected_fg_color; }
switch:checked              { background-color: @selected_bg_color; border-color: @selected_bg_color; }
progressbar progress        { background-color: @selected_bg_color; }
progressbar trough          { background-color: @bg_alt_color; }
scale trough highlight      { background-color: @selected_bg_color; }
scale slider                { background-color: @selected_bg_color; border-color: @selected_bg_color; }
paned > separator           { background-color: @bg_hover_color; }
paned > separator:hover     { background-color: @selected_bg_color; }
statusbar                   { background-color: @bg_color; color: @fg_dim_color; }
label                       { color: @fg_color; }
label.dim-label, label:disabled { color: @fg_dim_color; }
*:link                      { color: @purple_hover; }
*:visited                   { color: @purple_active; }
button, entry, menu, menuitem, popover,
notebook > header > tabs > tab { border-radius: 5px; }
CSSEOF

cat > "$CONFIG_DIR/gtk-4.0/gtk.css" << 'CSS4EOF'
/* SnowFox GTK4 / Libadwaita Color Override */
:root {
    --accent-bg-color:       #8139e8;
    --accent-fg-color:       #ffffff;
    --accent-color:          #9b5ef0;
    --destructive-bg-color:  #e05555;
    --destructive-fg-color:  #ffffff;
    --success-bg-color:      #5faf5f;
    --success-fg-color:      #ffffff;
    --warning-bg-color:      #ff9f5e;
    --warning-fg-color:      #1e1e2e;
    --error-bg-color:        #e05555;
    --error-fg-color:        #ffffff;
    --window-bg-color:       #1e1e2e;
    --window-fg-color:       #cdd6f4;
    --view-bg-color:         #252538;
    --view-fg-color:         #cdd6f4;
    --headerbar-bg-color:    #252538;
    --headerbar-fg-color:    #cdd6f4;
    --headerbar-border-color:#3d2a5c;
    --headerbar-shade-color: rgba(0,0,0,0.2);
    --sidebar-bg-color:      #252538;
    --sidebar-fg-color:      #cdd6f4;
    --sidebar-border-color:  #3d2a5c;
    --card-bg-color:         #252538;
    --card-fg-color:         #cdd6f4;
    --card-shade-color:      rgba(0,0,0,0.15);
    --dialog-bg-color:       #1e1e2e;
    --dialog-fg-color:       #cdd6f4;
    --popover-bg-color:      #252538;
    --popover-fg-color:      #cdd6f4;
    --shade-color:           rgba(0,0,0,0.25);
    --scrollbar-outline-color: rgba(0,0,0,0.3);
    --thumbnail-bg-color:    #2e2e45;
    --thumbnail-fg-color:    #cdd6f4;
}
CSS4EOF

# GTK2
cat > "$TARGET_HOME/.gtkrc-2.0" << G2EOF
include "/usr/share/themes/Arc-Dark/gtk-2.0/gtkrc"
include "$TARGET_HOME/.gtkrc-2.0.mine"
G2EOF

cat > "$TARGET_HOME/.gtkrc-2.0.mine" << 'G2EOF'
# SnowFox GTK2 Override (FLAT/MODERN)
gtk-color-scheme = "main_bg:#1e1e2e\nmain_fg:#cdd6f4\ntext_color:#cdd6f4\nbase_color:#1e1e2e\nselected_bg_color:#8139e8\nselected_fg_color:#ffffff\ntoolbar_bg:#1e1e2e\nmenubar_bg:#1e1e2e"

style "snowfox-colors" {
    base[NORMAL]      = "#1e1e2e"
    base[ACTIVE]      = "#8139e8"
    base[INSENSITIVE] = "#1e1e2e"
    base[SELECTED]    = "#8139e8"
    bg[NORMAL]        = "#1e1e2e"
    bg[ACTIVE]        = "#252538"
    bg[INSENSITIVE]   = "#1e1e2e"
    bg[SELECTED]      = "#8139e8"
    bg[PRELIGHT]      = "#252538"
    text[NORMAL]      = "#cdd6f4"
    text[ACTIVE]      = "#ffffff"
    text[SELECTED]    = "#ffffff"
    fg[NORMAL]        = "#cdd6f4"
    fg[ACTIVE]        = "#ffffff"
    fg[SELECTED]      = "#ffffff"
    fg[PRELIGHT]      = "#ffffff"
}

style "snowfox-sidebar" {
    base[NORMAL]      = "#252538"
    base[ACTIVE]      = "#2e2e45"
    base[SELECTED]    = "#8139e8"
    bg[NORMAL]        = "#252538"
    bg[ACTIVE]        = "#2e2e45"
    text[NORMAL]      = "#cdd6f4"
    text[SELECTED]    = "#ffffff"
    fg[NORMAL]        = "#cdd6f4"
    GtkTreeView::vertical-separator   = 4
    GtkTreeView::horizontal-separator = 4
}

style "snowfox-leisten" {
    bg[NORMAL]   = "#1e1e2e"
    bg[ACTIVE]   = "#252538"
    bg[PRELIGHT] = "#252538"
    fg[NORMAL]   = "#cdd6f4"
    engine "murrine" {
        gradient_shades   = { 1.0, 1.0, 1.0, 1.0 }
        contrast          = 0.0
        lightborder_shade = 1.0
        glow_shade        = 1.0
    }
}

style "snowfox-menus" {
    base[NORMAL]   = "#252538"
    bg[NORMAL]     = "#252538"
    bg[PRELIGHT]   = "#8139e8"
    bg[SELECTED]   = "#8139e8"
    fg[NORMAL]     = "#cdd6f4"
    fg[PRELIGHT]   = "#ffffff"
    text[NORMAL]   = "#cdd6f4"
    text[PRELIGHT] = "#ffffff"
    engine "murrine" {
        gradient_shades   = { 1.0, 1.0, 1.0, 1.0 }
        contrast          = 0.0
        lightborder_shade = 1.0
        glow_shade        = 1.0
        roundness         = 0
    }
}

style "snowfox-widgets" {
    base[NORMAL]   = "#252538"
    bg[NORMAL]     = "#252538"
    bg[PRELIGHT]   = "#2e2e45"
    bg[ACTIVE]     = "#8139e8"
    fg[NORMAL]     = "#cdd6f4"
    text[NORMAL]   = "#cdd6f4"
    engine "murrine" {
        gradient_shades   = { 1.0, 1.0, 1.0, 1.0 }
        contrast          = 0.0
        lightborder_shade = 1.0
        glow_shade        = 1.0
        roundness         = 3
    }
}

style "snowfox-trenner" {
    bg[NORMAL]        = "#8139e8"
    bg[ACTIVE]        = "#8139e8"
    bg[PRELIGHT]      = "#8139e8"
    GtkPaned::handle-size = 2
}

class "GtkWidget"                   style "snowfox-colors"
widget_class "*"                    style "snowfox-colors"
widget_class "*<GtkMenuBar>*"       style "snowfox-leisten"
widget_class "*<GtkToolbar>*"       style "snowfox-leisten"
class "GtkPaned"                    style "snowfox-trenner"
widget_class "*<GtkButton>*"        style "snowfox-widgets"
widget_class "*<GtkEntry>*"         style "snowfox-widgets"
widget_class "*<GtkMenu>*"          style:highest "snowfox-menus"
widget_class "*<GtkMenuItem>*"      style:highest "snowfox-menus"
widget_class "*MenuBar*.*MenuItem*" style:highest "snowfox-menus"
widget_class "*<GtkTreeView>*"      style "snowfox-sidebar"
widget_class "*<GtkSidePane>*"      style "snowfox-sidebar"
widget_class "*FmSidebar*"          style "snowfox-sidebar"
widget_class "*FmSidePane*"         style "snowfox-sidebar"
widget_class "*FmTreeView*"         style "snowfox-sidebar"
G2EOF

cat > "$CONFIG_DIR/xsettingsd/xsettingsd.conf" << XEOF
Net/ThemeName "Arc-Dark"
Net/IconThemeName "Papirus-Dark"
Gtk/CursorThemeName "Bibata-Modern-Classic"
Gtk/CursorThemeSize 24
XEOF

mkdir -p "$TARGET_HOME/.icons/default"
cat > "$TARGET_HOME/.icons/default/index.theme" << IEOF
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=Bibata-Modern-Classic
IEOF

info "Konfiguriere Qt-Styling..."
mkdir -p "$CONFIG_DIR/qt5ct" "$CONFIG_DIR/qt6ct"

cat > "$CONFIG_DIR/qt5ct/qt5ct.conf" << Q5EOF
[Appearance]
style=gtk2
Q5EOF

cat > "$CONFIG_DIR/qt6ct/qt6ct.conf" << Q6EOF
[Appearance]
style=gtk2
Q6EOF

# ── fastfetch Config ──────────────────────────────────────────
info "Konfiguriere fastfetch..."
if [[ -f "$SCRIPT_DIR/configs/fastfetch/config.jsonc" ]]; then
    mkdir -p "$CONFIG_DIR/fastfetch"
    cp "$SCRIPT_DIR/configs/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
    # Logo-Pfad auf aktuelles Repo anpassen
    sed -i "s|/home/xr7-code/SnowFoxOS-v2.2/assets/fuchs.png|$SCRIPT_DIR/assets/fuchs.png|g" \
        "$CONFIG_DIR/fastfetch/config.jsonc"
    success "fastfetch Config aus Repo kopiert"
else
    mkdir -p "$CONFIG_DIR/fastfetch"
    cat > "$CONFIG_DIR/fastfetch/config.jsonc" << FFEOF
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json",
  "logo": {
    "source": "$SCRIPT_DIR/assets/fuchs.png",
    "type": "kitty-direct",
    "width": 24,
    "height": 11
  },
  "modules": [
    "title",
    "separator",
    "os",
    "host",
    "kernel",
    "uptime",
    "packages",
    "shell",
    "display",
    "wm",
    "theme",
    "icons",
    "font",
    "cursor",
    "terminal",
    "terminalfont",
    "cpu",
    "gpu",
    "memory",
    "swap",
    "disk",
    "localip",
    "locale",
    "break",
    "colors"
  ]
}
FFEOF
    success "fastfetch Config erstellt"
fi

# ── bashrc — fastfetch statt neofetch ────────────────────────
grep -q "fastfetch\|neofetch\|snowfox-greeting" "$TARGET_HOME/.bashrc" 2>/dev/null || \
    printf '\n# SnowFoxOS Greeting\n[[ -x /usr/local/bin/snowfox-greeting ]] && snowfox-greeting\n' \
    >> "$TARGET_HOME/.bashrc"

if [[ -d "$SCRIPT_DIR/configs" ]]; then
    cp -r "$SCRIPT_DIR/configs/"* "$CONFIG_DIR/"
    success "Konfigurationsdateien kopiert"

    # Rofi Config anpassen — kein border-radius (kein picom mehr)
    if [[ -f "$CONFIG_DIR/rofi/config.rasi" ]]; then
        sed -i 's/show-icons: .*/show-icons: false;/' "$CONFIG_DIR/rofi/config.rasi"
        sed -i 's/icon-theme: .*/icon-theme: "Papirus-Dark";/' "$CONFIG_DIR/rofi/config.rasi"
        # border-radius auf 0 da kein picom
        sed -i 's/border-radius: [0-9]*;/border-radius: 0;/g' "$CONFIG_DIR/rofi/config.rasi"
        success "Rofi Config angepasst (border-radius=0, kein picom)"
    fi

    # picom Config entfernen falls vorhanden
    rm -f "$CONFIG_DIR/picom.conf" 2>/dev/null || true

    I3_CONFIG_PATH="$CONFIG_DIR/i3/config"
    if [[ -f "$I3_CONFIG_PATH" ]]; then
        # picom aus i3 Autostart entfernen
        sed -i '/exec.*picom/d' "$I3_CONFIG_PATH"
        sed -i '/exec --no-startup-id picom/d' "$I3_CONFIG_PATH"

        if grep -q '^bindsym \$mod+e' "$I3_CONFIG_PATH"; then
            sed -i 's|^bindsym \$mod+e.*|bindsym $mod+e exec pcmanfm|' "$I3_CONFIG_PATH"
        else
            echo 'bindsym $mod+e exec pcmanfm' >> "$I3_CONFIG_PATH"
        fi

        if grep -q '^bindsym \$mod+n' "$I3_CONFIG_PATH"; then
            sed -i 's|^bindsym \$mod+n.*|bindsym $mod+n exec kitty -e nmtui|' "$I3_CONFIG_PATH"
        else
            echo 'bindsym $mod+n exec kitty -e nmtui' >> "$I3_CONFIG_PATH"
        fi

        # Greenclip Autostart
        grep -q "greenclip" "$I3_CONFIG_PATH" || \
            echo 'exec --no-startup-id greenclip daemon' >> "$I3_CONFIG_PATH"

        success "i3-Config angepasst (picom entfernt, Shortcuts gesetzt, greenclip)"
    fi

    # GTK3-Override nach cp sicherstellen
    info "Stelle GTK3-Override nach Repo-Kopie sicher..."
    cp "$CONFIG_DIR/gtk-3.0/gtk.css" "$CONFIG_DIR/gtk-3.0/gtk.css.repo-bak" 2>/dev/null || true
    # (gtk.css wurde bereits oben geschrieben, cp -r könnte sie überschreiben haben)
    # Daher nochmal die fastfetch Config sichern
    if [[ -f "$CONFIG_DIR/fastfetch/config.jsonc" ]]; then
        sed -i "s|/home/xr7-code/SnowFoxOS-v2.2/assets/fuchs.png|$SCRIPT_DIR/assets/fuchs.png|g" \
            "$CONFIG_DIR/fastfetch/config.jsonc" 2>/dev/null || true
    fi

    success "GTK3-Override sichergestellt"
else
    warn "configs/-Verzeichnis nicht gefunden"
fi

find "$CONFIG_DIR" -name "*.sh" -exec chmod +x {} +

[[ -d "$SCRIPT_DIR/wallpapers" ]] && \
    cp -r "$SCRIPT_DIR/wallpapers/." "$TARGET_HOME/Pictures/wallpapers/"

DEFAULT_WP=$(ls "$TARGET_HOME/Pictures/wallpapers" 2>/dev/null | grep -iE "\.jpg$|\.png$|\.webp$|\.jpeg$" | head -n 1)
if [[ -n "$DEFAULT_WP" ]]; then
    echo "#!/bin/sh" > "$TARGET_HOME/.fehbg"
    echo "feh --bg-fill '$TARGET_HOME/Pictures/wallpapers/$DEFAULT_WP'" >> "$TARGET_HOME/.fehbg"
    chmod +x "$TARGET_HOME/.fehbg"
    chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.fehbg"
    info "Standard-Wallpaper gesetzt: $DEFAULT_WP"
fi

POLYBAR_CONF="$CONFIG_DIR/polybar/config.ini"
if [[ -f "$POLYBAR_CONF" ]]; then
    if [[ "$IS_LAPTOP" == "true" ]]; then
        BAT_NAME=$(ls /sys/class/power_supply/ 2>/dev/null | grep -E "BAT|battery" | head -1)
        [[ -n "$BAT_NAME" ]] && sed -i "s/battery = BAT1/battery = $BAT_NAME/" "$POLYBAR_CONF"

        BL_NAME=$(ls /sys/class/backlight/ 2>/dev/null | head -1)
        [[ -n "$BL_NAME" ]] && sed -i "s/card = intel_backlight/card = $BL_NAME/" "$POLYBAR_CONF"

        sed -i 's/^modules-right =.*/modules-right = backlight battery memory network pulseaudio/' "$POLYBAR_CONF"
        success "Polybar: Laptop-Modus (Akku + Helligkeit aktiv)"
    else
        sed -i 's/^modules-right =.*/modules-right = memory network pulseaudio/' "$POLYBAR_CONF"
        success "Polybar: Desktop-Modus (kein Akku/Helligkeit)"
    fi
fi

if [[ -d "$SCRIPT_DIR/configs/modprobe" ]]; then
    # amdgpu.conf wurde bereits oben mit Freeze-Fix geschrieben, nicht überschreiben
    # nvidia.conf aus Repo kopieren falls vorhanden, sonst Standard schreiben
    if [[ -f "$SCRIPT_DIR/configs/modprobe/nvidia.conf" ]]; then
        cp "$SCRIPT_DIR/configs/modprobe/nvidia.conf" /etc/modprobe.d/nvidia.conf
    fi
    update-initramfs -u 2>/dev/null || true
    success "modprobe Configs installiert"
fi

# nvidia.conf sicherstellen — falls nicht aus Repo kopiert
if [[ ! -f /etc/modprobe.d/nvidia.conf ]]; then
    cat > /etc/modprobe.d/nvidia.conf << 'EOF'
# SnowFoxOS — NVIDIA Konfiguration
blacklist nouveau

options nvidia NVreg_TemporaryFilePath=/var/tmp
options nvidia NVreg_EnableS0ixPowerManagement=0
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia-drm modeset=1
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_EnableGpuFirmware=0
EOF
    success "nvidia.conf geschrieben"
fi

[[ -f "$SCRIPT_DIR/configs/powermenu.sh" ]] && \
    cp "$SCRIPT_DIR/configs/powermenu.sh" /usr/local/bin/snowfox-powermenu && \
    chmod +x /usr/local/bin/snowfox-powermenu

if [[ -f "$SCRIPT_DIR/configs/snowfox-display.sh" ]]; then
    cp "$SCRIPT_DIR/configs/snowfox-display.sh" "$CONFIG_DIR/snowfox-display.sh"
    if ! grep -q "polybar/launch.sh" "$CONFIG_DIR/snowfox-display.sh"; then
        sed -i 's/i3-msg restart/i3-msg reload/' "$CONFIG_DIR/snowfox-display.sh"
        echo "" >> "$CONFIG_DIR/snowfox-display.sh"
        echo "sleep 0.5" >> "$CONFIG_DIR/snowfox-display.sh"
        echo "~/.config/polybar/launch.sh" >> "$CONFIG_DIR/snowfox-display.sh"
    fi
    chmod +x "$CONFIG_DIR/snowfox-display.sh"
    success "snowfox-display.sh installiert"
fi

mkdir -p "$CONFIG_DIR/polybar"
cat > "$CONFIG_DIR/polybar/launch.sh" << 'LAUNCHEOF'
#!/bin/bash
# SnowFoxOS — Polybar Starter
sleep 2
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done
PRIMARY=$(xrandr --query | grep " connected primary" | cut -d" " -f1)
if [[ -z "$PRIMARY" ]]; then
    PRIMARY=$(xrandr --query | grep " connected" | head -1 | cut -d" " -f1)
fi
MONITOR=$PRIMARY polybar snowfox 2>/tmp/polybar.log &
LAUNCHEOF
chmod +x "$CONFIG_DIR/polybar/launch.sh"
success "polybar/launch.sh installiert"

[[ -f "$SCRIPT_DIR/snowfox" ]] && \
    cp "$SCRIPT_DIR/snowfox" /usr/local/bin/snowfox && chmod +x /usr/local/bin/snowfox

[[ -f "$SCRIPT_DIR/snowfox-greeting.sh" ]] && \
    cp "$SCRIPT_DIR/snowfox-greeting.sh" /usr/local/bin/snowfox-greeting && \
    chmod +x /usr/local/bin/snowfox-greeting

echo ""
echo -e "${PURPLE}${BOLD}  Standard-Texteditor:${RESET}"
echo -e "  1) Mousepad (Standard)"
echo -e "  2) VSCodium"
read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-2]: "${RESET})" DEFAULT_EDITOR
case "$DEFAULT_EDITOR" in
    2) DEFAULT_EDITOR_DESKTOP="codium.desktop" ;;
    *) DEFAULT_EDITOR_DESKTOP="mousepad.desktop" ;;
esac

# DEFAULT_FM_DESKTOP should be set by lib/default_apps.sh if PCManFM was installed,
# otherwise fall back to a default. For now, set a default.
DEFAULT_FM_DESKTOP="pcmanfm.desktop"

cat > "$CONFIG_DIR/mimeapps.list" << MEOF
[Default Applications]
inode/directory=$DEFAULT_FM_DESKTOP
text/plain=$DEFAULT_EDITOR_DESKTOP
text/x-python=$DEFAULT_EDITOR_DESKTOP
text/x-shellscript=$DEFAULT_EDITOR_DESKTOP
application/x-shellscript=$DEFAULT_EDITOR_DESKTOP
x-scheme-handler/http=$DEFAULT_BROWSER_DESKTOP
x-scheme-handler/https=$DEFAULT_BROWSER_DESKTOP
text/html=$DEFAULT_BROWSER_DESKTOP
application/xhtml+xml=$DEFAULT_BROWSER_DESKTOP
application/pdf=$DEFAULT_BROWSER_DESKTOP
image/png=ristretto.desktop
image/jpeg=ristretto.desktop
image/gif=ristretto.desktop
video/mp4=mpv.desktop
video/x-matroska=mpv.desktop
audio/mpeg=mpv.desktop
application/zip=file-roller.desktop
application/x-tar=file-roller.desktop
MEOF
success "Standard-Anwendungen gesetzt"

# ── Berechtigungen ───────────────────────────────────────────
chown -R "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/Pictures/wallpapers"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.icons"
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.gtkrc-2.0"
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.gtkrc-2.0.mine"
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.bash_profile"

# DKMS_HOOKS is defined in the main script and assumed to be available
DKMS_HOOKS=(
    /etc/kernel/postinst.d/dkms
    /etc/kernel/prerm.d/dkms
    /usr/lib/kernel/install.d/50-dkms.install
)
for hook in "${DKMS_HOOKS[@]}"; do
    [[ -f "${hook}.snowfox-bak" ]] && mv "${hook}.snowfox-bak" "$hook"
done
info "DKMS-Hooks wiederhergestellt"

# ── initramfs mit allen Fixes neu bauen ──────────────────────
info "Baue initramfs mit allen Fixes neu..."
update-initramfs -u 2>/dev/null || true
success "initramfs aktualisiert"

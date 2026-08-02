#!/bin/bash

# ============================================================
#  SnowFoxOS v3.0 — Configuration & Finishing Steps
# ============================================================

source "$SCRIPT_DIR/lib/utils.sh"

step "10/10 — Konfiguration & Finishing"

CONFIG_DIR="$TARGET_HOME/.config"
mkdir -p "$CONFIG_DIR/fastfetch"
mkdir -p "$TARGET_HOME/Pictures/wallpapers"

# ── Distro-Identität ─────────────────────────────────────────
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

sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $TARGET_USER)/bus" \
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $TARGET_USER)/bus" \
    gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark' 2>/dev/null || true

# ── Papirus-Ordnerfarbe ───────────────────────────────────────
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

# ── GTK3 CSS ─────────────────────────────────────────────────
cat > "$CONFIG_DIR/gtk-3.0/gtk.css" << 'CSSEOF'
/* SnowFox GTK3 Color Override — lädt über Arc-Dark */
@define-color bg_color          #1a1825;
@define-color bg_alt_color      #201e2e;
@define-color bg_hover_color    #2a2840;
@define-color fg_color          #e0d9f5;
@define-color fg_dim_color      #6e6a8a;
@define-color selected_bg_color #9d6fe8;
@define-color selected_fg_color #ffffff;
@define-color purple_hover      #b899ff;
@define-color purple_active     #5c3d99;
@define-color error_color       #e87a7a;
@define-color success_color     #89c98a;
@define-color warning_color     #e8c97a;
@define-color border_color      #2a2840;

@define-color theme_bg_color            #1a1825;
@define-color theme_fg_color            #e0d9f5;
@define-color theme_base_color          #201e2e;
@define-color theme_text_color          #e0d9f5;
@define-color theme_selected_bg_color   #9d6fe8;
@define-color theme_selected_fg_color   #ffffff;
@define-color theme_tooltip_bg_color    #2a2840;
@define-color theme_tooltip_fg_color    #e0d9f5;
@define-color insensitive_bg_color      #1a1825;
@define-color insensitive_fg_color      #6e6a8a;
@define-color borders                   #2a2840;
@define-color alt_borders               #2a2840;
@define-color sidebar_bg_color          #201e2e;
@define-color sidebar_fg_color          #e0d9f5;
@define-color link_color                #b899ff;
@define-color link_visited_color        #5c3d99;

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

# ── GTK4 CSS ─────────────────────────────────────────────────
cat > "$CONFIG_DIR/gtk-4.0/gtk.css" << 'CSS4EOF'
/* SnowFox GTK4 / Libadwaita Color Override */
:root {
    --accent-bg-color:       #9d6fe8;
    --accent-fg-color:       #ffffff;
    --accent-color:          #b899ff;
    --destructive-bg-color:  #e87a7a;
    --destructive-fg-color:  #ffffff;
    --success-bg-color:      #89c98a;
    --success-fg-color:      #ffffff;
    --warning-bg-color:      #e8c97a;
    --warning-fg-color:      #1a1825;
    --error-bg-color:        #e87a7a;
    --error-fg-color:        #ffffff;
    --window-bg-color:       #1a1825;
    --window-fg-color:       #e0d9f5;
    --view-bg-color:         #201e2e;
    --view-fg-color:         #e0d9f5;
    --headerbar-bg-color:    #201e2e;
    --headerbar-fg-color:    #e0d9f5;
    --headerbar-border-color:#2a2840;
    --headerbar-shade-color: rgba(0,0,0,0.2);
    --sidebar-bg-color:      #201e2e;
    --sidebar-fg-color:      #e0d9f5;
    --sidebar-border-color:  #2a2840;
    --card-bg-color:         #201e2e;
    --card-fg-color:         #e0d9f5;
    --card-shade-color:      rgba(0,0,0,0.15);
    --dialog-bg-color:       #1a1825;
    --dialog-fg-color:       #e0d9f5;
    --popover-bg-color:      #2a2840;
    --popover-fg-color:      #e0d9f5;
    --shade-color:           rgba(0,0,0,0.25);
    --scrollbar-outline-color: rgba(0,0,0,0.3);
    --thumbnail-bg-color:    #2a2840;
    --thumbnail-fg-color:    #e0d9f5;
}
CSS4EOF

# ── GTK2 ─────────────────────────────────────────────────────
cat > "$TARGET_HOME/.gtkrc-2.0" << G2EOF
include "/usr/share/themes/Arc-Dark/gtk-2.0/gtkrc"
include "$TARGET_HOME/.gtkrc-2.0.mine"
G2EOF

cat > "$TARGET_HOME/.gtkrc-2.0.mine" << 'G2EOF'
gtk-color-scheme = "bg_color:#1a1825\nbg_alt_color:#201e2e\nbg_surface:#2a2840\nbg_hover:#332f50\nfg_color:#e0d9f5\nfg_dim_color:#6e6a8a\nbase_color:#1a1825\ntext_color:#e0d9f5\nselected_bg_color:#9d6fe8\nselected_fg_color:#ffffff\npurple_hover:#b899ff\nborder_color:#2a2840\ntooltip_bg_color:#2a2840\ntooltip_fg_color:#e0d9f5"

style "snowfox-colors" {
    base[NORMAL]      = "#1a1825"
    base[ACTIVE]      = "#332f50"
    base[INSENSITIVE] = "#1a1825"
    base[SELECTED]    = "#9d6fe8"
    bg[NORMAL]        = "#2a2840"
    bg[ACTIVE]        = "#201e2e"
    bg[INSENSITIVE]   = "#1a1825"
    bg[SELECTED]      = "#9d6fe8"
    bg[PRELIGHT]      = "#332f50"
    text[NORMAL]      = "#e0d9f5"
    text[ACTIVE]      = "#ffffff"
    text[SELECTED]    = "#ffffff"
    text[INSENSITIVE] = "#6e6a8a"
    fg[NORMAL]        = "#e0d9f5"
    fg[ACTIVE]        = "#ffffff"
    fg[SELECTED]      = "#ffffff"
    fg[PRELIGHT]      = "#ffffff"
    fg[INSENSITIVE]   = "#6e6a8a"
    engine "murrine" {
        contrast            = 0.0
        gradient_shades     = { 1.0, 1.0, 1.0, 1.0 }
        lightborder_shade   = 1.0
        border_shades       = { 1.0, 1.0 }
        focus_color         = "#b899ff"
    }
}

style "snowfox-sidebar" {
    base[NORMAL]      = "#201e2e"
    base[ACTIVE]      = "#332f50"
    base[SELECTED]    = "#9d6fe8"
    bg[NORMAL]        = "#201e2e"
    bg[ACTIVE]        = "#332f50"
    bg[PRELIGHT]      = "#332f50"
    bg[SELECTED]      = "#9d6fe8"
    text[NORMAL]      = "#e0d9f5"
    text[SELECTED]    = "#ffffff"
    fg[NORMAL]        = "#e0d9f5"
    fg[PRELIGHT]      = "#ffffff"
    fg[SELECTED]      = "#ffffff"
    GtkTreeView::vertical-separator   = 4
    GtkTreeView::horizontal-separator = 4
}

style "snowfox-leisten" {
    bg[NORMAL]   = "#1a1825"
    bg[ACTIVE]   = "#201e2e"
    bg[PRELIGHT] = "#2a2840"
    fg[NORMAL]   = "#e0d9f5"
    engine "murrine" {
        gradient_shades   = { 1.0, 1.0, 1.0, 1.0 }
        contrast          = 0.0
        lightborder_shade = 1.0
        glow_shade        = 1.0
    }
}

style "snowfox-menus" {
    base[NORMAL]   = "#2a2840"
    bg[NORMAL]     = "#2a2840"
    bg[PRELIGHT]   = "#9d6fe8"
    bg[SELECTED]   = "#9d6fe8"
    fg[NORMAL]     = "#e0d9f5"
    fg[PRELIGHT]   = "#ffffff"
    text[NORMAL]   = "#e0d9f5"
    text[PRELIGHT] = "#ffffff"
    engine "murrine" {
        gradient_shades   = { 1.0, 1.0, 1.0, 1.0 }
        contrast          = 0.0
        lightborder_shade = 1.0
        glow_shade        = 1.0
        roundness         = 6
    }
}

style "snowfox-widgets" {
    bg[NORMAL]     = "#2a2840"
    bg[PRELIGHT]   = "#332f50"
    bg[ACTIVE]     = "#9d6fe8"
    fg[NORMAL]     = "#e0d9f5"
    fg[PRELIGHT]   = "#ffffff"
    engine "murrine" {
        gradient_shades   = { 1.0, 1.0, 1.0, 1.0 }
        contrast          = 0.0
        lightborder_shade = 1.0
        glow_shade        = 1.0
        roundness         = 8
        focus_color       = "#b899ff"
    }
}

style "snowfox-trenner" {
    bg[NORMAL]        = "#2a2840"
    bg[ACTIVE]        = "#9d6fe8"
    bg[PRELIGHT]      = "#b899ff"
    GtkPaned::handle-size = 2
}

style "snowfox-scrollbar" {
    bg[NORMAL]    = "#6e6a8a"
    bg[PRELIGHT]  = "#b899ff"
    bg[ACTIVE]    = "#9d6fe8"
    engine "murrine" {
        contrast      = 0.0
        gradient_shades = { 1.0, 1.0, 1.0, 1.0 }
        roundness     = 10
    }
}

style "snowfox-tooltip" {
    bg[NORMAL] = "#2a2840"
    fg[NORMAL] = "#e0d9f5"
}

class "GtkWidget"                    style "snowfox-colors"
widget_class "*"                     style "snowfox-colors"
widget_class "*<GtkMenuBar>*"        style "snowfox-leisten"
widget_class "*<GtkToolbar>*"        style "snowfox-leisten"
class "GtkPaned"                     style:highest "snowfox-trenner"
widget_class "*GtkPaned*"            style:highest "snowfox-trenner"
widget_class "*<GtkButton>*"         style "snowfox-widgets"
widget_class "*<GtkEntry>*"          style "snowfox-widgets"
widget_class "*<GtkScrollbar>*"      style "snowfox-scrollbar"
widget_class "*<GtkMenu>*"           style:highest "snowfox-menus"
widget_class "*<GtkMenuItem>*"       style:highest "snowfox-menus"
widget_class "*MenuBar*.*MenuItem*"  style:highest "snowfox-menus"
widget_class "*<GtkTreeView>*"       style "snowfox-sidebar"
widget_class "*<GtkSidePane>*"       style "snowfox-sidebar"
widget_class "*FmSidebar*"           style "snowfox-sidebar"
widget_class "*FmSidePane*"          style "snowfox-sidebar"
widget_class "*FmPlacesView*"        style "snowfox-sidebar"
widget "*Tooltip*"                   style "snowfox-tooltip"
G2EOF

# ── xsettingsd ───────────────────────────────────────────────
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

# ── Qt Styling ────────────────────────────────────────────────
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
    "title", "separator", "os", "host", "kernel", "uptime",
    "packages", "shell", "display", "wm", "theme", "icons",
    "font", "cursor", "terminal", "terminalfont", "cpu", "gpu",
    "memory", "swap", "disk", "localip", "locale", "break", "colors"
  ]
}
FFEOF
    success "fastfetch Config erstellt"
fi

# ── bashrc ────────────────────────────────────────────────────
grep -q "fastfetch\|neofetch\|snowfox-greeting" "$TARGET_HOME/.bashrc" 2>/dev/null || \
    printf '\n# SnowFoxOS Greeting\n[[ -x /usr/local/bin/snowfox-greeting ]] && snowfox-greeting\n' \
    >> "$TARGET_HOME/.bashrc"

# ── Configs aus Repo kopieren ─────────────────────────────────
if [[ -d "$SCRIPT_DIR/configs" ]]; then
    cp -r "$SCRIPT_DIR/configs/"* "$CONFIG_DIR/"
    success "Konfigurationsdateien kopiert"

    # picom.conf explizit kopieren
    if [[ -f "$SCRIPT_DIR/configs/picom.conf" ]]; then
        cp "$SCRIPT_DIR/configs/picom.conf" "$CONFIG_DIR/picom.conf"
        success "picom.conf installiert"
    else
        warn "configs/picom.conf nicht gefunden — picom läuft ohne Config"
    fi

    # Rofi Config anpassen
    if [[ -f "$CONFIG_DIR/rofi/config.rasi" ]]; then
        sed -i 's/show-icons: .*/show-icons: true;/' "$CONFIG_DIR/rofi/config.rasi"
        sed -i 's/icon-theme: .*/icon-theme: "Papirus-Dark";/' "$CONFIG_DIR/rofi/config.rasi"
        success "Rofi Config angepasst"
    fi

    # i3 Config anpassen
    I3_CONFIG_PATH="$CONFIG_DIR/i3/config"

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

    # clip-saver statt greenclip
    if grep -q "greenclip" "$I3_CONFIG_PATH"; then
        sed -i 's|exec --no-startup-id greenclip daemon|exec --no-startup-id ~/.config/i3/clip-saver.sh|' \
            "$I3_CONFIG_PATH"
        sed -i '/greenclip print/d' "$I3_CONFIG_PATH"
    else
        grep -q "clip-saver" "$I3_CONFIG_PATH" || \
            echo 'exec --no-startup-id ~/.config/i3/clip-saver.sh' >> "$I3_CONFIG_PATH"
    fi

    # clip-saver.sh installieren
    mkdir -p "$CONFIG_DIR/i3"
    if [[ -f "$SCRIPT_DIR/configs/i3/clip-saver.sh" ]]; then
        cp "$SCRIPT_DIR/configs/i3/clip-saver.sh" "$CONFIG_DIR/i3/clip-saver.sh"
        chmod +x "$CONFIG_DIR/i3/clip-saver.sh"
        success "clip-saver.sh installiert"
    else
        warn "configs/i3/clip-saver.sh nicht gefunden"
    fi

    success "i3-Config angepasst"

    # GTK3-Override nach cp sicherstellen
    info "Stelle GTK3-Override nach Repo-Kopie sicher..."
    cp "$CONFIG_DIR/gtk-3.0/gtk.css" "$CONFIG_DIR/gtk-3.0/gtk.css.repo-bak" 2>/dev/null || true

    if [[ -f "$CONFIG_DIR/fastfetch/config.jsonc" ]]; then
        sed -i "s|/home/xr7-code/SnowFoxOS-v2.2/assets/fuchs.png|$SCRIPT_DIR/assets/fuchs.png|g" \
            "$CONFIG_DIR/fastfetch/config.jsonc" 2>/dev/null || true
    fi

    success "GTK3-Override sichergestellt"
else
    warn "configs/-Verzeichnis nicht gefunden"
fi

find "$CONFIG_DIR" -name "*.sh" -exec chmod +x {} +

# ── Wallpaper ─────────────────────────────────────────────────
[[ -d "$SCRIPT_DIR/wallpapers" ]] && \
    cp -r "$SCRIPT_DIR/wallpapers/." "$TARGET_HOME/Pictures/wallpapers/"

DEFAULT_WP=$(ls "$TARGET_HOME/Pictures/wallpapers" 2>/dev/null \
    | grep -iE "\.jpg$|\.png$|\.webp$|\.jpeg$" | head -n 1)
if [[ -n "$DEFAULT_WP" ]]; then
    echo "#!/bin/sh" > "$TARGET_HOME/.fehbg"
    echo "feh --bg-fill '$TARGET_HOME/Pictures/wallpapers/$DEFAULT_WP'" >> "$TARGET_HOME/.fehbg"
    chmod +x "$TARGET_HOME/.fehbg"
    chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.fehbg"
    info "Standard-Wallpaper gesetzt: $DEFAULT_WP"
fi

# ── Polybar ───────────────────────────────────────────────────
POLYBAR_CONF="$CONFIG_DIR/polybar/config.ini"
if [[ -f "$POLYBAR_CONF" ]]; then
    if [[ "$IS_LAPTOP" == "true" ]]; then
        BAT_NAME=$(ls /sys/class/power_supply/ 2>/dev/null | grep -E "BAT|battery" | head -1)
        [[ -n "$BAT_NAME" ]] && sed -i "s/battery = BAT1/battery = $BAT_NAME/" "$POLYBAR_CONF"

        BL_NAME=$(ls /sys/class/backlight/ 2>/dev/null | grep -E "amdgpu_bl|intel_backlight" | head -1)
        BL_NAME="${BL_NAME:-$(ls /sys/class/backlight/ 2>/dev/null | head -1)}"

        if [[ -n "$BL_NAME" ]]; then
            sed -i "s/^card = .*/card = $BL_NAME/" "$POLYBAR_CONF"
            success "Polybar: Backlight-Card gesetzt → $BL_NAME"
        else
            sed -i "s/^card = .*/card = amdgpu_bl0/" "$POLYBAR_CONF"
            warn "Backlight-Gerät noch nicht sichtbar — Fallback amdgpu_bl0 gesetzt"
        fi

        sed -i 's/^modules-right =.*/modules-right = backlight gap battery gap memory gap network gap pulseaudio gap bluetooth gap tray-spacer/' "$POLYBAR_CONF"
        success "Polybar: Laptop-Modus aktiv"
    else
        sed -i 's/^modules-right =.*/modules-right = memory gap network gap pulseaudio gap bluetooth gap tray-spacer/' "$POLYBAR_CONF"
        success "Polybar: Desktop-Modus aktiv"
    fi
fi

# ── modprobe Configs ──────────────────────────────────────────
if [[ -d "$SCRIPT_DIR/configs/modprobe" ]]; then
    if [[ -f "$SCRIPT_DIR/configs/modprobe/nvidia.conf" ]]; then
        cp "$SCRIPT_DIR/configs/modprobe/nvidia.conf" /etc/modprobe.d/nvidia.conf
    fi
    update-initramfs -u 2>/dev/null || true
    success "modprobe Configs installiert"
fi

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

# ── Hilfsskripte ─────────────────────────────────────────────
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

# ── Polybar launch.sh ─────────────────────────────────────────
mkdir -p "$CONFIG_DIR/polybar/scripts"

if [[ -f "$SCRIPT_DIR/configs/polybar/launch.sh" ]]; then
    cp "$SCRIPT_DIR/configs/polybar/launch.sh" "$CONFIG_DIR/polybar/launch.sh"
    chmod +x "$CONFIG_DIR/polybar/launch.sh"
    success "polybar/launch.sh installiert"
else
    warn "configs/polybar/launch.sh nicht gefunden — Fallback wird geschrieben"
    cat > "$CONFIG_DIR/polybar/launch.sh" << 'LAUNCHEOF'
#!/bin/bash
# SnowFoxOS — Polybar Starter
sleep 2
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done
PRIMARY=$(xrandr --query | grep " connected primary" | cut -d" " -f1)
[[ -z "$PRIMARY" ]] && PRIMARY=$(xrandr --query | grep " connected" | head -1 | cut -d" " -f1)
CHASSIS=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "0")
IS_LAPTOP=false
[[ "$CHASSIS" =~ ^(8|9|10|14)$ ]] && IS_LAPTOP=true
ls /sys/class/power_supply/BAT* &>/dev/null && IS_LAPTOP=true
if $IS_LAPTOP; then
    BAT=$(ls /sys/class/power_supply/ | grep -E '^BAT' | head -1)
    AC=$(ls /sys/class/power_supply/ | grep -E '^(AC|ADP|ACAD)' | head -1)
    [[ -n "$BAT" ]] && sed -i "s/^battery = .*/battery = $BAT/" ~/.config/polybar/config.ini
    [[ -n "$AC" ]]  && sed -i "s/^adapter = .*/adapter = $AC/"  ~/.config/polybar/config.ini
    BACKLIGHT_CARD=$(ls /sys/class/backlight/ | head -1)
    [[ -n "$BACKLIGHT_CARD" ]] && sed -i "s/^card = .*/card = $BACKLIGHT_CARD/" ~/.config/polybar/config.ini
    MONITOR=$PRIMARY polybar snowfox-laptop 2>/tmp/polybar.log &
else
    MONITOR=$PRIMARY polybar snowfox 2>/tmp/polybar.log &
fi
LAUNCHEOF
    chmod +x "$CONFIG_DIR/polybar/launch.sh"
fi

# ── Bluetooth Script ──────────────────────────────────────────
if [[ -f "$SCRIPT_DIR/configs/polybar/scripts/bluetooth.sh" ]]; then
    cp "$SCRIPT_DIR/configs/polybar/scripts/bluetooth.sh" \
        "$CONFIG_DIR/polybar/scripts/bluetooth.sh"
else
    cat > "$CONFIG_DIR/polybar/scripts/bluetooth.sh" << 'BTEOF'
#!/bin/bash
if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    echo "aus"
    exit 0
fi
DEV=$(bluetoothctl devices Connected 2>/dev/null \
    | head -n1 \
    | awk '{$1=""; $2=""; print $0}' \
    | xargs)
[[ -n "$DEV" ]] && echo "$DEV" || echo "an"
BTEOF
fi
chmod +x "$CONFIG_DIR/polybar/scripts/bluetooth.sh"
success "polybar/scripts/bluetooth.sh installiert"

# ── snowfox CLI ───────────────────────────────────────────────
if [[ -f "$SCRIPT_DIR/snowfox" ]]; then
    cp "$SCRIPT_DIR/snowfox" /usr/local/bin/snowfox
    chmod +x /usr/local/bin/snowfox
    if [[ -d "$SCRIPT_DIR/cli" ]]; then
        mkdir -p /usr/local/lib/snowfox/cli
        cp "$SCRIPT_DIR/cli/"*.sh /usr/local/lib/snowfox/cli/
        chmod 644 /usr/local/lib/snowfox/cli/*.sh
        success "snowfox CLI + Module installiert"
    else
        warn "cli/-Verzeichnis nicht gefunden — nur snowfox Binary kopiert"
        success "snowfox CLI installiert (ohne Module)"
    fi
fi

[[ -f "$SCRIPT_DIR/snowfox-greeting.sh" ]] && \
    cp "$SCRIPT_DIR/snowfox-greeting.sh" /usr/local/bin/snowfox-greeting && \
    chmod +x /usr/local/bin/snowfox-greeting

# ── Standard-Anwendungen ──────────────────────────────────────
echo ""
echo -e "${PURPLE}${BOLD}  Standard-Texteditor:${RESET}"
echo -e "  1) Mousepad (Standard)"
echo -e "  2) VSCodium"
read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-2]: "${RESET})" DEFAULT_EDITOR
case "$DEFAULT_EDITOR" in
    2) DEFAULT_EDITOR_DESKTOP="codium.desktop" ;;
    *) DEFAULT_EDITOR_DESKTOP="mousepad.desktop" ;;
esac

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

info "Setze Besitzer für $TARGET_HOME ($TARGET_USER)..."
mkdir -p "$TARGET_HOME/.local/share/xorg"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"
success "Berechtigungen gesetzt — $TARGET_HOME gehört $TARGET_USER"

# ── DKMS-Hooks wiederherstellen ───────────────────────────────
DKMS_HOOKS=(
    /etc/kernel/postinst.d/dkms
    /etc/kernel/prerm.d/dkms
    /usr/lib/kernel/install.d/50-dkms.install
)
for hook in "${DKMS_HOOKS[@]}"; do
    [[ -f "${hook}.snowfox-bak" ]] && mv "${hook}.snowfox-bak" "$hook"
done
info "DKMS-Hooks wiederhergestellt"

# ── initramfs ─────────────────────────────────────────────────
info "Baue initramfs mit allen Fixes neu..."
update-initramfs -u 2>/dev/null || true
success "initramfs aktualisiert"

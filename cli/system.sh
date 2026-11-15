#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Module: System (Update, Profile, Node, Reset)
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

PROFILE_FILE="$HOME/.config/snowfox/profile"
NODE_MODE_FILE="$HOME/.config/snowfox/node-mode"

# ============================================================
# snowfox prof — System profile
# ============================================================
cmd_profile() {
    mkdir -p "$HOME/.config/snowfox"

    local CURRENT
    CURRENT=$(cat "$PROFILE_FILE" 2>/dev/null || echo "balanced")

    case "$1" in
        performance)
            echo "performance" > "$PROFILE_FILE"
            echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor &>/dev/null || true
            sudo sysctl -w vm.swappiness=10 &>/dev/null
            pkill redshift 2>/dev/null || true
            ok "Profile: ${BOLD}Performance${RESET}"
            info "  CPU governor: performance | swappiness: 10 | redshift: off"
            ;;
        battery)
            echo "battery" > "$PROFILE_FILE"
            echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor &>/dev/null || true
            sudo sysctl -w vm.swappiness=60 &>/dev/null
            pkill redshift 2>/dev/null || true
            redshift -l 48.3:14.3 &>/dev/null &
            ok "Profile: ${BOLD}Battery${RESET}"
            info "  CPU governor: powersave | swappiness: 60 | redshift: on"
            ;;
        privacy)
            echo "privacy" > "$PROFILE_FILE"
            sudo rfkill block wifi bluetooth &>/dev/null || true
            pkill redshift 2>/dev/null || true
            ok "Profile: ${BOLD}Privacy${RESET}"
            info "  WiFi: off | Bluetooth: off | Radio: blocked"
            warn "  Network disabled — use 'snowfox prof balanced' to restore"
            ;;
        balanced|"")
            echo "balanced" > "$PROFILE_FILE"
            echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor &>/dev/null || true
            sudo sysctl -w vm.swappiness=10 &>/dev/null
            sudo rfkill unblock all &>/dev/null || true
            pkill redshift 2>/dev/null || true
            redshift -l 48.3:14.3 &>/dev/null &
            ok "Profile: ${BOLD}Balanced${RESET}"
            info "  CPU governor: schedutil | swappiness: 10 | redshift: on"
            ;;
        status)
            header "System Profile"
            row "Active" "$CURRENT" "$CYAN"
            echo ""
            echo -e "  Available profiles:"
            echo -e "  ${CYAN}balanced${RESET}     — default, balanced"
            echo -e "  ${CYAN}performance${RESET}  — maximum CPU performance"
            echo -e "  ${CYAN}battery${RESET}      — power saving, CPU throttled"
            echo -e "  ${CYAN}privacy${RESET}      — no radio, maximum isolation"
            echo ""
            ;;
        *)
            err "Unknown profile: $1"
            info "Available: balanced, performance, battery, privacy, status"
            exit 1
            ;;
    esac
}

# ============================================================
# snowfox up — System update
# ============================================================
cmd_update() {
    header "System Update"

    # Locate repo directory
    local REPO_DIR=""
    for candidate in \
        "$HOME/SnowFoxOS-v3" \
        "$HOME/SnowFoxOS" \
        "/opt/snowfoxos"
    do
        if [[ -d "$candidate/.git" ]]; then
            REPO_DIR="$candidate"
            break
        fi
    done

    if [[ -z "$REPO_DIR" ]]; then
        warn "Repo directory not found."
        read -rp "$(echo -e ${PURPLE}${BOLD}"Path to SnowFoxOS repo: "${RESET})" REPO_DIR
        [[ ! -d "$REPO_DIR/.git" ]] && err "No git repo found at: $REPO_DIR" && exit 1
    fi

    echo ""
    echo -e "  ${CYAN}1${RESET}) Packages only (apt)"
    echo -e "  ${CYAN}2${RESET}) Everything — repo + configs + CLI + packages (recommended)"
    echo ""
    read -rp "$(echo -e ${PURPLE}${BOLD}"Choice [1-2]: "${RESET})" CHOICE

    case "$CHOICE" in
        1)
            fox "Updating packages..."
            sudo apt-get update -qq
            sudo apt-get upgrade -y
            sudo apt-get autoremove -y
            sudo apt-get autoclean -y

            if command -v yt-dlp &>/dev/null; then
                info "Updating yt-dlp..."
                sudo curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
                    -o /usr/local/bin/yt-dlp && \
                    sudo chmod +x /usr/local/bin/yt-dlp && \
                    ok "yt-dlp updated ($(yt-dlp --version))" || \
                    warn "yt-dlp update failed"
            fi
            ok "Packages are up to date."
            ;;

        2)
            # ── Update repo ──────────────────────────────────
            fox "Updating repo: ${BOLD}$REPO_DIR${RESET}"
            cd "$REPO_DIR" || { err "Cannot change to $REPO_DIR"; exit 1; }

            local LOCAL
            LOCAL=$(git rev-parse HEAD 2>/dev/null)
            git pull --ff-only 2>&1 | while IFS= read -r line; do info "  $line"; done
            local REMOTE
            REMOTE=$(git rev-parse HEAD 2>/dev/null)

            if [[ "$LOCAL" == "$REMOTE" ]]; then
                ok "Repo already up to date."
            else
                ok "Repo updated (${LOCAL:0:7} → ${REMOTE:0:7})"
            fi

            # ── Backup ───────────────────────────────────────
            local BACKUP_DIR="$HOME/.snowfox-backup/$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$BACKUP_DIR"
            for dir in i3 polybar rofi dunst kitty; do
                [[ -e "$HOME/.config/$dir" ]] && cp -r "$HOME/.config/$dir" "$BACKUP_DIR/"
            done
            [[ -f /usr/local/bin/snowfox ]] && cp /usr/local/bin/snowfox "$BACKUP_DIR/snowfox.bak"
            [[ -d /usr/local/lib/snowfox/cli ]] && cp -r /usr/local/lib/snowfox/cli "$BACKUP_DIR/cli.bak"
            ok "Backup saved → $BACKUP_DIR"

            # ── Update CLI ───────────────────────────────────
            sudo cp "$REPO_DIR/snowfox" /usr/local/bin/snowfox
            sudo chmod +x /usr/local/bin/snowfox
            if [[ -d "$REPO_DIR/cli" ]]; then
                sudo mkdir -p /usr/local/lib/snowfox/cli
                sudo cp "$REPO_DIR/cli/"*.sh /usr/local/lib/snowfox/cli/
                sudo chmod 644 /usr/local/lib/snowfox/cli/*.sh
                ok "snowfox CLI + modules updated"
            else
                warn "cli/ directory not found in repo: $REPO_DIR/cli/"
                ok "snowfox CLI updated (modules unchanged)"
            fi

            # ── Console Launcher ─────────────────────────────
            local LAUNCHER_DIR="$HOME/SnowFox-Console-Launcher"
            if [[ -d "$LAUNCHER_DIR" ]]; then
                info "Updating Console Launcher..."
                if git -C "$LAUNCHER_DIR" pull 2>/dev/null; then
                    ok "Console Launcher updated"
                else
                    warn "Console Launcher update failed"
                fi
                [[ -f "$LAUNCHER_DIR/snowfox_launcher" ]] && \
                    chmod +x "$LAUNCHER_DIR/snowfox_launcher"
            fi

            # ── Update configs ───────────────────────────────
            if [[ -d "$REPO_DIR/configs" ]]; then
                cp -r "$REPO_DIR/configs/"* "$HOME/.config/"
                ok "Configs updated"
                i3-msg reload &>/dev/null && ok "i3 reloaded"
                if pgrep -x polybar &>/dev/null; then
                    pkill polybar
                    sleep 0.5
                    bash "$HOME/.config/polybar/launch.sh" &
                    ok "Polybar restarted"
                fi
            fi

            # ── Update packages ──────────────────────────────
            fox "Updating packages..."
            sudo apt-get update -qq
            sudo apt-get upgrade -y
            sudo apt-get autoremove -y

            if command -v yt-dlp &>/dev/null; then
                sudo curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
                    -o /usr/local/bin/yt-dlp && sudo chmod +x /usr/local/bin/yt-dlp && \
                    ok "yt-dlp updated" || warn "yt-dlp update failed"
            fi

            divider
            ok "System fully updated."
            info "  On problems: cp -r $BACKUP_DIR/* ~/.config/"
            ;;
        *)
            err "Invalid choice."
            exit 1
            ;;
    esac

    divider
}

# ============================================================
# snowfox node — System mode
# ============================================================
cmd_node() {
    mkdir -p "$HOME/.config/snowfox"
    local CURRENT
    CURRENT=$(cat "$NODE_MODE_FILE" 2>/dev/null || echo "desktop")

    case "$1" in
        d|desktop) _node_desktop "$CURRENT" ;;
        s|server)  _node_server "$CURRENT" ;;
        c|console) _node_console "$CURRENT" ;;
        status|"")
            header "Node Mode"
            row "Current" "$CURRENT" "$CYAN"
            echo ""
            case "$CURRENT" in
                desktop) info "Full desktop mode — i3, polybar, rofi, dunst" ;;
                server)  info "Server mode — no X11, terminal only" ;;
                console) info "Console mode — i3 + launcher, no polybar/dunst" ;;
            esac
            echo ""
            ;;
        help|*)
            header "snowfox node"
            row "snowfox node d" "Desktop mode (i3 + polybar + rofi + dunst)"
            echo ""
            row "snowfox node s" "Server mode (no X11, terminal only)"
            echo ""
            row "snowfox node c" "Console mode (i3 + game launcher)"
            echo ""
            row "snowfox node status" "Show current mode"
            echo ""
            divider
            info "From server mode back to desktop: snowfox node d"
            echo ""
            ;;
    esac
}

_node_desktop() {
    local current="$1"
    header "Node → Desktop"

    # Restore graphical target if coming from server
    if [[ "$current" == "server" ]]; then
        info "Restoring graphical target..."
        sudo systemctl set-default graphical.target 2>/dev/null
        # Stop any leftover server services
        for svc in nginx apache2 postgresql mysql docker; do
            systemctl is-active --quiet "$svc" 2>/dev/null && \
                sudo systemctl stop "$svc" 2>/dev/null && \
                info "  Stopped $svc"
        done
        ok "graphical.target restored"
    fi

    # Remove launcher autostart if present
    if grep -q "SnowFox-Console-Launcher" "$HOME/.config/i3/config" 2>/dev/null; then
        sed -i '/exec.*SnowFox-Console-Launcher/d' "$HOME/.config/i3/config"
        ok "Console Launcher removed from i3 autostart"
    fi

    # Ensure polybar is running
    if ! pgrep -x polybar &>/dev/null; then
        "$HOME/.config/polybar/launch.sh" &>/dev/null &
        ok "Polybar started"
    fi

    # Ensure dunst is running
    if ! pgrep -x dunst &>/dev/null; then
        dunst &>/dev/null &
        ok "Dunst started"
    fi

    echo "desktop" > "$NODE_MODE_FILE"

    # If i3 is running: reload. If not: start X session.
    if pgrep -x i3 &>/dev/null; then
        i3-msg restart 2>/dev/null || true
        ok "Desktop mode active (i3 reloaded)"
    else
        ok "Desktop mode active — starting X session"
        info "  Launching startx..."
        sleep 1
        exec startx
    fi
}

_node_server() {
    header "Node → Server"

    info "Stopping desktop environment..."

    # Kill desktop components
    killall polybar 2>/dev/null || true
    killall dunst 2>/dev/null || true
    killall redshift 2>/dev/null || true
    killall picom 2>/dev/null || true
    ok "Desktop processes stopped"

    # Switch default target
    info "Switching to multi-user.target..."
    sudo systemctl set-default multi-user.target 2>/dev/null
    ok "Server mode will be default after next boot"

    # Server optimizations
    info "Applying server optimizations..."
    command -v tlp &>/dev/null && sudo tlp ac 2>/dev/null || true
    sudo systemctl is-active --quiet earlyoom && \
        sudo systemctl restart earlyoom 2>/dev/null || true
    ok "Server optimizations applied"

    echo "server" > "$NODE_MODE_FILE"

    divider
    ok "Server mode active — terminal only"
    warn "X11 will not start after this i3 session ends"
    info "Return to desktop: snowfox node d"
    echo ""

    # Exit i3 — user lands in TTY
    i3-msg exit 2>/dev/null || true
}

_node_console() {
    header "Node → Console"
    local LAUNCHER="$HOME/SnowFox-Console-Launcher/snowfox_launcher"

    if [[ ! -f "$LAUNCHER" ]]; then
        err "Launcher not found: $LAUNCHER"
        info "Install with:"
        info "  git clone https://github.com/Xr7-Code/SnowFox-Console-Launcher.git ~/SnowFox-Console-Launcher"
        exit 1
    fi
    [[ ! -x "$LAUNCHER" ]] && chmod +x "$LAUNCHER"

    # i3 stays running, polybar stays visible
    info "Switching to workspace 8..."
    i3-msg workspace 8 2>/dev/null || true

    echo "console" > "$NODE_MODE_FILE"

    ok "Starting Console Launcher..."
    exec "$LAUNCHER"
}

# ============================================================
# snowfox rst — Factory reset
# ============================================================
function_reset_system() {
    clear
    echo -e "\e[31m######################################################################\e[0m"
    echo -e "\e[31m   WARNING: THIS ACTION WILL DELETE ALL YOUR PERSONAL FILES!          \e[0m"
    echo -e "\e[31m######################################################################\e[0m"
    echo ""
    echo "The system will be reset to a minimal Debian base."
    echo "- All documents, pictures, downloads and personal data will be DELETED."
    echo "- All additional packages will be removed."
    echo "- SnowFoxOS configuration will be reset to factory defaults."
    echo ""
    echo -e "\e[33mAre you absolutely sure? This cannot be undone!\e[0m"
    echo ""

    read -p "Type 'YES' in uppercase to continue: " confirm

    if [[ "$confirm" == "YES" ]]; then
        echo ""
        echo -e "\e[32m[+]\e[0m Starting reset..."
        sleep 2

        # 1. Remove personal data and dotfiles
        echo -e "\e[34m[*]\e[0m Deleting personal data and configs from $HOME..."
        find "$HOME" -mindepth 1 -maxdepth 1 ! -name ".bash_history" -exec rm -rf {} + 2>/dev/null

        # 2. Recreate standard directories
        echo -e "\e[34m[*]\e[0m Recreating clean folder structure..."
        mkdir -p "$HOME/Desktop" "$HOME/Downloads" "$HOME/Documents" "$HOME/Pictures" "$HOME/Music" "$HOME/Videos"

        # 3. Clean package manager
        echo -e "\e[34m[*]\e[0m Cleaning system packages (apt autoremove & clean)..."
        sudo apt-get autoremove --purge -y
        sudo apt-get clean

        # 4. Restore SnowFoxOS configs from repo
        echo -e "\e[34m[*]\e[0m Fetching fresh SnowFoxOS configuration..."
        local REPO_URL="https://github.com/Xr7-Code/SnowFoxOS-v3.git"
        local TMP_DIR
        TMP_DIR=$(mktemp -d)

        if git clone --depth=1 "$REPO_URL" "$TMP_DIR" 2>/dev/null; then
            cp -r "$TMP_DIR"/.config "$HOME/" 2>/dev/null
            cp -r "$TMP_DIR"/wallpapers "$HOME/" 2>/dev/null
            cp "$TMP_DIR"/snowfox "$HOME/" 2>/dev/null
            chmod +x "$HOME/snowfox"
            if [[ -d "$TMP_DIR/cli" ]]; then
                sudo mkdir -p /usr/local/lib/snowfox/cli
                sudo cp "$TMP_DIR/cli/"*.sh /usr/local/lib/snowfox/cli/
                sudo chmod 644 /usr/local/lib/snowfox/cli/*.sh
                sudo cp "$TMP_DIR/snowfox" /usr/local/bin/snowfox
                sudo chmod +x /usr/local/bin/snowfox
            fi
            rm -rf "$TMP_DIR"
            echo -e "\e[32m[+]\e[0m Factory configurations restored."
        else
            echo -e "\e[31m[!]\e[0m Error: Could not clone repository. Check internet connection.\e[0m"
        fi

        echo ""
        echo -e "\e[32m######################################################################\e[0m"
        echo -e "\e[32m   RESET COMPLETE! System is back to factory state.                  \e[0m"
        echo -e "\e[32m   Rebooting in 5 seconds...                                         \e[0m"
        echo -e "\e[32m######################################################################\e[0m"
        sleep 5
        sudo reboot
    else
        echo ""
        echo -e "\e[31m[-] Reset cancelled. No changes were made.\e[0m"
        exit 1
    fi
}

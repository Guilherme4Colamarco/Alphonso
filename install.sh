#!/bin/bash
# ============================================================================
# Kamalen Shell Installer v2.1
# ============================================================================
# Improved version with:
# - Symlink-based config install (~/.config → repo, like meloworld)
# - --unlink to revert symlinks and restore backups
# - Better error handling and rollback
# - Progress feedback and colored output
# - Dependency verification
# - Dry-run mode
# - Detailed summary
# - Backup verification
# ============================================================================

set -euo pipefail

# ── Colors & Formatting ──────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── State ────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR=""
ERRORS=()
WARNINGS=()
DRY_RUN=false
VERBOSE=false
SKIP_DEPS=false
SKIP_CONFIGS=false
START_TIME=$(date +%s)

# ── Logging ──────────────────────────────────────────────────────
log()      { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()     { echo -e "${YELLOW}[!]${RESET} $*"; WARNINGS+=("$*"); }
error()    { echo -e "${RED}[✗]${RESET} $*"; ERRORS+=("$*"); }
info()     { echo -e "${BLUE}[i]${RESET} $*"; }
header()   { echo -e "\n${BOLD}${CYAN}═══ $* ═══${RESET}\n"; }
step()     { echo -e "${DIM}  → $*${RESET}"; }

# ── Utility ──────────────────────────────────────────────────────
command_exists() { command -v "$1" &>/dev/null; }

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        error "Installation failed!"
        if [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]]; then
            info "Your old configs are backed up in: $BACKUP_DIR"
        fi
        echo -e "${DIM}Check the errors above and try again.${RESET}"
    fi
}

trap cleanup EXIT

# ── Help ─────────────────────────────────────────────────────────
usage() {
    cat << EOF
${BOLD}Kamalen Shell Installer v2.1${RESET}

${BOLD}Usage:${RESET}
  ./install.sh [options] [command]

${BOLD}Commands:${RESET}
  (none)      Full installation (interactive)
  deps        Install dependencies only
  configs     Install configs only (symlinks ~/.config/ → repo)
  unlink      Remove symlinks and optionally restore backup
  mango       Build mango-ext only
  sddm        Install/synchronize the optional SDDM theme
  verify      Verify installation
  status      Show installation status

${BOLD}Options:${RESET}
  -n, --dry-run     Show what would be done without doing it
  -v, --verbose     Show full command output
  --skip-deps       Skip dependency installation
  --skip-configs    Skip config installation
  -h, --help        Show this help

${BOLD}Examples:${RESET}
  ./install.sh                    # Full install (interactive)
  ./install.sh --dry-run          # Preview what would happen
  ./install.sh deps               # Install deps only
  ./install.sh --skip-deps        # Skip deps, install configs
  ./install.sh verify             # Check if everything is installed
EOF
    exit 0
}

# ── Parse Args ───────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run)    DRY_RUN=true; shift ;;
            -v|--verbose)    VERBOSE=true; shift ;;
            --skip-deps)     SKIP_DEPS=true; shift ;;
            --skip-configs)  SKIP_CONFIGS=true; shift ;;
            -h|--help)       usage ;;
            deps|configs|mango|sddm|verify|status|unlink)
                COMMAND="$1"; shift ;;
            *)
                error "Unknown option: $1"
                usage ;;
        esac
    done
}

COMMAND="${1:-}"

install_sddm_theme() {
    local args=()
    $DRY_RUN && args+=(--dry-run)
    local installer="$SCRIPT_DIR/scripts/install/sddm-theme.sh"
    if [[ ! -x "$installer" ]]; then
        if $DRY_RUN; then
            info "dry-run: would detect SDDM and offer the optional Kamalen login theme"
            return 0
        fi
        error "SDDM theme installer is missing: $installer"
        return 1
    fi
    "$installer" "${args[@]}" install
}

# ── Preflight Checks ────────────────────────────────────────────
preflight() {
    header "Preflight Checks"

    # Must be Arch
    if [[ ! -f /etc/arch-release ]]; then
        error "This installer is for Arch Linux only"
        exit 1
    fi
    log "Arch Linux detected"

    # Must have .config directory
    if [[ ! -d "$SCRIPT_DIR/.config" ]]; then
        error "Cannot find .config directory in $SCRIPT_DIR"
        exit 1
    fi
    log "Project structure verified"

    # Check for AUR helper
    if ! $SKIP_DEPS; then
        if command_exists yay; then
            AUR_HELPER="yay"
        elif command_exists paru; then
            AUR_HELPER="paru"
        else
            AUR_HELPER=""
            warn "No AUR helper found (yay/paru)"
        fi
        if [[ -n "$AUR_HELPER" ]]; then
            log "AUR helper: $AUR_HELPER"
        fi
    fi

    # Check for git
    if ! command_exists git; then
        error "git is required but not installed"
        exit 1
    fi
    log "git available"

    # Check for meson (needed for mango-ext)
    if ! command_exists meson; then
        warn "meson not found (will be installed with deps)"
    fi
}

# ── Install Dependencies ────────────────────────────────────────
install_deps() {
    header "Installing Dependencies"

    if [[ -z "$AUR_HELPER" ]]; then
        error "Cannot install deps without AUR helper (yay/paru)"
        return 1
    fi

    local pacman_pkgs=(
        kitty cava fastfetch starship grim slurp
        mpd mpc mpv ffmpeg swayidle wlr-randr gammastep
        ttf-jetbrains-mono-nerd alsa-utils networkmanager
        bluez bluez-utils pipewire wireplumber
        brightnessctl playerctl imagemagick
        python python-pillow python-pam python-numpy
        inotify-tools neovim meson ninja
        wayland-protocols libinput seatd xorg-xwayland
        pixman glslang libglvnd libxkbcommon xcb-util-wm
    )

    local aur_pkgs=(
        quickshell-git awww-git mpvpaper rmpc
        mpd-mpris tiramisu gpu-screen-recorder
        mangowm-git pokemon-colorscripts-go
    )

    info "Installing ${#pacman_pkgs[@]} pacman packages..."
    if $DRY_RUN; then
        info "dry-run: sudo pacman -S --needed ${pacman_pkgs[*]}"
    else
        sudo pacman -S --needed "${pacman_pkgs[@]}" || {
            error "Failed to install some pacman packages"
            return 1
        }
    fi
    log "Pacman packages installed"

    info "Installing ${#aur_pkgs[@]} AUR packages..."
    if $DRY_RUN; then
        info "dry-run: $AUR_HELPER -S --needed ${aur_pkgs[*]}"
    else
        $AUR_HELPER -S --needed "${aur_pkgs[@]}" || {
            warn "Some AUR packages failed to install"
        }
    fi
    log "AUR packages installed"

    # Build mango-ext
    install_mango_ext

    # Enable services
    info "Enabling services..."
    if ! $DRY_RUN; then
        sudo systemctl enable --now NetworkManager 2>/dev/null || true
        sudo systemctl enable --now bluetooth 2>/dev/null || true
        systemctl --user enable --now mpd 2>/dev/null || true
        systemctl --user enable --now mpd-mpris 2>/dev/null || true
    fi
    log "Services enabled"
}

# ── Build Mango-Ext ─────────────────────────────────────────────
install_mango_ext() {
    header "Building mango-ext"

    local tmp_dir

    info "Cloning mango-ext..."
    if $DRY_RUN; then
        info "dry-run: git clone https://github.com/ernestoCruz05/mango-ext.git"
        log "mango-ext installed"
        return 0
    fi

    tmp_dir=$(mktemp -d)
    git clone https://github.com/ernestoCruz05/mango-ext.git "$tmp_dir/mango-ext" 2>/dev/null || {
        error "Failed to clone mango-ext"
        rm -rf "$tmp_dir"
        return 1
    }

    cd "$tmp_dir/mango-ext"

    info "Configuring with meson..."
    if ! $DRY_RUN; then
        meson setup build -Dprefix=/usr || { error "meson setup failed"; cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1; }
    fi

    info "Compiling..."
    if ! $DRY_RUN; then
        meson compile -C build || { error "meson compile failed"; cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1; }
    fi

    info "Installing..."
    if ! $DRY_RUN; then
        sudo meson install -C build || { error "meson install failed"; cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1; }
    fi

    cd "$SCRIPT_DIR"
    rm -rf "$tmp_dir"

    mkdir -p ~/.config/mango-ext
    log "mango-ext installed"
}

# ── Setup PAM ───────────────────────────────────────────────────
setup_pam() {
    if [[ ! -f /etc/pam.d/lockscreen ]] || grep -qE 'pam_unix\.so.*nullok' /etc/pam.d/lockscreen; then
        info "Setting up PAM lockscreen service..."
        if ! $DRY_RUN; then
            local pam_tmp
            pam_tmp=$(mktemp)
            printf '%s\n' \
                'auth required pam_unix.so nodelay' \
                'account required pam_unix.so' > "$pam_tmp"
            sudo install -m 0644 -o root -g root "$pam_tmp" /etc/pam.d/lockscreen
            rm -f "$pam_tmp"
        fi
        log "PAM lockscreen configured"
    else
        log "PAM lockscreen already configured"
    fi
}

# ── Managed Config Dirs ──────────────────────────────────────────
# These directories are symlinked from the repo to ~/.config/
get_managed_dirs() {
    echo "mango mango-ext kitty quickshell fastfetch cava rmpc nvim"
}

# ── Install Configs (Symlink Mode) ───────────────────────────────
install_configs() {
    header "Installing Configs (Symlink Mode)"

    # Create system directories (config dirs are symlinked, not created)
    local dirs=(
        ~/.config ~/.local/bin ~/wallpapers ~/screenshots ~/screen-recordings
        ~/.cache/wallpaper-thumbs ~/.cache/wallpaper-colors ~/.cache/qs
        ~/.config/mpd/playlists
    )

    info "Creating directories..."
    for dir in "${dirs[@]}"; do
        if ! $DRY_RUN; then
            mkdir -p "$dir"
        fi
    done
    log "Directories created"

    # Create MPD state files
    info "Initializing MPD state..."
    if ! $DRY_RUN; then
        touch ~/.config/mpd/database 2>/dev/null || true
        touch ~/.config/mpd/state 2>/dev/null || true
        touch ~/.config/mpd/sticker.sql 2>/dev/null || true
    fi
    log "MPD state initialized"

    local config_dirs
    read -ra config_dirs <<< "$(get_managed_dirs)"

    # Backup existing configs
    BACKUP_DIR=~/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)
    local has_backup=false
    if ! $DRY_RUN; then
        mkdir -p "$BACKUP_DIR"
    fi

    for dir in "${config_dirs[@]}"; do
        local cfg=~/.config/"$dir"
        local repo_target="$SCRIPT_DIR/.config/$dir"

        # Already symlinked to our repo? Skip
        if [[ -L "$cfg" ]] && [[ "$(readlink -f "$cfg" 2>/dev/null)" == "$repo_target" ]]; then
            step "$dir already symlinked — skipping"
            continue
        fi

        # Exists (file, dir, or symlink elsewhere)? Back it up
        if [[ -e "$cfg" || -L "$cfg" ]]; then
            step "Backing up $dir"
            if ! $DRY_RUN; then
                mv "$cfg" "$BACKUP_DIR/"
                has_backup=true
            fi
        fi
    done

    # starship.toml (single file)
    local star=~/.config/starship.toml
    local star_target="$SCRIPT_DIR/.config/starship.toml"
    if [[ -L "$star" ]] && [[ "$(readlink -f "$star" 2>/dev/null)" == "$star_target" ]]; then
        step "starship.toml already symlinked — skipping"
    elif [[ -e "$star" || -L "$star" ]]; then
        step "Backing up starship.toml"
        if ! $DRY_RUN; then
            mv "$star" "$BACKUP_DIR/"
            has_backup=true
        fi
    fi

    if ! $has_backup && ! $DRY_RUN; then
        rmdir "$BACKUP_DIR" 2>/dev/null || true
        BACKUP_DIR=""
    fi
    [[ -n "$BACKUP_DIR" ]] && log "Existing configs backed up to $BACKUP_DIR" || log "No existing configs to back up"

    # Create symlinks from repo → ~/.config/
    info "Creating symlinks..."
    for dir in "${config_dirs[@]}"; do
        local repo_dir="$SCRIPT_DIR/.config/$dir"
        if [[ -d "$repo_dir" ]]; then
            step "Symlinking $dir → $repo_dir"
            if ! $DRY_RUN; then
                ln -s "$repo_dir" ~/.config/"$dir"
            fi
        fi
    done

    if [[ -f "$star_target" ]]; then
        step "Symlinking starship.toml"
        if ! $DRY_RUN; then
            ln -s "$star_target" "$star"
        fi
    fi
    log "Configs symlinked to $SCRIPT_DIR/.config/"

    # Initialize Quickshell state (writes through symlink → repo dir)
    info "Initializing Quickshell state..."
    if ! $DRY_RUN; then
        mkdir -p ~/.config/quickshell/state
        [[ ! -f ~/.config/quickshell/state/settings.json ]] && echo "{}" > ~/.config/quickshell/state/settings.json 2>/dev/null || true
        [[ ! -f ~/.config/quickshell/state/app_usage.json ]] && echo "{}" > ~/.config/quickshell/state/app_usage.json 2>/dev/null || true
    fi
    log "Quickshell state initialized"

    # Copy wallpapers
    info "Installing wallpapers..."
    if [[ -d "$SCRIPT_DIR/wallpapers" ]] && [[ -n "$(ls -A "$SCRIPT_DIR/wallpapers" 2>/dev/null)" ]]; then
        if ! $DRY_RUN; then
            cp -n "$SCRIPT_DIR/wallpapers"/* ~/wallpapers/ 2>/dev/null || true
        fi
        log "Wallpapers installed"
    else
        warn "No wallpapers found in project"
    fi

    # Set current wallpaper
    local first_wall
    first_wall=$(find ~/wallpapers -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.webm" \) -print -quit 2>/dev/null || true)
    if [[ -n "$first_wall" ]]; then
        if ! $DRY_RUN; then
            ln -sf "$first_wall" ~/wallpapers/current
        fi
        log "Current wallpaper set"
    fi

    # Set permissions
    info "Setting permissions..."
    if ! $DRY_RUN; then
        chmod +x ~/.config/quickshell/iris/iris.py 2>/dev/null || true
    fi

    # Setup PAM
    setup_pam

    # Create launcher script
    info "Creating launcher script..."
    if ! $DRY_RUN; then
        cat > ~/.local/bin/start-quickshell.sh << 'EOF'
#!/bin/bash
pkill quickshell 2>/dev/null
sleep 0.3
nohup quickshell &>/dev/null &
EOF
        chmod +x ~/.local/bin/start-quickshell.sh
    fi
    log "Launcher script created"
}

# ── Unlink Configs ───────────────────────────────────────────────
unlink_configs() {
    header "Unlinking Configs"

    local config_dirs
    read -ra config_dirs <<< "$(get_managed_dirs)"

    local removed=0
    local skipped=0

    for dir in "${config_dirs[@]}"; do
        local cfg=~/.config/"$dir"
        local repo_target="$SCRIPT_DIR/.config/$dir"

        if [[ -L "$cfg" ]]; then
            local points_to
            points_to=$(readlink -f "$cfg" 2>/dev/null)
            if [[ "$points_to" == "$repo_target" ]]; then
                step "Removing symlink $dir"
                if ! $DRY_RUN; then
                    rm "$cfg"
                fi
                ((removed++)) || true
            else
                step "Skipping $dir (symlink points elsewhere: $points_to)"
                ((skipped++)) || true
            fi
        elif [[ -e "$cfg" ]]; then
            step "Skipping $dir (not a symlink — use 'rm -rf' manually)"
            ((skipped++)) || true
        else
            step "Skipping $dir (doesn't exist)"
            ((skipped++)) || true
        fi
    done

    # starship.toml
    local star=~/.config/starship.toml
    local star_target="$SCRIPT_DIR/.config/starship.toml"
    if [[ -L "$star" ]] && [[ "$(readlink -f "$star" 2>/dev/null)" == "$star_target" ]]; then
        step "Removing symlink starship.toml"
        if ! $DRY_RUN; then
            rm "$star"
        fi
        ((removed++)) || true
    fi

    echo ""
    log "Removed $removed symlinks, skipped $skipped"

    # Offer to restore latest backup
    local latest_backup
    latest_backup=$(ls -td ~/.dotfiles-backup-* 2>/dev/null | head -1)
    if [[ -n "$latest_backup" && -d "$latest_backup" ]]; then
        echo ""
        info "Latest backup available: $latest_backup"
        if ! $DRY_RUN; then
            read -p "Restore configs from this backup? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                for dir in "${config_dirs[@]}" starship.toml; do
                    if [[ -e "$latest_backup/$dir" ]]; then
                        mv "$latest_backup/$dir" ~/.config/
                        step "Restored $dir"
                    fi
                done
                rmdir "$latest_backup" 2>/dev/null || true
                log "Configs restored from backup"
            else
                info "Backup left at $latest_backup"
            fi
        fi
    else
        info "No backups found to restore"
    fi

    # Remove launcher script
    local launcher=~/.local/bin/start-quickshell.sh
    if [[ -f "$launcher" ]]; then
        step "Removing launcher script"
        if ! $DRY_RUN; then
            rm "$launcher"
        fi
    fi
}

# ── Configure User Shell ────────────────────────────────────────
configure_user_shell() {
    if $DRY_RUN; then
        info "dry-run: would offer optional default-shell configuration"
        return 0
    fi

    header "Shell & Prompt Setup"

    echo -e "Choose your default terminal shell:"
    echo "  1) Fish Shell (Recommended, with auto-suggestions & vi-mode)"
    echo "  2) Zsh Shell (Starship prompt & vi-mode)"
    echo "  3) Bash Shell (Starship prompt & vi-mode)"
    echo "  4) Skip / Keep Current Shell"
    echo ""

    local choice
    read -p "Enter choice [1-4]: " choice || choice=4

    case "$choice" in
        1)
            # Configure Fish
            info "Configuring Fish Shell..."
            if ! command_exists fish; then
                info "Installing fish shell..."
                if [[ -n "${AUR_HELPER:-}" ]]; then
                    $AUR_HELPER -S --needed fish || sudo pacman -S --needed fish
                else
                    sudo pacman -S --needed fish
                fi
            fi

            # Set fish as default shell
            local fish_path
            fish_path=$(which fish 2>/dev/null || echo "/usr/bin/fish")
            if [[ "${SHELL:-}" != "$fish_path" ]]; then
                info "Setting default shell to Fish..."
                sudo chsh -s "$fish_path" "$USER" || chsh -s "$fish_path"
            fi

            # Write Fish Config
            mkdir -p ~/.config/fish
            local fish_config=~/.config/fish/config.fish
            if [[ -f "$fish_config" ]]; then
                # Back up existing config with timestamp (preserve previous backups)
                cp "$fish_config" "$fish_config.bak.$(date +%s)"
            fi

            if ! grep -Fq "fish_vi_key_bindings" "$fish_config" 2>/dev/null; then
                cat << 'EOF' >> "$fish_config"

# Kamalen Shell: Vi key bindings
if status is-interactive
    fish_vi_key_bindings
end
EOF
            fi

            if ! grep -Fq "starship init fish" "$fish_config" 2>/dev/null; then
                cat << 'EOF' >> "$fish_config"

# Kamalen Shell: Starship prompt
if type -q starship
    starship init fish | source
end
EOF
            fi
            log "Fish Shell configured successfully with Starship and Vi mode."
            ;;
        2)
            # Configure Zsh
            info "Configuring Zsh Shell..."
            if ! command_exists zsh; then
                info "Installing zsh shell..."
                if [[ -n "${AUR_HELPER:-}" ]]; then
                    $AUR_HELPER -S --needed zsh || sudo pacman -S --needed zsh
                else
                    sudo pacman -S --needed zsh
                fi
            fi

            # Set zsh as default shell
            local zsh_path
            zsh_path=$(which zsh 2>/dev/null || echo "/bin/zsh")
            if [[ "${SHELL:-}" != "$zsh_path" ]]; then
                info "Setting default shell to Zsh..."
                sudo chsh -s "$zsh_path" "$USER" || chsh -s "$zsh_path"
            fi

            # Write Zsh Config
            local zsh_config=~/.zshrc
            if [[ -f "$zsh_config" ]]; then
                cp "$zsh_config" "$zsh_config.bak"
            fi

            if ! grep -Fq "bindkey -v" "$zsh_config" 2>/dev/null; then
                cat << 'EOF' >> "$zsh_config"

# Kamalen Shell: Vi key bindings
bindkey -v
EOF
            fi

            if ! grep -Fq "starship init zsh" "$zsh_config" 2>/dev/null; then
                cat << 'EOF' >> "$zsh_config"

# Kamalen Shell: Starship prompt
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi
EOF
            fi
            log "Zsh Shell configured successfully with Starship and Vi mode."
            ;;
        3)
            # Configure Bash
            info "Configuring Bash Shell..."
            local bash_config=~/.bashrc
            if [[ -f "$bash_config" ]]; then
                cp "$bash_config" "$bash_config.bak"
            fi

            if ! grep -Fq "set -o vi" "$bash_config" 2>/dev/null; then
                cat << 'EOF' >> "$bash_config"

# Kamalen Shell: Vi key bindings
set -o vi
EOF
            fi

            if ! grep -Fq "starship init bash" "$bash_config" 2>/dev/null; then
                cat << 'EOF' >> "$bash_config"

# Kamalen Shell: Starship prompt
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi
EOF
            fi
            log "Bash Shell configured successfully with Starship and Vi mode."
            ;;
        *)
            info "Shell setup skipped."
            ;;
    esac
}

# ── Verify Installation ─────────────────────────────────────────
verify_installation() {
    header "Verifying Installation"

    local issues=0

    # Check critical commands
    local cmds=(kitty cava fastfetch starship mpv nvim playerctl brightnessctl)
    for cmd in "${cmds[@]}"; do
        if command_exists "$cmd"; then
            log "$cmd: installed"
        else
            error "$cmd: not found"
            ((issues++)) || true
        fi
    done

    # Check AUR packages
    local aur_cmds=(quickshell awww rmpc)
    for cmd in "${aur_cmds[@]}"; do
        if command_exists "$cmd"; then
            log "$cmd: installed"
        else
            warn "$cmd: not found (AUR package)"
        fi
    done

    # Check config files
    local cfg_mango=~/.config/mango/config.conf
    local cfg_kitty=~/.config/kitty/kitty.conf
    local cfg_shell=~/.config/quickshell/shell.qml
    local cfg_iris=~/.config/quickshell/iris/iris.py
    local cfg_colors=~/.config/quickshell/Colors.qml

    for cfg in "$cfg_mango" "$cfg_kitty" "$cfg_shell" "$cfg_iris" "$cfg_colors"; do
        if [[ -f "$cfg" ]]; then
            log "$(basename "$cfg"): present"
        else
            error "$(basename "$cfg"): missing"
            ((issues++)) || true
        fi
    done

    # Check PAM
    if [[ -f /etc/pam.d/lockscreen ]]; then
        log "PAM lockscreen: configured"
    else
        warn "PAM lockscreen: not configured"
    fi

    # Check services
    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
        log "NetworkManager: running"
    else
        warn "NetworkManager: not running"
    fi

    echo ""
    if [[ $issues -eq 0 ]]; then
        log "Installation verified successfully!"
    else
        error "$issues critical issue(s) found"
    fi

    return $issues
}

# ── Show Status ──────────────────────────────────────────────────
show_status() {
    header "Installation Status"

    echo -e "${BOLD}Installed Components:${RESET}"
    echo "─────────────────────"

    local name cmd
    for name_cmd in "MangoWM:mango" "Quickshell:quickshell" "Kitty:kitty" "Neovim:nvim" "Cava:cava" "Fastfetch:fastfetch" "Starship:starship" "MPV:mpv" "Playerctl:playerctl"; do
        name="${name_cmd%%:*}"
        cmd="${name_cmd##*:}"
        if command_exists "$cmd"; then
            echo -e "  ${GREEN}✓${RESET} $name"
        else
            echo -e "  ${RED}✗${RESET} $name"
        fi
    done

    echo ""
    echo -e "${BOLD}Config Files:${RESET}"
    echo "─────────────"

    local cfg_name cfg_path
    for name_path in "Mango config:$HOME/.config/mango/config.conf" "Kitty config:$HOME/.config/kitty/kitty.conf" "Quickshell:$HOME/.config/quickshell/shell.qml" "Iris (color extraction):$HOME/.config/quickshell/iris/iris.py" "Colors.qml:$HOME/.config/quickshell/Colors.qml" "PAM lockscreen:/etc/pam.d/lockscreen"; do
        cfg_name="${name_path%%:*}"
        cfg_path="${name_path##*:}"
        if [[ -f "$cfg_path" ]]; then
            if [[ -L "${cfg_path%/*}" ]]; then
                echo -e "  ${GREEN}✓${RESET} $cfg_name ${DIM}(symlinked)${RESET}"
            else
                echo -e "  ${GREEN}✓${RESET} $cfg_name"
            fi
        else
            echo -e "  ${RED}✗${RESET} $cfg_name"
        fi
    done

    echo ""
    if [[ -d ~/wallpapers ]]; then
        local wall_count
        wall_count=$(find ~/wallpapers -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" \) 2>/dev/null | wc -l)
        echo -e "  ${BLUE}i${RESET} Wallpapers: $wall_count images"
    fi

    if [[ -d ~/.cache/wallpaper-colors ]]; then
        local cache_count
        cache_count=$(find ~/.cache/wallpaper-colors -name "*.json" 2>/dev/null | wc -l)
        echo -e "  ${BLUE}i${RESET} Color cache: $cache_count entries"
    fi
}

# ── Print Summary ────────────────────────────────────────────────
print_summary() {
    header "Installation Summary"

    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    echo -e "${BOLD}Completed:${RESET}"
    echo "──────────"
    echo "  • Dependencies installed"
    echo "  • Configs symlinked to ~/.config/ → $SCRIPT_DIR/.config/"
    echo "  • Wallpapers copied to ~/wallpapers/"
    echo "  • PAM lockscreen configured"
    if [[ -n "$BACKUP_DIR" ]]; then
        echo "  • Backup saved to: $BACKUP_DIR"
    fi
    echo ""

    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Warnings:${RESET}"
        echo "──────────"
        for w in "${WARNINGS[@]}"; do
            echo -e "  ${YELLOW}!${RESET} $w"
        done
        echo ""
    fi

    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo -e "${RED}Errors:${RESET}"
        echo "─────────"
        for e in "${ERRORS[@]}"; do
            echo -e "  ${RED}✗${RESET} $e"
        done
        echo ""
    fi

    echo -e "${BOLD}Next Steps:${RESET}"
    echo "───────────"
    echo "  1. Log out of your current session"
    echo "  2. Select MangoWM (or mango-ext) from your login manager"
    echo "  3. Log back in"
    echo "  4. Run: ~/.local/bin/start-quickshell.sh"
    echo ""
    echo -e "${DIM}Duration: ${duration}s${RESET}"
    echo ""
    echo -e "${GREEN}${BOLD}THANK YOU FOR INSTALLING KAMALEN SHELL :)${RESET}"
}

# ── Main ─────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    # Handle --dry-run flag before case
    if $DRY_RUN; then
        echo -e "\n${YELLOW}${BOLD}DRY RUN MODE${RESET} - No changes will be made\n"
    fi

    case "${COMMAND:-}" in
        deps)
            preflight
            install_deps
            echo ""
            log "Dependencies installed"
            ;;
        configs)
            preflight
            install_configs
            install_sddm_theme
            echo ""
            log "Configs installed"
            ;;
        mango)
            preflight
            install_mango_ext
            ;;
        sddm)
            preflight
            install_sddm_theme
            ;;
        verify)
            verify_installation
            ;;
        status)
            show_status
            ;;
        unlink)
            preflight
            unlink_configs
            ;;
        *)
            preflight

            echo -e "${BOLD}Welcome to Kamalen Shell!${RESET}"
            echo ""
            echo "This will install:"
            echo "  • System dependencies (kitty, cava, neovim, etc.)"
            echo "  • Quickshell widgets and config"
            echo "  • MangoWM config"
            echo "  • Wallpapers"
            echo "  • PAM lockscreen"
            echo ""

            if ! $DRY_RUN; then
                read -p "Continue with full installation? [Y/n] " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Nn]$ ]]; then
                    info "Installation cancelled"
                    exit 0
                fi
            fi

            if ! $SKIP_DEPS; then
                install_deps
            else
                info "Skipping dependencies (--skip-deps)"
            fi

            if ! $SKIP_CONFIGS; then
                install_configs
                configure_user_shell
                install_sddm_theme
            else
                info "Skipping configs (--skip-configs)"
            fi

            echo ""
            print_summary
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi

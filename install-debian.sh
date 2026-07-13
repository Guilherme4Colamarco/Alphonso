#!/bin/bash
# ============================================================================
# Kamalen Shell Installer — Debian/Ubuntu Edition v2.1
# ============================================================================
# Port of the Arch installer for Debian-based distros.
# Same feature set: symlink configs, dry-run, unlink/restore, verify, status.
#
# Package mapping strategy:
#   - Pacman packages → apt equivalents (direct or close match)
#   - AUR packages → build-from-source, flatpak, snap, or cargo
#   - Config/service/PAM logic is identical to the Arch installer
#
# Tested on: Debian 12 (Bookworm), Debian 13 (Trixie), Ubuntu 24.04+
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
SKIP_BUILDS=false
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
${BOLD}Kamalen Shell Installer — Debian/Ubuntu Edition v2.1${RESET}

${BOLD}Usage:${RESET}
  ./install-debian.sh [options] [command]

${BOLD}Commands:${RESET}
  (none)      Full installation (interactive)
  deps        Install dependencies only
  builds      Build from-source packages only (quickshell, mango-ext, awww, etc.)
  configs     Install configs only (symlinks ~/.config/ → repo)
  sddm        Install/synchronize the optional SDDM theme
  unlink      Remove symlinks and optionally restore backup
  verify      Verify installation
  status      Show installation status

${BOLD}Options:${RESET}
  -n, --dry-run     Show what would be done without doing it
  -v, --verbose     Show full command output
  --skip-deps       Skip dependency installation
  --skip-configs    Skip config installation
  --skip-builds     Skip building from-source packages
  -h, --help        Show this help

${BOLD}Examples:${RESET}
  ./install-debian.sh                    # Full install (interactive)
  ./install-debian.sh --dry-run          # Preview what would happen
  ./install-debian.sh deps               # Install deps only
  ./install-debian.sh builds             # Build from-source only
  ./install-debian.sh --skip-deps        # Skip deps, install configs
  ./install-debian.sh verify             # Check if everything is installed
EOF
    exit 0
}

# ── Parse Args ───────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run)     DRY_RUN=true; shift ;;
            -v|--verbose)     VERBOSE=true; shift ;;
            --skip-deps)      SKIP_DEPS=true; shift ;;
            --skip-configs)   SKIP_CONFIGS=true; shift ;;
            --skip-builds)    SKIP_BUILDS=true; shift ;;
            -h|--help)        usage ;;
            deps|builds|configs|sddm|verify|status|unlink)
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

# ── Distro Detection ────────────────────────────────────────────
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_LIKE="${ID_LIKE:-}"
        DISTRO_VERSION="${VERSION_ID:-}"
        DISTRO_CODENAME="${VERSION_CODENAME:-}"
    elif [[ -f /etc/debian_version ]]; then
        DISTRO_ID="debian"
        DISTRO_LIKE="debian"
        DISTRO_VERSION=$(cat /etc/debian_version)
        DISTRO_CODENAME=""
    else
        DISTRO_ID="unknown"
        DISTRO_LIKE=""
        DISTRO_VERSION=""
        DISTRO_CODENAME=""
    fi

    # Determine if Debian-based
    IS_DEBIAN=false
    case "$DISTRO_ID" in
        debian|ubuntu|linuxmint|pop|elementary|zorin|kali|parrot|regolith|vanilla|siduction)
            IS_DEBIAN=true ;;
        *)
            if [[ "$DISTRO_LIKE" == *"debian"* ]] || [[ "$DISTRO_LIKE" == *"ubuntu"* ]]; then
                IS_DEBIAN=true
            fi ;;
    esac

    if ! $IS_DEBIAN; then
        error "This installer is for Debian-based distributions only."
        error "Detected: $DISTRO_ID ($DISTRO_LIKE)"
        error "For Arch Linux, use ./install.sh instead."
        exit 1
    fi

    log "Detected: ${BOLD}$DISTRO_ID${RESET} $DISTRO_VERSION ($DISTRO_CODENAME)"
}

# ── Preflight Checks ────────────────────────────────────────────
preflight() {
    header "Preflight Checks"

    detect_distro

    # Must have .config directory
    if [[ ! -d "$SCRIPT_DIR/.config" ]]; then
        error "Cannot find .config directory in $SCRIPT_DIR"
        exit 1
    fi
    log "Project structure verified"

    # Check for git
    if ! command_exists git; then
        error "git is required but not installed"
        exit 1
    fi
    log "git available"

    # Check for sudo
    if ! command_exists sudo; then
        error "sudo is required but not installed"
        exit 1
    fi
    log "sudo available"

    # Check available disk space (warn if < 2GB)
    local avail_kb
    avail_kb=$(df --output=avail / | tail -1 | tr -d ' ')
    if [[ "$avail_kb" -lt 2097152 ]]; then
        warn "Low disk space: $((avail_kb / 1048576))GB available (recommend 2GB+)"
    fi
}

# ── Package Lists ───────────────────────────────────────────────
# Maps Arch pacman packages to Debian apt equivalents.
# Organized by category for maintainability.

get_apt_packages() {
    # Core desktop tools
    local pkgs=(
        # Terminal & shell
        kitty neovim fish zsh starship

        # Audio
        mpd mpc mpv ffmpeg
        pipewire pipewire-audio pipewire-pulse wireplumber
        libspa-0.2-bluetooth libspa-0.2-jack
        alsa-utils playerctl pavucontrol

        # Wayland core
        swayidle swaylock swaybg waybar wofi
        grim slurp wl-clipboard
        xwayland seatd
        wayland-protocols

        # Display & graphics
        brightnessctl gammastep wlr-randr
        imagemagick

        # System
        network-manager network-manager-gnome
        bluez bluez-tools
        inotify-tools

        # Fonts
        fonts-jetbrains-mono fonts-noto-color-emoji

        # Build essentials (needed for from-source builds)
        build-essential cmake ninja-build pkg-config
        meson

        # Python
        python3 python3-pil python3-pam python3-numpy python3-gi

        # Dev libraries (for quickshell, mango, awww, etc.)
        qt6-base-dev qt6-declarative-dev qt6-svg-dev
        qt6-wayland-dev qt6-tools-dev qt6-tools-dev-tools
        libqt6shadertools6-dev
        libdrm-dev libxkbcommon-dev libinput-dev
        libpixman-1-dev libgl-dev libglx-dev libegl-dev
        libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-shape0-dev
        libxcb-render0-dev libxcb-xfixes0-dev
        libdbus-1-dev libsystemd-dev libudev-dev
        libpipewire-0.3-dev libspa-0.2-dev
        libpango1.0-dev libcairo2-dev libpcre2-dev
        libdisplay-info-dev libliftoff-dev
        hwdata
        libseat-dev
        libcli11-dev

        # Misc tools
        curl wget gnupg
        cava  # fastfetch: only in Debian 13+, not Bookworm
        mpvpaper
        fc-cache
    )

    echo "${pkgs[@]}"
}

get_build_from_source_packages() {
    # Packages that must be built from source (AUR equivalents)
    echo "quickshell mango-ext awww rmpc gpu-screen-recorder tiramisu pokemon-colorscripts"
}

# ── Install Dependencies ────────────────────────────────────────
install_deps() {
    header "Installing Dependencies (apt)"

    # Update package lists
    info "Updating package lists..."
    if ! $DRY_RUN; then
        sudo apt update || { error "apt update failed"; return 1; }
    fi
    log "Package lists updated"

    # Enable non-free repos if needed (for some firmware/packages)
    info "Ensuring non-free repos are available..."
    if ! $DRY_RUN; then
        if [[ -f /etc/apt/sources.list ]]; then
            # Debian 12 style
            if ! grep -q "non-free" /etc/apt/sources.list 2>/dev/null; then
                warn "Consider adding non-free repos to /etc/apt/sources.list"
            fi
        fi
    fi

    # Install apt packages
    local apt_pkgs
    read -ra apt_pkgs <<< "$(get_apt_packages)"
    info "Installing ${#apt_pkgs[@]} apt packages..."

    if $DRY_RUN; then
        info "dry-run: sudo apt install -y ${apt_pkgs[*]}"
    else
        # Install in batches to handle partial failures gracefully
        local batch_size=20
        local total=${#apt_pkgs[@]}
        local i=0

        while [[ $i -lt $total ]]; do
            local batch=("${apt_pkgs[@]:$i:$batch_size}")
            if ! sudo apt install -y "${batch[@]}" 2>/dev/null; then
                warn "Some packages in batch $((i/batch_size + 1)) failed — continuing"
            fi
            ((i += batch_size))
        done
    fi
    log "Apt packages installed"

    # Install starship prompt (if not in repos or outdated)
    install_starship

    # Enable services
    info "Enabling services..."
    if ! $DRY_RUN; then
        sudo systemctl enable --now NetworkManager 2>/dev/null || true
        sudo systemctl enable --now bluetooth 2>/dev/null || true
        systemctl --user enable --now pipewire.service 2>/dev/null || true
        systemctl --user enable --now pipewire-pulse.service 2>/dev/null || true
        systemctl --user enable --now wireplumber.service 2>/dev/null || true
        systemctl --user enable --now mpd 2>/dev/null || true
    fi
    log "Services enabled"
}

# ── Install Starship Prompt ─────────────────────────────────────
install_starship() {
    if command_exists starship; then
        log "Starship already installed"
        return 0
    fi

    info "Installing Starship prompt..."
    if $DRY_RUN; then
        info "dry-run: curl -sS https://starship.rs/install.sh | sh -s -- -y"
    else
        curl -sS https://starship.rs/install.sh | sh -s -- -y || {
            warn "Starship install script failed — install manually from https://starship.rs"
            return 0
        }
    fi
    log "Starship installed"
}

# ── Build From Source: Quickshell ───────────────────────────────
build_quickshell() {
    header "Building Quickshell"

    if command_exists quickshell; then
        log "Quickshell already installed — skipping"
        return 0
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)

    info "Cloning quickshell..."
    if $DRY_RUN; then
        info "dry-run: git clone https://github.com/quickshell-mirror/quickshell.git"
    else
        git clone --depth 1 https://github.com/quickshell-mirror/quickshell.git "$tmp_dir/quickshell" 2>/dev/null || {
            error "Failed to clone quickshell"
            rm -rf "$tmp_dir"
            return 1
        }
    fi

    cd "$tmp_dir/quickshell"

    info "Configuring quickshell (cmake)..."
    if ! $DRY_RUN; then
        cmake -B build -G Ninja \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DCMAKE_INSTALL_PREFIX=/usr \
            -DINSTALL_QML=false \
            2>&1 | if $VERBOSE; then cat; else tail -5; fi || {
            error "cmake configure failed for quickshell"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
    fi

    info "Compiling quickshell..."
    if ! $DRY_RUN; then
        cmake --build build -j"$(nproc)" 2>&1 | if $VERBOSE; then cat; else tail -5; fi || {
            error "cmake build failed for quickshell"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
    fi

    info "Installing quickshell..."
    if ! $DRY_RUN; then
        sudo cmake --install build || {
            error "cmake install failed for quickshell"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
    fi

    cd "$SCRIPT_DIR"
    rm -rf "$tmp_dir"
    log "Quickshell installed"
}

# ── Build From Source: Mango-Ext ────────────────────────────────
build_mango_ext() {
    header "Building Mango-Ext"

    if command_exists mango-ext; then
        log "Mango-ext already installed — skipping"
        return 0
    fi

    local build_dir="$HOME/.local/share/kamalen-builds"
    mkdir -p "$build_dir"

    # Build wlroots 0.19.x first
    build_wlroots "$build_dir"

    # Build scenefx
    build_scenefx "$build_dir"

    # Build mango-ext
    local tmp_dir
    tmp_dir=$(mktemp -d)

    info "Cloning mango-ext..."
    if $DRY_RUN; then
        info "dry-run: git clone https://github.com/ernestoCruz05/mango-ext.git"
    else
        git clone --depth 1 https://github.com/ernestoCruz05/mango-ext.git "$tmp_dir/mango-ext" 2>/dev/null || {
            error "Failed to clone mango-ext"
            rm -rf "$tmp_dir"
            return 1
        }
    fi

    cd "$tmp_dir/mango-ext"

    info "Configuring mango-ext..."
    if ! $DRY_RUN; then
        meson setup build -Dprefix=/usr || {
            error "meson setup failed for mango-ext"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
    fi

    info "Compiling mango-ext..."
    if ! $DRY_RUN; then
        meson compile -C build || {
            error "meson compile failed for mango-ext"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
    fi

    info "Installing mango-ext..."
    if ! $DRY_RUN; then
        sudo meson install -C build || {
            error "meson install failed for mango-ext"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
    fi

    cd "$SCRIPT_DIR"
    rm -rf "$tmp_dir"

    mkdir -p ~/.config/mango-ext
    log "mango-ext installed"
}

build_wlroots() {
    local build_dir="$1"
    info "Building wlroots 0.19.x..."

    if pkg-config --exists wlroots 2>/dev/null; then
        local wlroots_ver
        wlroots_ver=$(pkg-config --modversion wlroots 2>/dev/null || echo "0")
        if [[ "$wlroots_ver" == 0.19* ]]; then
            log "wlroots $wlroots_ver already installed — skipping"
            return 0
        fi
    fi

    local wlroots_dir="$build_dir/wlroots"
    if [[ -d "$wlroots_dir" ]]; then
        rm -rf "$wlroots_dir"
    fi

    if ! $DRY_RUN; then
        git clone --depth 1 -b 0.19.3 https://gitlab.freedesktop.org/wlroots/wlroots.git "$wlroots_dir" || {
            error "Failed to clone wlroots"
            return 1
        }
        cd "$wlroots_dir"
        meson setup build -Dprefix=/usr
        sudo ninja -C build install
        cd "$SCRIPT_DIR"
        rm -rf "$wlroots_dir"
    fi
    log "wlroots installed"
}

build_scenefx() {
    local build_dir="$1"
    info "Building scenefx..."

    if pkg-config --exists scenefx 2>/dev/null; then
        log "scenefx already installed — skipping"
        return 0
    fi

    local scenefx_dir="$build_dir/scenefx"
    if [[ -d "$scenefx_dir" ]]; then
        rm -rf "$scenefx_dir"
    fi

    if ! $DRY_RUN; then
        git clone --depth 1 -b 0.4.1 https://github.com/wlrfx/scenefx.git "$scenefx_dir" || {
            error "Failed to clone scenefx"
            return 1
        }
        cd "$scenefx_dir"
        meson setup build -Dprefix=/usr
        sudo ninja -C build install
        cd "$SCRIPT_DIR"
        rm -rf "$scenefx_dir"
    fi
    log "scenefx installed"
}

# ── Build From Source: awww (Wayland Wallpaper Daemon) ──────────
build_awww() {
    header "Building awww"

    if command_exists awww; then
        log "awww already installed — skipping"
        return 0
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)

    info "Cloning awww..."
    if $DRY_RUN; then
        info "dry-run: git clone https://codeberg.org/LGFae/awww.git"
    else
        git clone --depth 1 https://codeberg.org/LGFae/awww.git "$tmp_dir/awww" 2>/dev/null || {
            error "Failed to clone awww"
            rm -rf "$tmp_dir"
            return 1
        }
    fi

    cd "$tmp_dir/awww"

    info "Building awww..."
    if ! $DRY_RUN; then
        make || {
            error "make failed for awww"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
    fi

    info "Installing awww..."
    if ! $DRY_RUN; then
        sudo make install || {
            error "make install failed for awww"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
    fi

    cd "$SCRIPT_DIR"
    rm -rf "$tmp_dir"
    log "awww installed"
}

# ── Build From Source: mpvpaper ─────────────────────────────────
build_mpvpaper() {
    header "Building mpvpaper"

    if command_exists mpvpaper; then
        log "mpvpaper already installed — skipping"
        return 0
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)

    info "Cloning mpvpaper..."
    if $DRY_RUN; then
        info "dry-run: git clone https://github.com/GhostNaN/mpvpaper.git"
    else
        git clone --depth 1 https://github.com/GhostNaN/mpvpaper.git "$tmp_dir/mpvpaper" 2>/dev/null || {
            error "Failed to clone mpvpaper"
            rm -rf "$tmp_dir"
            return 1
        }
    fi

    cd "$tmp_dir/mpvpaper"

    info "Building mpvpaper..."
    if ! $DRY_RUN; then
        meson setup build --prefix=/usr || {
            error "meson setup failed for mpvpaper"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
        sudo ninja -C build install || {
            error "ninja install failed for mpvpaper"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
    fi

    cd "$SCRIPT_DIR"
    rm -rf "$tmp_dir"
    log "mpvpaper installed"
}

# ── Install From Source: rmpc (Rust MPD Client) ─────────────────
install_rmpc() {
    header "Installing rmpc"

    if command_exists rmpc; then
        log "rmpc already installed — skipping"
        return 0
    fi

    # Try cargo first, fall back to binary download
    if command_exists cargo; then
        info "Installing rmpc via cargo..."
        if ! $DRY_RUN; then
            cargo install rmpc || {
                warn "cargo install rmpc failed — trying binary download"
                install_rmpc_binary
                return 0
            }
        fi
    else
        install_rmpc_binary
    fi

    log "rmpc installed"
}

install_rmpc_binary() {
    info "Downloading rmpc binary..."
    if $DRY_RUN; then
        info "dry-run: download rmpc binary from GitHub releases"
        return 0
    fi

    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        *)       error "Unsupported architecture: $arch"; return 1 ;;
    esac

    local tmp_dir
    tmp_dir=$(mktemp -d)

    # Get latest release URL
    local latest_url
    latest_url=$(curl -sL "https://api.github.com/repos/mierak/rmpc/releases/latest" | grep -o '"browser_download_url": *"[^"]*linux-'"$arch"'"' | head -1 | cut -d'"' -f4) || true

    if [[ -z "$latest_url" ]]; then
        warn "Could not fetch rmpc binary — install manually via cargo or snap"
        rm -rf "$tmp_dir"
        return 0
    fi

    curl -sL "$latest_url" -o "$tmp_dir/rmpc" || { rm -rf "$tmp_dir"; return 1; }
    chmod +x "$tmp_dir/rmpc"
    sudo mv "$tmp_dir/rmpc" /usr/local/bin/
    rm -rf "$tmp_dir"
    log "rmpc binary installed"
}

# ── Install From Source: gpu-screen-recorder ────────────────────
install_gpu_screen_recorder() {
    header "Installing gpu-screen-recorder"

    if command_exists gpu-screen-recorder; then
        log "gpu-screen-recorder already installed — skipping"
        return 0
    fi

    # Prefer flatpak if available
    if command_exists flatpak; then
        info "Installing gpu-screen-recorder via Flatpak..."
        if ! $DRY_RUN; then
            flatpak install -y flathub com.dec05eba.gpu_screen_recorder 2>/dev/null || {
                warn "Flatpak install failed — trying build from source"
                build_gpu_screen_recorder
                return 0
            }
        fi
    else
        build_gpu_screen_recorder
    fi

    log "gpu-screen-recorder installed"
}

build_gpu_screen_recorder() {
    local tmp_dir
    tmp_dir=$(mktemp -d)

    info "Cloning gpu-screen-recorder..."
    if ! $DRY_RUN; then
        git clone --depth 1 https://git.dec05eba.com/gpu-screen-recorder.git "$tmp_dir/gpu-screen-recorder" 2>/dev/null || {
            error "Failed to clone gpu-screen-recorder"
            rm -rf "$tmp_dir"
            return 1
        }
    fi

    cd "$tmp_dir/gpu-screen-recorder"

    info "Building gpu-screen-recorder..."
    if ! $DRY_RUN; then
        ./install.sh || {
            error "gpu-screen-recorder build failed"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
    fi

    cd "$SCRIPT_DIR"
    rm -rf "$tmp_dir"
}

# ── Install From Source: tiramisu (Screenshot Tool) ─────────────
install_tiramisu() {
    header "Installing tiramisu"

    if command_exists tiramisu; then
        log "tiramisu already installed — skipping"
        return 0
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)

    info "Cloning tiramisu..."
    if ! $DRY_RUN; then
        git clone --depth 1 https://github.com/Scrumplex/tiramisu.git "$tmp_dir/tiramisu" 2>/dev/null || {
            error "Failed to clone tiramisu"
            rm -rf "$tmp_dir"
            return 1
        }
    fi

    cd "$tmp_dir/tiramisu"

    info "Building tiramisu..."
    if ! $DRY_RUN; then
        meson setup build || {
            error "meson setup failed for tiramisu"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
        sudo ninja -C build install || {
            error "ninja install failed for tiramisu"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
    fi

    cd "$SCRIPT_DIR"
    rm -rf "$tmp_dir"
    log "tiramisu installed"
}

# ── Install Pokemon Colorscripts ────────────────────────────────
install_pokemon_colorscripts() {
    header "Installing pokemon-colorscripts"

    if command_exists pokemon-colorscripts; then
        log "pokemon-colorscripts already installed — skipping"
        return 0
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)

    info "Cloning pokemon-colorscripts..."
    if ! $DRY_RUN; then
        git clone --depth 1 https://gitlab.com/phoneybadner/pokemon-colorscripts.git "$tmp_dir/pokemon-colorscripts" 2>/dev/null || {
            error "Failed to clone pokemon-colorscripts"
            rm -rf "$tmp_dir"
            return 1
        }
    fi

    cd "$tmp_dir/pokemon-colorscripts"

    info "Installing pokemon-colorscripts..."
    if ! $DRY_RUN; then
        sudo make install || {
            error "make install failed for pokemon-colorscripts"
            cd "$SCRIPT_DIR"; rm -rf "$tmp_dir"; return 1
        }
    fi

    cd "$SCRIPT_DIR"
    rm -rf "$tmp_dir"
    log "pokemon-colorscripts installed"
}

# ── Install All From-Source Packages ────────────────────────────
install_builds() {
    header "Building From-Source Packages"

    if $DRY_RUN; then
        info "dry-run: build quickshell mango-ext awww mpvpaper rmpc gpu-screen-recorder tiramisu pokemon-colorscripts"
        log "From-source build plan generated"
        return 0
    fi

    build_quickshell
    build_mango_ext
    build_awww
    build_mpvpaper
    install_rmpc
    install_gpu_screen_recorder
    install_tiramisu
    install_pokemon_colorscripts

    log "All from-source packages built"
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
get_managed_dirs() {
    echo "mango mango-ext kitty quickshell fastfetch cava rmpc nvim"
}

# ── Install Configs (Symlink Mode) ───────────────────────────────
install_configs() {
    header "Installing Configs (Symlink Mode)"

    # Create system directories
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

    # Initialize Quickshell state
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
    first_wall=$(find ~/wallpapers -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.webm" \) 2>/dev/null | head -1 || true)
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

    # Create Mango-Ext launcher
    info "Creating mango-ext launcher..."
    if ! $DRY_RUN; then
        cat > ~/.local/bin/start-mango-ext.sh << 'EOF'
#!/bin/bash
pkill mango-ext 2>/dev/null
sleep 0.3
exec mango-ext
EOF
        chmod +x ~/.local/bin/start-mango-ext.sh
    fi
    log "Mango-ext launcher created"
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

    # Remove launcher scripts
    local launcher=~/.local/bin/start-quickshell.sh
    if [[ -f "$launcher" ]]; then
        step "Removing launcher script"
        if ! $DRY_RUN; then
            rm "$launcher"
        fi
    fi

    local mango_launcher=~/.local/bin/start-mango-ext.sh
    if [[ -f "$mango_launcher" ]]; then
        step "Removing mango-ext launcher"
        if ! $DRY_RUN; then
            rm "$mango_launcher"
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
            info "Configuring Fish Shell..."
            if ! command_exists fish; then
                info "Installing fish shell..."
                sudo apt install -y fish || { error "fish install failed"; return 1; }
            fi

            local fish_path
            fish_path=$(which fish 2>/dev/null || echo "/usr/bin/fish")
            if [[ "${SHELL:-}" != "$fish_path" ]]; then
                info "Setting default shell to Fish..."
                sudo chsh -s "$fish_path" "$USER" || chsh -s "$fish_path"
            fi

            mkdir -p ~/.config/fish
            local fish_config=~/.config/fish/config.fish
            if [[ -f "$fish_config" ]]; then
                cp "$fish_config" "$fish_config.bak.$(date +%s)"
            fi

            if ! grep -Fq "fish_vi_key_bindings" "$fish_config" 2>/dev/null; then
                cat << 'FISH_EOF' >> "$fish_config"

# Kamalen Shell: Vi key bindings
if status is-interactive
    fish_vi_key_bindings
end
FISH_EOF
            fi

            if ! grep -Fq "starship init fish" "$fish_config" 2>/dev/null; then
                cat << 'FISH_EOF' >> "$fish_config"

# Kamalen Shell: Starship prompt
if type -q starship
    starship init fish | source
end
FISH_EOF
            fi
            log "Fish Shell configured with Starship and Vi mode."
            ;;
        2)
            info "Configuring Zsh Shell..."
            if ! command_exists zsh; then
                info "Installing zsh shell..."
                sudo apt install -y zsh || { error "zsh install failed"; return 1; }
            fi

            local zsh_path
            zsh_path=$(which zsh 2>/dev/null || echo "/bin/zsh")
            if [[ "${SHELL:-}" != "$zsh_path" ]]; then
                info "Setting default shell to Zsh..."
                sudo chsh -s "$zsh_path" "$USER" || chsh -s "$zsh_path"
            fi

            local zsh_config=~/.zshrc
            if [[ -f "$zsh_config" ]]; then
                cp "$zsh_config" "$zsh_config.bak"
            fi

            if ! grep -Fq "bindkey -v" "$zsh_config" 2>/dev/null; then
                cat << 'ZSH_EOF' >> "$zsh_config"

# Kamalen Shell: Vi key bindings
bindkey -v
ZSH_EOF
            fi

            if ! grep -Fq "starship init zsh" "$zsh_config" 2>/dev/null; then
                cat << 'ZSH_EOF' >> "$zsh_config"

# Kamalen Shell: Starship prompt
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi
ZSH_EOF
            fi
            log "Zsh configured with Starship and Vi mode."
            ;;
        3)
            info "Configuring Bash Shell..."
            local bash_config=~/.bashrc
            if [[ -f "$bash_config" ]]; then
                cp "$bash_config" "$bash_config.bak"
            fi

            if ! grep -Fq "set -o vi" "$bash_config" 2>/dev/null; then
                cat << 'BASH_EOF' >> "$bash_config"

# Kamalen Shell: Vi key bindings
set -o vi
BASH_EOF
            fi

            if ! grep -Fq "starship init bash" "$bash_config" 2>/dev/null; then
                cat << 'BASH_EOF' >> "$bash_config"

# Kamalen Shell: Starship prompt
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi
BASH_EOF
            fi
            log "Bash configured with Starship and Vi mode."
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

    # Check critical commands (apt-installed)
    local cmds=(kitty cava starship mpv nvim playerctl brightnessctl grim slurp)
    for cmd in "${cmds[@]}"; do
        if command_exists "$cmd"; then
            log "$cmd: installed"
        else
            error "$cmd: not found"
            ((issues++)) || true
        fi
    done

    # Optional commands (not in all Debian versions)
    if command_exists fastfetch; then
        log "fastfetch: installed"
    else
        warn "fastfetch: not found (only in Debian 13+)"
    fi

    # Check from-source commands
    local build_cmds=(quickshell mango-ext awww rmpc gpu-screen-recorder tiramisu pokemon-colorscripts)
    for cmd in "${build_cmds[@]}"; do
        if command_exists "$cmd"; then
            log "$cmd: installed"
        else
            warn "$cmd: not found (from-source package)"
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

    if systemctl --user is-active --quiet pipewire 2>/dev/null; then
        log "PipeWire: running"
    else
        warn "PipeWire: not running"
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

    echo -e "${BOLD}System:${RESET}"
    echo "────────"
    echo "  Distro: $DISTRO_ID $DISTRO_VERSION ($DISTRO_CODENAME)"
    echo ""

    echo -e "${BOLD}Installed Components:${RESET}"
    echo "─────────────────────"

    local name cmd
    for name_cmd in "MangoWM:mango" "Mango-Ext:mango-ext" "Quickshell:quickshell" "Kitty:kitty" "Neovim:nvim" "Cava:cava" "Fastfetch:fastfetch" "Starship:starship" "MPV:mpv" "Playerctl:playerctl" "AWWW:awww" "MPvpaper:mpvpaper" "RMPC:rmpc" "GPU-Screen-Recorder:gpu-screen-recorder"; do
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
}

# ── Print Summary ────────────────────────────────────────────────
print_summary() {
    header "Installation Summary"

    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    echo -e "${BOLD}Completed:${RESET}"
    echo "──────────"
    echo "  • Dependencies installed (apt + from-source)"
    echo "  • Configs symlinked to ~/.config/ → $SCRIPT_DIR/.config/"
    echo "  • Wallpapers copied to ~/wallpapers/"
    echo "  • PAM lockscreen configured"
    echo "  • Launchers created in ~/.local/bin/"
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
    echo "  2. Select Mango-Ext from your login manager"
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
        builds)
            preflight
            install_builds
            echo ""
            log "From-source packages built"
            ;;
        configs)
            preflight
            install_configs
            install_sddm_theme
            echo ""
            log "Configs installed"
            ;;
        sddm)
            preflight
            install_sddm_theme
            ;;
        verify)
            detect_distro
            verify_installation
            ;;
        status)
            detect_distro
            show_status
            ;;
        unlink)
            preflight
            unlink_configs
            ;;
        *)
            preflight

            echo -e "${BOLD}Welcome to Kamalen Shell (Debian/Ubuntu)!${RESET}"
            echo ""
            echo "This will install:"
            echo "  • System dependencies via apt"
            echo "  • From-source packages (quickshell, mango-ext, awww, etc.)"
            echo "  • Quickshell widgets and config"
            echo "  • Mango-Ext config"
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

            if ! $SKIP_BUILDS; then
                install_builds
            else
                info "Skipping from-source builds (--skip-builds)"
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

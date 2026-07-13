#!/usr/bin/env bash
# Shared entrypoint for experimental distro profiles.
# It reuses the established config backup/symlink workflow from install.sh,
# while keeping package-manager actions profile-specific and conservative.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="${KAMALEN_PROFILE:?KAMALEN_PROFILE must be set by an entrypoint}"

# install.sh exposes config, unlink, verification, and summary functions. Its
# main guard keeps sourcing side-effect free.
source "$ROOT_DIR/install.sh"

WITH_PAM=false

usage() {
    cat <<EOF
Kamalen Shell ${PROFILE} installer (experimental)

Usage: ./install-${PROFILE}.sh [options] [command]

Commands: deps, configs, sddm, unlink, verify, status
Options: --dry-run, --skip-deps, --skip-configs, --with-pam, --help

This profile installs only native repository dependencies. It never enables
third-party repositories automatically and does not build mango-ext for you.
EOF
    exit 0
}

parse_args() {
    COMMAND=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run) DRY_RUN=true ;;
            -v|--verbose) VERBOSE=true ;;
            --skip-deps) SKIP_DEPS=true ;;
            --skip-configs) SKIP_CONFIGS=true ;;
            --with-pam) WITH_PAM=true ;;
            -h|--help) usage ;;
            deps|configs|sddm|unlink|verify|status)
                [[ -z "$COMMAND" ]] || { error "Only one command is allowed"; exit 2; }
                COMMAND="$1" ;;
            *) error "Unknown option: $1"; usage ;;
        esac
        shift
    done
}

read_os_release() {
    local os_release="${KAMALEN_OS_RELEASE:-/etc/os-release}"
    [[ -r "$os_release" ]] || { error "Cannot read $os_release"; exit 1; }
    # shellcheck disable=SC1090
    source "$os_release"
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
}

profile_matches_host() {
    case "$PROFILE" in
        fedora) [[ "$DISTRO_ID" == "fedora" ]] ;;
        opensuse) [[ "$DISTRO_ID" == opensuse-* || "$DISTRO_ID" == opensuse ]] ;;
        pacman) [[ "$DISTRO_ID" == manjaro || "$DISTRO_ID" == biglinux || "$DISTRO_ID" == endeavouros || "$DISTRO_ID" == garuda || "$DISTRO_ID" == cachyos ]] ;;
        void) [[ "$DISTRO_ID" == "void" ]] ;;
        *) return 1 ;;
    esac
}

preflight() {
    header "Preflight Checks"
    read_os_release
    if ! profile_matches_host; then
        error "This installer profile is for $PROFILE; detected $DISTRO_ID ($DISTRO_LIKE)"
        exit 1
    fi
    [[ -d "$ROOT_DIR/.config" ]] || { error "Cannot find .config in $ROOT_DIR"; exit 1; }
    command_exists git || { error "git is required"; exit 1; }
    local profile_label
    case "$PROFILE" in
        fedora) profile_label="Fedora" ;;
        opensuse) profile_label="openSUSE" ;;
        pacman) profile_label="Pacman family" ;;
        void) profile_label="Void Linux" ;;
    esac
    log "Detected ${BOLD}$DISTRO_ID${RESET}; profile $profile_label"
}

setup_pam() {
    if ! $WITH_PAM; then
        warn "PAM lockscreen setup is skipped. Re-run with --with-pam only after reviewing your distro's PAM policy."
        return 0
    fi
    if $DRY_RUN; then
        info "dry-run: install /etc/pam.d/lockscreen using pam_unix"
        return 0
    fi
    local pam_tmp
    pam_tmp=$(mktemp)
    printf '%s\n' 'auth required pam_unix.so nodelay' 'account required pam_unix.so' > "$pam_tmp"
    sudo install -m 0644 -o root -g root "$pam_tmp" /etc/pam.d/lockscreen
    rm -f "$pam_tmp"
    log "PAM lockscreen configured"
}

configure_user_shell() {
    warn "Default-shell changes are intentionally skipped by experimental installers. Configure Fish/Zsh manually after verifying the session."
}

install_deps() {
    header "Installing Native Dependencies"
    case "$PROFILE" in
        fedora)
            local pkgs=(git kitty cava fastfetch starship grim slurp mpd mpc mpv ffmpeg swayidle wlr-randr gammastep alsa-utils NetworkManager bluez bluez-tools pipewire wireplumber brightnessctl playerctl ImageMagick python3 python3-pillow python3-pam python3-numpy inotify-tools neovim meson ninja wayland-protocols libinput seatd xorg-x11-server-Xwayland pixman glslang libglvnd libxkbcommon xcb-util-wm quickshell)
            if $DRY_RUN; then info "dry-run: sudo dnf install ${pkgs[*]}"; else sudo dnf install -y "${pkgs[@]}"; fi
            warn "mango-ext, awww, mpvpaper, and related optional tools are not installed from third-party repositories automatically."
            ;;
        opensuse)
            local pkgs=(git kitty cava fastfetch starship grim slurp mpd mpc mpv ffmpeg swayidle wlr-randr gammastep alsa-utils NetworkManager bluez bluez-tools pipewire wireplumber brightnessctl playerctl ImageMagick python3 python3-Pillow python3-pam python3-numpy inotify-tools neovim meson ninja wayland-protocols libinput seatd xwayland pixman glslang libglvnd libxkbcommon xcb-util-wm)
            if $DRY_RUN; then info "dry-run: sudo zypper install ${pkgs[*]}"; else sudo zypper --non-interactive install "${pkgs[@]}"; fi
            warn "Quickshell and mpvpaper need an OBS repository opt-in; mango-ext requires a validated source build."
            ;;
        pacman)
            local pkgs=(git kitty cava fastfetch starship grim slurp mpd mpc mpv ffmpeg swayidle wlr-randr gammastep alsa-utils networkmanager bluez bluez-utils pipewire wireplumber brightnessctl playerctl imagemagick python python-pillow python-pam python-numpy inotify-tools neovim meson ninja wayland-protocols libinput seatd xorg-xwayland pixman glslang libglvnd libxkbcommon xcb-util-wm)
            if $DRY_RUN; then info "dry-run: sudo pacman -S --needed ${pkgs[*]}"; else sudo pacman -S --needed "${pkgs[@]}"; fi
            warn "AUR is disabled for Manjaro/BigLinux profiles. Use only distro-compatible packages after a full system update and snapshot."
            ;;
        void)
            warn "Void Linux is configuration-only for now: service management uses runit and the required Wayland packages need per-install verification."
            ;;
    esac
}

main "$@"

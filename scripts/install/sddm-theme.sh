#!/usr/bin/env bash
# Install the optional Kamalen SDDM theme without replacing existing SDDM config.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THEME_SOURCE="${KAMALEN_SDDM_THEME_SOURCE:-$ROOT_DIR/sddm/kamalen}"
SYNC_SOURCE="${KAMALEN_SDDM_SYNC_SOURCE:-$ROOT_DIR/scripts/sddm/sync-kamalen-sddm.py}"
THEME_DIR="${KAMALEN_SDDM_THEME_DIR:-/usr/share/sddm/themes/kamalen}"
STATE_DIR="${KAMALEN_SDDM_STATE_DIR:-/var/lib/kamalen-sddm}"
CONFIG_FILE="${KAMALEN_SDDM_CONFIG:-/etc/sddm.conf.d/99-kamalen-theme.conf}"
SYNC_BIN="${KAMALEN_SDDM_BIN:-/usr/local/bin/kamalen-sddm-sync}"
DRY_RUN=false
ASSUME_YES=false
COMMAND=install

usage() {
    cat <<'EOF'
Usage: sddm-theme.sh [--dry-run] [--yes] [install|verify|uninstall]

  install     Install and initially synchronize the optional theme
  verify      Verify theme, state, sync helper, and activation drop-in
  uninstall   Remove only files managed by this installer

Activation is opt-in. The installer never restarts SDDM.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=true ;;
        -y|--yes) ASSUME_YES=true ;;
        install|verify|uninstall) COMMAND="$1" ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

run_privileged() {
    if [[ "${KAMALEN_SDDM_TEST_MODE:-0}" == "1" ]] || [[ ${EUID:-$(id -u)} -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

install_root_file() {
    local mode="$1" source="$2" destination="$3"
    if [[ "${KAMALEN_SDDM_TEST_MODE:-0}" == "1" ]]; then
        install -D -m "$mode" "$source" "$destination"
    else
        run_privileged install -D -m "$mode" -o root -g root "$source" "$destination"
    fi
}

sddm_present() {
    case "${KAMALEN_SDDM_PRESENT:-auto}" in
        1) return 0 ;;
        0) return 1 ;;
        auto) command -v sddm >/dev/null 2>&1 || [[ -x /usr/bin/sddm ]] ;;
        *) echo "Invalid KAMALEN_SDDM_PRESENT override" >&2; return 2 ;;
    esac
}

dry_run_plan() {
    echo "dry-run: install root-owned theme in $THEME_DIR"
    echo "dry-run: create state directory $STATE_DIR (0750, user:sddm)"
    echo "dry-run: install $SYNC_BIN and run initial synchronization"
    echo "dry-run: activation would require confirmation and create only $CONFIG_FILE"
}

install_theme() {
    if ! sddm_present; then
        echo "SDDM is not installed; skipping the optional Kamalen SDDM theme."
        return 0
    fi
    [[ -d "$THEME_SOURCE" && -f "$THEME_SOURCE/Main.qml" ]] || {
        echo "Theme source is incomplete: $THEME_SOURCE" >&2
        return 1
    }
    [[ -f "$SYNC_SOURCE" ]] || { echo "Sync helper is missing: $SYNC_SOURCE" >&2; return 1; }

    if $DRY_RUN; then
        dry_run_plan
        return 0
    fi

    local target_user="${SUDO_USER:-${USER:-$(id -un)}}"
    if [[ "${KAMALEN_SDDM_TEST_MODE:-0}" != "1" ]] && ! getent group sddm >/dev/null; then
        echo "The sddm group is missing; refusing to create an unreadable state directory." >&2
        return 1
    fi

    run_privileged rm -rf "$THEME_DIR"
    if [[ "${KAMALEN_SDDM_TEST_MODE:-0}" == "1" ]]; then
        install -d -m 0755 "$THEME_DIR"
    else
        run_privileged install -d -m 0755 -o root -g root "$THEME_DIR"
    fi
    run_privileged cp -a "$THEME_SOURCE/." "$THEME_DIR/"
    if [[ "${KAMALEN_SDDM_TEST_MODE:-0}" != "1" ]]; then
        run_privileged chown -R root:root "$THEME_DIR"
    fi
    run_privileged find "$THEME_DIR" -type d -exec chmod 0755 {} +
    run_privileged find "$THEME_DIR" -type f -exec chmod 0644 {} +
    run_privileged rm -f "$THEME_DIR/theme.conf.user"
    run_privileged ln -s "$STATE_DIR/theme.conf.user" "$THEME_DIR/theme.conf.user"

    run_privileged install -d -m 0750 "$STATE_DIR"
    if [[ "${KAMALEN_SDDM_TEST_MODE:-0}" != "1" ]]; then
        run_privileged chown "$target_user:sddm" "$STATE_DIR"
    fi
    install_root_file 0755 "$SYNC_SOURCE" "$SYNC_BIN"

    "$SYNC_BIN" --state-dir "$STATE_DIR"
    echo "Kamalen SDDM theme installed and synchronized."

    local activate=false
    if $ASSUME_YES; then
        activate=true
    elif [[ -t 0 ]]; then
        read -r -p "Activate Kamalen as the SDDM theme? [y/N] " reply
        [[ "$reply" =~ ^[Yy]$ ]] && activate=true
    else
        read -r reply || reply=""
        [[ "$reply" =~ ^[Yy]$ ]] && activate=true
    fi

    if $activate; then
        local tmp
        tmp=$(mktemp)
        printf '%s\n' '[Theme]' 'Current=kamalen' > "$tmp"
        install_root_file 0644 "$tmp" "$CONFIG_FILE"
        rm -f "$tmp"
        echo "Theme activated for the next logout or boot; SDDM was not restarted."
    else
        echo "Theme installed but not activated. Run with --yes to activate it."
    fi
}

verify_theme() {
    local failures=0
    [[ -f "$THEME_DIR/Main.qml" ]] || { echo "missing: $THEME_DIR/Main.qml"; failures=$((failures + 1)); }
    [[ -x "$SYNC_BIN" ]] || { echo "missing: $SYNC_BIN"; failures=$((failures + 1)); }
    [[ -d "$STATE_DIR" ]] || { echo "missing: $STATE_DIR"; failures=$((failures + 1)); }
    if [[ ! -L "$THEME_DIR/theme.conf.user" ]] || \
       [[ "$(readlink "$THEME_DIR/theme.conf.user" 2>/dev/null || true)" != "$STATE_DIR/theme.conf.user" ]]; then
        echo "invalid theme.conf.user symlink: expected $STATE_DIR/theme.conf.user"
        failures=$((failures + 1))
    fi
    if [[ "${KAMALEN_SDDM_TEST_MODE:-0}" != "1" ]]; then
        [[ "$(stat -c '%U:%G' "$THEME_DIR/Main.qml" 2>/dev/null || true)" == "root:root" ]] || {
            echo "invalid QML ownership: expected root:root"
            failures=$((failures + 1))
        }
        [[ "$(stat -c '%a' "$STATE_DIR" 2>/dev/null || true)" == "750" ]] || {
            echo "invalid state permissions: expected 0750"
            failures=$((failures + 1))
        }
    fi
    if [[ -f "$CONFIG_FILE" ]]; then
        grep -Fxq 'Current=kamalen' "$CONFIG_FILE" || {
            echo "invalid activation drop-in: $CONFIG_FILE"
            failures=$((failures + 1))
        }
    else
        echo "Theme is installed but not activated."
    fi
    if [[ $failures -eq 0 ]]; then
        echo "Kamalen SDDM installation verified."
    fi
    return "$failures"
}

uninstall_theme() {
    if $DRY_RUN; then
        echo "dry-run: remove $THEME_DIR, $STATE_DIR, $SYNC_BIN, and $CONFIG_FILE"
        return 0
    fi
    run_privileged rm -rf "$THEME_DIR" "$STATE_DIR"
    run_privileged rm -f "$SYNC_BIN" "$CONFIG_FILE"
    echo "Kamalen SDDM files removed. Other SDDM themes and configuration were preserved."
}

case "$COMMAND" in
    install) install_theme ;;
    verify) verify_theme ;;
    uninstall) uninstall_theme ;;
esac

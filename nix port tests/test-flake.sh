#!/usr/bin/env bash
# Test script for Kamalen Shell NixOS port

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

log() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; }
error() { echo -e "${RED}[✗]${RESET} $*"; }
info() { echo -e "${BLUE}[i]${RESET} $*"; }

cd "$FLAKE_DIR"

info "Testing Kamalen Shell NixOS port..."
echo ""

# 1. Check flake validity
info "Checking flake validity..."
if nix flake check --no-build 2>&1 | tail -20; then
    log "Flake check passed"
else
    error "Flake check failed"
    exit 1
fi
echo ""

# 2. Show available outputs
info "Available flake outputs:"
nix flake show --json 2>/dev/null | jq -r '.packages."x86_64-linux" | keys[]' 2>/dev/null | head -20 || nix flake show 2>&1 | head -30
echo ""

# 3. Build devShell
info "Building devShell..."
if nix build .#devShells.x86_64-linux.default --no-link 2>&1 | tail -10; then
    log "devShell builds successfully"
else
    warn "devShell build failed (expected if hashes are placeholder)"
fi
echo ""

# 4. Build individual packages
PACKAGES=(
    "mango-ext"
    "awww"
    "mpvpaper"
    "rmpc"
    "tiramisu"
    "gpu-screen-recorder"
    "pokemon-colorscripts"
    "kamalen-python"
)

info "Building packages (will fail with placeholder hashes)..."
for pkg in "${PACKAGES[@]}"; do
    info "Building $pkg..."
    if nix build ".#checks.x86_64-linux.$pkg" --no-link 2>&1 | tail -5; then
        log "$pkg builds"
    else
        warn "$pkg failed (expected with placeholder hashes)"
    fi
done
echo ""

# 5. Check NixOS module
info "Checking NixOS module..."
if nix eval --raw ".#nixosModules.kamalen-shell" --apply 'builtins.hasAttr "options"' 2>/dev/null; then
    log "NixOS module has options"
else
    warn "NixOS module check failed"
fi
echo ""

# 6. Check Home Manager module
info "Checking Home Manager module..."
if nix eval --raw ".#homeManagerModules.kamalen-shell" --apply 'builtins.hasAttr "options"' 2>/dev/null; then
    log "Home Manager module has options"
else
    warn "Home Manager module check failed"
fi
echo ""

# 7. Show module options
info "Kamalen Shell NixOS options:"
nix eval --json ".#nixosModules.kamalen-shell.options.kamalen-shell" 2>/dev/null | jq -r 'keys[]' 2>/dev/null | head -20 || true
echo ""

info "Kamalen Shell Home Manager options:"
nix eval --json ".#homeManagerModules.kamalen-shell.options.kamalen-shell" 2>/dev/null | jq -r 'keys[]' 2>/dev/null | head -20 || true
echo ""

# 8. Test NixOS configuration build (dry-run)
info "Testing NixOS configuration (dry-run)..."
if nix build ".#nixosConfigurations.kamalen-test.config.system.build.toplevel" --dry-run 2>&1 | tail -10; then
    log "NixOS config evaluates"
else
    warn "NixOS config evaluation failed (expected without real hashes)"
fi
echo ""

# 9. Test Home Manager configuration build (dry-run)
info "Testing Home Manager configuration (dry-run)..."
if nix build ".#homeConfigurations.geko.activationPackage" --dry-run 2>&1 | tail -10; then
    log "Home Manager config evaluates"
else
    warn "Home Manager config evaluation failed (expected without real hashes)"
fi
echo ""

log "Test script completed!"
echo ""
info "Next steps:"
echo "  1. Update all SHA256 hashes in pkgs/*/default.nix"
echo "  2. Run: nix flake check"
echo "  3. Test in VM: nix build .#nixosConfigurations.kamalen-test.config.system.build.vm"
echo "  4. Deploy to real hardware"
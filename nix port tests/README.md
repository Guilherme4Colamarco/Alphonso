# Kamalen Shell - NixOS Port Tests

This directory contains the NixOS port of Kamalen Shell, a dynamic Wayland desktop environment.

## Structure

```
nix port tests/
├── flake.nix                    # Main flake entry point
├── pkgs/                        # Custom package derivations
│   ├── mango-ext/              # Enhanced MangoWM compositor
│   ├── awww/                   # Wayland wallpaper daemon
│   ├── mpvpaper/               # Video wallpaper utility
│   ├── rmpc/                   # Rust MPD TUI client
│   ├── tiramisu/               # Screenshot tool
│   ├── gpu-screen-recorder/    # GPU screen recorder
│   ├── pokemon-colorscripts/   # Pokemon terminal art
│   └── kamalen-python/         # Python utilities (iris, mango_config, etc.)
├── modules/
│   ├── nixos/                  # NixOS system modules
│   │   └── default.nix         # System-level: PAM, services, window manager
│   └── home-manager/           # Home-manager user modules
│       └── default.nix         # User-level: dotfiles, services, packages
├── hosts/
│   ├── configuration.nix       # NixOS system configuration
│   └── home.nix                # Home-manager user configuration
├── lib/
│   └── helpers.nix             # Helper functions
└── README.md                   # This file
```

## Quick Start

### 1. Test the flake

```bash
cd /home/geko/kamalen-shell/"nix port tests"

# Check flake validity
nix flake check

# Build all packages
nix build .#checks.x86_64-linux.mango-ext
nix build .#checks.x86_64-linux.awww
nix build .#checks.x86_64-linux.mpvpaper
nix build .#checks.x86_64-linux.rmpc
nix build .#checks.x86_64-linux.tiramisu
nix build .#checks.x86_64-linux.gpu-screen-recorder
nix build .#checks.x86_64-linux.pokemon-colorscripts
nix build .#checks.x86_64-linux.kamalen-python

# Enter dev shell
nix develop
```

### 2. Test NixOS configuration (in VM)

```bash
# Build VM
nix build .#nixosConfigurations.kamalen-test.config.system.build.vm

# Run VM
./result/bin/run-*-vm
```

### 3. Test Home Manager (standalone)

```bash
# Build home configuration
nix build .#homeConfigurations.geko.activationPackage

# Activate (run as user)
./result/activate
```

### 4. Deploy to existing NixOS system

```bash
# Add to your flake.nix
{
  inputs.kamalen-shell.url = "github:Guilherme4Colamarco/kamalen-shell";
  inputs.kamalen-shell.inputs.nixpkgs.follows = "nixpkgs";
}

# Use modules
{ config, inputs, ... }:
{
  imports = [ inputs.kamalen-shell.nixosModules.kamalen-shell ];
  kamalen-shell.enable = true;
  kamalen-shell.user = "your-user";
}
```

## Package Status

| Package | Status | Notes |
|---------|--------|-------|
| mango-ext | 🔄 WIP | Needs wlroots 0.19, scenefx |
| awww | 🔄 WIP | Simple Makefile build |
| mpvpaper | 🔄 WIP | Meson build |
| rmpc | 🔄 WIP | Cargo build |
| tiramisu | 🔄 WIP | Meson build |
| gpu-screen-recorder | 🔄 WIP | Meson build, many deps |
| pokemon-colorscripts | 🔄 WIP | Simple Makefile |
| kamalen-python | ✅ Ready | Python scripts bundled |

## TODO: Update SHA256 Hashes

All packages currently have placeholder SHA256 hashes. Update them:

```bash
# For GitHub sources
nix-prefetch-github --owner ernestoCruz05 --repo mango-ext --rev main

# For GitLab sources
nix-prefetch-gitlab --owner phoneybadner --repo pokemon-colorscripts --rev main

# For Cargo packages
nix-prefetch-cargo --url https://github.com/mierak/rmpc --rev v0.15.0
```

## Architecture

### System Layer (NixOS Module)
- PAM configuration for lockscreen
- Seat management (seatd)
- PipeWire/WirePlumber audio
- NetworkManager, Bluetooth
- MPD system service (optional)
- Window manager integration

### User Layer (Home Manager)
- Dotfiles deployment (symlinks to repo)
- Systemd user services:
  - quickshell
  - awww (wallpaper daemon)
  - mpvpaper (video wallpapers)
  - tiramisu (notifications)
  - mpd + mpd-mpris
  - kamalen-dbus-notifier
  - kamalen-wallpaper-pregen
  - kamalen-wallpaper-apply
- Shell configuration (Fish + Starship)
- Package management

### Development Layer (DevShell)
- All build dependencies
- Source packages for hacking
- Environment variables set

## Key Differences from Arch install.sh

| Aspect | Arch install.sh | NixOS Port |
|--------|-----------------|------------|
| Package management | pacman + AUR + manual builds | Nix packages + overlay |
| Config deployment | Symlinks via bash script | home-manager declarative |
| Services | systemctl --user manual | systemd.user.services declarative |
| PAM | Manual /etc/pam.d/lockscreen | security.pam.services.lockscreen |
| Window manager | Manual mango-ext build | nixosModules + package |
| Reproducibility | Partial | Full (flake.lock) |
| Rollback | Manual backup restore | nixos-rebuild switch --rollback |

## Testing Checklist

- [ ] All packages build successfully
- [ ] DevShell enters correctly
- [ ] NixOS VM boots to mango-ext
- [ ] QuickShell starts and shows bar
- [ ] Wallpaper daemon works
- [ ] Color extraction (iris.py) works
- [ ] MangoWM config CLI works
- [ ] Notifications appear
- [ ] Lockscreen PAM works
- [ ] MPD + mpd-mpris works
- [ ] Video wallpapers play
- [ ] Home-manager activation works

## Contributing

1. Update SHA256 hashes for all packages
2. Test on actual NixOS hardware
3. Submit missing packages to nixpkgs upstream
4. Add more configuration options
5. Document any hardware-specific quirks
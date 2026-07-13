# Kamalen Shell - NixOS Port

NixOS port of Kamalen Shell, a dynamic Wayland desktop environment built on mango-ext (MangoWM) + QuickShell.

> **Status: experimental and incomplete.** Several derivations still use `lib.fakeHash`; builds, activation, and deployment are not reproducible or supported until every placeholder hash is replaced and the target host is adapted.

## Structure

```
nix port tests/
├── flake.nix                    # Main flake entry point
├── pkgs/                        # Custom package derivations
│   ├── mango-ext/              # Enhanced MangoWM compositor
│   ├── awww/                   # Wayland wallpaper daemon
│   ├── mpvpaper/               # Video wallpaper utility
│   ├── rmpc/                   # Rust MPD TUI client
│   ├── tiramisu/               # Notification daemon
│   ├── gpu-screen-recorder/    # GPU screen recorder
│   ├── pokemon-colorscripts/   # Pokemon terminal art
│   └── kamalen-python/         # Python utilities (iris, mango_config, etc.)
├── modules/
│   ├── nixos/                  # NixOS system module
│   │   └── default.nix         # System-level: PAM, PipeWire, seatd, fonts, etc.
│   └── home-manager/           # Home-manager user module
│       └── default.nix         # User-level: dotfiles, services, packages, shell
├── hosts/
│   ├── configuration.nix       # NixOS system configuration (test VM)
│   ├── hardware-configuration.nix  # QEMU/KVM hardware config (replace on real HW)
│   └── home.nix                # Home-manager user configuration
├── lib/
│   ├── default.nix             # Lib entry point
│   └── helpers.nix             # Helper functions
├── README.md                   # This file
└── test-flake.sh               # Test script
```

## Architecture

### Overlay-based package access

All custom packages are available via a flake overlay. Inside any module,
they're accessible as `pkgs.mango-ext`, `pkgs.awww`, etc. — no need to pass
`customPackages` as a special argument.

### System vs User separation

| Layer | Module | Responsibilities |
|-------|--------|-----------------|
| System | `modules/nixos/` | PAM, PipeWire, seatd, graphics, fonts, D-Bus, polkit, NetworkManager, Bluetooth |
| User | `modules/home-manager/` | Dotfiles deployment, systemd user services, packages, shell config |

User services (quickshell, awww, mpvpaper, tiramisu, MPD) are defined only in
the home-manager module to avoid duplication with the NixOS module.

## Evaluation

### 1. Check flake validity

```bash
cd "$(git rev-parse --show-toplevel)/nix port tests"
nix flake check --no-build
```

## After replacing hashes and validating locally

The following commands are not a quick-start path. Run them only after replacing all placeholder hashes and adapting the host configuration for your machine.

### Build individual packages

```bash
nix build .#mango-ext
nix build .#awww
nix build .#mpvpaper
nix build .#rmpc
nix build .#tiramisu
nix build .#gpu-screen-recorder
nix build .#pokemon-colorscripts
nix build .#kamalen-python
```

> **Note:** All packages use `lib.fakeHash` for source hashes. When you first
> build, Nix will fail and print the correct hash. Replace `lib.fakeHash` with
> the reported hash in each `pkgs/*/default.nix`.

### Enter dev shell

```bash
nix develop
```

### Test NixOS configuration in a VM

```bash
# Build VM
nix build .#nixosConfigurations.kamalen-test.config.system.build.vm

# Run VM
./result/bin/run-*-vm
```

### Test Home Manager

```bash
# Build home configuration
nix build .#homeConfigurations.geko.activationPackage

# Activate (run as user)
./result/activate
```

### Example integration — requires adaptation

`hosts/home.nix` includes user- and machine-specific paths. It is an example for local development, not a generic configuration to copy unchanged.

Add to your flake inputs:
```nix
inputs.kamalen-shell.url = "github:Guilherme4Colamarco/kamalen-shell";
inputs.kamalen-shell.inputs.nixpkgs.follows = "nixpkgs";
```

Use in your NixOS config:
```nix
{ config, inputs, ... }:
{
  imports = [ inputs.kamalen-shell.nixosModules.kamalen-shell ];

  # Apply the overlay so custom packages are available
  nixpkgs.overlays = [ inputs.kamalen-shell.overlays.default ];

  kamalen-shell = {
    enable = true;
    user = "your-user";
    windowManager.enable = true;
    # ...
  };
}
```

## Package Status

| Package | Status | Notes |
|---------|--------|-------|
| mango-ext | WIP | Needs wlroots, scenefx (may require nixpkgs-unstable) |
| awww | WIP | Simple Makefile build |
| mpvpaper | WIP | Meson build |
| rmpc | WIP | Cargo build (`cargoHash`) |
| tiramisu | WIP | Meson build |
| gpu-screen-recorder | WIP | Meson build, many deps |
| pokemon-colorscripts | WIP | Simple script copy |
| kamalen-python | Partial | Python scripts bundled; not validated in a complete deployment |

## TODO: Update Hashes

All packages use `lib.fakeHash` as a placeholder. To get the real hash:

```bash
# Method 1: Just build and read the error
nix build .#mango-ext
# Nix will print: got: sha256-<real-hash>
# Replace lib.fakeHash with the printed hash.

# Method 2: Use nix-prefetch
nix run nixpkgs#nix-prefetch -- --fetcher fetchFromGitHub --owner ernestoCruz05 --repo mango-ext --rev main

# For Cargo packages (rmpc):
# The cargoHash is separate — build will report it.
```

## Key Differences from Arch install.sh

| Aspect | Arch install.sh | NixOS Port |
|--------|-----------------|------------|
| Package management | pacman + AUR + manual builds | Nix packages + overlay |
| Config deployment | Symlinks via bash script | home-manager declarative (xdg.configFile) |
| Services | systemctl --user manual | systemd.user.services declarative |
| PAM | Manual /etc/pam.d/lockscreen | security.pam.services |
| Window manager | Manual mango-ext build | nixosModules + package |
| Reproducibility | Partial | Intended; blocked by placeholder hashes |
| Rollback | Manual backup restore | Available after a successful declarative deployment |

## Criteria for a usable port

- [ ] All packages build with real hashes
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

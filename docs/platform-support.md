# Platform support

Kamalen Shell is a Wayland desktop configuration with compositor and session dependencies that differ substantially across distributions. The support levels below describe what the installer can safely automate today; they do not guarantee a complete graphical session on every hardware or desktop-manager combination.

## Supported installers

| Family | Distributions | Entry point | Status | Notes |
| --- | --- | --- | --- | --- |
| Arch | Arch Linux, EndeavourOS, CachyOS | `install.sh` | Primary | Uses pacman and, where available, an AUR helper. |
| Debian | Debian 12/13, Ubuntu 24.04+, Linux Mint, Zorin OS | `install-debian.sh` | Supported | Installs native dependencies and offers source-build stages. Confirm that a Wayland-capable login session is available before use. |
| Pacman derivatives | Manjaro, BigLinux, Garuda | `install-pacman.sh` | Beta | Native-repository dependencies only. AUR is deliberately disabled because repository cadence and ABI compatibility differ from Arch. Create a snapshot and perform a full system update first. |
| Fedora | Current Fedora releases | `install-fedora.sh` | Experimental | Installs official-repository baseline dependencies. It does not add Terra, COPR, or other third-party repositories; mango-ext and several optional tools remain manual/source-build work. |
| openSUSE | Tumbleweed and Leap-family IDs | `install-opensuse.sh` | Experimental | Installs native baseline dependencies only. Quickshell/mpvpaper OBS repositories and mango-ext builds require explicit user review. |
| Void | Void Linux | `install-void.sh` | Configuration-only | Safe backup/symlink, unlink, verification, and dry-run flow. Dependency and service setup remain manual because Void uses XBPS and runit. |

All experimental entrypoints accept `--dry-run`, `deps`, `configs`, `sddm`, `unlink`, `verify`, and `status`. PAM setup is skipped unless `--with-pam` is given after reviewing the distribution's PAM policy.

## Optional SDDM integration

The shared `sddm` command is distribution-neutral. It only proceeds when SDDM is already installed; it never installs or replaces a display manager. A dry run is non-mutating and non-interactive. A real installation copies the root-owned theme, prepares the user-readable synchronized state, installs `kamalen-sddm-sync`, and asks before creating its own activation drop-in. It does not restart SDDM, so changes appear after the next logout or boot.

```bash
./install.sh --dry-run sddm
./install.sh sddm
scripts/install/sddm-theme.sh verify
scripts/install/sddm-theme.sh uninstall
```

Uninstall removes only the Kamalen theme, its state, sync command, and `99-kamalen-theme.conf`. Other themes and SDDM configuration remain untouched.

## DIY and declarative distributions

### Gentoo

Gentoo does not have an imperative installer yet. Use the repository as configuration source only after selecting your init system and validating the required Qt6, Wayland, PipeWire, PAM, wlroots, and compositor USE flags. An automated `emerge` script would hide too much profile- and hardware-specific behavior to be safe.

### NixOS

NixOS support is declarative and remains experimental in [`nix port tests/`](<../nix port tests/README.md>). The flake currently contains placeholder hashes and example host paths, so evaluate it before attempting a build and adapt the host files to your user and hardware.

## Choosing an installer

```bash
# Arch family
./install.sh --dry-run

# Debian, Ubuntu, Mint, or Zorin
./install-debian.sh --dry-run

# Manjaro, BigLinux, or Garuda
./install-pacman.sh --dry-run

# Fedora
./install-fedora.sh --dry-run

# openSUSE
./install-opensuse.sh --dry-run

# Void configuration only
./install-void.sh --dry-run configs
```

Before a non-dry run, take a snapshot or backup and read the output. Do not mix repositories from different distribution families, and do not run an AUR package manager against Manjaro or BigLinux unless you have explicitly reviewed compatibility.

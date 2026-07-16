# Kamalen Shell

<p align="center">
  <strong>A wallpaper-adaptive Wayland shell for MangoWM.</strong><br>
  Quickshell surfaces, modular compositor settings, and a desktop that changes character with its wallpaper.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Guilherme4Colamarco/kamalen-shell?style=for-the-badge&label=license&color=9b8afb&labelColor=292337" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/session-Wayland-76c7c0?style=for-the-badge&labelColor=292337" alt="Wayland session">
  <img src="https://img.shields.io/badge/shell-Quickshell-b4befe?style=for-the-badge&labelColor=292337" alt="Quickshell">
  <a href="README.pt-BR.md"><img src="https://img.shields.io/badge/readme-pt--BR-f9e2af?style=for-the-badge&labelColor=292337" alt="Leia em português brasileiro"></a>
</p>

<p align="center">
  <img src="docs/assets/screenshots/desktop-overview.webp) | ![Local wallpaper carousel](docs/assets/screenshots/wallpaper-local-carousel.webp" width="880">
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#everyday-use">Shortcuts</a> ·
  <a href="#screenshots">Screenshots</a> ·
  <a href="#repository-map">Documentation</a>
</p>

> [!NOTE]
> **Adaptive by default.** Iris extracts the wallpaper palette and applies it across the shell, MangoWM, GTK, Neovim, Kitty, and Starship — without losing the selected visual skin.

> Arch Linux is the primary target. Debian 12/13 and Ubuntu 24.04+ use a separate installer; the NixOS port is experimental.

## Highlights

| Surface | What it brings |
| --- | --- |
| **Shell** | Reactive Quickshell bar, dashboard, launcher, notifications, lock screen, and wallpaper picker. |
| **Appearance** | Four adaptive skins — Kamalen, Commonality, Aqua 2009, and Skeuos Workshop — plus wallpaper-driven colors. |
| **Control** | A standalone Settings window for Appearance, Monitors, Mango, Binds, and Rules; monitor changes use confirm/revert previews. |
| **Flow** | Keyboard-first layers with outside dismissal, shortcut help, global scale, and optional Vim navigation. |
| **Configuration** | Modular MangoWM files under `.config/mango/conf.d/`, with a test suite covering the installer, configuration bridge, QML integration, lock screen, and wallpaper providers. |

## Requirements

- Arch Linux or a derivative with a Wayland session, or Debian 12/13 or Ubuntu 24.04+ with the Debian installer.
- `mango-ext`/MangoWM, Quickshell, and the dependencies installed by the installer.
- A backup of any local configuration you do not want the installer to replace.

## Install

Review the planned changes before installing:

```bash
git clone https://github.com/Guilherme4Colamarco/kamalen-shell.git
cd kamalen-shell
./install.sh --dry-run
./install.sh
./install.sh verify
```

`install.sh` backs up existing configuration and links the repository's `.config/` into `~/.config/`. As a result, repository edits are live configuration edits.

For Debian/Ubuntu, preview and verify through the dedicated installer:

```bash
./install-debian.sh --dry-run
./install-debian.sh
./install-debian.sh verify
```

### Optional SDDM theme

If SDDM is already installed, the regular/config installation offers the Kamalen login theme. It mirrors the current wallpaper and Iris palette using static, optimized assets. Installation does not activate the theme unless confirmed and never restarts SDDM during the active session.

```bash
./install.sh --dry-run sddm
./install.sh sddm
kamalen-sddm-sync
scripts/install/sddm-theme.sh verify
scripts/install/sddm-theme.sh uninstall
```

The theme lives under `/usr/share/sddm/themes/kamalen`; synchronized user data is isolated in `/var/lib/kamalen-sddm`. Activation uses only `/etc/sddm.conf.d/99-kamalen-theme.conf`, so uninstalling it reveals the previously configured theme without editing its files.

## Everyday use

| Shortcut | Action |
| --- | --- |
| `Super + D` | Open the launcher |
| `Super + A` | Open the Quick/Media/System dashboard |
| `Super + ,` | Open Settings |
| `Super + W` | Open the wallpaper picker |
| `Super + V` | Open clipboard history |
| `Super + Shift + /` | Show the shortcut reference |
| `Super + X` | Lock the session |
| `Super + Enter` | Open Kitty |
| `Super + Space` | Cycle window layouts |
| `Super + Q` | Close the focused window |

More bindings are available in `.config/mango/conf.d/binds.conf`.

The wallpaper picker includes Local, Wallhaven, and Live tabs. The Live tab filters DesktopHut results by title, accepts only HTTPS downloads from its allowed `/files/` host path, and shows the original source page before applying a wallpaper.

## Screenshots

<p align="center"><sub>One color pipeline, four surfaces — the palette stays responsive while the material changes.</sub></p>

| Desktop overview | Local wallpaper browsing |
| --- | --- |
| ![Kamalen desktop overview](docs/assets/screenshots/desktop-overview.webp) | ![Local wallpaper carousel](docs/assets/screenshots/wallpaper-local-carousel.webp) |

| Appearance and materials | Monitor configuration |
| --- | --- |
| ![Appearance settings](docs/assets/screenshots/settings-appearance.webp) | ![Monitor settings](docs/assets/screenshots/settings-monitors.webp) |

| MangoWM controls | Wallpaper discovery |
| --- | --- |
| ![Mango settings](docs/assets/screenshots/settings-mango.webp) | ![Wallpaper picker](docs/assets/screenshots/wallpaper-picker.webp) |

<p align="center">See the <a href="docs/screenshots.md">full screenshot gallery</a> for context.</p>

## Repository map

```text
.config/                 Live desktop configuration
  mango/                 MangoWM configuration and Python bridge
  quickshell/            QML shell, shared state, components, and helpers
  scripts/               User-facing helper scripts
docs/                    Architecture, specifications, plans, and reviews
tests/                   Python regression and integration checks
sddm/                    Optional Qt 6 login theme
scripts/                 Cross-distribution installation and SDDM sync helpers
nix port tests/          Experimental NixOS/Home Manager flake
wallpapers/              Bundled wallpaper collection
```

- [Architecture](docs/architecture.md)
- [Current shell guide](docs/current-shell.md)
- [Roadmap](docs/TODO.md)
- [Screenshot gallery](docs/screenshots.md)
- [Platform support](docs/platform-support.md)
- [Contributing](CONTRIBUTING.md)
- [Historical specifications and plans](docs/archive/)
- [Historical technical reviews](docs/archive/reviews/)
- [Experimental NixOS port](<nix port tests/README.md>)

> [!TIP]
> Start with the [current shell guide](docs/current-shell.md) for daily use, then
> use [architecture](docs/architecture.md) when changing the live configuration.

## Development and verification

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
qmllint -I .config/quickshell .config/quickshell/LiveWallpaperTab.qml
./install.sh verify
```

After QML changes, restart Quickshell from the active session:

```bash
pkill quickshell
sleep 1
nohup quickshell &>/dev/null &
```

## Credits and provenance

Kamalen Shell is an integration project; it does not claim ownership of the technologies or projects it configures.

- [MangoWM](https://github.com/mangowm/mango) is the compositor foundation.
- [mango-ext](https://github.com/ernestoCruz05/mango-ext) is the MangoWM fork used by this configuration.
- [Quickshell](https://github.com/outfoxxed/quickshell) provides the Qt Modeling Language (QML) shell runtime.
- [Catppuccin](https://github.com/catppuccin/catppuccin) informs the base palette used by the color system.
- [Wallhaven](https://wallhaven.cc/) and [DesktopHut](https://www.desktophut.com/) are optional wallpaper discovery sources; their content remains subject to their respective terms and creator attribution.
- The NixOS/Home Manager work is an experimental port of this repository, maintained in `nix port tests/`.
- The SDDM synchronization boundary was inspired by [iNiR's Pixel SDDM sync helper](https://github.com/snowarch/iNiR/blob/main/scripts/sddm/sync-pixel-sddm.py); Kamalen uses its own implementation and keeps greeter code root-owned.
- Dynamic Island patterns were studied from [Dynamic-island-for-arch](https://github.com/patheonsceo/Dynamic-island-for-arch), [Tide-island](https://github.com/enhaoswen/Tide-island), [quickshell-DynamicIsland](https://github.com/HandsomeMJZ/quickshell-DynamicIsland), [Dynamic-Bar](https://github.com/turbogoomba/Dynamic-Bar), and [dynamic-island-bar](https://github.com/SergioM26/dynamic-island-bar). They are design and architecture references, not copied code; the retained notes are in [docs/archive/quickshell](docs/archive/quickshell/).
- The broader Linux customization community, including r/unixporn, has influenced the visual language and workflow ideas.

## License

Kamalen Shell is distributed under the [MIT License](LICENSE). See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution terms. Third-party projects, wallpapers, fonts, and downloaded media retain their own licenses and terms.

# Kamalen Shell

[Português (pt-BR)](README.pt-BR.md)

Kamalen Shell is a Wayland desktop configuration for MangoWM/mango-ext. It pairs a Quickshell interface with a wallpaper-driven color pipeline and a modular MangoWM configuration.

> Arch Linux is the primary target. Debian 12/13 and Ubuntu 24.04+ use a separate installer; the NixOS port is experimental.

## Highlights

- Reactive Quickshell bar, dashboard, launcher, notifications, lock screen, and wallpaper picker.
- Iris color pipeline: a wallpaper change updates the shell, MangoWM borders, GTK, Neovim, Kitty, and Starship.
- Modular MangoWM configuration under `.config/mango/conf.d/`.
- Local video wallpapers through `mpvpaper`, plus an optional DesktopHut browser with source links.
- A test suite for installer behavior, Mango configuration, QML integration, lock-screen safety, and wallpaper providers.

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
| `Super + W` | Open the wallpaper picker |
| `Super + X` | Lock the session |
| `Super + Enter` | Open Kitty |
| `Super + Space` | Cycle window layouts |
| `Super + Q` | Close the focused window |

More bindings are available in `.config/mango/conf.d/binds.conf`.

The wallpaper picker includes Local, Wallhaven, and Live tabs. The Live tab filters DesktopHut results by title, accepts only HTTPS downloads from its allowed `/files/` host path, and shows the original source page before applying a wallpaper.

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
- [Platform support](docs/platform-support.md)
- [Contributing](CONTRIBUTING.md)
- [Historical specifications and plans](docs/archive/)
- [Historical technical reviews](docs/archive/reviews/)
- [Experimental NixOS port](<nix port tests/README.md>)

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

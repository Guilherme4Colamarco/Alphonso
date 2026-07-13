# Architecture

Kamalen Shell is a local Wayland desktop configuration. It has no application server: Quickshell QML processes, MangoWM, and a small set of Python/shell helpers communicate through local commands, files, and IPC.

## Runtime layers

| Layer | Location | Responsibility |
| --- | --- | --- |
| Window manager | `.config/mango/` | MangoWM options, bindings, rules, monitors, and autostart. |
| Desktop shell | `.config/quickshell/` | Bar, dashboard, launcher, wallpapers, notifications, lock screen, and global QML state. |
| Shared visual state | `Colors.qml`, `UIState.qml`, `Animations.qml` | Palette, persisted presentation settings, and animation profile values. |
| Integration helpers | Python and shell helpers | Mango configuration bridge, wallpaper palette extraction, notification stream, and online wallpaper providers. |
| Verification | `tests/` | Regression tests for installer behavior, configuration layout, QML invariants, and security-sensitive flows. |

## Data flows

```text
Wallpaper selection
  -> iris.py extracts a palette
  -> Colors/UIState update Quickshell
  -> MangoConfig writes modular MangoWM settings
  -> GTK, Neovim, Kitty, and Starship receive generated colors

Dashboard control
  -> QML singleton or MangoConfig
  -> mmsg/mango_config.py
  -> active MangoWM configuration
```

## Configuration boundaries

- `.config/mango/config.conf` is source-only. Category files live in `.config/mango/conf.d/`.
- `.config/quickshell/qmldir` registers QML singletons and reusable components.
- Files under `state/` are generated runtime data and are intentionally ignored by Git.
- `nix port tests/` is a separate experimental flake; it does not replace the Arch-oriented installer.

## Documentation

- `docs/archive/specs/` records historical requirements.
- `docs/archive/plans/` records completed or superseded plans.
- `docs/archive/reviews/` contains point-in-time review evidence.
- `docs/archive/quickshell/` preserves Dynamic Island research and design notes.

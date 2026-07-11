# AGENTS.md — Kamalen Shell

## What this repo is

MangoWM rice/dotfiles for Arch Linux. Quickshell (QML) desktop shell with bar, dashboard, launcher, wallpapers, notifications, lockscreen, and MangoWM configuration UI. No backend server — everything runs locally as QML processes on Wayland.

## Repo ↔ filesystem relationship

`.config/` in the repo is **symlinked** to `~/.config/` via `install.sh`. Edits to repo files ARE the live config. Don't create files expecting them to be "deployed" — they're already live.

```
~/.config/quickshell/ → /home/geko/kamalen-shell/.config/quickshell/
~/.config/mango/      → /home/geko/kamalen-shell/.config/mango/
```

## Architecture

### Singletons (registered in `qmldir`, importable by name)

| Singleton | Role |
|-----------|------|
| `Colors` | Catppuccin palette, `a(c,o)` alpha helper, `toHex()`, dark/light mode |
| `UIState` | Global shell state: dark mode, blur profile, bar mode, border radius, notifications, dropdown toggles |
| `Animations` | Duration/easing constants, profile cycling (bubbly/calm/snappy/extraslow/none) |
| `L10n` | i18n via `tr(key, fallback)` |
| `MangoConfig` | Reactive MangoWM config properties, `set(key, value)` for live apply |
| `TrayState` | System tray active item tracking |

### IPC patterns

- **MangoWM → Shell**: `inotifywait` watches file touches (`/tmp/qs-*`). External tools trigger shell actions by touching files.
- **Shell → MangoWM**: `mmsg dispatch setoption,<key>,<value>` for live option changes; `reload_config` for binds/rules/monitors.
- **Shell → System**: `Process {}` QML type for running shell commands. Stdout via `SplitParser`.
- **Notifications**: `dbus-notifier.py` runs as persistent process, outputs tab-separated lines to stdout.

### Dashboard tabs (`tabs/`)

Dashboard uses `StackLayout` with 9 tabs: Quick, Display, Media, System, Look, Mango, Binds, Rules, Monitors.

- Tabs receive `helpers` QtObject from Dashboard for shared functions (cycle power mode, blur, etc.)
- `helpers` is evaluated lazily — use `function() { if (helpers) helpers.fn() }` not `helpers ? helpers.fn : function(){}`
- MangoTab uses `MangoConfig.set()` for live MangoWM configuration
- BindsTab, WindowRulesTab and MonitorsTab use `MangoConfig.listDirectives()` / `addDirective()` / `removeDirective()` for MangoWM directive management

### Reusable components (`components/`)

| Component | Purpose |
|-----------|---------|
| `ConfigSection` | Collapsible section with title/icon |
| `ConfigSlider` | Slider, emits `onValueModified(v)` on release (not drag) |
| `ConfigToggle` | Switch, emits `onToggled(c)` |
| `ConfigSpinner` | Cycle through values, emits `onActivated(idx)` |
| `ConfigColorRow` | Color picker, accepts/emits Mango hex strings (`0xRRGGBBAA`) |
| `TileButton` | Dashboard tile button |
| `InfoRow` | Label + value row |
| `SliderRow` | Label + slider row |

## MangoWM config

**Backend**: `mango_config.py` — Python CLI for reading/writing MangoWM config files.

```bash
# Read a value
python3 ~/.config/mango/mango_config.py get focus_conf sloppyfocus

# Write + live apply
python3 ~/.config/mango/mango_config.py set focus_conf sloppyfocus 1

# Batch write + reload
python3 ~/.config/mango/mango_config.py set-module focus_conf '{"sloppyfocus":1,"warpcursor":1}'

# Validate config
python3 ~/.config/mango/mango_config.py validate
```

**Config structure**: `config.conf` only contains `source=conf.d/*.conf`. Each category has its own file in `conf.d/`. Never edit `config.conf` directly.

**Mango key naming**: No underscores in some keys. Check `conf.d/` files for exact names. Boolean values are `0`/`1`, not `true`/`false`.

**QML wrapper**: `MangoConfig` singleton loads values on startup, exposes reactive properties, writes via Python backend, and provides `listDirectives(module, callback)` / `addDirective(module, prefix, value)` / `removeDirective(module, index)` for managing binds, window rules and monitor rules.

## CRITICAL: Shell process management

**NEVER start a quickshell process without first killing any existing instance.** Always follow this exact sequence:

```bash
pkill quickshell       # kill existing instance first
sleep 1                # wait for cleanup
nohup quickshell &>/dev/null &  # then start fresh
```

Multiple instances conflict on the Wayland session and cause corruption. Never skip the kill step.

## QuickShell lifecycle

```bash
# Restart (kills and starts fresh)
pkill quickshell && sleep 1 && nohup quickshell &>/dev/null &

# Dry-run validation (blocks if another instance running)
quickshell -p ~/.config/quickshell/shell.qml

# Check logs
tail -50 /run/user/1000/quickshell/by-id/*/log.qslog
```

QuickShell is started by MangoWM via `exec-once=quickshell` in `conf.d/autostart.conf`. It's NOT a systemd service.

## Color pipeline

1. Wallpaper change → `iris.py` extracts dominant color
2. `Colors.applyFromJson()` updates palette with animated transitions
3. `UIState` propagates to blur profile, dark mode, MangoWM border colors
4. `MangoConfig` syncs colors to MangoWM config files
5. GTK, Neovim, Starship are also updated via iris.py

## Critical QML patterns

- **Null-safe `QsWindow`**: Always `QsWindow?.window` — window may be null during init
- **Alpha helper**: `Colors.a(color, opacity)` — use instead of `Qt.rgba()` for consistency
- **Process restart**: Every `Process` needs a `Timer` restart on `onExited` (shell processes crash/restart)
- **Behaviors**: Kamalen style uses `Behavior on` for all animatable properties
- **Border radius**: `UIState.borderRadius` controls global rounding; tiles use `br * 0.875` etc.

## What NOT to touch

- `state/*.json` — generated runtime state, gitignored
- `.config/nvim/lua/colors.lua` — generated by iris.py, gitignored
- `__pycache__/` — Python bytecode, gitignored

## Commit conventions

- Use conventional commits: `feat:`, `fix:`, `refactor:`, `chore:`
- Messages in Portuguese or English (mixed is fine)
- Each logical change = one commit
- Update `CHANGELOG-Bar.md` with Fase number for significant changes
- Always test QuickShell restart after QML changes before committing

## Install/verify

```bash
./install.sh              # Full interactive install
./install.sh --dry-run    # Preview changes
./install.sh verify       # Check installation status
./install.sh unlink       # Remove symlinks, optionally restore backup
```

## Key file paths

| File | Purpose |
|------|---------|
| `shell.qml` | Entry point — instantiates all Variants |
| `UIState.qml` | Global state hub |
| `Colors.qml` | Color palette singleton |
| `MangoConfig.qml` | MangoWM config bridge |
| `Bar.qml` | Main bar (pill/fixed/floating/autohide modes) |
| `Dashboard.qml` | Dashboard with 6 tabs |
| `Launcher.qml` | App launcher |
| `Wallpaper.qml` | Wallpaper picker + video support |
| `iris/iris.py` | Color extraction from wallpaper |
| `mango/mango_config.py` | MangoWM config backend |
| `mango/conf.d/` | Modular MangoWM config files |
| `CHANGELOG-Bar.md` | Change log by phase |

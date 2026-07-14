# AGENTS.md — Kamalen Shell

## Mission and scope

Kamalen Shell is a local Wayland desktop environment built from MangoWM/mango-ext
configuration and a Quickshell QML shell. It provides the bar, dashboard,
standalone settings window, launcher, wallpapers, notifications, lockscreen,
and MangoWM configuration UI. There is no application server: state and IPC are
local QML, Python, shell commands, D-Bus, and MangoWM IPC.

The primary target is Arch Linux. Debian/Ubuntu have a dedicated installer, and
`nix port tests/` is an experimental flake rather than the primary installation
path.

## Live configuration boundary

`install.sh` links this repository's `.config/` into `~/.config/`. Treat source
edits as live desktop edits:

```text
~/.config/quickshell/ -> /home/geko/kamalen-shell/.config/quickshell/
~/.config/mango/      -> /home/geko/kamalen-shell/.config/mango/
```

Before attributing runtime behavior, confirm the active path with:

```bash
readlink -f ~/.config/quickshell
readlink -f ~/.config/mango
```

Do not edit generated runtime state or generated theme output by hand:

- `.config/quickshell/state/*.json`
- `.config/nvim/lua/colors.lua`
- `~/.config/gtk-{3,4}.0/kamalen-*.css`
- `__pycache__/`, caches, thumbnails, or temporary `/tmp/qs-*` files

Change their source (`UIState`, `Colors`, `theme_engine.py`, `gtk_theme.py`, or
the owning backend) and let the normal pipeline regenerate them.

## Architecture map

| Area | Main files | Contract |
| --- | --- | --- |
| Shell entrypoint | `.config/quickshell/shell.qml` | Instantiates singleton-driven shell surfaces and supervised services. |
| Global state | `UIState.qml`, `Colors.qml`, `Animations.qml`, `Metrics.qml`, `Runtime.qml` | Persisted UI state, adaptive palette, animation profiles, scaling, and process helpers. |
| Appearance | `Skins.qml`, `StyleProfiles.qml`, `components/Material*.qml`, `tabs/LookTab.qml` | Skin geometry/materials and optional palette modes; do not hardcode a skin's colors. |
| Dashboard | `Dashboard.qml`, `tabs/QuickTab.qml`, `MediaTab.qml`, `SystemTab.qml` | Transient overlay with exactly Quick, Media, and System. |
| Settings | `SettingsWindow.qml`, `LookTab.qml`, `MonitorsTab.qml`, `MangoTab.qml`, `BindsTab.qml`, `WindowRulesTab.qml` | Normal `FloatingWindow` with Appearance, Monitors, Mango, Binds, and Rules. |
| Mango bridge | `MangoConfig.qml`, `.config/mango/mango_config.py`, `.config/mango/conf.d/` | Transactional MangoWM reads/writes, directive management, and monitor preview. |
| System integrations | `iris/iris.py`, `theme_engine.py`, `gtk_theme.py`, `dbus-notifier.py`, `ipc_bridge.py`, `process_supervisor.py` | Palette, GTK/terminal output, notifications, local IPC, and resilient subprocesses. |
| Tests | `tests/` | Python regression and static QML integration checks. |

`qmldir` is the source of truth for registered QML singletons and reusable
components. Register a new reusable QML type there and add a focused invariant
test when its registration matters to runtime behavior.

## State, color, and material rules

1. Wallpaper selection feeds `iris.py`; `theme_engine.py` resolves the effective
   palette according to `UIState.colorMode` and `colorPreset`.
2. `Colors` updates the shell, then `UIState` updates Mango borders and calls the
   GTK/Neovim/Kitty/Starship generators.
3. `Skins.qml` owns geometry and material tokens. Supported skin IDs are
   `kamalen`, `commonality`, `aqua-2009`, and `skeuos-workshop`.
4. A skin may suggest a color mode/preset but must never silently disable the
   automatic wallpaper-adaptive pipeline.
5. Rich materials are semantic: Skeuos uses wood/paper/metal roles; Aqua uses
   brushed/glass materials. Keep all actual colors palette-derived.
6. GTK root `gtk.css` is an import shim for generated `kamalen-colors.css` and
   `kamalen-material.css`. Preserve user CSS while replacing only Kamalen-managed
   `@define-color` declarations.

Do not add titlebars or docks as part of the skin/material system unless the user
explicitly requests them.

## MangoWM persistence rules

`.config/mango/config.conf` is source-only. Category configuration belongs in
`.config/mango/conf.d/*.conf`; do not add normal options to the root file.

Use the Python backend or `MangoConfig`, never ad-hoc config text mutation from
QML. The durable mutation path is:

```text
write conf.d -> mango -p validation -> Mango reload/apply -> rollback on failure
```

`MangoConfig` queues changes and updates local state only after
`configurationApplied`; surface `configurationFailed` errors in UI code. For
directive lists (binds, rules, monitors), use `listDirectives`, `addDirective`,
and `removeDirective` so updates remain serial and confirmed.

Useful checks:

```bash
python3 .config/mango/mango_config.py validate
mango -p
python3 .config/mango/mango_config.py get focus_conf sloppyfocus
```

Mango booleans are `0`/`1`. Verify exact key spelling in the existing `conf.d`
module before adding an option.

## QML and process conventions

- Use `QsWindow?.window` whenever a QML window can be absent during startup.
- Use `Colors.a(color, opacity)` for color alpha and `Metrics.dp()` / `Metrics.sp()`
  for geometry and text sizing.
- Use `Skins` material/geometry primitives instead of local radius or texture
  guesses.
- Use `Behavior on` for intentional animated visual properties.
- Interactive controls need keyboard focus and accessibility names where relevant.
- Transient layers must close on Escape and outside click where their UX expects
  it; respect `UIState.closeTransientSurfaces()` rather than inventing parallel
  visibility state.
- Long-running `Process` objects must be supervised with `Runtime.supervise()` or
  have an explicit restart timer in `onExited`.
- Do not hardcode `/home/geko` in QML. Use `Quickshell.env("HOME")`.

## Quickshell lifecycle

Never start another Quickshell instance over an existing one. For a deliberate
restart after QML changes, use exactly this sequence:

```bash
pkill quickshell
sleep 1
nohup quickshell &>/dev/null &
```

Then inspect the newest runtime log:

```bash
tail -50 /run/user/$(id -u)/quickshell/by-id/*/log.qslog
```

Quickshell is started by MangoWM `exec-once`; it is not a systemd service. Do not
restart it for Python-only or documentation-only edits unless runtime validation
requires it.

## ECC working agreement

Use Everything Claude Code practices as a compact engineering loop, adapted to
this QML/Python repository:

1. **Orient first.** Check `git status`, the live symlink target, relevant tests,
   and the existing implementation before changing code.
2. **Use the smallest applicable skill.** For bug fixes/refactors, use TDD:
   add a focused reproducer, prove RED, make the minimal change, prove GREEN.
   For substantive changes, follow with the verification loop.
3. **Prefer evidence over assumptions.** Verify browser/API claims against their
   primary source; validate desktop changes through the actual backend or runtime,
   not only static inspection.
4. **Use configured MCPs intentionally.** Run `codex mcp list` when an MCP may
   help. Use NixOS MCP for Nix packages/options, Context7 for current library
   documentation, and Exa for external research. Do not add, remove, publish, or
   reconfigure MCPs without explicit user authorization.
5. **Delegate only when useful and authorized.** Keep one clear owner for edits;
   parallelize independent read-only investigation or review only when the user
   requests agents or the task materially benefits from it.
6. **Keep commits auditable.** Use conventional commits. With TDD, make the RED
   test checkpoint and GREEN fix checkpoint separately. This checkout may be
   sparse, so stage intentionally with `git add --sparse <path>` when required.

Before declaring a code change complete, run the narrow test first, then the
appropriate broader checks:

```bash
python3 -m unittest discover -s tests
qmllint -I .config/quickshell <changed-qml-file>
python3 -m py_compile <changed-python-file>
git diff --check
```

For Mango changes, also run `mango -p`. For changed live QML, do the safe
Quickshell restart and verify the newest log reaches a loaded state. Run
`./install.sh verify` when installer/linking behavior is in scope.

## Safety and repository hygiene

- Preserve unrelated dirty files. Do not reset, checkout, clean, or overwrite
  generated user configuration to obtain a clean tree.
- Avoid destructive system actions and external publishing. Pushing, opening PRs,
  changing credentials, installing packages, or modifying global MCP settings
  requires explicit user direction.
- Treat wallpapers, URLs, and downloaded media as untrusted input. Preserve the
  repository's HTTPS/allowed-host validation in wallpaper providers.
- Keep secrets out of QML, commits, logs, and tests. Use environment variables or
  the existing local configuration boundary.
- Add a `CHANGELOG-Bar.md` phase entry for significant shell-facing changes.

## Useful commands

```bash
# Full repository tests
python3 -m unittest discover -s tests

# Validate Mango configuration
python3 .config/mango/mango_config.py validate && mango -p

# Preview installation without writes
./install.sh --dry-run

# Verify active installation
./install.sh verify
```

## Key paths

| Path | Purpose |
| --- | --- |
| `.config/quickshell/shell.qml` | Shell root and supervised integration processes. |
| `.config/quickshell/UIState.qml` | Persisted UI state, shortcuts, and surface coordination. |
| `.config/quickshell/Colors.qml` | Palette application and downstream theme generation. |
| `.config/quickshell/MangoConfig.qml` | Confirmed/queued MangoWM configuration bridge. |
| `.config/quickshell/SettingsWindow.qml` | Standalone settings application window. |
| `.config/quickshell/Skins.qml` | Skin recipes, geometry, and material roles. |
| `.config/quickshell/gtk_theme.py` | GTK color/material CSS generation and legacy migration. |
| `.config/mango/mango_config.py` | MangoWM configuration backend. |
| `.config/mango/conf.d/` | Modular MangoWM configuration. |
| `tests/` | Regression suite. |
| `docs/architecture.md` | Longer-lived architecture overview. |

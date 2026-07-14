# Current shell guide

Kamalen Shell is a local Quickshell interface for MangoWM/mango-ext. The shell
is intentionally split into a fast transient layer for daily controls and a
normal window for configuration that benefits from space, persistence, and
keyboard navigation.

## Daily surfaces

| Surface | Open with | Use it for |
| --- | --- | --- |
| Launcher | `Super + D` | Find and launch applications. |
| Dashboard | `Super + A` | Quick controls, media, system status, notifications, and the shortcut reference. |
| Settings | `Super + ,` | Appearance, monitors, MangoWM options, bindings, and window rules. |
| Wallpaper picker | `Super + W` | Local, Wallhaven, and live wallpapers. |
| Media | `Super + Shift + M` | Playback and visualizer controls. |
| Clipboard | `Super + V` | Clipboard history. |
| Shortcut help | `Super + Shift + /` | Global keyboard shortcut reference. |

Transient overlays close with `Esc` and normally close when clicking outside.
Opening one transient surface closes the others, so layers do not accumulate.

## Dashboard and Settings

The Dashboard contains exactly three tabs: **Quick**, **Media**, and **System**.
Use `1`, `2`, `3`, arrows, or optional Vim navigation to move between them.

Settings is a normal `FloatingWindow` with five sections:

1. **Appearance** — skin, color source, motion, blur, global interface scale,
   and optional Vim navigation.
2. **Monitors** — detected output diagram, drag positioning, resolution,
   refresh rate, scale, and a timed preview that can be confirmed or reverted.
3. **Mango** — compositor options such as gaps, blur, opacity, focus, and
   animations.
4. **Binds** — editable MangoWM key, mouse, axis, and gesture bindings.
5. **Rules** — editable window rules.

Settings shortcuts are `Ctrl+1…5`, `Ctrl+Tab`, `Ctrl+Shift+Tab`, `Ctrl+W`, and
`Esc`. When Vim navigation is enabled, `h/j/k/l`, `g`, and `G` move between
sections.

## Appearance system

The wallpaper is still the primary color source. Iris extracts a palette and the
theme engine resolves it in one of three modes:

| Mode | Behavior |
| --- | --- |
| Automatic | Wallpaper-derived colors drive the entire interface. |
| Adaptive preset | A preset supplies neutral structure while the wallpaper supplies accents. |
| Fixed preset | The selected preset controls the palette. |

Changing a skin never silently changes the color mode. The available skins are:

| Skin | Visual language | Optional suggestion |
| --- | --- | --- |
| Kamalen | Rounded, light, and translucent. | Automatic / Catppuccin |
| Commonality | Compact CDE/Motif bevels and grid texture. | Adaptive Solarized |
| Aqua 2009 | Brushed metal, glass, and glossy controls. | Adaptive Nord |
| Skeuos Workshop | Semantic wood frame, paper content, and metal controls. | Adaptive Gruvbox |

The same effective palette feeds Quickshell, MangoWM borders, GTK 3/4, Neovim,
Kitty, Starship, and the optional SDDM synchronizer. GTK material CSS does not
create titlebars or docks.

## Bar and workspace controls

The bar supports `pill` (default), `floating`, `autohide`, and `fixed` modes.
Its border follows the same adaptive focus color used by MangoWM windows. The
Dashboard can cycle modes, while standard workspace controls remain in
`.config/mango/conf.d/binds.conf`.

Useful window-management bindings include:

- `Super + H/J/K/L` or arrows: focus direction.
- `Super + Shift + H/J/K/L` or arrows: exchange windows.
- `Super + Ctrl + H/J/K/L` or arrows: resize.
- `Super + 1…5`: view a tag; `Super + Shift + 1…5`: move the focused client.
- `Super + Space`: cycle layout; `Super + T/C/S`: tile, center tile, or scroller.

## Safety boundaries

Monitor changes use a preview token and timeout; confirm only after the new
layout is visible. MangoWM writes are performed through `MangoConfig` and
`mango_config.py`, which validate before committing and surface failures in the
UI. Do not edit generated state or generated GTK CSS directly; see
[AGENTS.md](../AGENTS.md) for the source-of-truth rules.

## Related documents

- [Architecture](architecture.md)
- [Current roadmap and TODO](TODO.md)
- [Screenshot gallery](screenshots.md)
- [ADR-001: adaptive skins and color pipeline](decisions/ADR-001-adaptive-skins.md)

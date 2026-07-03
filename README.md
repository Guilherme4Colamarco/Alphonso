<div align="center">

**English (en)** • [Português (pt-BR)](README.pt-BR.md)

</div>

---

<div align="center">

# 🦎 Kamalen Shell

![Status](https://img.shields.io/badge/Status-Active-green?style=flat-square)
![WM](https://img.shields.io/badge/WM-MangoWM-e8a87c?style=flat-square)
![Wayland](https://img.shields.io/badge/Protocol-Wayland-ffbc42?style=flat-square&logo=wayland&logoColor=white)
![Engine](https://img.shields.io/badge/Colors-Iris%20Engine-89b4fa?style=flat-square)

<br>

> 🎨 **A dynamic and responsive setup for MangoWM that changes colors like a chameleon, adapting to any wallpaper instantly.**

</div>

---

## 📢 The Concept

Most Linux rices/setups are custom-built to work with only one specific wallpaper and a static color palette. **Kamalen Shell** breaks this barrier: it is designed to extract colors from whatever image you set as a wallpaper and propagate this palette dynamically across your entire system.

No matter what image you throw at it, 90% of the time it will generate a cohesive and pleasing theme without you having to open a single configuration file. It also features 5 different animation profiles (bubbly, calm, snappy, extraslow, none) to adapt to your workflow.

---

## 🚀 What's actually cool?

* **Smart Color Extraction** — A Python script (`iris.py`) uses K-Means clustering in LAB color space to identify the dominant tones of the active wallpaper. It generates background, foreground, accent, and even code syntax highlighting colors, applying them instantly to:
  - **Kitty** (via socket in real time, no restart needed)
  - **Neovim** (creates a dynamic Lua color scheme)
  - **GTK 3/4** (writes CSS directly to theme folders)
  - **MangoWM** (updates window border colors)
  - **Starship Prompt** (syncs your terminal prompt)

* **3D Wallpaper Picker** — No more boring grids. Navigate your wallpapers in a cylindrical 3D carousel that plays GIFs and videos in the center card. Press `R` to pick a random one!

* **Integrated Lockscreen** — Built in Quickshell, it supports video/GIF wallpapers with a dynamic blur effect, uses Python PAM for super-fast authentication, and displays animations for incorrect password attempts.

* **Fully Modular** — Change animation speeds, toggle transparency, adjust window border radius, or change the bar style with simple clicks on the panel.

---

## 📸 Screenshots

![](./screenshots/1.png)
![](./screenshots/2.png)
![](./screenshots/3.png)
![](./screenshots/4.png)
![](./screenshots/5.png)
![](./screenshots/6.png)
![](./screenshots/7.png)
![](./screenshots/8.png)
![](./screenshots/9.png)
![](./screenshots/10.png)

---

## 🛠️ The Stack

| Component | Tool |
|---|---|
| **Window Manager** | [mango-ext](https://github.com/ernestoCruz05/mango-ext) (Enhanced fork of MangoWM) |
| **Panels / Widgets** | [Quickshell](https://github.com/outfoxxed/quickshell) (Reactive QML) |
| **Terminal** | Kitty |
| **Text Editor** | Neovim |
| **Lockscreen** | Quickshell + python-pam |
| **Notifications** | Tiramisu redirected to Quickshell |
| **Wallpaper Daemon** | awww-daemon |
| **Video Wallpapers** | mpvpaper |
| **Audio Visualizer** | Cava (12 frequency bars) |

---

## 📥 Installation

The installation script was developed and tested on **Arch Linux** (and derivatives like CachyOS).

```bash
git clone https://github.com/Guilherme4Colamarco/kamalen-shell.git
cd kamalen-shell
chmod +x install.sh
./install.sh
```

### What the installer does:
- Installs all system dependencies and compiles `mango-ext` automatically.
- Safely backs up your old configurations to `~/.dotfiles-backup-<timestamp>`.
- Copies everything to `~/.config/`.
- Configures the PAM authentication service for the lockscreen.
- Creates the required cache and state directories.

**Next steps after installing:**
1. Log out of your current session.
2. Select **MangoWM** (or mango-ext) from your login manager.
3. Log back in.
4. Run `~/.config/scripts/random-wallpaper.sh` to set your first color theme!

---

## ✨ Features in Detail

### 🎨 Color Extraction (Iris Engine)
The `iris.py` script handles all the heavy lifting. It downscales the image to optimize processing speed, analyzes the spatial distribution of colors, and generates ideal palettes (including auto dark/light modes). Everything is cached, making returning to a previous wallpaper instantaneous.

### 🎞️ Animation Profiles
You can change the system personality on the control panel by choosing from 5 profiles:
- **bubbly**: Bouncy, springy, overshooting transitions (default).
- **calm**: Slow, smooth, macOS-style transitions.
- **snappy**: Fast, clean, and highly responsive.
- **extraslow**: Graceful and slow-paced movements.
- **none**: Instant transitions (no animations).

### 🔒 Lockscreen
Displays clock, date, and profile picture. Plays the same video or GIF background as your desktop with a continuous blur effect. Features password length dots and a shake animation for failed authentication attempts.
*(Security Note: `killall quickshell` bypasses the lockscreen. It is a visual convenience lock, not a high-security vault).*

### 🖼️ 3D Wallpaper Picker
Activated with `Super + W`. Use `H/L` or arrow keys to rotate the wallpaper cylinder. Hovering over a video or GIF starts playback on the card. Press `Enter` to apply, and the system colors will update in under 2 seconds.

### 🎵 Media Control
A top-center drop-down widget that shows playback status via `playerctl` (Spotify, Firefox, mpv, etc.). Supports interactive progress bars, scrolling marquee titles, and two visualization modes: **Vinyl mode** (spinning vinyl record with album art overlay) and **GIF mode** (dynamic GIFs synced to the music). A 12-bar Cava visualizer is rendered at the base.

### 📊 Dashboard
A right-side panel housing your profile picture, system uptime, power menu, and 11 quick setting tiles (Wi-Fi, Bluetooth, DND, Transparency, Power profiles, Animation profiles, and border radius). It also groups notifications by app.

---

## ⌨️ Key Bindings (Main List)

| Binding | Action |
|---|---|
| `Super + Enter` | Open terminal (Kitty) |
| `Super + Shift + Enter` | Open floating terminal |
| `Super + D` | App launcher |
| `Super + W` | 3D Wallpaper Picker |
| `Super + E` | File Manager (Thunar) |
| `Super + X` | Lock Screen |
| `Super + M` | Maximize/Restore Window |
| `Super + Shift + Q` | Close focused window |
| `Super + Shift + Space` | Toggle floating/tiling |
| `Super + Space` | Cycle layouts (Tile, Scroller, Grid, etc.) |
| `Super + O` | Toggle Window Overview |
| `Super + P` | Toggle Canvas Layout Overview |
| `Super + G` | Toggle Gaps |
| `Super + F` | Fullscreen |
| `Super + H/J/K/L` | Focus window (left, down, up, right) |
| `Super + Shift + H/J/K/L` | Move window position |
| `Super + CTRL + H/J/K/L` | Resize active window |
| `Super + 1-5` | Switch workspace |
| `Super + Shift + 1-5` | Send window to workspace |
| `Super + T` | Tiling layout (Dwindle) |
| `Super + Shift + T` | Tiling layout (Classic Tile) |
| `Super + C` | Canvas layout (Infinite workspace) |
| `Super + S` | Scroller layout (Horizontal pages) |
| `Super + Ctrl + R` | Reload compositor config (Reload) |
| `Print` | Capture fullscreen screenshot |
| `Shift + Print` | Capture selected area screenshot |

---

## 📂 File Structure

```
~/.config/quickshell/
├── iris/iris.py              # Main color extraction script
├── state/
│   ├── settings.json         # Settings persistence (dark mode, profiles, etc.)
│   └── app_usage.json        # Launcher usage data
├── assets/
│   ├── pfps/                 # Profile pictures
│   └── gifs/                 # Media widget animated GIFs
├── Colors.qml                # Palette manager singleton
├── UIState.qml               # Global state manager
├── Animations.qml            # Animation profile physics definitions
├── Dashboard.qml             # Right side control panel
├── Launcher.qml              # Application menu
├── Wallpaper.qml             # 3D wallpaper carousel
├── Music.qml                 # Music controller widget
├── Calendar.qml              # Status bar calendar and clock
├── Lockscreen.qml            # Lockscreen panel
├── NotificationPopup.qml     # Toast banners
├── PolkitDialog.qml          # Polkit authentication prompt
├── ClipboardMenu.qml         # Clipboard manager widget
├── PowerMenu.qml             # Quick power options overlay
├── dbus-notifier.py          # Notification integration script
├── qmldir                    # QML module configuration
├── shell.qml                 # Main entrypoint window
└── Bar.qml                   # Top status bar panel

~/.config/mango/
└── config.conf               # MangoWM general settings
```

---

## ⚠️ Known Issues

- **System Tray:** Some applications require starting the bar under a full Qt application session for right-click context menus to render. If the tray disappears or hangs, restart the bar with `quickshell & disown`.
- **Extreme Color Extraction:** Wallpapers that are completely black, white, or have excessively complex gradients might occasionally yield low-contrast accent colors. Photographic or graphic illustrations are recommended.
- **Initial Wallpaper Loading:** The first run of the carousel might experience a slight delay while thumbnails are generated in the background.

---

## 🤝 Credits

- **[MangoWM](https://github.com/mangowm/mango):** The foundational Wayland compositor.
- **[mango-ext](https://github.com/ernestoCruz05/mango-ext):** For amazing window and tiling extensions.
- **[Quickshell](https://github.com/outfoxxed/quickshell):** The flexible QML engine powering the panels.
- The **r/unixporn** community for endless aesthetic inspiration.

---

## 📄 License

This project is licensed under the MIT License. Feel free to use, study, modify, and distribute it.

<div align="center">

*Change your wallpaper and watch the magic happen. 🦎🎨*

</div>

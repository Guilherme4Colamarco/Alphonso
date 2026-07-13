# NixOS system-level module for Kamalen Shell.
#
# This module handles system-wide concerns:
#   - PAM lockscreen service
#   - PipeWire / WirePlumber audio
#   - Seatd (Wayland seat management)
#   - Graphics, fonts, D-Bus, polkit
#   - NetworkManager, Bluetooth
#   - Systemd user linger
#
# User-level services (quickshell, wallpaper daemon, notifications, MPD, etc.)
# are handled by the home-manager module to avoid duplication.
{ config, lib, pkgs, ... }:

let
  cfg = config.kamalen-shell;
in
{
  options.kamalen-shell = {
    enable = lib.mkEnableOption "Kamalen Shell desktop environment";

    user = lib.mkOption {
      type = lib.types.str;
      default = "geko";
      description = "User to configure Kamalen Shell for";
    };

    # Window manager
    windowManager = {
      enable = lib.mkEnableOption "Enable mango-ext as window manager";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.mango-ext;
        description = "mango-ext package to use";
      };
    };

    # Wallpaper daemon
    wallpaperDaemon = {
      enable = lib.mkEnableOption "Enable awww wallpaper daemon";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.awww;
        description = "awww package to use";
      };
    };

    # Video wallpaper
    videoWallpaper = {
      enable = lib.mkEnableOption "Enable mpvpaper for video wallpapers";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.mpvpaper;
        description = "mpvpaper package to use";
      };
    };

    # Notification daemon
    notifications = {
      enable = lib.mkEnableOption "Enable tiramisu notification daemon";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.tiramisu;
        description = "tiramisu package to use";
      };
    };

    # Screen recorder
    screenRecorder = {
      enable = lib.mkEnableOption "Enable gpu-screen-recorder";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.gpu-screen-recorder;
        description = "gpu-screen-recorder package to use";
      };
    };

    # MPD configuration
    mpd = {
      enable = lib.mkEnableOption "Enable MPD music daemon";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.mpd;
        description = "MPD package to use";
      };
      mpdMpris = lib.mkEnableOption "Enable mpd-mpris for MPRIS support";
    };

    # PAM configuration for lockscreen
    pam = {
      enable = lib.mkEnableOption "Configure PAM for lockscreen authentication";
      serviceName = lib.mkOption {
        type = lib.types.str;
        default = "lockscreen";
        description = "PAM service name for lockscreen";
      };
    };

    # QuickShell
    quickshell = {
      enable = lib.mkEnableOption "Enable QuickShell";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.unstable.quickshell;
        description = "QuickShell package to use";
      };
    };

    # Python utilities
    pythonUtils = {
      enable = lib.mkEnableOption "Install Kamalen Python utilities (iris, mango_config, etc.)";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.kamalen-python;
        description = "kamalen-python package to use";
      };
    };

    # Additional packages
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to install at system level";
    };
  };

  config = lib.mkMerge [
    # ── Always-on system services when kamalen-shell is enabled ──────────
    (lib.mkIf cfg.enable {
      # PipeWire audio (replaces PulseAudio)
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
      services.pipewire.wireplumber.enable = true;

      # Graphics (hardware.opengl was renamed to hardware.graphics in 24.05+)
      hardware.graphics.enable = true;

      # Seat management for Wayland
      services.seatd.enable = true;

      # Font configuration
      fonts.fontconfig.enable = true;
      fonts.packages = with pkgs; [
        (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
        noto-fonts
        noto-fonts-emoji
        noto-fonts-cjk-sans
      ];

      # D-Bus for desktop integration
      services.dbus.enable = true;

      # Polkit for authentication
      security.polkit.enable = true;

      # Udev rules for input devices
      services.udev.packages = with pkgs; [ libinput ];

      # NetworkManager
      networking.networkmanager.enable = true;

      # Bluetooth
      hardware.bluetooth.enable = true;

      # Home Manager/systemd user services are started with the graphical session.
      # Extra packages
      environment.systemPackages = cfg.extraPackages;
    })

    # ── Window manager ───────────────────────────────────────────────────
    (lib.mkIf (cfg.enable && cfg.windowManager.enable) {
      environment.systemPackages = [ cfg.windowManager.package ];
    })

    # ── PAM lockscreen ──────────────────────────────────────────────────
    (lib.mkIf (cfg.enable && cfg.pam.enable) {
      security.pam.services.${cfg.pam.serviceName} = {
        text = ''
          auth required pam_unix.so nodelay nullok
          account required pam_unix.so
        '';
      };
    })

    # ── Screen recorder ─────────────────────────────────────────────────
    (lib.mkIf (cfg.enable && cfg.screenRecorder.enable) {
      environment.systemPackages = [ cfg.screenRecorder.package ];
    })

    # ── QuickShell ──────────────────────────────────────────────────────
    (lib.mkIf (cfg.enable && cfg.quickshell.enable) {
      environment.systemPackages = [ cfg.quickshell.package ];
    })

    # ── Python utilities ────────────────────────────────────────────────
    (lib.mkIf (cfg.enable && cfg.pythonUtils.enable) {
      environment.systemPackages = [ cfg.pythonUtils.package ];
    })
  ];
}

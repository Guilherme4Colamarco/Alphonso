{ customPackages, ... }:

let
  cfg = config.kamalen-shell;
  pkgs = config.pkgs;
in
{
  options.kamalen-shell = {
    enable = lib.mkEnableOption "Kamalen Shell desktop environment";

    # User configuration
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
        default = customPackages.mango-ext;
        description = "mango-ext package to use";
      };
    };

    # Wallpaper daemon
    wallpaperDaemon = {
      enable = lib.mkEnableOption "Enable awww wallpaper daemon";
      package = lib.mkOption {
        type = lib.types.package;
        default = customPackages.awww;
      };
    };

    # Video wallpaper
    videoWallpaper = {
      enable = lib.mkEnableOption "Enable mpvpaper for video wallpapers";
      package = lib.mkOption {
        type = lib.types.package;
        default = customPackages.mpvpaper;
      };
    };

    # Notification daemon
    notifications = {
      enable = lib.mkEnableOption "Enable tiramisu notification daemon";
      package = lib.mkOption {
        type = lib.types.package;
        default = customPackages.tiramisu;
      };
    };

    # Screen recorder
    screenRecorder = {
      enable = lib.mkEnableOption "Enable gpu-screen-recorder";
      package = lib.mkOption {
        type = lib.types.package;
        default = customPackages.gpu-screen-recorder;
      };
    };

    # MPD configuration
    mpd = {
      enable = lib.mkEnableOption "Enable MPD music daemon";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.mpd;
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
      enable = lib.mkEnableOption "Enable QuickShell (installed via nixpkgs)";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.quickshell;
      };
    };

    # Python utilities
    pythonUtils = {
      enable = lib.mkEnableOption "Install Kamalen Python utilities (iris, mango_config, etc.)";
      package = lib.mkOption {
        type = lib.types.package;
        default = customPackages.kamalen-python;
      };
    };

    # Additional packages
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to install";
    };
  };

  config = lib.mkIf cfg.enable {
    # Window Manager: mango-ext
    lib.mkIf cfg.windowManager.enable {
      environment.systemPackages = [ cfg.windowManager.package ];

      # Wayland session desktop entry
      wayland.windowManager.mango-ext = {
        enable = true;
        package = cfg.windowManager.package;
      };

      # Autostart QuickShell and other services via mango-ext config
      # (handled by home-manager module)
    };

    # PAM for lockscreen
    lib.mkIf cfg.pam.enable {
      security.pam.services.${cfg.pam.serviceName} = {
        text = ''
          auth required pam_unix.so nodelay nullok
          account required pam_unix.so
        '';
      };
    };

    # Wallpaper daemon (awww) - systemd user service
    lib.mkIf cfg.wallpaperDaemon.enable {
      systemd.user.services.awww = {
        description = "AWWW - Wayland Wallpaper Daemon";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${cfg.wallpaperDaemon.package}/bin/awww";
          Restart = "on-failure";
          RestartSec = 5;
          Environment = "WAYLAND_DISPLAY=${config.services.wayland.displayName}";
        };
      };
    };

    # Video wallpaper (mpvpaper) - systemd user service
    lib.mkIf cfg.videoWallpaper.enable {
      systemd.user.services.mpvpaper = {
        description = "MPVPaper - Video Wallpaper for Wayland";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${cfg.videoWallpaper.package}/bin/mpvpaper --fork '*' ${config.home.homeDirectory}/wallpapers/current";
          Restart = "on-failure";
          RestartSec = 5;
          Environment = "WAYLAND_DISPLAY=${config.services.wayland.displayName}";
        };
      };
    };

    # Notification daemon (tiramisu)
    lib.mkIf cfg.notifications.enable {
      systemd.user.services.tiramisu = {
        description = "Tiramisu - Notification Daemon for Wayland";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${cfg.notifications.package}/bin/tiramisu";
          Restart = "on-failure";
          RestartSec = 5;
          Environment = "WAYLAND_DISPLAY=${config.services.wayland.displayName}";
        };
      };
    };

    # Screen recorder
    lib.mkIf cfg.screenRecorder.enable {
      environment.systemPackages = [ cfg.screenRecorder.package ];
    };

    # MPD + mpd-mpris
    lib.mkIf cfg.mpd.enable {
      services.mpd = {
        enable = true;
        user = cfg.user;
        network = {
          bindToAddress = "127.0.0.1";
          port = 6600;
        };
        database = "/home/${cfg.user}/.config/mpd/database";
        logFile = "/home/${cfg.user}/.config/mpd/log";
        pidFile = "/home/${cfg.user}/.config/mpd/pid";
        stateFile = "/home/${cfg.user}/.config/mpd/state";
        stickerFile = "/home/${cfg.user}/.config/mpd/sticker.sql";
        musicDirectory = "/home/${cfg.user}/Music";
        playlistDirectory = "/home/${cfg.user}/.config/mpd/playlists";
        extraConfig = ''
          audio_output {
            type "pipewire"
            name "PipeWire"
          }
        '';
      };

      lib.mkIf cfg.mpd.mpdMpris {
        systemd.user.services.mpd-mpris = {
          description = "MPD MPRIS Bridge";
          wantedBy = [ "graphical-session.target" ];
          after = [ "mpd.service" ];
          serviceConfig = {
            ExecStart = "${pkgs.mpd-mpris}/bin/mpd-mpris";
            Restart = "on-failure";
            RestartSec = 5;
          };
        };
      };
    };

    # QuickShell
    lib.mkIf cfg.quickshell.enable {
      environment.systemPackages = [ cfg.quickshell.package ];
    };

    # Python utilities
    lib.mkIf cfg.pythonUtils.enable {
      environment.systemPackages = [ cfg.pythonUtils.package ];
    };

    # Extra packages
    environment.systemPackages = cfg.extraPackages;

    # Required services for Wayland
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = false;
    };

    services.wireplumber.enable = true;

    hardware.opengl.enable = true;

    # Seat management for Wayland
    services.seatd.enable = true;

    # Font configuration
    fonts.fontconfig.enable = true;
    fonts.packages = with pkgs; [
      jetbrains-mono-nerdfonts
      noto-fonts
      noto-fonts-emoji
      noto-fonts-cjk
    ];

    # D-Bus for desktop integration
    services.dbus.enable = true;

    # Polkit for authentication
    services.polkit.enable = true;

    # Udev rules for input devices
    services.udev.packages = with pkgs; [ libinput ];

    # NetworkManager for network management
    services.networkmanager.enable = true;

    # Bluetooth
    services.bluez.enable = true;
    hardware.bluetooth.enable = true;

    # User services
    systemd.user.enable = true;
    systemd.user.lingerUsers = [ cfg.user ];
  };
}
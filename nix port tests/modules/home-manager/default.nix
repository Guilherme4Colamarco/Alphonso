# Home-manager user-level module for Kamalen Shell.
#
# This module handles user-level concerns:
#   - Dotfiles deployment (quickshell, mango, kitty, nvim, etc.)
#   - Systemd user services (quickshell, awww, mpvpaper, tiramisu, MPD, etc.)
#   - User packages
#   - Shell configuration (Fish + Starship)
#   - Git, SSH, GnuPG, direnv, etc.
#
# System-level services (PAM, PipeWire, seatd) are handled by the NixOS module.
{ config, lib, pkgs, ... }:

let
  cfg = config.kamalen-shell;
  user = cfg.user;
  homeDir = "/home/${user}";
in
{
  options.kamalen-shell = {
    enable = lib.mkEnableOption "Kamalen Shell home-manager configuration";

    user = lib.mkOption {
      type = lib.types.str;
      default = "geko";
      description = "User to configure";
    };

    configSource = lib.mkOption {
      type = lib.types.path;
      description = "Path to Kamalen Shell config repository root";
    };

    # Wallpapers
    wallpapers = {
      enable = lib.mkEnableOption "Deploy wallpapers";
      source = lib.mkOption {
        type = lib.types.path;
        default = cfg.configSource + "/wallpapers";
        defaultText = lib.literalExpression "configSource + \"/wallpapers\"";
        description = "Source wallpapers directory";
      };
      targetDir = lib.mkOption {
        type = lib.types.str;
        default = "${homeDir}/wallpapers";
        description = "Target directory for wallpapers";
      };
      setCurrent = lib.mkEnableOption "Set first wallpaper as current symlink";
    };

    # QuickShell config
    quickshell = {
      enable = lib.mkEnableOption "Deploy QuickShell configuration and service";
      source = lib.mkOption {
        type = lib.types.path;
        default = cfg.configSource + "/.config/quickshell";
        defaultText = lib.literalExpression "configSource + \"/.config/quickshell\"";
        description = "Source QuickShell config directory";
      };
    };

    # MangoWM config
    mango = {
      enable = lib.mkEnableOption "Deploy MangoWM configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = cfg.configSource + "/.config/mango";
        defaultText = lib.literalExpression "configSource + \"/.config/mango\"";
        description = "Source MangoWM config directory";
      };
    };

    # Kitty config
    kitty = {
      enable = lib.mkEnableOption "Deploy Kitty configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = cfg.configSource + "/.config/kitty";
        defaultText = lib.literalExpression "configSource + \"/.config/kitty\"";
        description = "Source Kitty config directory";
      };
    };

    # Neovim config
    nvim = {
      enable = lib.mkEnableOption "Deploy Neovim configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = cfg.configSource + "/.config/nvim";
        defaultText = lib.literalExpression "configSource + \"/.config/nvim\"";
        description = "Source Neovim config directory";
      };
    };

    # Starship config
    starship = {
      enable = lib.mkEnableOption "Deploy Starship configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = cfg.configSource + "/.config/starship.toml";
        defaultText = lib.literalExpression "configSource + \"/.config/starship.toml\"";
        description = "Source Starship config file";
      };
    };

    # Notification daemon
    notifications = {
      enable = lib.mkEnableOption "Deploy and run the notification daemon";
    };

    # Cava config
    cava = {
      enable = lib.mkEnableOption "Deploy Cava configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = cfg.configSource + "/.config/cava";
        defaultText = lib.literalExpression "configSource + \"/.config/cava\"";
        description = "Source Cava config directory";
      };
    };

    # RMPC config
    rmpc = {
      enable = lib.mkEnableOption "Deploy RMPC configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = cfg.configSource + "/.config/rmpc";
        defaultText = lib.literalExpression "configSource + \"/.config/rmpc\"";
        description = "Source RMPC config directory";
      };
    };

    # Fastfetch config
    fastfetch = {
      enable = lib.mkEnableOption "Deploy Fastfetch configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = cfg.configSource + "/.config/fastfetch";
        defaultText = lib.literalExpression "configSource + \"/.config/fastfetch\"";
        description = "Source Fastfetch config directory";
      };
    };

    # Scripts
    scripts = {
      enable = lib.mkEnableOption "Deploy custom scripts";
      source = lib.mkOption {
        type = lib.types.path;
        default = cfg.configSource + "/.config/scripts";
        defaultText = lib.literalExpression "configSource + \"/.config/scripts\"";
        description = "Source scripts directory";
      };
    };

    # MPD
    mpd = {
      enable = lib.mkEnableOption "Configure MPD as a user service";
      mpdMpris = lib.mkEnableOption "Enable mpd-mpris";
    };

    # Cache directories to create
    cacheDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${homeDir}/.cache/wallpaper-thumbs"
        "${homeDir}/.cache/wallpaper-colors"
        "${homeDir}/.cache/qs"
      ];
      description = "Cache directories to create";
    };

    # MPD directories to create
    mpdDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "${homeDir}/.config/mpd/playlists" ];
      description = "MPD directories to create";
    };
  };

  config = lib.mkMerge [
    # ── Dotfiles deployment via xdg.configFile ──────────────────────────
    (lib.mkIf (cfg.enable && cfg.quickshell.enable) {
      xdg.configFile."quickshell".source = cfg.quickshell.source;
    })
    (lib.mkIf (cfg.enable && cfg.mango.enable) {
      xdg.configFile."mango".source = cfg.mango.source;
    })
    (lib.mkIf (cfg.enable && cfg.kitty.enable) {
      xdg.configFile."kitty".source = cfg.kitty.source;
    })
    (lib.mkIf (cfg.enable && cfg.nvim.enable) {
      xdg.configFile."nvim".source = cfg.nvim.source;
    })
    (lib.mkIf (cfg.enable && cfg.starship.enable) {
      xdg.configFile."starship.toml".source = cfg.starship.source;
    })
    (lib.mkIf (cfg.enable && cfg.cava.enable) {
      xdg.configFile."cava".source = cfg.cava.source;
    })
    (lib.mkIf (cfg.enable && cfg.rmpc.enable) {
      xdg.configFile."rmpc".source = cfg.rmpc.source;
    })
    (lib.mkIf (cfg.enable && cfg.fastfetch.enable) {
      xdg.configFile."fastfetch".source = cfg.fastfetch.source;
    })
    (lib.mkIf (cfg.enable && cfg.scripts.enable) {
      # Scripts go to ~/.local/bin/
      home.file.".local/bin/scripts" = {
        source = cfg.scripts.source;
        recursive = true;
      };
    })

    # ── Wallpaper deployment ────────────────────────────────────────────
    (lib.mkIf (cfg.enable && cfg.wallpapers.enable) {
      home.activation.kamalenWallpaperDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        ''
          mkdir -p "${cfg.wallpapers.targetDir}"
          if [ -d "${cfg.wallpapers.source}" ]; then
            cp -n "${cfg.wallpapers.source}"/* "${cfg.wallpapers.targetDir}/" 2>/dev/null || true
          fi
        '' + lib.optionalString cfg.wallpapers.setCurrent ''
          first_wall=$(find "${cfg.wallpapers.targetDir}" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.webm" \) 2>/dev/null | head -1)
          if [ -n "$first_wall" ]; then
            ln -sf "$first_wall" "${cfg.wallpapers.targetDir}/current"
          fi
        ''
      );
    })

    # ── Cache directories ───────────────────────────────────────────────
    (lib.mkIf cfg.enable {
      home.activation.kamalenCacheDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${lib.concatStringsSep "\n" (builtins.map (dir: "mkdir -p ${dir}") cfg.cacheDirs)}
      '';
    })

    # ── MPD directories ─────────────────────────────────────────────────
    (lib.mkIf (cfg.enable && cfg.mpd.enable) {
      home.activation.kamalenMpdDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${lib.concatStringsSep "\n" (builtins.map (dir: "mkdir -p ${dir}") cfg.mpdDirs)}
        touch "${homeDir}/.config/mpd/database" 2>/dev/null || true
        touch "${homeDir}/.config/mpd/state" 2>/dev/null || true
        touch "${homeDir}/.config/mpd/sticker.sql" 2>/dev/null || true
      '';
    })

    # ── Systemd user services ───────────────────────────────────────────
    (lib.mkIf (cfg.enable && cfg.quickshell.enable) {
      systemd.user.services.quickshell = {
        description = "QuickShell - Reactive QML Desktop Shell";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.unstable.quickshell}/bin/quickshell";
          Restart = "on-failure";
          RestartSec = 2;
        };
        environment = {
          WAYLAND_DISPLAY = "wayland-0";
          HOME = homeDir;
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.wallpapers.enable) {
      systemd.user.services.awww = {
        description = "AWWW - Wayland Wallpaper Daemon";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.awww}/bin/awww";
          Restart = "on-failure";
          RestartSec = 5;
        };
        environment = {
          WAYLAND_DISPLAY = "wayland-0";
        };
      };

      systemd.user.services.mpvpaper = {
        description = "MPVPaper - Video Wallpaper for Wayland";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.mpvpaper}/bin/mpvpaper --fork '*' ${cfg.wallpapers.targetDir}/current";
          Restart = "on-failure";
          RestartSec = 5;
        };
        environment = {
          WAYLAND_DISPLAY = "wayland-0";
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.notifications.enable) {
      systemd.user.services.tiramisu = {
        description = "Tiramisu - Notification Daemon";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.tiramisu}/bin/tiramisu";
          Restart = "on-failure";
          RestartSec = 5;
        };
        environment = {
          WAYLAND_DISPLAY = "wayland-0";
        };
      };
    })

    # DBus notifier (feeds notifications to QuickShell)
    (lib.mkIf cfg.enable {
      systemd.user.services.kamalen-dbus-notifier = {
        description = "Kamalen DBus Notifier";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.kamalen-python}/bin/kamalen-dbus-notifier";
          Restart = "on-failure";
          RestartSec = 2;
        };
        environment = {
          WAYLAND_DISPLAY = "wayland-0";
          HOME = homeDir;
        };
      };
    })

    # Wallpaper pre-generation (thumbnails)
    (lib.mkIf cfg.enable {
      systemd.user.services.kamalen-wallpaper-pregen = {
        description = "Kamalen Wallpaper Pre-generation";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c 'shopt -s nullglob; CACHE=\"${homeDir}/.cache/wallpaper-thumbs\"; mkdir -p \"$CACHE\"; touch \"$CACHE/colors.tsv\"; for f in \"${cfg.wallpapers.targetDir}\"/*.{jpg,jpeg,png,gif,webp}; do [ -L \"$f\" ] && continue; name=$(basename \"$f\"); thumb=\"$CACHE/${"$"}{name}.thumb.jpg\"; [ -f \"$thumb\" ] && continue; ${pkgs.imagemagick}/bin/magick \"${"$"}{f}[0]\" -resize 600x -quality 85 \"$thumb\" 2>/dev/null; done'";
        };
        environment = {
          HOME = homeDir;
        };
      };

      # Wallpaper apply on session start
      systemd.user.services.kamalen-wallpaper-apply = {
        description = "Kamalen Wallpaper Apply";
        wantedBy = [ "graphical-session.target" ];
        after = [ "kamalen-wallpaper-pregen.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c 'current=\"${cfg.wallpapers.targetDir}/current\"; [ -L \"$current\" ] || exit 0; wall=$(readlink -f \"$current\"); [ -f \"$wall\" ] || exit 0; ext=\"${"$"}{wall##*.}\"; ext=$(echo \"$ext\" | tr \"[:upper:]\" \"[:lower:]\"); case \"$ext\" in mp4|webm|mkv) frame=\"/tmp/wall-frame-$$.jpg\"; ${pkgs.ffmpeg}/bin/ffmpeg -i \"$wall\" -vframes 1 -q:v 2 \"$frame\" -y 2>/dev/null; ${pkgs.awww}/bin/awww img --transition-type wipe \"$frame\" 2>/dev/null; sleep 1.5; pkill -f \"mpvpaper.*${"$"}{wall}\" 2>/dev/null; ${pkgs.mpvpaper}/bin/mpvpaper --fork \"*\" \"$wall\" 2>/dev/null; rm -f \"$frame\" ;; *) ${pkgs.awww}/bin/awww img --transition-type wipe \"$wall\" 2>/dev/null ;; esac'";
        };
        environment = {
          HOME = homeDir;
        };
      };
    })

    # ── MPD user service ────────────────────────────────────────────────
    (lib.mkIf (cfg.enable && cfg.mpd.enable) {
      systemd.user.services.mpd = {
        description = "Music Player Daemon";
        wantedBy = [ "default.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.mpd}/bin/mpd --no-daemon";
          Restart = "on-failure";
          RestartSec = 5;
        };
        environment = {
          HOME = homeDir;
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.mpd.enable && cfg.mpd.mpdMpris) {
      systemd.user.services.mpd-mpris = {
        description = "MPD MPRIS Bridge";
        wantedBy = [ "default.target" ];
        after = [ "mpd.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.mpd-mpris}/bin/mpd-mpris";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    })

    # ── Packages ────────────────────────────────────────────────────────
    (lib.mkIf cfg.enable {
      home.packages = with pkgs; [
        # Custom packages (from overlay)
        mango-ext
        awww
        mpvpaper
        rmpc
        tiramisu
        gpu-screen-recorder
        pokemon-colorscripts
        kamalen-python
        # Desktop tools
        unstable.quickshell
        kitty
        neovim
        starship
        cava
        fastfetch
        fish
        git
        curl
        wget
        unzip
        p7zip
        tree
        fd
        ripgrep
        fzf
        bat
        eza
        delta
        bottom
        btop
        lazygit
        zoxide
        direnv
        imagemagick
        ffmpeg
        mpv
        playerctl
        brightnessctl
        grim
        slurp
        wl-clipboard
        swayidle
        swaylock
        gammastep
        wlr-randr
        networkmanager
        bluez
        pipewire
        wireplumber
        alsa-utils
        pavucontrol
        (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
        noto-fonts
        noto-fonts-emoji
        noto-fonts-cjk-sans
      ];
    })

    # ── Shell configuration ─────────────────────────────────────────────
    (lib.mkIf cfg.enable {
      programs.fish = {
        enable = true;
        shellAliases = {
          vim = "nvim";
          gs = "git status";
          gd = "git diff";
          ga = "git add .";
          gc = "git commit";
          gp = "git push";
          ll = "eza -la";
          lt = "eza --tree";
          cat = "bat";
          grep = "rg";
          find = "fd";
          top = "btop";
        };
        shellInit = ''
          fish_vi_key_bindings
          set -g fish_greeting
          starship init fish | source
        '';
      };

      programs.starship = {
        enable = true;
        enableFishIntegration = true;
      };

      programs.git = {
        enable = true;
        userName = "Guilherme4Colamarco";
        userEmail = "guilherme@example.com";
      };

      programs.ssh.enable = true;


      programs.direnv.enable = true;
      programs.zoxide.enable = true;
      programs.fzf.enable = true;
      programs.bat.enable = true;

      # Nix settings (user-level)
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      nix.settings.auto-optimise-store = true;


    })
  ];
}

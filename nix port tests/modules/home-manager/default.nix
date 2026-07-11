{ customPackages, pkgs, lib, config, ... }:

let
  cfg = config.kamalen-shell;
  user = cfg.user;
  homeDir = "/home/${user}";
  configSource = cfg.configSource;
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
      default = ./.;
      description = "Path to Kamalen Shell config repository";
    };

    # Wallpapers
    wallpapers = {
      enable = lib.mkEnableOption "Deploy wallpapers";
      source = lib.mkOption {
        type = lib.types.path;
        default = configSource + "/wallpapers";
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
      enable = lib.mkEnableOption "Deploy QuickShell configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = configSource + "/.config/quickshell";
        description = "Source QuickShell config directory";
      };
      target = lib.mkOption {
        type = lib.types.str;
        default = "${homeDir}/.config/quickshell";
        description = "Target QuickShell config directory";
      };
    };

    # MangoWM config
    mango = {
      enable = lib.mkEnableOption "Deploy MangoWM configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = configSource + "/.config/mango";
        description = "Source MangoWM config directory";
      };
      target = lib.mkOption {
        type = lib.types.str;
        default = "${homeDir}/.config/mango";
        description = "Target MangoWM config directory";
      };
    };

    # Kitty config
    kitty = {
      enable = lib.mkEnableOption "Deploy Kitty configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = configSource + "/.config/kitty";
        description = "Source Kitty config directory";
      };
      target = lib.mkOption {
        type = lib.types.str;
        default = "${homeDir}/.config/kitty";
        description = "Target Kitty config directory";
      };
    };

    # Neovim config
    nvim = {
      enable = lib.mkEnableOption "Deploy Neovim configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = configSource + "/.config/nvim";
        description = "Source Neovim config directory";
      };
      target = lib.mkOption {
        type = lib.types.str;
        default = "${homeDir}/.config/nvim";
        description = "Target Neovim config directory";
      };
    };

    # Starship config
    starship = {
      enable = lib.mkEnableOption "Deploy Starship configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = configSource + "/.config/starship.toml";
        description = "Source Starship config file";
      };
      target = lib.mkOption {
        type = lib.types.str;
        default = "${homeDir}/.config/starship.toml";
        description = "Target Starship config file";
      };
    };

    # Cava config
    cava = {
      enable = lib.mkEnableOption "Deploy Cava configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = configSource + "/.config/cava";
        description = "Source Cava config directory";
      };
      target = lib.mkOption {
        type = lib.types.str;
        default = "${homeDir}/.config/cava";
        description = "Target Cava config directory";
      };
    };

    # RMPC config
    rmpc = {
      enable = lib.mkEnableOption "Deploy RMPC configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = configSource + "/.config/rmpc";
        description = "Source RMPC config directory";
      };
      target = lib.mkOption {
        type = lib.types.str;
        default = "${homeDir}/.config/rmpc";
        description = "Target RMPC config directory";
      };
    };

    # Fastfetch config
    fastfetch = {
      enable = lib.mkEnableOption "Deploy Fastfetch configuration";
      source = lib.mkOption {
        type = lib.types.path;
        default = configSource + "/.config/fastfetch";
        description = "Source Fastfetch config directory";
      };
      target = lib.mkOption {
        type = lib.types.str;
        default = "${homeDir}/.config/fastfetch";
        description = "Target Fastfetch config directory";
      };
    };

    # Scripts
    scripts = {
      enable = lib.mkEnableOption "Deploy custom scripts";
      source = lib.mkOption {
        type = lib.types.path;
        default = configSource + "/.config/scripts";
        description = "Source scripts directory";
      };
      target = lib.mkOption {
        type = lib.types.str;
        default = "${homeDir}/.local/bin";
        description = "Target scripts directory";
      };
    };

    # MPD configuration
    mpd = {
      enable = lib.mkEnableOption "Configure MPD";
      mpdMpris = lib.mkEnableOption "Enable mpd-mpris";
      configDir = lib.mkOption {
        type = lib.types.str;
        default = "${homeDir}/.config/mpd";
        description = "MPD config directory";
      };
      musicDir = lib.mkOption {
        type = lib.types.str;
        default = "${homeDir}/Music";
        description = "Music directory";
      };
      playlistDir = lib.mkOption {
        type = lib.types.str;
        default = "${homeDir}/.config/mpd/playlists";
        description = "Playlist directory";
      };
    };

    # Cache directories
    cacheDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${homeDir}/.cache/wallpaper-thumbs"
        "${homeDir}/.cache/wallpaper-colors"
        "${homeDir}/.cache/qs"
      ];
      description = "Cache directories to create";
    };

    # MPD directories
    mpdDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${homeDir}/.config/mpd/playlists"
      ];
      description = "MPD directories to create";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create directories
    home.file = lib.optionalAttrs cfg.wallpapers.enable {
      "${cfg.wallpapers.targetDir}/.gitkeep" = {
        text = "";
        executable = false;
      };
    } // lib.optionalAttrs cfg.scripts.enable {
      "${cfg.scripts.target}/.gitkeep" = {
        text = "";
        executable = false;
      };
    };

    # Deploy wallpapers
    lib.mkIf cfg.wallpapers.enable {
      home.activation.createWallpaperDirs = {
        text = ''
          mkdir -p "${cfg.wallpapers.targetDir}"
          if [ -d "${cfg.wallpapers.source}" ]; then
            cp -n "${cfg.wallpapers.source}"/* "${cfg.wallpapers.targetDir}/" 2>/dev/null || true
          fi
        '';
        deps = [ ];
      };

      lib.mkIf cfg.wallpapers.setCurrent {
        home.activation.setCurrentWallpaper = {
          text = ''
            first_wall=$(find "${cfg.wallpapers.targetDir}" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.webm" \) 2>/dev/null | head -1)
            if [ -n "$first_wall" ]; then
              ln -sf "$first_wall" "${cfg.wallpapers.targetDir}/current"
            fi
          '';
          deps = [ "createWallpaperDirs" ];
        };
      };
    }

    # Deploy QuickShell config
    lib.mkIf cfg.quickshell.enable {
      home.file."quickshell".source = cfg.quickshell.source;
      home.file."quickshell".target = cfg.quickshell.target;
      home.file."quickshell".recursive = true;
    }

    # Deploy MangoWM config
    lib.mkIf cfg.mango.enable {
      home.file."mango".source = cfg.mango.source;
      home.file."mango".target = cfg.mango.target;
      home.file."mango".recursive = true;
    }

    # Deploy Kitty config
    lib.mkIf cfg.kitty.enable {
      home.file."kitty".source = cfg.kitty.source;
      home.file."kitty".target = cfg.kitty.target;
      home.file."kitty".recursive = true;
    }

    # Deploy Neovim config
    lib.mkIf cfg.nvim.enable {
      home.file."nvim".source = cfg.nvim.source;
      home.file."nvim".target = cfg.nvim.target;
      home.file."nvim".recursive = true;
    }

    # Deploy Starship config
    lib.mkIf cfg.starship.enable {
      home.file."starship.toml".source = cfg.starship.source;
      home.file."starship.toml".target = cfg.starship.target;
    }

    # Deploy Cava config
    lib.mkIf cfg.cava.enable {
      home.file."cava".source = cfg.cava.source;
      home.file."cava".target = cfg.cava.target;
      home.file."cava".recursive = true;
    }

    # Deploy RMPC config
    lib.mkIf cfg.rmpc.enable {
      home.file."rmpc".source = cfg.rmpc.source;
      home.file."rmpc".target = cfg.rmpc.target;
      home.file."rmpc".recursive = true;
    }

    # Deploy Fastfetch config
    lib.mkIf cfg.fastfetch.enable {
      home.file."fastfetch".source = cfg.fastfetch.source;
      home.file."fastfetch".target = cfg.fastfetch.target;
      home.file."fastfetch".recursive = true;
    }

    # Deploy scripts
    lib.mkIf cfg.scripts.enable {
      home.file."scripts".source = cfg.scripts.source;
      home.file."scripts".target = cfg.scripts.target;
      home.file."scripts".recursive = true;
      home.file."scripts".executable = true;
    }

    # Create cache directories
    home.activation.createCacheDirs = {
      text = ''
        ${lib.concatStringsSep "\n" (builtins.map (dir: "mkdir -p ${dir}") cfg.cacheDirs)}
      '';
    };

    # Create MPD directories
    lib.mkIf cfg.mpd.enable {
      home.activation.createMpdDirs = {
        text = ''
          ${lib.concatStringsSep "\n" (builtins.map (dir: "mkdir -p ${dir}") cfg.mpdDirs)}
          touch "${cfg.mpd.configDir}/database" 2>/dev/null || true
          touch "${cfg.mpd.configDir}/state" 2>/dev/null || true
          touch "${cfg.mpd.configDir}/sticker.sql" 2>/dev/null || true
        '';
        deps = [ "createCacheDirs" ];
      };
    }

    # Systemd user services
    lib.mkIf cfg.mpd.enable {
      systemd.user.services.mpd = {
        description = "Music Player Daemon";
        wantedBy = [ "default.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.mpd}/bin/mpd --no-daemon";
          Restart = "on-failure";
          RestartSec = 5;
          Environment = "HOME=${homeDir}";
        };
      };
    }

    lib.mkIf (cfg.mpd.enable && cfg.mpd.mpdMpris) {
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
    }

    # QuickShell service
    lib.mkIf cfg.quickshell.enable {
      systemd.user.services.quickshell = {
        description = "QuickShell - Reactive QML Desktop Shell";
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.quickshell}/bin/quickshell";
          Restart = "on-failure";
          RestartSec = 2;
          Environment = "WAYLAND_DISPLAY=${config.services.wayland.displayName}";
        };
      };
    }

    # AWWW wallpaper daemon
    systemd.user.services.awww = {
      description = "AWWW - Wayland Wallpaper Daemon";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${customPackages.awww}/bin/awww";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = "WAYLAND_DISPLAY=${config.services.wayland.displayName}";
      };
    }

    # MPVPaper video wallpaper
    systemd.user.services.mpvpaper = {
      description = "MPVPaper - Video Wallpaper for Wayland";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${customPackages.mpvpaper}/bin/mpvpaper --fork '*' ${cfg.wallpapers.targetDir}/current";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = "WAYLAND_DISPLAY=${config.services.wayland.displayName}";
      };
    }

    # Tiramisu notifications
    systemd.user.services.tiramisu = {
      description = "Tiramisu - Notification Daemon";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${customPackages.tiramisu}/bin/tiramisu";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = "WAYLAND_DISPLAY=${config.services.wayland.displayName}";
      };
    }

    # DBus notifier (for QuickShell)
    systemd.user.services.kamalen-dbus-notifier = {
      description = "Kamalen DBus Notifier";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${customPackages.kamalen-python}/bin/kamalen-dbus-notifier";
        Restart = "on-failure";
        RestartSec = 2;
        Environment = "WAYLAND_DISPLAY=${config.services.wayland.displayName}";
      };
    }

    # Wallpaper pre-generation
    systemd.user.services.kamalen-wallpaper-pregen = {
      description = "Kamalen Wallpaper Pre-generation";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'shopt -s nullglob; CACHE=\"${homeDir}/.cache/wallpaper-thumbs\"; mkdir -p \"$CACHE\"; touch \"$CACHE/colors.tsv\"; for f in \"${cfg.wallpapers.targetDir}\"/*.{jpg,jpeg,png,gif,webp}; do [ -L \"$f\" ] && continue; name=$(basename \"$f\"); thumb=\"$CACHE/${name}.thumb.jpg\"; [ -f \"$thumb\" ] && continue; ${pkgs.imagemagick}/bin/magick \"${f}[0]\" -resize 600x -quality 85 \"$thumb\" 2>/dev/null; done'";
        Environment = "HOME=${homeDir}";
      };
    }

    # Wallpaper apply on session start
    systemd.user.services.kamalen-wallpaper-apply = {
      description = "Kamalen Wallpaper Apply";
      wantedBy = [ "graphical-session.target" ];
      after = [ "kamalen-wallpaper-pregen.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'current=\"${cfg.wallpapers.targetDir}/current\"; [ -L \"$current\" ] || exit 0; wall=$(readlink -f \"$current\"); [ -f \"$wall\" ] || exit 0; ext=\"${wall##*.}\"; ext=$(echo \"$ext\" | tr '[:upper:]' '[:lower:]'); case \"$ext\" in mp4|webm|mkv) frame=\"/tmp/wall-frame-$$.jpg\"; ${pkgs.ffmpeg}/bin/ffmpeg -i \"$wall\" -vframes 1 -q:v 2 \"$frame\" -y 2>/dev/null; ${customPackages.awww}/bin/awww img --transition-type wipe \"$frame\" 2>/dev/null; sleep 1.5; pkill -f \"mpvpaper.*$wall\" 2>/dev/null; ${customPackages.mpvpaper}/bin/mpvpaper --fork '*' \"$wall\" 2>/dev/null; rm -f \"$frame\" ;; *) ${customPackages.awww}/bin/awww img --transition-type wipe \"$wall\" 2>/dev/null ;; esac'";
        Environment = "HOME=${homeDir}";
      };
    }

    # Packages
    home.packages = with pkgs; [
      customPackages.mango-ext
      customPackages.awww
      customPackages.mpvpaper
      customPackages.rmpc
      customPackages.tiramisu
      customPackages.gpu-screen-recorder
      customPackages.pokemon-colorscripts
      customPackages.kamalen-python
      quickshell
      kitty
      neovim
      starship
      cava
      fastfetch
      fish
      zsh
      bash
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
      ttf-jetbrains-mono-nerd
      noto-fonts
      noto-fonts-emoji
      noto-fonts-cjk
    ];

    # Shell configuration
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

    programs.ssh = {
      enable = true;
      startAgent = true;
    };

    programs.gnupg = {
      enable = true;
      agent = {
        enable = true;
        enableSSHSupport = true;
      };
    };

    programs.direnv.enable = true;
    programs.zoxide.enable = true;
    programs.fzf.enable = true;
    programs.bat.enable = true;
    programs.eza.enable = true;
    programs.delta.enable = true;
    programs.bottom.enable = true;
    programs.lazygit.enable = true;

    # Nix
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.settings.auto-optimise-store = true;
    nix.settings.max-jobs = "auto";
    nix.settings.cores = 0;

    # News
    home-manager.news.enable = false;
  };
}
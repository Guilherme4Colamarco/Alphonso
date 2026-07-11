{ config, pkgs, lib, customPackages, ... }:

{
  # Home-manager configuration for user "geko"
  home.username = "geko";
  home.homeDirectory = "/home/geko";
  home.stateVersion = "24.11";

  # Kamalen Shell home-manager module
  kamalen-shell = {
    enable = true;
    user = "geko";

    # Config source (local repo)
    configSource = ./../../..;

    # Wallpapers
    wallpapers = {
      enable = true;
      source = ./../../../wallpapers;
      targetDir = "/home/geko/wallpapers";
      setCurrent = true;
    };

    # QuickShell
    quickshell.enable = true;

    # MangoWM
    mango.enable = true;

    # Kitty
    kitty.enable = true;

    # Neovim
    nvim.enable = true;

    # Starship
    starship.enable = true;

    # Cava
    cava.enable = true;

    # RMPC
    rmpc.enable = true;

    # Fastfetch
    fastfetch.enable = true;

    # Scripts
    scripts.enable = true;

    # MPD
    mpd.enable = true;
    mpd.mpdMpris = true;

    # Cache dirs
    cacheDirs = [
      "/home/geko/.cache/wallpaper-thumbs"
      "/home/geko/.cache/wallpaper-colors"
      "/home/geko/.cache/qs"
    ];

    # MPD dirs
    mpdDirs = [
      "/home/geko/.config/mpd/playlists"
    ];
  };

  # Additional packages
  home.packages = with pkgs; [
    firefox
    thunderbird
    code
    discord
    spotify
    steam
    lutris
    gamemode
    mangohud
    protonup-qt
    bottles
    heroic-games-launcher
    obs-studio
    kdenlive
    blender
    gimp
    inkscape
    krita
    libreoffice
    zotero
    keepassxc
    bitwarden
    signal-desktop
    telegram-desktop
    whatsie
    element-desktop
    vesktop
  ];

  # Programs
  programs.fish = {
    enable = true;
    shellAliases = {
      vim = "nvim";
      gs = "git status";
      gd = "git diff";
      ga = "git add .";
      gc = "git commit";
      gp = "git push";
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
}
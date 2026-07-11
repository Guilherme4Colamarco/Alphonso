{ config, pkgs, lib, customPackages, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "kamalen-nixos";
  networking.networkmanager.enable = true;

  # Time
  time.timeZone = "America/Sao_Paulo";

  # Locale
  i18n.defaultLocale = "pt_BR.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };

  # Users
  users.users.geko = {
    isNormalUser = true;
    description = "Guilherme";
    extraGroups = [ "wheel" "networkmanager" "video" "seat" "render" "docker" ];
    packages = with pkgs; [
      git
      vim
      htop
      btop
      curl
      wget
      unzip
      p7zip
    ];
  };

  # Sudo
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # Kamalen Shell
  kamalen-shell = {
    enable = true;
    user = "geko";

    windowManager.enable = true;
    wallpaperDaemon.enable = true;
    videoWallpaper.enable = true;
    notifications.enable = true;
    screenRecorder.enable = true;
    mpd.enable = true;
    mpd.mpdMpris = true;
    pam.enable = true;
    quickshell.enable = true;
    pythonUtils.enable = true;

    extraPackages = with pkgs; [
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
  };

  # Hardware
  hardware.enableAllFirmware = true;
  hardware.opengl.enable = true;
  hardware.pulseaudio.enable = false;  # Using PipeWire
  hardware.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = false;
  };
  hardware.bluetooth.enable = true;

  # Virtualization
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;

  # Nix
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.settings.max-jobs = "auto";
  nix.settings.cores = 0;

  # System packages
  environment.systemPackages = with pkgs; [
    git
    vim
    htop
    btop
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
    starship
    fish
  ];

  # Services
  services.flatpak.enable = true;
  services.distrobox.enable = true;

  # Clean up
  system.autoUpgrade.enable = false;
}
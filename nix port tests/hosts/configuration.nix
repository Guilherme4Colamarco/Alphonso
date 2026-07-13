# NixOS system configuration for the kamalen-test VM.
#
# This is an example/test host. On real hardware, run:
#   nixos-generate-config --root /mnt
# to generate a proper hardware-configuration.nix, then replace the one below.
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ── Boot ──────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Networking ────────────────────────────────────────────────────────
  networking.hostName = "kamalen-nixos";
  networking.networkmanager.enable = true;

  # ── Time & Locale ─────────────────────────────────────────────────────
  time.timeZone = "America/Sao_Paulo";

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

  # ── Users ─────────────────────────────────────────────────────────────
  users.users.geko = {
    isNormalUser = true;
    description = "Guilherme";
    extraGroups = [ "wheel" "networkmanager" "video" "seat" "render" "docker" ];
    # Generate a hash with: mkpasswd -m sha-512
    # hashedPassword = "$6$...";
  };

  # ── Sudo ──────────────────────────────────────────────────────────────
  security.sudo.enable = true;
  # NOTE: wheelNeedsPassword defaults to true (password required).
  # The previous config set it to false, which is a security risk.

  # ── Kamalen Shell ─────────────────────────────────────────────────────
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
      vscode
      discord
      spotify
      steam
      lutris
      gamemode
      mangohud
      protonup-qt
      bottles
      heroic
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
      element-desktop
      vesktop
    ];
  };

  # ── Hardware ──────────────────────────────────────────────────────────
  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;
  # PipeWire is enabled by the kamalen-shell NixOS module.
  # Do NOT enable PulseAudio — they conflict.
  hardware.bluetooth.enable = true;

  # ── Virtualization ────────────────────────────────────────────────────
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;

  # ── Nix ───────────────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  # ── System packages (basic tools) ─────────────────────────────────────
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
    distrobox
  ];

  # ── Services ──────────────────────────────────────────────────────────
  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ── Auto-upgrade (disabled for test VM) ───────────────────────────────
  system.autoUpgrade.enable = false;

  # ── State version ─────────────────────────────────────────────────────
  system.stateVersion = "24.11";
}

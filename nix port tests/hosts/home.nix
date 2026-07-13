# Home-manager configuration for user "geko".
#
# This file sets basic home info and configures the kamalen-shell
# home-manager module with host-specific options.
#
# Programs (fish, starship, git, etc.) and packages are configured by the
# kamalen-shell home-manager module itself — do not duplicate them here.
{ config, pkgs, lib, ... }:

let
  # Path to the kamalen-shell repo root (two levels up from hosts/)
  repoRoot = ./../..;
in
{
  # ── Home basics ───────────────────────────────────────────────────────
  home.username = "geko";
  home.homeDirectory = "/home/geko";
  home.stateVersion = "24.11";

  # ── Kamalen Shell configuration ───────────────────────────────────────
  kamalen-shell = {
    enable = true;
    user = "geko";

    # Path to the kamalen-shell repo (for config file deployment)
    configSource = repoRoot;

    # Wallpapers
    wallpapers = {
      enable = false;
      source = "/home/geko/wallpapers";
      targetDir = "/home/geko/wallpapers";
      setCurrent = false;
    };

    # Config deployments
    quickshell.enable = true;
    mango.enable = true;
    kitty.enable = true;
    nvim.enable = true;
    starship.enable = true;
    cava.enable = true;
    rmpc.enable = true;
    fastfetch.enable = true;
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

  # ── Host-specific packages (not in the module) ───────────────────────
  # The kamalen-shell module already installs the core desktop packages.
  # Add only host-specific applications here.
  home.packages = with pkgs; [ ];
}

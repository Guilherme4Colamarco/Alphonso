{ pkgs }:

let
  version = "1.1.0";
  rev = "v1.1.0";
  src = pkgs.fetchFromGitHub {
    owner = "GhostNaN";
    repo = "mpvpaper";
    rev = rev;
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # TODO: update with real hash
  };
in
pkgs.stdenv.mkDerivation {
  pname = "mpvpaper";
  inherit version;
  inherit src;

  nativeBuildInputs = with pkgs; [ meson ninja pkg-config ];

  buildInputs = with pkgs; [
    mpv
    wayland
    wayland-protocols
    libdrm
    libxkbcommon
    libinput
    pixman
    libglvnd
    libseat
    libdisplay-info
    libliftoff
    hwdata
    cairo
    pango
    glib
    dbus
    systemd
    ffmpeg
  ];

  mesonFlags = [
    "-Dprefix=${pkgs.stdenv.lib.getPrefix pkgs}"
    "-Dbuildtype=release"
    "-Db_ndebug=true"
  ];

  meta = with pkgs.lib; {
    description = "Video wallpaper utility for Wayland using mpv";
    homepage = "https://github.com/GhostNaN/mpvpaper";
    license = licenses.gpl3;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
{ pkgs }:

let
  version = "0.1.0";
  rev = "main";
  src = pkgs.fetchFromGitHub {
    owner = "Scrumplex";
    repo = "tiramisu";
    rev = rev;
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # TODO: update with real hash
  };
in
pkgs.stdenv.mkDerivation {
  pname = "tiramisu";
  inherit version;
  inherit src;

  nativeBuildInputs = with pkgs; [ meson ninja pkg-config ];

  buildInputs = with pkgs; [
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
    libnotify
    gtk3
    libappindicator-gtk3
  ];

  mesonFlags = [
    "-Dprefix=${pkgs.stdenv.lib.getPrefix pkgs}"
    "-Dbuildtype=release"
    "-Db_ndebug=true"
  ];

  meta = with pkgs.lib; {
    description = "Screenshot tool for Wayland";
    homepage = "https://github.com/Scrumplex/tiramisu";
    license = licenses.gpl3;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
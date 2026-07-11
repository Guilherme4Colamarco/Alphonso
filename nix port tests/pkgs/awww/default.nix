{ pkgs }:

let
  version = "0.3.0";
  rev = "v0.3.0";
  src = pkgs.fetchFromGitHub {
    owner = "LGFae";
    repo = "awww";
    rev = rev;
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # TODO: update with real hash
  };
in
pkgs.stdenv.mkDerivation {
  pname = "awww";
  inherit version;
  inherit src;

  nativeBuildInputs = with pkgs; [ pkg-config ];

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
  ];

  makeFlags = [ "PREFIX=${pkgs.stdenv.lib.getPrefix pkgs}" ];

  installFlags = [ "PREFIX=${pkgs.stdenv.lib.getPrefix pkgs}" ];

  meta = with pkgs.lib; {
    description = "Wayland wallpaper daemon with transitions";
    homepage = "https://codeberg.org/LGFae/awww";
    license = licenses.gpl3;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
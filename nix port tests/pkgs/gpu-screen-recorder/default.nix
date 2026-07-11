{ pkgs }:

let
  version = "0.1.0";
  rev = "main";
  src = pkgs.fetchFromGitHub {
    owner = "wlrfx";
    repo = "gpu-screen-recorder";
    rev = rev;
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # TODO: update with real hash
  };
in
pkgs.stdenv.mkDerivation {
  pname = "gpu-screen-recorder";
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
    ffmpeg
    libva
    libvdpau
    vulkan-headers
    vulkan-loader
    mesa
    libpipewire-0.3
    libspa-0.2
    gtk3
    libappindicator-gtk3
    libnotify
  ];

  mesonFlags = [
    "-Dprefix=${pkgs.stdenv.lib.getPrefix pkgs}"
    "-Dbuildtype=release"
    "-Db_ndebug=true"
    "-Dgtk=enabled"
    "-Dsystemd=enabled"
  ];

  meta = with pkgs.lib; {
    description = "GPU-accelerated screen recorder for Wayland";
    homepage = "https://git.dec05eba.com/gpu-screen-recorder";
    license = licenses.gpl3;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
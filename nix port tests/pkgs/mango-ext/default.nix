# mango-ext — Enhanced fork of MangoWM (Wayland compositor).
#
# Build dependencies follow the wlroots ecosystem.
# All hashes are lib.fakeHash during development. Run `nix build .#mango-ext`
# and Nix will report the correct hash to substitute.
{ lib, pkgs, ... }:

let
  version = "0.1.0";
  rev = "main";
  src = pkgs.fetchFromGitHub {
    owner = "ernestoCruz05";
    repo = "mango-ext";
    inherit rev;
    hash = lib.fakeHash; # TODO: replace with real hash (nix-prefetch-github or lib.fakeHash + nix build)
  };
in
pkgs.stdenv.mkDerivation {
  pname = "mango-ext";
  inherit version src;

  nativeBuildInputs = with pkgs; [
    meson
    ninja
    pkg-config
    wayland-protocols
    glslang
  ];

  buildInputs = with pkgs; [
    # Wayland / wlroots stack
    wayland
    wayland-protocols
    wlroots
    libdrm
    libxkbcommon
    libinput
    pixman
    libglvnd
    # Seat / display
    seatd
    libdisplay-info
    libliftoff
    hwdata
    # X11 (XWayland support)
    xorg.libxcb
    xorg.xcbutilwm
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    xorg.xcbutilimage
    xorg.xcbutilcursor
    xorg.libX11
    xorg.libXfixes
    xorg.libXext
    xorg.libXrender
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXrandr
    xorg.libXinerama
    xorg.libXcursor
    xorg.libXi
    xorg.libXtst
    xorg.libxshmfence
    # Rendering / graphics
    mesa
    libva
    libvdpau
    vulkan-headers
    vulkan-loader
    libepoxy
    # System
    dbus
    systemd
    glib
    # Text / fonts
    pango
    cairo
    gdk-pixbuf
    fontconfig
    freetype
    harfbuzz
    # Libraries used by mango-ext config
    jsoncpp
    fmt
    spdlog
    nlohmann_json
    cli11
    # NOTE: scenefx and toml11 may not be in nixpkgs 24.11.
    # If they're missing, add them to the overlay from nixpkgs-unstable
    # or package them separately.
    # scenefx
    # toml11
  ];

  mesonFlags = [
    "-Dbuildtype=release"
    "-Db_ndebug=true"
    "-Dwerror=false"
  ];

  postInstall = ''
    mkdir -p $out/share/mango-ext
    cp -r data/* $out/share/mango-ext/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "Enhanced fork of MangoWM - Wayland compositor";
    homepage = "https://github.com/ernestoCruz05/mango-ext";
    license = licenses.gpl3;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}

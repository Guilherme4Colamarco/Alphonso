{ pkgs }:

let
  version = "0.1.0";
  rev = "main";
  src = pkgs.fetchFromGitHub {
    owner = "ernestoCruz05";
    repo = "mango-ext";
    rev = rev;
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # TODO: update with real hash
  };
in
pkgs.stdenv.mkDerivation {
  pname = "mango-ext";
  inherit version;
  inherit src;

  nativeBuildInputs = with pkgs; [
    meson ninja pkg-config
    wayland-protocols
  ];

  buildInputs = with pkgs; [
    wlroots-0.19
    scenefx
    libdrm
    libxkbcommon
    libinput
    pixman
    libglvnd
    libxcb
    xcb-util-wm
    xcb-util-keysyms
    xcb-util-renderutil
    xcb-util-image
    xcb-util-cursor
    libseat
    libdisplay-info
    libliftoff
    hwdata
    cli11
    jsoncpp
    toml11
    fmt
    spdlog
    nlohmann_json
    glslang
    vulkan-headers
    vulkan-loader
    wayland
    wayland-protocols
    xorgproto
    libx11
    libxfixes
    libxext
    libxrender
    libxcomposite
    libxdamage
    libxrandr
    libxinerama
    libxcursor
    libxi
    libxtst
    libxkbfile
    libxkbcommon
    libinput
    libudev
    systemd
    dbus
    glib
    pango
    cairo
    gdk-pixbuf
    at-spi2-core
    atk
    gtk3
    gtk4
    adwaita-icon-theme
    hicolor-icon-theme
    fontconfig
    freetype
    harfbuzz
    libepoxy
    mesa
    libva
    libvdpau
    libdrm
    libxshmfence
    libxpresent
    libxcb-dri3
    libxcb-present
    libxcb-sync
    libxcb-dri2
    libxcb-glx
    libxcb-dri3
    libxcb-present
    libxcb-sync
    libxcb-dri2
    libxcb-glx
  ];

  mesonFlags = [
    "-Dprefix=${pkgs.stdenv.lib.getPrefix pkgs}"
    "-Dbuildtype=release"
    "-Db_ndebug=true"
    "-Dwerror=false"
  ];

  # Install to ~/.config/mango-ext for config compatibility
  postInstall = ''
    mkdir -p $out/share/mango-ext
    cp -r data/* $out/share/mango-ext/ 2>/dev/null || true
  '';

  meta = with pkgs.lib; {
    description = "Enhanced fork of MangoWM - Wayland compositor";
    homepage = "https://github.com/ernestoCruz05/mango-ext";
    license = licenses.gpl3;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
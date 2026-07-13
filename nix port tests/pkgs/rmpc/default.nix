# rmpc — MPD client written in Rust with TUI.
{ lib, pkgs, ... }:

let
  version = "0.15.0";
  rev = "v0.15.0";
  src = pkgs.fetchFromGitHub {
    owner = "mierak";
    repo = "rmpc";
    inherit rev;
    hash = lib.fakeHash; # TODO: replace with real hash
  };
in
pkgs.rustPlatform.buildRustPackage {
  pname = "rmpc";
  inherit version src;

  cargoHash = lib.fakeHash; # TODO: replace with real hash

  nativeBuildInputs = with pkgs; [ pkg-config ];

  buildInputs = with pkgs; [
    libmpdclient
    openssl
    ncurses
    readline
    curl
    sqlite
    libnotify
    dbus
    glib
    gtk3
    libappindicator-gtk3
  ];

  buildFeatures = [ "notify" "dbus" "appindicator" ];

  meta = with lib; {
    description = "MPD client written in Rust with TUI";
    homepage = "https://github.com/mierak/rmpc";
    license = licenses.gpl3;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}

{ pkgs }:

let
  version = "0.15.0";
  rev = "v0.15.0";
  src = pkgs.fetchFromGitHub {
    owner = "mierak";
    repo = "rmpc";
    rev = rev;
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # TODO: update with real hash
  };
in
pkgs.rustPlatform.buildRustPackage {
  pname = "rmpc";
  inherit version;
  inherit src;

  cargoSha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # TODO: update with real hash

  nativeBuildInputs = with pkgs; [ pkg-config ];

  buildInputs = with pkgs; [
    libmpdclient
    openssl
    ncurses
    readline
    libcurl
    sqlite
    libnotify
    dbus
    glib
    gtk3
    libappindicator-gtk3
  ];

  # RMPC uses cargo features
  cargoFeatures = [ "notify" "dbus" "appindicator" ];

  meta = with pkgs.lib; {
    description = "MPD client written in Rust with TUI";
    homepage = "https://github.com/mierak/rmpc";
    license = licenses.gpl3;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
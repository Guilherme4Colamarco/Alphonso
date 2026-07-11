{ pkgs }:

let
  version = "1.0.0";
  rev = "main";
  src = pkgs.fetchFromGitLab {
    owner = "phoneybadner";
    repo = "pokemon-colorscripts";
    rev = rev;
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # TODO: update with real hash
  };
in
pkgs.stdenv.mkDerivation {
  pname = "pokemon-colorscripts";
  inherit version;
  inherit src;

  nativeBuildInputs = with pkgs; [ ];

  buildInputs = with pkgs; [ bash coreutils ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/pokemon-colorscripts
    cp -r pokemon-colorscripts.sh $out/bin/pokemon-colorscripts
    cp -r colorscripts $out/share/pokemon-colorscripts/
    chmod +x $out/bin/pokemon-colorscripts
  '';

  meta = with pkgs.lib; {
    description = "Pokemon colorscripts for terminal";
    homepage = "https://gitlab.com/phoneybadner/pokemon-colorscripts";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
{ nixpkgs, ... }:

{
  # Helper functions for the flake

  # Get package from custom packages
  getCustomPackage = name: system: nixpkgs.legacyPackages.${system}.customPackages.${name};

  # Create a simple derivation from a script
  makeScript = { name, script, dependencies ? [ ], ... } @ attrs:
    nixpkgs.stdenv.mkDerivation (attrs // {
      pname = name;
      version = "1.0.0";
      src = nixpkgs.lib.cleanSourceWith {
        src = nixpkgs.lib.fileset.fromSource {
          root = ./.;
          pattern = ".";
        };
        filter = _: _: false;
      };
      nativeBuildInputs = dependencies;
      installPhase = ''
        mkdir -p $out/bin
        cat > $out/bin/${name} << 'EOF'
${script}
EOF
        chmod +x $out/bin/${name}
      '';
    });

  # Fetch from GitHub with hash verification
  fetchGitHubChecked = { owner, repo, rev, sha256 }:
    nixpkgs.fetchFromGitHub { inherit owner repo rev sha256; };

  # Fetch from GitLab with hash verification
  fetchGitLabChecked = { owner, repo, rev, sha256 }:
    nixpkgs.fetchFromGitLab { inherit owner repo rev sha256; };

  # Create a Python package from local scripts
  makePythonPackage = { name, version, scripts, dependencies ? [ ], ... } @ attrs:
    nixpkgs.python3Packages.buildPythonApplication (attrs // {
      pname = name;
      inherit version;
      src = nixpkgs.lib.cleanSourceWith {
        src = nixpkgs.lib.fileset.toSource {
          root = ./.;
          fileset = nixpkgs.lib.fileset.union (builtins.map (s: nixpkgs.lib.fileset.fromSource {
            root = ./.;
            pattern = s.src;
          }) scripts);
        };
        filter = path: type: type != "directory";
      };
      postInstall = ''
        mkdir -p $out/bin
        ${lib.concatStringsSep "\n" (builtins.map (s: ''
          cp $src/${s.src} $out/share/${name}/${s.dest}
          ln -s $out/share/${name}/${s.dest} $out/bin/${s.binName}
          chmod +x $out/share/${name}/${s.dest}
        '') scripts)}
      '';
      propagatedBuildInputs = dependencies;
    });

  # Merge multiple home-manager modules
  mergeHomeModules = modules:
    nixpkgs.lib.foldl' (acc: m: nixpkgs.lib.mergeEqualOption acc m) { } modules;

  # Create systemd user service
  makeUserService = { name, description, execStart, wantedBy ? [ "graphical-session.target" ], after ? [ ], environment ? { }, restart ? "on-failure", restartSec ? 5 }:
    {
      enable = true;
      description = description;
      wantedBy = wantedBy;
      after = after;
      serviceConfig = {
        ExecStart = execStart;
        Restart = restart;
        RestartSec = toString restartSec;
        Environment = nixpkgs.lib.concatStringsSep " " (builtins.map (kv: "${kv.name}=${kv.value}") (builtins.attrValues environment));
      };
    };

  # Create XDG config file entry
  makeXdgConfig = { name, source, target, recursive ? true }:
    {
      source = source;
      target = target;
      recursive = recursive;
    };

  # Create home file entry
  makeHomeFile = { name, source, target, recursive ? false, executable ? false, text ? null }:
    (if text != null then
      { text = text; executable = executable; }
    else
      { source = source; target = target; recursive = recursive; executable = executable; }
    );
}
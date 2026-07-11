{
  description = "Kamalen Shell - NixOS Port";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Optional: for unstable packages not in 24.11
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, home-manager, nixpkgs-unstable, ... } @ inputs:
    let
      # Supported systems
      systems = [ "x86_64-linux" "aarch64-linux" ];

      # Helper to create packages for all systems
      forAllSystems = f:
        builtins.listToAttrs (builtins.map (system: {
          name = system;
          value = f { inherit system; pkgs = nixpkgs.legacyPackages.${system}; };
        }) systems);

      # Custom packages overlay
      customPackages = forAllSystems ({ system, pkgs }: {
        # Import package definitions
        mango-ext = (import ./pkgs/mango-ext { inherit pkgs; }).mango-ext;
        awww = (import ./pkgs/awww { inherit pkgs; }).awww;
        mpvpaper = (import ./pkgs/mpvpaper { inherit pkgs; }).mpvpaper;
        rmpc = (import ./pkgs/rmpc { inherit pkgs; }).rmpc;
        tiramisu = (import ./pkgs/tiramisu { inherit pkgs; }).tiramisu;
        gpu-screen-recorder = (import ./pkgs/gpu-screen-recorder { inherit pkgs; }).gpu-screen-recorder;
        pokemon-colorscripts = (import ./pkgs/pokemon-colorscripts { inherit pkgs; }).pokemon-colorscripts;
        kamalen-python = (import ./pkgs/kamalen-python { inherit pkgs; }).kamalen-python;
      });

      # Overlay for nixpkgs
      overlay = final: prev: {
        inherit (customPackages.${builtins.head systems}) mango-ext awww mpvpaper rmpc tiramisu gpu-screen-recorder pokemon-colorscripts kamalen-python;
      };

      # NixOS module
      nixosModule = import ./modules/nixos { inherit customPackages; };

      # Home-manager module
      homeManagerModule = import ./modules/home-manager { inherit customPackages; };

      # DevShell for development
      devShell = forAllSystems ({ system, pkgs }: {
        default = pkgs.mkShell {
          name = "kamalen-shell-dev";
          buildInputs = with pkgs; [
            customPackages.${system}.mango-ext
            customPackages.${system}.awww
            customPackages.${system}.mpvpaper
            customPackages.${system}.rmpc
            customPackages.${system}.tiramisu
            # Build dependencies
            meson ninja cmake pkg-config
            qt6-base qt6-declarative qt6-svg qt6-wayland qt6-tools
            libdrm libxkbcommon libinput libpixman-1 libglvnd
            libxcb-icccm libxcb-keysyms libxcb-shape libxcb-render libxcb-xfixes
            libdbus-1 libsystemd libudev libpipewire-0.3 libspa-0.2
            libpango1.0 libcairo2 libpcre2 libdisplay-info libliftoff
            hwdata libseat cli11
            python3 python3Packages.pillow python3Packages.numpy python3Packages.pam
            rustc cargo
            git
          ];
          shellHook = ''
            export MANGO_CONFIG_DIR="$HOME/.config/mango"
            export QT_QPA_PLATFORM=wayland
            echo "Kamalen Shell dev environment ready"
            echo "Run: mango-ext, quickshell, awww, mpvpaper, rmpc, tiramisu"
          '';
        };
      });

      # Lib helpers
      lib = import ./lib { inherit nixpkgs; };
    in
    {
      # Package overlay for use in other flakes
      overlay = overlay;

      # Custom packages per system
      packages = customPackages;

      # NixOS modules
      nixosModules = {
        kamalen-shell = nixosModule;
      };

      # Home-manager modules
      homeManagerModules = {
        kamalen-shell = homeManagerModule;
      };

      # DevShells
      devShells = devShell;

      # Library functions
      lib = lib;

      # Example NixOS configuration (for testing)
      nixosConfigurations = {
        kamalen-test = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ({ pkgs, ... }: {
              imports = [ ./hosts/configuration.nix ];
              nixpkgs.overlays = [ self.overlay ];
            })
            nixosModule
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.geko = import ./hosts/home.nix { inherit customPackages; };
            }
          ];
        };
      };

      # Home-manager configurations (standalone)
      homeConfigurations = {
        geko = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [
            homeManagerModule
            ./hosts/home.nix
          ];
        };
      };

      # Checks for CI
      checks = forAllSystems ({ system, pkgs }: {
        # Build all custom packages
        mango-ext = customPackages.${system}.mango-ext;
        awww = customPackages.${system}.awww;
        mpvpaper = customPackages.${system}.mpvpaper;
        rmpc = customPackages.${system}.rmpc;
        tiramisu = customPackages.${system}.tiramisu;
        gpu-screen-recorder = customPackages.${system}.gpu-screen-recorder;
        pokemon-colorscripts = customPackages.${system}.pokemon-colorscripts;
        kamalen-python = customPackages.${system}.kamalen-python;
      });
    };
}
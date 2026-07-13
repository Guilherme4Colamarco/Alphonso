{
  description = "Kamalen Shell - NixOS Port";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];

      forAllSystems = f:
        builtins.listToAttrs (builtins.map (system: {
          name = system;
          value = f { inherit system; pkgs = nixpkgs.legacyPackages.${system}; };
        }) systems);

      # Overlay: adds unstable packages + all custom packages to pkgs
      # This makes pkgs.mango-ext, pkgs.awww, etc. available everywhere
      overlay = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit (final) config;
          inherit (final.stdenv.hostPlatform) system;
        };
        mango-ext = final.callPackage ./pkgs/mango-ext { };
        awww = final.callPackage ./pkgs/awww { };
        mpvpaper = final.callPackage ./pkgs/mpvpaper { };
        rmpc = final.callPackage ./pkgs/rmpc { };
        tiramisu = final.callPackage ./pkgs/tiramisu { };
        gpu-screen-recorder = final.callPackage ./pkgs/gpu-screen-recorder { };
        pokemon-colorscripts = final.callPackage ./pkgs/pokemon-colorscripts { };
        kamalen-python = final.callPackage ./pkgs/kamalen-python { };
      };
    in
    {
      # Overlays for consumption by other flakes or within nixosConfigurations
      overlays = {
        default = overlay;
        kamalen-shell = overlay;
      };

      # Custom packages per system (for: nix build .#<name>)
      packages = forAllSystems ({ system, pkgs }: {
        mango-ext = pkgs.callPackage ./pkgs/mango-ext { };
        awww = pkgs.callPackage ./pkgs/awww { };
        mpvpaper = pkgs.callPackage ./pkgs/mpvpaper { };
        rmpc = pkgs.callPackage ./pkgs/rmpc { };
        tiramisu = pkgs.callPackage ./pkgs/tiramisu { };
        gpu-screen-recorder = pkgs.callPackage ./pkgs/gpu-screen-recorder { };
        pokemon-colorscripts = pkgs.callPackage ./pkgs/pokemon-colorscripts { };
        kamalen-python = pkgs.callPackage ./pkgs/kamalen-python { };
        default = self.packages.${system}.kamalen-python;
      });

      # NixOS module (system-level: PAM, PipeWire, seatd, fonts, etc.)
      nixosModules = {
        kamalen-shell = import ./modules/nixos;
        default = self.nixosModules.kamalen-shell;
      };

      # Home-manager module (user-level: dotfiles, services, packages)
      homeManagerModules = {
        kamalen-shell = import ./modules/home-manager;
        default = self.homeManagerModules.kamalen-shell;
      };

      # DevShell with all build dependencies
      devShells = forAllSystems ({ system, pkgs }: {
        default = pkgs.mkShell {
          name = "kamalen-shell-dev";
          nativeBuildInputs = with pkgs; [
            meson
            ninja
            cmake
            pkg-config
            glslang
          ];
          buildInputs = with pkgs; [
            # Wayland / wlroots stack
            wayland
            wayland-protocols
            libdrm
            libxkbcommon
            libinput
            pixman
            libglvnd
            seatd
            libdisplay-info
            libliftoff
            hwdata
            # X11 (for XWayland support)
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
            pipewire
            # Text / fonts
            pango
            cairo
            gdk-pixbuf
            fontconfig
            freetype
            harfbuzz
            # Qt6 (for QuickShell)
            qt6.qtbase
            qt6.qtdeclarative
            qt6.qtsvg
            qt6.qtwayland
            qt6.qttools
            # Libraries used by mango-ext
            jsoncpp
            fmt
            spdlog
            nlohmann_json
            cli11
            # Python
            python3
            python3Packages.pillow
            python3Packages.numpy
            python3Packages.pam
            # Rust (for rmpc)
            rustc
            cargo
            # Misc
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

      # Library helpers
      lib = import ./lib { inherit nixpkgs; };

      # Example NixOS configuration (for testing in VM)
      nixosConfigurations = {
        kamalen-test = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            # Apply overlay so pkgs.mango-ext etc. are available in all modules
            { nixpkgs.overlays = [ self.overlays.default ]; }
            ./hosts/configuration.nix
            self.nixosModules.kamalen-shell
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.geko = {
                imports = [
                  self.homeManagerModules.kamalen-shell
                  ./hosts/home.nix
                ];
              };
            }
          ];
        };
      };

      # Standalone home-manager configuration (for non-NixOS or non-flake systems)
      homeConfigurations = {
        geko = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [
            { nixpkgs.overlays = [ self.overlays.default ]; }
            self.homeManagerModules.kamalen-shell
            ./hosts/home.nix
          ];
        };
      };

      # CI checks (nix flake check)
      checks = forAllSystems ({ system, ... }: {
        mango-ext = self.packages.${system}.mango-ext;
        awww = self.packages.${system}.awww;
        mpvpaper = self.packages.${system}.mpvpaper;
        rmpc = self.packages.${system}.rmpc;
        tiramisu = self.packages.${system}.tiramisu;
        gpu-screen-recorder = self.packages.${system}.gpu-screen-recorder;
        pokemon-colorscripts = self.packages.${system}.pokemon-colorscripts;
        kamalen-python = self.packages.${system}.kamalen-python;
      });
    };
}

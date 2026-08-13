{
  description = "LowLevelLover's NixOS-Hyprland";

  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    ags.url = "github:aylur/ags/v1";

    hyprland.url = "github:hyprwm/Hyprland";

    # Hyprland ecosystem pieces, pinned to the SAME dependency set as the
    # Hyprland flake above. Without these `follows`, each flake would pull its
    # own hyprutils/hyprlang/aquamarine and you can end up with a portal or
    # polkit agent built against a different ABI than the running compositor.
    xdg-desktop-portal-hyprland = {
      url = "github:hyprwm/xdg-desktop-portal-hyprland";
      inputs.nixpkgs.follows = "hyprland/nixpkgs";
      inputs.systems.follows = "hyprland/systems";
      inputs.hyprland-protocols.follows = "hyprland/hyprland-protocols";
      inputs.hyprlang.follows = "hyprland/hyprlang";
      inputs.hyprutils.follows = "hyprland/hyprutils";
      inputs.hyprwayland-scanner.follows = "hyprland/hyprwayland-scanner";
    };

    hyprpolkitagent = {
      url = "github:hyprwm/hyprpolkitagent";
      inputs.nixpkgs.follows = "hyprland/nixpkgs";
      inputs.systems.follows = "hyprland/systems";
      inputs.hyprutils.follows = "hyprland/hyprutils";
      inputs.hyprlang.follows = "hyprland/hyprlang";
      inputs.hyprgraphics.follows = "hyprland/hyprgraphics";
      inputs.aquamarine.follows = "hyprland/aquamarine";
    };

    thyx.url = "github:rccyx/thyx";
  };

  outputs = inputs @ { self, nixpkgs-stable, nixpkgs-unstable, ... }:
  let
    system = "x86_64-linux";
    host = "lowlevellover";
    username = "farzin";

    # ----------------------------------------------------
    # WORKING overlay to disable certificate checking
    # for ANY URL under *.nvidia.com
    # ----------------------------------------------------
    nvidiaInsecureOverlay = (final: prev: {
      fetchurl = args:
        let
          singleUrl =
            if args ? url then args.url else null;

          urlList =
            if args ? urls then args.urls else [];

          anyUrl =
            if singleUrl != null then [ singleUrl ] else urlList;

          isNvidiaURL = url:
            builtins.match "https?://.*nvidia\\.com.*" url != null;

          hasNvidia =
            builtins.any isNvidiaURL anyUrl;
        in
          if hasNvidia
          then prev.fetchurl (args // { curlOpts = "--insecure"; })
          else prev.fetchurl args;
    });
    pkgs = import nixpkgs-stable {
      inherit system;
      config.allowUnfree = true;

      overlays = [
        nvidiaInsecureOverlay
        (final: prev: {
          vaapiIntel = prev.vaapiIntel.override {
            enableHybridCodec = true;
          };
        })
      ];
    };

    unstablePkgs = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        nvidiaInsecureOverlay
      ];
    };
  in {
    nixosConfigurations = {
      "${host}" = nixpkgs-stable.lib.nixosSystem {
        specialArgs = {
          inherit system inputs username host;
          pkgs-stable = pkgs;
          pkgs-unstable = unstablePkgs;
        };

        modules = [
          ./configuration.nix
          inputs.thyx.nixosModules.default

          {
            services.displayManager.sddm.thyx.enable = true;
            services.displayManager.sddm.wayland.enable = true;
          }

          {
            environment.systemPackages = with pkgs; [
              (callPackage ./pkgs/ktea.nix {})
              (callPackage ./pkgs/codegraph.nix {})
              (callPackage ./pkgs/genyconnect.nix {})
              (callPackage ./pkgs/orca.nix {})
            ];
          }
        ];
      };
    };
  };
}

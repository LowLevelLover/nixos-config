{
  description = "LowLevelLover's NixOS-Hyprland";

  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    ags.url = "github:aylur/ags/v1";

    hyprland.url = "github:hyprwm/Hyprland";
    hypr-dynamic-cursors = {
      url = "github:VirtCode/hypr-dynamic-cursors";
      inputs.hyprland.follows = "hyprland";
    };
    hyprgrass = {
      url = "github:horriblename/hyprgrass";
      inputs.hyprland.follows = "hyprland";
    };
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

          {
            environment.systemPackages = with pkgs; [
              (callPackage ./pkgs/ktea.nix {})
            ];
          }
        ];
      };
    };
  };
}

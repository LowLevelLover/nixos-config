{
  description = "LowLevelLover's NixOS-Hyprland"; 
  	
  inputs = {
  	nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
	
  	#hyprland.url = "github:hyprwm/Hyprland"; # hyprland development
  	#distro-grub-themes.url = "github:AdisonCavani/distro-grub-themes";
  	ags.url = "github:aylur/ags/v1"; # aylurs-gtk-shell-v1
  };

  outputs = 
	inputs@{ self, nixpkgs-stable, nixpkgs-unstable, ... }:
	let
    system = "x86_64-linux";
    host = "lowlevellover";
    username = "farzin";

    pkgs = import nixpkgs-stable {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };
    unstablePkgs = import nixpkgs-unstable { inherit system; };
  in
  {
    apps.${system}.zellij = {
        type = "app";
        program = "${unstablePkgs.zellij}/bin/zellij";
    };

  	nixosConfigurations = {
      "${host}" = nixpkgs-stable.lib.nixosSystem rec {
        specialArgs = { 
      			inherit system;
      			inherit inputs;
      			inherit username;
      			inherit host;
    		};
        modules = [ 
          ./configuration.nix
        ];
			};
		};
	};
}

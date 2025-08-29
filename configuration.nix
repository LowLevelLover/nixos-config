# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs-stable, pkgs-unstable, host, username, options, lib, inputs, system, ... }:

# Must set this ip as .env
let
  httpProxy = "http://10.164.88.51:10809";

  python-packages = pkgs-stable.python3.withPackages (
    ps:
      with ps; [
        requests
      ]
  );
in
{

  imports =
    [
      ./hardware-configuration.nix
    ];

  nix.settings = {
    download-attempts = 5;
    # http-connections = 50;
    # stalled-download-timeout = 300;
    # connect-timeout = 60;
    # max-jobs = 1;
    # builders-use-substitutes = true;
    # http-connections = 1;
  };

  boot = {
    # kernelPackages = pkgs-stable.linuxPackages_zen; # zen Kernel
    # kernelPackages = pkgs-stable.linuxPackages_latest; # Kernel 
    kernelPackages = pkgs-stable.linuxPackages_6_12; # Kernel 

    kernelParams = [
      "systemd.mask=systemd-vconsole-setup.service"
      "systemd.mask=dev-tpmrm0.device" #this is to mask that stupid 1.5 mins systemd bug
      "nowatchdog" 
      # "modprobe.blacklist=sp5100_tco" #watchdog for AMD
      "modprobe.blacklist=iTCO_wdt" #watchdog for Intel
      "nvidia-drm.modeset=1"
 	  ];

    kernel.sysctl = {
      "vm.swappiness" = 10;
    };

    # Blacklist nouveau to avoid conflicts
    blacklistedKernelModules = [ "nouveau" ];

    # This is for OBS Virtual Cam Support
    kernelModules = [ "v4l2loopback" "snd_hda_intel" "vboxdrv" "hid_apple" ];
    extraModprobeConfig = ''
        options hid_apple fnmode=2
    '';
    extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    
    initrd = { 
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
      kernelModules = [ ];
    };

    # Needed For Some Steam Games
    #kernel.sysctl = {
    #  "vm.max_map_count" = 2147483642;
    #};

    ## BOOT LOADERS: NOTE USE ONLY 1. either systemd or grub  
    # Bootloader SystemD
    loader.systemd-boot.enable = true;
    loader.systemd-boot.editor = false;
    loader.systemd-boot.configurationLimit = 10;
  
    loader.efi = {
	    efiSysMountPoint = "/boot"; #this is if you have separate /efi partition
	    canTouchEfiVariables = true;
	  };

    loader.timeout = 5;    
  			
    ## -end of BOOTLOADERS----- ##
  
    # Make /tmp a tmpfs
    tmp = {
      useTmpfs = false;
      tmpfsSize = "30%";
      };
    
    # Appimage Support
    binfmt.registrations.appimage = {
      wrapInterpreterInShell = false;
      interpreter = "${pkgs-stable.appimage-run}/bin/appimage-run";
      recognitionType = "magic";
      offset = 0;
      mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
      magicOrExtension = ''\x7fELF....AI\x02'';
      };

    supportedFilesystems = ["ntfs"];

    plymouth.enable = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs-stable; [
      mesa.drivers
      libglvnd
      intel-media-driver
      nvidia-vaapi-driver
      libvdpau-va-gl
      libva
      libva-utils
      vaapiVdpau
      libvdpau
      vdpauinfo
      vulkan-loader
      vulkan-tools
    ];
  };

    
  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;
    
    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    powerManagement.enable = true;
    
    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = true;
    
    #dynamicBoost.enable = true; # Dynamic Boost

    nvidiaPersistenced = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = true;
    
    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    
    nvidiaSettings = true;
    
    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    #   version = "555.58.02";
    #   sha256_64bit = "sha256-xctt4TPRlOJ6r5S54h5W6PT6/3Zy2R4ASNFPu8TSHKM=";
    #   sha256_aarch64 = "sha256-xctt4TPRlOJ6r5S54h5W6PT6/3Zy2R4ASNFPu8TSHKM=";
    #   openSha256 = "sha256-ZpuVZybW6CFN/gz9rx+UJvQ715FZnAOYfHn5jt5Z2C8=";
    #   settingsSha256 = "sha256-ZpuVZybW6CFN/gz9rx+UJvQ715FZnAOYfHn5jt5Z2C8=";
    #   persistencedSha256 = lib.fakeSha256;
    # };
  };

  hardware.nvidia.prime = {
    offload = {
      enable = true;
      enableOffloadCmd = true;
    };
    # Make sure to use the correct Bus ID values for your system!
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  time.hardwareClockInLocalTime = true;

  # Use the systemd-boot EFI boot loader.
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";

  networking.hostName = "lowlevellover"; # Define your hostname.
  # # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  fonts.packages = with pkgs-stable; [
    (nerdfonts.override { fonts = [ "FiraCode"]; })
  ];

  users.extraGroups.vboxusers.members = [ "farzin" ];

  environment.systemPackages = (with pkgs-stable; [
    # System Packages
    btrfs-progs
    cpufrequtils
    fd
    glib
    ffmpeg
    gsettings-qt
    killall
    libappindicator
    libnotify
    openssl
    nano
    pciutils
    helix
    vim
    qt6.qtwayland
    libinput
    seatd
    unrar
    ntfs3g
    zellij
    bat
    git
    fish
    fzf
    starship
    dust
    brave
    vlc
    obs-studio
    cudatoolkit
    eza
    zoxide
    variety
    yazi
    telegram-desktop
    cmake
    meson
    cpio
    asusctl
    supergfxctl
    pkg-config
    tlp
    xdg-desktop-portal-hyprland
    ninja
    udis86
    wayland-protocols
    wayland-scanner
    freeglut
    mesa
    libdrm
    libGL
    stow
    gitui
    motrix
    docker-compose
    zathura
    vscode-fhs
    shadow
    bruno
    calibre
    beekeeper-studio
    dbeaver-bin
    libepoxy
    google-chrome
    obsidian
    ripgrep
    xclip
    nodejs
    nodePackages.npm
    kubectl
    krew
    hyprshot
    mcron
    just

    # Qt platform plugins
    qt5.qtbase
    qt5.qtwayland
    qt5.qttools
    qt5.qtquickcontrols2

    # For X11 support
    xorg.libX11
    xorg.libxcb
    xorg.xcbutil
    xorg.libXrender

    # GStreamer
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base

    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav

    gst_all_1.gst-vaapi
    fdk_aac

    # JetBrains
    jetbrains.rust-rover
    jetbrains.idea-community-bin
    jetbrains.idea-ultimate
    jetbrains.clion
    jetbrains.webstorm

    # Kotlin
    openjdk17
    gradle
    kotlin
    kotlin-language-server

    # Hyprland
    ags # desktop overview  
    btop
    brightnessctl # for brightness control
    cava
    cliphist
    loupe
    gnome-system-monitor
    grim
    gtk-engine-murrine #for gtk themes
    hypridle
    imagemagick 
    inxi
    jq
    kitty
    libsForQt5.qtstyleplugin-kvantum #kvantum
    networkmanagerapplet
    nwg-displays
    nwg-look
    nvtopPackages.full	 
    pamixer
    pavucontrol
    playerctl
    polkit_gnome
    libsForQt5.qt5ct
    kdePackages.qt6ct
    kdePackages.qtwayland
    kdePackages.qtstyleplugin-kvantum #kvantum
    rofi-wayland
    slurp
    swappy
    swaynotificationcenter
    swww
    unzip
    wallust
    wl-clipboard
    wlogout
    xarchiver
    yad
    yt-dlp
    xwaylandvideobridge
    xdg-desktop-portal

    bluez
    bluez-tools
    blueman
    
    # C
    gcc
    glibc
    clang
    clang-tools
    gdb
    gnumake
    valgrind

    # Rust
    rustup

    #Python
    uv
    ruff
    basedpyright
    python3Packages.debugpy

    ]) ++ [
  	  python-packages
  ] ++ (with pkgs-unstable; [
    code-cursor
    zellij
    jujutsu
    yaak
    pocketbase
    zed-editor
  ]);

  programs = {
    neovim = {
      enable = true;
      defaultEditor = true;
    };

    nix-ld.enable = true;

    hyprland = {
      enable = true;
      portalPackage = pkgs-stable.xdg-desktop-portal-hyprland; # xdph none git
      xwayland.enable = true;
    };

    waybar.enable = true;
    firefox.enable = true;
    fish.enable = true;
    hyprlock.enable = true;
    git.enable = true;
    nm-applet.indicator = true;
    thunar.enable = true;
    thunar.plugins = with pkgs-stable.xfce; [
		  exo
		  mousepad
		  thunar-archive-plugin
		  thunar-volman
		  tumbler
	  ];

    virt-manager.enable = false;

    xwayland.enable = true;

    dconf.enable = true;
    seahorse.enable = true;
    fuse.userAllowOther = true;
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    command-not-found.enable = false;
    nix-index = {
      enable = true;
      enableBashIntegration = true; # or Zsh if you use that
    };
  };

  xdg.portal = {
    enable = true;
    wlr.enable = false;
    extraPortals = [
      pkgs-stable.xdg-desktop-portal-hyprland
    ];
    config = {
      hyprland = {
        default = [ "hyprland" ];
      };
    };
    configPackages = [
      pkgs-stable.xdg-desktop-portal-gtk
      pkgs-stable.xdg-desktop-portal
    ];
  };
  
  # Set your time zone.
  time.timeZone = "Asia/Tehran";

    networking.proxy.default = "${httpProxy}";
    networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain,::1";

  networking.extraHosts = ''
    127.0.0.1 kafka
    # 192.168.1.100 kafka-node-1
    # 192.168.1.101 kafka-node-2
  '';

  # networking.nameservers = [ "185.51.200.2" "178.22.122.100" ];
  # networking.networkmanager.insertNameservers = [ "185.51.200.2" "178.22.122.100" ];

  environment.variables = {
     http_proxy = "${httpProxy}";
     https_proxy = "${httpProxy}";
     all_proxy = "${httpProxy}";
     no_proxy = "127.0.0.1,localhost,internal.domain,::1";
     EDITOR = "nvim";
  };
   
  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # hardware.pulseaudio.enable = true;
  # OR

	hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
	    General = {
	      Enable = "Source,Sink,Media,Socket";
	      Experimental = true;
	    };
    };
  };

  # Security / Polkit
  security.rtkit.enable = true;
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.isInGroup("users")
          && (
            action.id == "org.freedesktop.login1.reboot" ||
            action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
            action.id == "org.freedesktop.login1.power-off" ||
            action.id == "org.freedesktop.login1.power-off-multiple-sessions"
          )
        )
      {
        return polkit.Result.YES;
      }
    })
  '';

  security.wrappers.newuidmap = {
    source = "${pkgs-stable.shadow}/bin/newuidmap";
    setuid = true;
  };

  security.wrappers.newgidmap = {
    source = "${pkgs-stable.shadow}/bin/newgidmap";
    setuid = true;
  };

  services = {
  
    asusd.enable = true;
    asusd.enableUserService = true;
    supergfxd.enable = true;

    tlp.settings = {
      "START_CHARGE_THRESH_BAT0" = 40;  # Start charging below 40%
      "STOP_CHARGE_THRESH_BAT0" = 80;   # Stop charging at 80%
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };

    udev.enable = true;
    envfs.enable = true;
    dbus.enable = true;

    fstrim = {
      enable = true;
      interval = "weekly";
    };

    rpcbind.enable = false;
    nfs.server.enable = false;

    flatpak.enable = false;

    blueman.enable = true;

    fwupd.enable = true;

    upower.enable = true;
  
    gnome.gnome-keyring.enable = true;

    # Enable touchpad support (enabled default in most desktopManager).
    libinput.enable = true;

    xserver.xkb = {
      layout = "us";
      variant = "";
    };

    # Enable the OpenSSH daemon.
    openssh.enable = true;
    xserver.videoDrivers = [ "nvidia" ];

    seatd.enable = true;

    gvfs.enable = true;
  
    xserver.displayManager.gdm = {
      enable = true;
      wayland = true;
    };
  };

  security.pam.services.hyprlock = {};

  powerManagement = {
  	enable = true;
	  cpuFreqGovernor = "schedutil";
  };

  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [ "https://hyprland.cachix.org" ];
      trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # Virtualization / Containers
  virtualisation = {
    virtualbox.host.enable = true;
    virtualbox.guest.enable = true;
    virtualbox.guest.dragAndDrop = true;

    containers.enable = true;
    containers.storage.settings = {
      storage = {
        driver = "overlay";
        runroot = "/run/containers/storage";
        graphroot = "/var/lib/containers/storage";
        rootless_storage_path = "/tmp/containers-$USER";
        options.overlay.mountopt = "nodev,metacopy=on";
      };
    };

    libvirtd.enable = true;
    # oci-containers.backend = "podman";
    # podman = {
    #   enable = true;
    #   dockerCompat = true;
    #   defaultNetwork.settings.dns_enabled = true;
    # };
    oci-containers.backend = "docker";
    docker.enable = true;
  };

  hardware.nvidia-container-toolkit.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.farzin= {
    shell = pkgs-stable.fish;
    isNormalUser = true;
    subUidRanges = [
      { startUid = 100000; count = 65536; }
    ];
    subGidRanges = [
      { startGid = 100000; count = 65536; }
    ];
    extraGroups = [ "wheel" "docker" ]; # Enable ‘sudo’ for the user.
    initialPassword = "password"; # Change Later
    packages = with pkgs-stable; [
      tree
    ];
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs-stable version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?
}

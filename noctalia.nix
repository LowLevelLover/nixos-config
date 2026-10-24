{ config, lib, pkgs-stable, inputs, ... }:

# Noctalia desktop shell (bar, notifications, launcher, lock, idle, polkit),
# run as the systemd user service noctalia.service.
let
  noNvidiaEnv = import ./no-nvidia-env.nix;

  # A user service has no logind session of its own, so Noctalia only finds
  # the graphical session (for `loginctl lock-session` and LockedHint) through
  # $XDG_SESSION_ID. Resolve it from the user's display session at each start.
  sessionEnv = pkgs-stable.writeShellScript "noctalia-session-env" ''
    s=$(${config.systemd.package}/bin/loginctl show-user "$UID" --property=Display --value)
    echo "''${s:+XDG_SESSION_ID=$s}" > "$1"
  '';
in
{
  imports = [ inputs.noctalia.nixosModules.default ./noctalia-plugins.nix ];

  programs.noctalia = {
    enable = true;
    # Unit: noctalia.service, WantedBy/PartOf graphical-session.target.
    systemd.enable = true;
    # Not recommendedServices: it would enable power-profiles-daemon, which
    # conflicts with TLP. NetworkManager, bluetooth and upower are already on.
  };

  # Noctalia's power-profile switch speaks the power-profiles-daemon D-Bus API;
  # tlp-pd provides it on top of TLP.
  services.tlp.pd.enable = true;

  # Merges into the module's unit, which already drops NixOS's default PATH,
  # so commands run from the bar/launcher keep the full session PATH.
  systemd.user.services.noctalia = {
    # Noctalia links glvnd EGL; keep it off the NVIDIA GPU so RTD3 can power it down.
    environment = noNvidiaEnv;
    # graphical-session.target can start before Hyprland exports WAYLAND_DISPLAY;
    # skip instead of crash-looping into the start limit, which would also
    # block Hyprland's own `systemctl --user restart noctalia.service`.
    unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
    serviceConfig = {
      ExecStartPre = "-${sessionEnv} %t/noctalia-session.env";
      EnvironmentFile = "-%t/noctalia-session.env";
    };
  };

  # Launcher/dock/taskbar apps run as transient app-<id>@<uuid>.service units
  # (launch_apps_as_systemd_services), and Noctalia copies its whole
  # environment into them (systemd-run -E). Drop the Mesa-only override there
  # so apps and games can still use the NVIDIA GPU.
  systemd.user.units."app-.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      UnsetEnvironment=${lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "${n}=${v}") noNvidiaEnv)}
    '';
  };

  # Lock screen authenticates against the stock "login" PAM service, and the
  # polkit agent uses polkit's socket-activated helper; nothing to add for either.

  nix.settings = {
    substituters = [ "https://noctalia.cachix.org" ];
    trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
  };
}

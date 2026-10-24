{ config, lib, pkgs-stable, pkgs-unstable, ... }:

# greetd + Noctalia Greeter login screen (replaces SDDM).
#
# Adapted from nixpkgs-unstable's services/display-managers/noctalia-greeter.nix.
# That module can't be imported on 26.05: it sets
# security.polkit.enablePkexecWrapper, which doesn't exist here yet. Switch to
# services.displayManager.noctalia-greeter once on 26.11.
let
  # 26.05 ships 1.3.1, whose sync helper predates the constrained `--sync`
  # protocol Noctalia 5.3 uses. Cached on cache.nixos.org, and its
  # libgbm/glibc match the Hyprland flake build that already runs against the
  # system Mesa here.
  greeter = pkgs-unstable.noctalia-greeter;

  # Admin config only. No appearance keys on purpose: greeter.toml wins over
  # the sync.toml Noctalia writes, so they would mask the synced look.
  greeterToml = (pkgs-stable.formats.toml { }).generate "greeter.toml" {
    session.default = "Hyprland"; # desktop-entry Name=, not the file name
    user.default = "farzin"; # open on the password step
    cursor = {
      # Same theme as the Hyprland session; the copy in ~/.local/share/icons
      # isn't readable by the greeter user.
      theme = "Bibata-Modern-Amber";
      size = 24;
      path = "${pkgs-stable.bibata-cursors}/share/icons";
    };
  };

  # Runs the greeter on the iGPU alone unless a monitor hangs off the dGPU:
  # the internal panel (eDP-1) is on the iGPU, and opening the dGPU (or
  # NVIDIA's EGL vendor) would wake it out of RTD3 while the login screen sits
  # there. cardN numbering isn't stable and the by-path names contain ':',
  # WLR_DRM_DEVICES' separator, so resolve the node from the PCI address.
  # Falls back to wlroots' own GPU pick (external screen on the dGPU, MUX in
  # dGPU mode).
  launcher = pkgs-stable.writeShellScript "noctalia-greeter-launch" ''
    igpu=/sys/bus/pci/devices/0000:00:02.0
    card=
    for _ in {1..50}; do # i915 can still be probing when greetd starts
      for c in "$igpu"/drm/card[0-9]*; do
        [ -e "$c" ] && card=''${c##*/}
      done
      [ -n "$card" ] && break
      ${pkgs-stable.coreutils}/bin/sleep 0.2
    done

    dgpu_out=
    for s in /sys/bus/pci/devices/*/drm/card[0-9]*/card*-*/status; do
      case $s in "$igpu"/*) continue ;; esac
      read -r st 2>/dev/null <"$s" && [ "$st" = connected ] && dgpu_out=1
    done

    if [ -n "$card" ] && [ -z "$dgpu_out" ]; then
      export WLR_DRM_DEVICES=/dev/dri/$card
      ${lib.concatStringsSep "\n  " (
        lib.mapAttrsToList (n: v: "export ${n}=${lib.escapeShellArg v}") (import ./no-nvidia-env.nix)
      )}
    fi

    # PAM's environment already carries this; don't depend on it to find
    # Hyprland's session file.
    export XDG_DATA_DIRS=${config.services.displayManager.sessionData.desktops}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}
    exec ${greeter}/bin/noctalia-greeter-session "$@"
  '';
in
{
  services.greetd = {
    enable = true;
    # The session wrapper starts the greeter's bundled wlroots compositor.
    settings.default_session.command = "${launcher}";
  };

  # greetd's module already defaults this to gnome-keyring.enable; pinned so
  # the login keyring keeps unlocking at login like it did under SDDM.
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Noctalia finds noctalia-greeter and its sync helper on PATH, and polkit
  # picks up the helper's action from share/polkit-1.
  environment.systemPackages = [ greeter ];

  # Greeter state: greeter.toml (declarative) + sync.toml and wallpaper files
  # written by Noctalia's greeter sync. Must be owned by the greeter account.
  systemd.tmpfiles.settings."10-noctalia-greeter" = {
    "/var/lib/noctalia-greeter".d = {
      user = "greeter";
      group = "greeter";
      mode = "0750";
    };
    "/var/lib/noctalia-greeter/greeter.toml"."L+".argument = "${greeterToml}";
  };

  # User avatars on the login screen; Noctalia writes them as IconFile.
  services.accounts-daemon.enable = true;

  # Lets Noctalia's auto-sync run without a password prompt. Covers only the
  # constrained `noctalia-greeter-apply-appearance --sync` (appearance and
  # outputs into /var/lib/noctalia-greeter, never session commands), and only
  # from farzin's active local session.
  security.polkit.extraConfig = lib.mkAfter ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.noctalia.greeter.sync-appearance" &&
          action.lookup("program") == "${greeter}/bin/noctalia-greeter-apply-appearance" &&
          action.lookup("user") == "root" &&
          subject.local && subject.active && subject.user == "farzin") {
        return polkit.Result.YES;
      }
    });
  '';
}

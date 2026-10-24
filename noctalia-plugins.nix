{ pkgs-stable, pkgs-unstable, ... }:

# Runtime dependencies of the Noctalia plugins turned on in
# ~/.config/noctalia/config.toml ([plugins] enabled). Noctalia clones and
# updates the plugins itself (~/.local/state/noctalia/plugins) but only lists
# what they need, so the missing tools are installed here.
let
  pkgs = pkgs-stable;

  # shelf: its drag-and-drop window is a PyGObject GTK 4 app. NixOS has no
  # global typelib path, so wrapGAppsHook4 collects GTK 4's typelibs into the
  # wrapper. gtk4-layer-shell has to be preloaded ahead of libwayland-client;
  # the helper skips its own re-exec when LD_PRELOAD already has it.
  shelfPython = pkgs.stdenvNoCC.mkDerivation {
    name = "noctalia-shelf-python";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.wrapGAppsHook4 pkgs.gobject-introspection pkgs.makeWrapper ];
    buildInputs = [ pkgs.gtk4 pkgs.gtk4-layer-shell ];
    # Wrap by hand: the hook's own wrapper changes argv0, and python then misses
    # the env's site-packages (no `gi`). Reuse only the arguments it collected.
    dontWrapGApps = true;
    installPhase = "mkdir -p $out/bin";
    postFixup = ''
      makeWrapper ${pkgs.python3.withPackages (ps: [ ps.pygobject3 ])}/bin/python3 $out/bin/noctalia-shelf-python \
        "''${gappsWrapperArgs[@]}" \
        --prefix LD_PRELOAD : ${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so.0
    '';
  };

  # cursor: its engine (curmgr.py, shipped in the plugin) imports wand and
  # win2xcur to build themes. Point the plugin's engine_path at this instead of
  # putting those modules into the system python3.
  cursorPython = pkgs.python3.withPackages (ps: [ ps.wand (ps.toPythonModule pkgs.win2xcur) ]);
  cursorEngine = pkgs.writeShellScriptBin "noctalia-cursor-engine" ''
    exec ${cursorPython}/bin/python3 -B \
      "''${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/plugins/materialized/community/cursor/bin/curmgr.py" "$@"
  '';

  # audio-switcher, soundcore-buds: only the pactl/paplay clients (they talk to
  # pipewire-pulse); the full pulseaudio package would also bring its daemon's
  # autostart entry.
  pulseClients = pkgs.runCommand "pulseaudio-clients" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.pulseaudio}/bin/pactl ${pkgs.pulseaudio}/bin/paplay $out/bin/
  '';
in
{
  environment.systemPackages = [
    pulseClients
    pkgs-unstable.open-scq30 # soundcore-buds; tested against 2.11, stable has 2.6
    pkgs.nix-search-tv # nix-search (/nix)
    pkgs.psmisc # fuser: network-monitor's "stop the process on this port"
    pkgs.smartmontools # smartctl: drive-health
    pkgs.zenity # cursor: file pickers for importing themes
    pkgs.lua5_4 # hyprland-settings saves and reverts through `lua txn.lua`
    shelfPython
    cursorEngine
  ];
}

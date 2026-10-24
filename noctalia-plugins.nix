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

  # soundcore-buds (and Sounds.sh): only the pactl/paplay clients (they talk to
  # pipewire-pulse); the full pulseaudio package would also bring its daemon's
  # autostart entry.
  pulseClients = pkgs.runCommand "pulseaudio-clients" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.pulseaudio}/bin/pactl ${pkgs.pulseaudio}/bin/paplay $out/bin/
  '';

  # bongocat: typing without putting farzin in the input group, which would let
  # any app read every keystroke. bongocat-keys@.service reads the keyboards as a
  # dynamic user in the input group and passes on only key down / repeat / up,
  # in evtest's line format, with every key name but Space/Enter stripped (the
  # plugin only uses those two, for the two-paw slap). The plugin runs
  # `<executable_path> <device>` per input_devices entry; the client ignores it.
  bongocatKeysReader = pkgs.writeScript "bongocat-keys-reader" ''
    #!${pkgs.python3}/bin/python3 -I
    import glob
    import os
    import select
    import struct
    import sys

    # struct input_event on 64-bit Linux: timeval (2 longs), type, code, value.
    FMT = "llHHi"
    SIZE = struct.calcsize(FMT)
    EV_KEY = 1
    # The plugin only looks at Space/Enter (two-paw slap); every other key is anonymous.
    NAMES = {28: "KEY_ENTER", 57: "KEY_SPACE", 96: "KEY_ENTER"}

    fds = []
    for path in sys.argv[1:] or sorted(glob.glob("/dev/input/by-path/*-event-kbd")):
        try:
            fds.append(os.open(path, os.O_RDONLY))
        except OSError as e:
            print(f"{path}: {e}", file=sys.stderr)

    try:
        while fds:
            ready, _, _ = select.select(fds, [], [])
            lines = []
            for fd in ready:
                try:
                    data = os.read(fd, SIZE * 64)
                except OSError:
                    data = b""
                if not data:  # unplugged
                    fds.remove(fd)
                    continue
                for off in range(0, len(data) - SIZE + 1, SIZE):
                    _, _, etype, code, value = struct.unpack_from(FMT, data, off)
                    if etype == EV_KEY and code < 0x100:  # keys only, no buttons
                        lines.append(f"type 1 (EV_KEY), {NAMES.get(code, 'KEY')}, value {value}\n")
            if lines:
                os.write(1, "".join(lines).encode())
    except BrokenPipeError:
        pass
  '';
  bongocatKeys = pkgs.writeShellScriptBin "noctalia-bongocat-keys" ''
    exec ${pkgs.socat}/bin/socat -u UNIX-CONNECT:/run/bongocat-keys.sock STDOUT
  '';

  # drive-health: smartctl needs root for the NVMe controllers (/dev/nvme0 is
  # root-only, 0600), and on NixOS the plugin won't install its own collector.
  # This is the plugin's collect_raw.sh pinned from upstream rather than run from
  # its auto-updating checkout in ~/.local/state, which any farzin process (or a
  # bad plugin update) could rewrite into root code. The plugin wants this exact
  # collector_version (EXPECTED_COLLECTOR_VERSION in collector.luau); when it
  # asks for an upgrade, bump rev + hash.
  driveHealthCollector = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/noctalia-dev/community-plugins/ff289e523fb3dca794979dd3476d336642296463/drive-health/scripts/collect_raw.sh";
    hash = "sha256-O1j5ajQQTkerV6iVROa4xbnjLe4NXZOVI0BznDIu6dw="; # collector_version 2.0.1
  };
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
    bongocatKeys
  ];

  # drive-health's Full SMART mode reads /run/noctalia-drive-health/raw.json
  # (system_collector_enabled in the plugin settings). Mirrors the plugin's
  # packaging/noctalia-drive-health.{service.in,timer}.
  systemd.services.noctalia-drive-health = {
    description = "Collect read-only SMART data for Noctalia Drive Health";
    documentation = [ "man:smartctl(8)" ];
    after = [ "local-fs.target" ];
    path = with pkgs; [ coreutils gnused util-linux smartmontools ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/sh ${driveHealthCollector} --output /run/noctalia-drive-health/raw.json";
      Group = "users"; # farzin's primary group reads the cache
      RuntimeDirectory = "noctalia-drive-health";
      RuntimeDirectoryMode = "0750";
      RuntimeDirectoryPreserve = "yes";
      UMask = "0027";
      StandardOutput = "null";
      TimeoutStartSec = "60s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateNetwork = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      CapabilityBoundingSet = [ "CAP_DAC_OVERRIDE" "CAP_SYS_ADMIN" "CAP_SYS_RAWIO" ];
      ReadWritePaths = [ "/run/noctalia-drive-health" ];
    };
  };

  systemd.timers.noctalia-drive-health = {
    description = "Refresh SMART data for Noctalia";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "20s";
      OnUnitActiveSec = "15min";
      AccuracySec = "5s";
      Unit = "noctalia-drive-health.service";
    };
  };

  systemd.sockets.bongocat-keys = {
    description = "Key presses for the Noctalia bongocat widget";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "/run/bongocat-keys.sock" ];
    socketConfig = {
      Accept = true; # one reader per connection
      SocketUser = "farzin";
      SocketMode = "0600";
    };
  };

  systemd.services."bongocat-keys@" = {
    description = "Key presses for the Noctalia bongocat widget";
    serviceConfig = {
      ExecStart = bongocatKeysReader;
      StandardInput = "socket";
      StandardOutput = "socket";
      DynamicUser = true;
      SupplementaryGroups = [ "input" ];
      DevicePolicy = "closed";
      DeviceAllow = [ "char-input r" ];
      PrivateNetwork = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
      CapabilityBoundingSet = "";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };
  };
}

{ stdenv, appimageTools, fetchurl, lib, autoPatchelfHook, makeWrapper
, symlinkJoin, qt6, libglvnd, e2fsprogs }:

let
  pname = "genyconnect";
  version = "1.4.800";

  src = fetchurl {
    url = "https://github.com/genyleap/GenyConnect/releases/download/v${version}/GenyConnect-${version}-linux-x86_64.AppImage";
    sha256 = "sha256-nVBAb+8ybBhaEfkSHzkY5kFbUR403zJ86MgrXSyE40A=";
  };

  # The AppImage bundles Qt 6.8, but its QML uses RectangularShadow (Qt 6.9+),
  # so we replace the bundled Qt with nixpkgs Qt 6.11. The module set mirrors
  # everything the AppImage shipped under usr/lib.
  qtModules = with qt6; [
    qtbase
    qtdeclarative
    qtsvg
    qtquicktimeline
    qtvirtualkeyboard
    qt3d
    qtshadertools
    qtwayland
    qtimageformats
    qt5compat
    qtscxml
  ];

  qtEnv = symlinkJoin {
    name = "${pname}-qt";
    paths = qtModules;
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
stdenv.mkDerivation {
  inherit pname version src;

  # GenyConnect is a VPN client: it shells out to `pkexec` to run its TUN
  # helper as root. pkexec needs the kernel's setuid bit, which bwrap (used by
  # appimageTools.wrapType2) disables via no_new_privs. So we run it
  # unsandboxed: extract the payload and patchelf it onto the host instead.
  dontUnpack = true;

  # We wrap the prebuilt binary ourselves below (custom QML/plugin paths).
  dontWrapQtApps = true;

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [ stdenv.cc.cc.lib libglvnd e2fsprogs ] ++ qtModules;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/genyconnect
    cp -r ${appimageContents}/usr/* $out/libexec/genyconnect/
    chmod -R u+w $out/libexec/genyconnect

    # Drop the stale bundled Qt 6.8 (libs, qml modules, plugins, config) so the
    # binaries resolve against nixpkgs Qt 6.11 via the rpath autoPatchelf sets.
    rm -f  $out/libexec/genyconnect/lib/libQt6*
    rm -rf $out/libexec/genyconnect/qml
    rm -rf $out/libexec/genyconnect/plugins
    rm -f  $out/libexec/genyconnect/bin/qt.conf

    # Keep the remaining bundled (non-Qt) libraries available to autoPatchelf.
    addAutoPatchelfSearchPath $out/libexec/genyconnect/lib

    makeWrapper $out/libexec/genyconnect/bin/GenyConnect $out/bin/genyconnect \
      --set QT_PLUGIN_PATH ${qtEnv}/lib/qt-6/plugins \
      --set QML2_IMPORT_PATH ${qtEnv}/lib/qt-6/qml \
      --set QML_IMPORT_PATH ${qtEnv}/lib/qt-6/qml

    install -Dm444 ${appimageContents}/genyconnect.desktop $out/share/applications/genyconnect.desktop 2>/dev/null || true
    cp -r ${appimageContents}/usr/share/icons $out/share/icons 2>/dev/null || true

    # Point the .desktop entry at the wrapped binary.
    if [ -f $out/share/applications/genyconnect.desktop ]; then
      substituteInPlace $out/share/applications/genyconnect.desktop \
        --replace-warn "Exec=GenyConnect" "Exec=genyconnect" \
        --replace-warn "Exec=AppRun" "Exec=genyconnect"
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "GenyConnect - cross-platform connectivity client by Genyleap";
    homepage = "https://github.com/genyleap/GenyConnect";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    maintainers = [ "LowLevelLover" ];
    mainProgram = "genyconnect";
  };
}

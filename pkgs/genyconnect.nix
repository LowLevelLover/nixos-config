{ appimageTools, fetchurl, lib, makeWrapper, symlinkJoin, qt6 }:

let
  pname = "genyconnect";
  version = "1.4.800";

  src = fetchurl {
    url = "https://github.com/genyleap/GenyConnect/releases/download/v${version}/GenyConnect-${version}-linux-x86_64.AppImage";
    sha256 = "sha256-nVBAb+8ybBhaEfkSHzkY5kFbUR403zJ86MgrXSyE40A=";
  };

  # The AppImage bundles Qt 6.8, but its QML uses RectangularShadow (Qt 6.9+),
  # so it fails to load. We override the bundled Qt with nixpkgs Qt 6.11.
  # The binary's RUNPATH ($ORIGIN/../lib) is searched *after* LD_LIBRARY_PATH,
  # so the newer Qt libs win while non-Qt bundled libs still resolve normally.
  qtEnv = symlinkJoin {
    name = "${pname}-qt";
    paths = with qt6; [
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
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };

  unwrapped = appimageTools.wrapType2 { inherit pname version src; };
in
symlinkJoin {
  name = "${pname}-${version}";
  paths = [ unwrapped ];
  nativeBuildInputs = [ makeWrapper ];

  postBuild = ''
    rm -f $out/bin/${pname}
    makeWrapper ${unwrapped}/bin/${pname} $out/bin/${pname} \
      --prefix LD_LIBRARY_PATH : ${qtEnv}/lib \
      --prefix QT_PLUGIN_PATH : ${qtEnv}/lib/qt-6/plugins \
      --prefix QML2_IMPORT_PATH : ${qtEnv}/lib/qt-6/qml \
      --prefix QML_IMPORT_PATH : ${qtEnv}/lib/qt-6/qml

    install -Dm444 ${appimageContents}/genyconnect.desktop -t $out/share/applications 2>/dev/null || true
    cp -r ${appimageContents}/usr/share/icons $out/share/icons 2>/dev/null || true
  '';

  meta = with lib; {
    description = "GenyConnect - cross-platform connectivity client by Genyleap";
    homepage = "https://github.com/genyleap/GenyConnect";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    maintainers = [ "LowLevelLover" ];
    mainProgram = pname;
  };
}

{ appimageTools, fetchurl, lib }:

let
  pname = "orca";
  version = "1.4.135";

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    hash = "sha256-E8vCVVDFXMtsRWgmkIVtG8hXt916lmwF7tjjhYLUuko=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/orca-ide.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/orca-ide.desktop \
      --replace-quiet 'Exec=AppRun' 'Exec=${pname}'
    cp -r ${appimageContents}/usr/share/icons $out/share/icons
  '';

  meta = with lib; {
    description = "Orca - AI-powered IDE by Stably";
    homepage = "https://github.com/stablyai/orca";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ "LowLevelLover" ];
    mainProgram = pname;
  };
}

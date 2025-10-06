{ stdenv, fetchurl, lib }:

stdenv.mkDerivation rec {
  pname = "ktea";
  version = "0.5.1";

  src = fetchurl {
    url = "https://github.com/jonas-grgt/ktea/releases/download/v${version}/ktea_${version}_linux_amd64.tar.gz";
    sha256 = "sha256-5yw7/82rOtuyF/M4gJzJggBEu2T1LggqoJ8UKiTs5Yo=";
  };

  sourceRoot = ".";
  installPhase = ''
    runHook preInstall
    install -Dm755 ktea $out/bin/${pname}
    runHook postInstall
  '';

  meta = with lib; {
    description = "Kafka TUI client";
    homepage = "https://github.com/jonas-grgt/ktea";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = ["LowLevelLover"];
  };
}

{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "ktea";
  version = "0.5.1";

  src = fetchurl {
    url = "https://github.com/jonas-grgt/ktea/releases/download/v${version}/ktea_${version}_linux_amd64.tar.gz";
    sha256 = "14n31g0cw1g2kzdzsfi43qclf0sgqpaqhmk2myqvyplwyiai8ajw";
  };

  sourceRoot = ".";
  installPhase = ''
    runHook preInstall
    install -Dm755 ktea $out/bin/${pname}
    runHook postInstall
  '';

  meta = with stdenv.lib; {
    description = "Kafka TUI client";
    homepage = "https://github.com/jonas-grgt/ktea";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = ["LowLevelLover"];
  };
}

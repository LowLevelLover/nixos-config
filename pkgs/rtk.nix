{ stdenv, fetchurl, lib }:

stdenv.mkDerivation rec {
  pname = "rtk";
  version = "0.42.4";

  src = fetchurl {
    url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-x86_64-unknown-linux-musl.tar.gz";
    sha256 = "sha256-NJdRFtoR4J5QJQHa91gUPgsi7TpCoQ62f7aTpicNnjY=";
  };

  sourceRoot = ".";
  installPhase = ''
    runHook preInstall
    install -Dm755 rtk $out/bin/${pname}
    runHook postInstall
  '';

  meta = with lib; {
    description = "Rust Token Killer - High-performance CLI proxy to minimize LLM token consumption";
    homepage = "https://github.com/rtk-ai/rtk";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = ["LowLevelLover"];
  };
}

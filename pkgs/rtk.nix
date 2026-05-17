{ stdenv, fetchurl, lib }:

stdenv.mkDerivation rec {
  pname = "rtk";
  version = "0.40.0";

  src = fetchurl {
    url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-x86_64-unknown-linux-musl.tar.gz";
    sha256 = "sha256-p10hCkRYdBBrwW2itO+6AdNtKXr6M+wTRyjy1fQu9a8=";
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

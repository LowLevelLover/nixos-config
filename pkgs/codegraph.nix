{ stdenv, fetchurl, lib, autoPatchelfHook }:

stdenv.mkDerivation rec {
  pname = "codegraph";
  version = "1.1.6";

  src = fetchurl {
    url = "https://github.com/colbymchenry/codegraph/releases/download/v${version}/codegraph-linux-x64.tar.gz";
    sha256 = "sha256-+rfx9stB8oJkiLRBHy68Ntp5km0ryg04IPT1EKvP0UM=";
  };

  # The archive bundles its own Node 24 runtime (a single ELF `node` binary,
  # native deps ship as WASM/node:sqlite so there are no *.node modules). The
  # ELF just needs its interpreter and libstdc++/libgcc paths fixed for NixOS.
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  sourceRoot = "codegraph-linux-x64";

  installPhase = ''
    runHook preInstall

    # Keep the bundle's node/lib/bin layout intact; the launcher execs ./node.
    mkdir -p $out/libexec/codegraph
    cp -r . $out/libexec/codegraph/

    mkdir -p $out/bin
    ln -s $out/libexec/codegraph/bin/codegraph $out/bin/codegraph

    runHook postInstall
  '';

  meta = with lib; {
    description = "Local-first code intelligence system that builds a semantic knowledge graph from any codebase";
    homepage = "https://github.com/colbymchenry/codegraph";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "codegraph";
  };
}

{
  lib,
  stdenv,
  makeWrapper,
  bun,
  cacert,
  chromium,
  nodejs,
}:

let
  maintainers = import ../../nix/maintainers.nix;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "geppetto";
  version = "0.1.0";

  deps = stdenv.mkDerivation {
    pname = "${finalAttrs.pname}-deps";
    inherit (finalAttrs) version;
    src = ../..;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-8BE1Vhfm+4PXf5p2GgEX91/cFT8b9wJmpeUY6u9wYNc=";

    nativeBuildInputs = [
      bun
      cacert
    ];

    buildPhase = ''
      runHook prBuild

      export HOME=$(pwd)/.home
      mkdir $HOME

      bun install --frozen-lockfile --production --filter @archival/geppetto
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      cp -r ./node_modules $out

      runHook postInstall
    '';

    dontFixup = true;
  };

  src = ../..;

  nativeBuildInputs = [
    bun
    makeWrapper
  ];

  buildInputs = [ nodejs ];

  buildPhase = ''
    runHook preBuild

    cp -r ${finalAttrs.deps} ./node_modules
    bun run --filter @archival/geppetto build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp ./packages/geppetto/dist/geppetto.js $out/bin/geppetto
    chmod +x $out/bin/geppetto

    runHook postInstall
  '';

  postInstall = ''
    wrapProgram $out/bin/geppetto --set PUPPETEER_EXECUTABLE_PATH ${chromium}/bin/chromium
  '';

  meta = {
    description = "Puppet puppeteer from an interactive shell";
    license = lib.licenses.agpl3Plus;
    maintainers = [ maintainers.rdrew ];
  };
})

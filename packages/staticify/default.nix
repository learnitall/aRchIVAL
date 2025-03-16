{
  lib,
  stdenv,
  makeWrapper,
  bun,
  cacert,
  chromium,
}:

let
  maintainers = import ../../nix/maintainers.nix;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "staticify";
  version = "0.1.0";

  deps = stdenv.mkDerivation {
    pname = "${finalAttrs.pname}-deps";
    inherit (finalAttrs) version;
    src = ../..;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-qTJII4Clr/gOGLIPsPyF5AHHcsFJqEIAdTzLGZ1ulSM=";

    nativeBuildInputs = [
      bun
      cacert
    ];

    buildPhase = ''
      runHook prBuild

      export HOME=$(pwd)/.home
      mkdir $HOME

      bun install --frozen-lockfile --production --filter @archival/staticify
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

  buildPhase = ''
    runHook preBuild

    cp -r ${finalAttrs.deps} ./node_modules
    bun run --filter @archival/staticify build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp ./packages/staticify/dist/staticify $out/bin/staticify
    chmod +x $out/bin/staticify

    runHook postInstall
  '';

  postInstall = ''
    wrapProgram $out/bin/staticify --set PUPPETEER_EXECUTABLE_PATH ${chromium}/bin/chromium
  '';

  dontFixup = true;

  meta = {
    description = "Download a static version of a web page";
    license = lib.licenses.agpl3Plus;
    maintainers = [ maintainers.rdrew ];
  };
})

# Two stage build process for wrangler.
#
# First, we'll create a pruned version of the workers-sdk monorepo that contains
# wrangler, its in-repo dependencies, and all external dependencies. This is saved
# as a fixed-output derivation.
#
# Second, we'll build wrangler from the pruned monorepo and copy the build outputs
# (defined in packages.json under the "files" key) to the output directory.
# for the project and its dependencies.
{
  stdenv,
  fetchFromGitHub,
  cacert,
  jq,
  nodejs,
  openssl,
  pnpm_9,
  turbo,
}:
let
  pname = "wrangler";
  version = "3.109.2";

  src = fetchFromGitHub {
    owner = "cloudflare";
    repo = "workers-sdk";
    rev = "wrangler@${version}";
    hash = "sha256-SiI11ax7xHH3chT/0DU95Q8Vy9MXS3+K8ual0eI6Qm8=";
  };

  deps = stdenv.mkDerivation {
    name = "${pname}-${version}-deps";
    inherit src;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-sxF/SNkMPNgMCI9NFnP9P5sV4sgBNq/tz7irMNTPW70=";

    nativeBuildInputs = [
      cacert # Need CA certificates to connect to the registry.
      nodejs
      pnpm_9
      turbo
    ];

    configurePhase = ''
      runHook preConfigure

      export HOME=$(pwd)/.home
      mkdir $HOME
      export STORE=$(pwd)/.store
      mkdir $STORE
      export PRUNED=$(pwd)/.pruned
      mkdir $PRUNED

      # This will cause pnpm to potentially change the version that is used.
      # We need to disable it to ensure consistent behavior with other
      # derivations that aren't fixed-output and can't reach out to the
      # registry.
      pnpm config set manage-package-manager-versions false
      pnpm config set store-dir $STORE
      pnpm config set side-effects-cache false
      pnpm config set update-notifier false
      turbo prune wrangler --out-dir $PRUNED

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild

      export HOME=$(pwd)/.home
      export PRUNED=$(pwd)/.pruned

      pushd $PRUNED
      # An alternative to using "pnpm install" here would be to
      # use "pnpm fetch", save the resulting store as a derivation, and
      # pass it as a source to a new derivation which performs "pnpm install".
      # This would give better caching behavior for dependencies. Unable to get
      # this to work, as "pnpm install" would later complain about missing dependencies.
      pnpm install --frozen-lockfile
      popd

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      export PRUNED=$(pwd)/.pruned
      cp -r $PRUNED $out/

      runHook postInstall
    '';

    # We need to remove the "prunedAt" field in node_modules/.modules.yaml. Otherwise
    # this derivation isn't idempotent.
    # This is the only fixup we can do. If we run the normal fixup phase, nix store paths
    # will be injected into our dependencies which will cause the build to fail (fixed-output
    # derivations can't contain references to the nix store.
    #
    # To check for idempotence:
    # 1. Clear the outputHash.
    # 2. Run the build twice.
    # 3. diff --recursive --brief /nix/store/<build 1> /nix/store/<build 2>
    fixupPhase = ''
      			mv $out/node_modules/.modules.yaml .modules.yaml.timestamped
      			grep -v "prunedAt" .modules.yaml.timestamped > $out/node_modules/.modules.yaml
      		'';
  };
in
stdenv.mkDerivation {
  pname = "wrangler";
  inherit version;

  src = deps;

  nativeBuildInputs = [
    cacert # Turbo will complain without, even though it doesn't make an external connection.
    jq
    nodejs
    pnpm_9
    turbo
  ];

  buildInputs = [
    cacert
    nodejs
    openssl
  ];

  configurePhase = ''
    runHook preConfigure

    export HOME=$(pwd)/.home
    mkdir $HOME
    export STORE=$(pwd)/.store
    mkdir $STORE

    # Reminder: turbo calls into package.json scripts that use pnpm under the hood.
    # The wrangler-sdk .npmrc has "manage-package-manager-versions" set,
    # which will cause pnpm to try and reach out to the registry when invoked.
    # We can't modify the value using "pnpm config", so just use sed instead.
    sed -i 's/manage-package-manager-versions = true/manage-package-manager-versions = false/' .npmrc
    pnpm config set store-dir $STORE
    pnpm config set side-effects-cache false
    pnpm config set update-notifier false

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    export HOME=$(pwd)/.home
    turbo build --filter wrangler...

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Unfortunately, "pnpm deploy" doesn't have an offline mode that we can
    # easily use here. Instead, we'll form a crude distribution by reading
    # the "files" key each package's package.json. We can already be
    # confident we have a semi-minimal distribution since we used "turbo prune"
    # before downloading dependencies.
    #
    # More info:
    # - https://github.com/pnpm/pnpm/issues/7367
    #
    # We'll structure the output as:
    # - src/: Contains all the source packages.
    # - bin/wrangler: Soft link to src/packages/wrangler/bin/wrangler.js, which
    #   is the cli entrypoint.

    SRC=$out/opt/wrangler
    mkdir -p $SRC

    for packageMetadata in $(find ./packages -name "package.json"); do
      cp --parents $packageMetadata $SRC/

      local packageDir=$(dirname $packageMetadata)

      # Check if packages.json has a "files" key. If not, the default is to
      # copy everything.
      if ! grep '"files":' $packageMetadata > /dev/null; then
        cp --parents -r $packageDir $SRC/
      else
        for includedFile in $(jq -r '.files[]' $packageMetadata); do
          local fullPath=$packageDir/$includedFile
          # Check if the target exists. If it doesn't, then ignore.
          # This matches the behavior of "pnpm deploy" which will ignore any
          # missing files or directories.
          # An example of where this is necessary is for "miniflare-dist" in
          # wrangler's package.json.
          if [[ -d "$fullPath" || -f "$fullPath" ]]; then
            cp --parents -r $fullPath $SRC/
          fi
        done
      fi

      # In addition to each package's files, we need their "node_modules"
      # (if applicable).
      local modulesDir=$packageDir/node_modules
      if [ -d "$modulesDir" ]; then
        cp --parents -r $modulesDir $SRC/
      fi
    done

    # We also need the top-level "node_modules", which holds some shared deps.
    cp -r ./node_modules $SRC/

    mkdir -p $out/bin
    ln -s $SRC/packages/wrangler/bin/wrangler.js ./bin/wrangler
    chmod +x $SRC/packages/wrangler/bin/wrangler.js

    runHook postInstall
  '';
}

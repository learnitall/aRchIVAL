{
  stdenv,
  fetchFromGitHub,
  bazel_7,
  cacert,
  llvmPackages_16,
  nodejs,
  pnpm_9,
}:
let
  pname = "workerd";
  version = "1.20250214.0";

  src = fetchFromGitHub {
    owner = "cloudflare";
    repo = "workerd";
    rev = "v${version}";
    hash = "sha256-BiTtQCJnm8AwPdn8jnqlRfcB7/BH9Jo01wOXsynfljk=";
  };

  build = stdenv.mkDerivation {
    name = "${pname}-${version}-build";
    inherit src;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "";

    nativeBuildInputs =
      [
        bazel_7
        cacert
        nodejs
        pnpm_9
      ]
      ++ (with llvmPackages_16; [
        llvm
        clang
      ]);

    configurePhase = ''
      runHook preConfigure

      export HOME=$(pwd)/.home
      mkdir $HOME
      export STORE=$(pwd)/.store
      mkdir $STORE
      export BAZEL_CACHE=$(pwd)/.bazel-cache
      mkdir $BAZEL_CACHE

      pnpm config set manage-package-manager-versions false
      pnpm config set store-dir $STORE
      pnpm config set side-effects-cache false
      pnpm config set update-notifier false

      rm .bazelversion

      echo "build:linux --action_env=CC=${llvmPackages_16.clang}/bin/clang --action_env=CXX=${llvmPackages_16.clang}/bin/clang++" >> .bazelrc
      echo "build:linux --host_action_env=CC=${llvmPackages_16.clang}/bin/clang --host_action_env=CXX=${llvmPackages_16.clang}/bin/clang++" >> .bazelrc

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild

      pnpm install
      pnpm exec bazel build --disk_cache=$BAZEL_CACHE --config=release_linux //src/workerd/server:workerd

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      export $BAZEL_CACHE=$(pwd)/.bazel-cache
      mkdir -p $out/opt/workerd
      cp ./bazel-bin/src/workerd/server/workerd $out/opt/workerd
      cp $BAZEL_CACHE $out/opt/.bazel-cache

      mkdir -p $out/bin
      ln -s $out/opt/workerd $out/bin/workerd
      runHook postInstall
    '';
  };
in
build

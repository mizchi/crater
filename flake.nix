{
  description = "Crater MoonBit browser engine — reproducible dev/CI toolchain";

  # NOTE: flake.lock is NOT committed yet because this flake was authored in an
  # environment without `nix`. Run `nix flake lock` once on a machine with Nix
  # to pin nixpkgs (and thereby every nixpkgs-sourced tool below) by narHash.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # Toolchain pins. Keep these in sync with:
      #   - .github/actions/setup-crater/action.yml  (node/just/wasm-tools)
      #   - .github/workflows/ci.yml                 (PKFIRE_TAG)
      #   - package.json                             (packageManager / pnpm)
      moonbitVersion = "0.1.20260618"; # expected `moon version`; see shellHook
      pkfVersion = "0.12.3";

      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      # pkfire ships per-platform static tarballs as GitHub release assets.
      # Hashes are flat-file SRI of `pkf-<asset>.tar.gz`. Only the assets we have
      # verified are filled in; the rest use lib.fakeHash so `nix build` prints
      # the real hash on first use (standard FOD bootstrap).
      pkfAssets = {
        "x86_64-linux" = {
          asset = "pkf-linux-amd64";
          # verified 2026-06-30 against pkfire@0.12.3 release
          hash = "sha256-AjeiXgYsVoGqjQrrVH9g454hRF1ACOd4ZryoJUPGN3M=";
        };
        "aarch64-linux" = { asset = "pkf-linux-arm64"; hash = nixpkgs.lib.fakeHash; };
        "x86_64-darwin" = { asset = "pkf-darwin-amd64"; hash = nixpkgs.lib.fakeHash; };
        "aarch64-darwin" = { asset = "pkf-darwin-arm64"; hash = nixpkgs.lib.fakeHash; };
      };

      mkPkf = pkgs: system:
        let a = pkfAssets.${system};
        in pkgs.stdenvNoCC.mkDerivation {
          pname = "pkf";
          version = pkfVersion;
          src = pkgs.fetchurl {
            url = "https://github.com/mizchi/pkfire/releases/download/pkfire@${pkfVersion}/${a.asset}.tar.gz";
            inherit (a) hash;
          };
          sourceRoot = ".";
          nativeBuildInputs = nixpkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ];
          installPhase = ''
            runHook preInstall
            install -Dm755 pkf "$out/bin/pkf"
            runHook postInstall
          '';
          meta.description = "pkfire CI gate runner (release binary ${pkfVersion})";
        };
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          pkf = mkPkf pkgs system;
          # Libraries the prebuilt MoonBit ELF binaries need at runtime.
          # Harmless on macOS; required on NixOS (alongside nix-ld) and used to
          # extend LD_LIBRARY_PATH so the installer-fetched `moon` can run.
          moonRuntimeLibs = nixpkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
          ];
        in
        {
          default = pkgs.mkShell {
            packages = [
              # --- pinned via flake.lock (nixpkgs) ---
              pkgs.just
              pkgs.nodejs_24 # bundles corepack -> honours package.json pnpm pin
              pkgs.pkl
              pkgs.wasm-tools
              pkgs.sqlite # libsqlite3 for native-deps builds
              pkgs.git
              pkgs.curl
              pkgs.cacert
              pkgs.gnumake
              # --- pinned via FOD (release asset) ---
              pkf
            ] ++ moonRuntimeLibs;

            env = {
              MOONBIT_EXPECTED_VERSION = moonbitVersion;
              LD_LIBRARY_PATH = nixpkgs.lib.makeLibraryPath moonRuntimeLibs;
            };

            shellHook = ''
              set -u
              # pnpm: honour the package.json `packageManager` pin via corepack.
              # Corepack lives in the read-only /nix/store, so `corepack enable`
              # cannot write shims next to its own binary; point it at a writable
              # dir that we prepend to PATH instead.
              export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
              corepack_shims="$HOME/.cache/crater/corepack-shims"
              mkdir -p "$corepack_shims"
              export PATH="$corepack_shims:$PATH"
              corepack enable --install-directory "$corepack_shims" pnpm npm >/dev/null 2>&1 || true

              # MoonBit is not in nixpkgs and upstream does not currently serve
              # pinned per-version binary tarballs (the dated /binaries/<ver>/
              # path 403s; only `latest` resolves). So we install via the
              # official installer and ASSERT the resulting version, failing
              # loudly on drift instead of silently floating.
              export PATH="$HOME/.moon/bin:$PATH"
              installed="$(moon version 2>/dev/null | awk 'NR==1{print $2}')"
              if [ "$installed" != "$MOONBIT_EXPECTED_VERSION" ]; then
                echo "crater: installing MoonBit (have '$installed', want '$MOONBIT_EXPECTED_VERSION')" >&2
                if curl -fsSL https://cli.moonbitlang.com/install/unix.sh \
                     | MOONBIT_INSTALL_VERSION="$MOONBIT_EXPECTED_VERSION" bash >&2; then :; else
                  echo "crater: pinned install failed; falling back to latest" >&2
                  curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash >&2 || true
                fi
                installed="$(moon version 2>/dev/null | awk 'NR==1{print $2}')"
                if [ "$installed" != "$MOONBIT_EXPECTED_VERSION" ]; then
                  echo "crater: WARNING MoonBit is '$installed', expected '$MOONBIT_EXPECTED_VERSION' (upstream may no longer publish the pinned build)" >&2
                fi
              fi

              echo "crater devshell: moon=$installed pkf=$(pkf --version 2>/dev/null) node=$(node --version) just=$(just --version)" >&2
              set +u
            '';
          };
        });

      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in { pkf = mkPkf pkgs system; });
    };
}

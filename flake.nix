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
      # MoonBit floats on "latest", matching .github/actions/setup-crater
      # (its `moonbit-version` input defaults to "latest"). Set this to a release
      # tag to pin only when an upstream nightly regresses — the same knob and
      # policy the CI action uses. See shellHook.
      moonbitVersion = "latest";
      pkfVersion = "0.12.3";

      # pkfire@0.12.3 publishes binaries for exactly three platforms (no
      # x86_64-darwin / Intel-mac asset exists upstream). `systems` therefore
      # tracks what pkf can actually be provided for; add a row here only when
      # pkfire starts shipping that target.
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      # pkfire ships per-platform static tarballs as GitHub release assets.
      # Hashes are flat-file SRI of `pkf-<asset>.tar.gz`, verified 2026-07-01
      # against the upstream `.tar.gz.sha256` sidecars of the pkfire@0.12.3
      # release. To add a platform: `nix build .#pkf` on it (or hash the tarball
      # with `openssl dgst -sha256 -binary <f> | openssl base64 -A`).
      pkfAssets = {
        "x86_64-linux" = {
          asset = "pkf-linux-amd64";
          hash = "sha256-AjeiXgYsVoGqjQrrVH9g454hRF1ACOd4ZryoJUPGN3M=";
        };
        "aarch64-linux" = {
          asset = "pkf-linux-arm64";
          hash = "sha256-wK2yy5IrktT0M+f/XGszGtmWKpDke2Dtfq0xXwtzb8s=";
        };
        "aarch64-darwin" = {
          asset = "pkf-darwin-arm64";
          hash = "sha256-HkOuPANkPJYdVGZrtSxESIDoJzEaY6o8HNZD/MBUCBY=";
        };
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
          # The prebuilt pkf ELF links only libc/libm and SIGABRTs (exit 134)
          # under nixpkgs-unstable's very new glibc (2.42), while running fine on
          # the host glibc that CI/most distros ship. So do NOT autopatch it onto
          # the nix loader — keep its original interpreter and let it bind the
          # host glibc at runtime. On NixOS this needs nix-ld, the same
          # requirement MoonBit already carries.
          dontPatchELF = true;
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
              MOONBIT_VERSION = moonbitVersion;
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

              # MoonBit is not in nixpkgs; install it via the official installer,
              # the same method and version policy as CI's setup-crater action.
              # MOONBIT_VERSION floats "latest"; set it to a release tag to pin
              # (the installer serves only "latest", so a tag pin may 403 — we
              # fall back to latest rather than fail).
              export PATH="$HOME/.moon/bin:$PATH"
              installed="$(moon version 2>/dev/null | awk 'NR==1{print $2}')"
              need_install=0
              if [ -z "$installed" ]; then
                need_install=1
              elif [ "$MOONBIT_VERSION" != "latest" ] && [ "$installed" != "$MOONBIT_VERSION" ]; then
                need_install=1
              fi
              if [ "$need_install" = 1 ]; then
                echo "crater: installing MoonBit ($MOONBIT_VERSION)" >&2
                if curl -fsSL https://cli.moonbitlang.com/install/unix.sh \
                     | MOONBIT_INSTALL_VERSION="$MOONBIT_VERSION" bash >&2; then :; else
                  echo "crater: install failed; retrying latest" >&2
                  curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash >&2 || true
                fi
                installed="$(moon version 2>/dev/null | awk 'NR==1{print $2}')"
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

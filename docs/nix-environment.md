# Reproducible dev/CI environment (Nix)

`flake.nix` provides a reproducible toolchain for Crater so local development
and CI converge on the same versions. This document is the **maintenance
contract**: what is pinned, where, and how to keep it from drifting.

## Quick start

```bash
nix develop          # enter the dev shell (or: direnv allow, with nix-direnv)
just check           # everything on PATH: moon, pkf, just, node, pnpm, pkl, ...
```

First entry: run `nix flake lock` once to generate `flake.lock` (see below).
The `nix-develop` CI job also produces one as a downloadable artifact.

## What is pinned, and how

| Tool | Pinned by | Where the version lives |
|---|---|---|
| nixpkgs (just, nodejs_24, pkl, wasm-tools, sqlite, git, curl, make) | `flake.lock` narHash | `flake.lock` (generate with `nix flake lock`) |
| `pkf` (pkfire) | fixed-output hash | `pkfVersion` + `pkfAssets.<system>.hash` in `flake.nix` |
| pnpm | corepack | `packageManager` in `package.json` |
| MoonBit (`moon`) | installer (**floats `latest`**) | `moonbitVersion` in `flake.nix` |

### Why MoonBit is special

MoonBit is not in nixpkgs, and the project deliberately **floats `latest`** —
`.github/actions/setup-crater` defaults its `moonbit-version` input to `latest`
and only pins a release tag "when the upstream nightly has a regression." The
dev shell mirrors that exactly: it installs via the official installer with
`MOONBIT_VERSION` (default `latest`) and does **not** assert a fixed version.

To pin (e.g. to dodge a bad nightly), set `moonbitVersion` in `flake.nix` to a
release tag — the same knob as the CI action's `moonbit-version`. Upstream's
installer serves only `latest`, so a tag pin can `403`; the shellHook then falls
back to `latest` rather than failing. So MoonBit is the one tool that is *not*
byte-reproducible here — by design, matching CI.

## flake.lock

`flake.lock` is intentionally **not committed yet** — the flake was authored in
an environment without `nix`, so the nixpkgs narHash could not be generated.
To finish pinning, either run it locally:

```bash
nix flake lock      # writes flake.lock
git add flake.lock
```

…or download the `flake.lock` artifact produced by the `nix-develop` CI job and
commit that. After it lands, the nixpkgs-sourced tools are byte-reproducible.

## Platforms for `pkf`

pkfire@0.12.3 ships binaries for exactly three targets, all with verified
hashes in `pkfAssets`:

| system | asset |
|---|---|
| `x86_64-linux` | `pkf-linux-amd64` |
| `aarch64-linux` | `pkf-linux-arm64` |
| `aarch64-darwin` | `pkf-darwin-arm64` |

There is **no** `x86_64-darwin` (Intel-mac) asset upstream, so that system is
omitted from `systems`. To add a target once pkfire publishes it: add it to
`systems`, then run `nix build .#pkf` on that machine (Nix prints the hash) or
hash the release tarball directly:

```bash
openssl dgst -sha256 -binary pkf-<asset>.tar.gz | openssl base64 -A
```

and paste `sha256-<that>` into `pkfAssets.<system>.hash`.

## Keeping pins in sync (the 保守 / maintenance part)

When you bump a tool, update **both** the flake and the existing CI source of
truth so they cannot drift apart:

| If you change… | also update… |
|---|---|
| `moonbitVersion` (flake, default `latest`) | `.github/actions/setup-crater/action.yml` (`moonbit-version`, default `latest`) |
| `pkfVersion` + hash (flake) | `.github/workflows/ci.yml` (`PKFIRE_TAG`) |
| `nodejs_24` (flake) | `setup-crater/action.yml` (`node-version`) |
| `wasm-tools` (flake) | `setup-crater/action.yml` (`wasm-tools-version`) |
| pnpm (`package.json`) | nothing — corepack reads it in both places |

The heavy CI jobs still use the curl-based installers in `setup-crater` (fast,
already cached, rate-limit-tuned). The flake is an additive reproduction layer.
A dedicated `nix-develop` job in `.github/workflows/ci.yml` enters the flake and
asserts every pinned tool resolves to its pin, so the reproducible env is
exercised on every PR and fails loudly if it drifts — without converting the
existing jobs.

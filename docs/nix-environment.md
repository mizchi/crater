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

## What is pinned, and how

| Tool | Pinned by | Where the version lives |
|---|---|---|
| nixpkgs (just, nodejs_24, pkl, wasm-tools, sqlite, git, curl, make) | `flake.lock` narHash | `flake.lock` (generate with `nix flake lock`) |
| `pkf` (pkfire) | fixed-output hash | `pkfVersion` + `pkfAssets.<system>.hash` in `flake.nix` |
| pnpm | corepack | `packageManager` in `package.json` |
| MoonBit (`moon`) | installer + **version assertion** | `moonbitVersion` in `flake.nix` |

### Why MoonBit is special

MoonBit is not in nixpkgs, and upstream does **not** currently serve pinned
per-version binary tarballs: `https://cli.moonbitlang.com/binaries/<version>/…`
returns `403`, only `latest` resolves. So the dev shell installs MoonBit via the
official installer and then **asserts** the resulting `moon version` equals
`moonbitVersion`, warning loudly on drift rather than floating silently. If/when
upstream publishes stable per-version URLs, promote MoonBit to a real
fixed-output derivation like `pkf`.

## flake.lock

`flake.lock` is intentionally **not committed yet** — the flake was authored in
an environment without `nix`, so the nixpkgs narHash could not be generated.
To finish pinning:

```bash
nix flake lock      # writes flake.lock
git add flake.lock
```

After that, the nixpkgs-sourced tools are byte-reproducible.

## Adding a platform for `pkf`

Only `x86_64-linux` has a verified hash; other systems use `lib.fakeHash`. To
fill one in, run `nix build .#pkf` on that system — Nix prints the real hash —
and paste it into `pkfAssets.<system>.hash` in `flake.nix`.

## Keeping pins in sync (the 保守 / maintenance part)

When you bump a tool, update **both** the flake and the existing CI source of
truth so they cannot drift apart:

| If you change… | also update… |
|---|---|
| `moonbitVersion` (flake) | `.github/actions/setup-crater/action.yml` (`moonbit-version`) |
| `pkfVersion` + hash (flake) | `.github/workflows/ci.yml` (`PKFIRE_TAG`) |
| `nodejs_24` (flake) | `setup-crater/action.yml` (`node-version`) |
| `wasm-tools` (flake) | `setup-crater/action.yml` (`wasm-tools-version`) |
| pnpm (`package.json`) | nothing — corepack reads it in both places |

CI itself is unchanged: jobs still use the curl-based installers in
`setup-crater`. The flake is an additive, opt-in local-reproduction layer; wiring
CI to run *inside* `nix develop` is a possible follow-up, not done here.

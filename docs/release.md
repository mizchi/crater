# Release runbook (MoonBit workspace → mooncakes)

Crater is a MoonBit **workspace**: ~20 public modules under one repo
(`moon.work` lists the members). A release publishes all of them to the
mooncakes registry at the same version, in dependency order.

The publishing itself is driven by
[`scripts/moon-publish-workspace.mjs`](../scripts/moon-publish-workspace.mjs),
exposed as pkfire tasks (`pkf run release-*`) and npm scripts
(`pnpm release:moon:*`).

## 0. Prerequisites

- `~/.moon/credentials.json` present and pointing at the **mizchi** account
  (not a machine user). The publish uses whatever account this file holds.
- Clean working tree on the branch you intend to release.
- `moon update` has been run recently so the local registry index is fresh.

## 1. Bump versions

There is **no automatic version bumper**. Every workspace `moon.mod` (and the
dev-only `conformance/moon.mod.json`) carries its own `version`, and the
internal `import { "mizchi/crater-*@X" }` pins reference sibling modules by
version. All of them must move together.

For a uniform bump (e.g. `0.18.0` → `0.19.0`), replacing the old version
string across every manifest is safe **only after** confirming no external
dependency happens to sit on the old version:

```bash
# Confirm every occurrence of the OLD version is a `version = "..."` field
# or an internal `mizchi/crater-*` pin (empty output = safe to bulk-replace):
git ls-files '*moon.mod' '*moon.mod.json' \
  | xargs grep -rnE '0\.18\.0' \
  | grep -vE 'version = "0\.18\.0"|"version": *"0\.18\.0"|mizchi/crater'

# Bulk replace (zsh needs xargs word-splitting, not `$(...)`):
git ls-files '*moon.mod' '*moon.mod.json' \
  | xargs perl -pi -e 's/0\.18\.0/0.19.0/g'
```

Then verify a top consumer builds against the bumped internal deps
(workspace-local resolution means unpublished versions still resolve):

```bash
moon -C browser check --target js   # expect 0 errors
```

## 2. Update external dependencies (optional but do it here)

External deps (`mizchi/css`, `mizchi/font`, `mizchi/x`, `moonbitlang/*`, …)
are pinned per-manifest. Compare against the registry index
(`~/.moon/registry/index/user/<owner>/<pkg>.index`, last line = latest) and
bump the pins you want. After bumping, `moon install` **at the repo root will
fail** because the root module tries to resolve the not-yet-published internal
deps from the registry — check per package instead:

```bash
moon -C <pkg> check --target js   # and --target native where relevant
```

> Gotcha: `mizchi/js` 0.11+ split its runtime bindings into separate modules.
> `import { "mizchi/js/deno" }` became `import { "mizchi/js_deno" @deno }`
> (add the `mizchi/js_deno` dep, alias it `@deno`). Same pattern for js_bun etc.

## 3. Preview the publish plan

```bash
pkf run release-plan     # or: pnpm release:moon:list
```

Prints the ~20 modules in topological publish order (core first, the
`mizchi/crater` facade last). Internal-only modules
(benchmarks / testing / tools / conformance) are excluded.

## 4. Dry run (limited for first releases)

```bash
pkf run release-dry-run  # or: pnpm release:moon:dry-run
```

- On **macOS** this uses `moon package` instead of `moon publish --dry-run`
  (the latter currently panics on macOS).
- For a **never-published version** the dry run cannot complete: `moon package`
  resolves cross-module deps from the registry, which is still on the previous
  version, so the first module whose deps aren't published yet fails. This is
  expected — there is no way to fully validate a first-time release offline.

## 5. Commit, tag, publish

```bash
# Commit the bump on a release branch (branch first if on main).
git commit -am "chore: bump workspace version to 0.19.0"

pkf run release-publish   # or: pnpm release:moon:publish  — IRREVERSIBLE
```

Publishing is **irreversible**: mooncakes does not allow unpublishing or
overwriting a version. The script:
- publishes in dependency order;
- retries (with `moon update`) when a just-published dep hasn't propagated to
  the registry index yet (expect several 5s retries — a full run takes a while);
- skips modules already published at this version (409), so a failed run is
  **safe to re-run** and resumes where it stopped.

Confirm the registry caught up:

```bash
moon update
tail -1 ~/.moon/registry/index/user/mizchi/crater-core.index  # -> "version":"0.19.0"
```

## 6. Tag at the release *tip*, not the bump commit

Publishing uses the working-tree manifests, so the released content is the
**tip** of your release branch (bump + dep updates + fixes), not the initial
bump commit. Tag the tip so `git checkout v0.19.0` matches the published
packages:

```bash
git tag v0.19.0 <release-tip-sha>
git push origin main --tags   # fast-forward main; avoid squash (orphans the tag)
```

## CI

The automated release workflow is `.github/workflows/release-moon.yml`
(`workflow_dispatch`, needs the `MOON_CREDENTIALS_JSON` secret). Running from
Linux CI also sidesteps the macOS `--dry-run` panic.

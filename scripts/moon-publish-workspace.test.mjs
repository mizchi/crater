import test from 'node:test'
import assert from 'node:assert/strict'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs'
import os from 'node:os'
import { execFileSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { assertReleaseArchiveEntries, prepareReleaseWorkspace } from './moon-release-workspace.mjs'

import {
  buildPublishPlan,
  formatCheckCommands,
  formatPackageCommands,
  loadWorkspaceModules,
  parseWorkspaceMembers,
  runCommands,
  resolveCheckTarget,
  shouldUsePackageFallback,
  shouldRetryRegistryPropagation,
} from './moon-publish-workspace.mjs'

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

test('publication retries a version missing during registry propagation', () => {
  assert.ok(shouldRetryRegistryPropagation("Failed to resolve registry dependency `mizchi/crater-core`: version `0.19.2` was not found in the registry"))
  assert.ok(!shouldRetryRegistryPropagation('Server status: 403 Forbidden'))
})

test('release archives require metadata, a package and any declared prebuild script', () => {
  const module = { name: 'mizchi/crater-browser-native' }
  assert.throws(() => assertReleaseArchiveEntries(module, []), /missing moon.mod/)
  assert.throws(() => assertReleaseArchiveEntries(module, ['moon.mod']), /contains no MoonBit package/)
  assert.throws(() => assertReleaseArchiveEntries(module, ['moon.mod', 'moon.pkg'], 'scripts/prebuild.mjs'), /missing prebuild script/)
  assert.doesNotThrow(() => assertReleaseArchiveEntries(module, ['moon.mod', 'moon.pkg', 'scripts/prebuild.mjs'], 'scripts/prebuild.mjs'))
  assert.doesNotThrow(() => assertReleaseArchiveEntries({ name: 'mizchi/crater' }, ['moon.mod']))
})

test('release staging separates module ignore rules and includes module-owned build scripts', () => {
  const source = mkdtempSync(path.join(os.tmpdir(), 'crater-release-test-'))
  let release
  try {
    execFileSync('git', ['init', '--quiet', source])
    const write = (file, content) => {
      const target = path.join(source, file)
      mkdirSync(path.dirname(target), { recursive: true })
      writeFileSync(target, content)
    }
    write('.moonignore', 'browser\njs\n')
    write('.gitignore', '_build/\nnode_modules/\n')
    write('moon.mod', 'name = "mizchi/crater"\nversion = "0.19.2"\n')
    write('README.mbt.md', 'Release readme\n')
    symlinkSync('README.mbt.md', path.join(source, 'README.md'))
    write('js/moon.mod', 'name = "mizchi/crater-js"\nversion = "0.19.2"\n')
    write('js/top.mbt', 'pub fn answer() -> Int32 { 42 }\n')
    write('js/_build/stale.js', 'generated')
    write('browser/native/moon.mod', 'name = "mizchi/crater-browser-native"\nversion = "0.19.2"\n')
    write('browser/native/scripts/prebuild.mjs', 'export const build = true\n')
    write('moon.work', 'members = [".", "js", "browser/native"]\n')
    const modules = loadWorkspaceModules(source)
    release = prepareReleaseWorkspace({ sourceRoot: source, modules })
    const stagedJs = release.moduleRoots.get('mizchi/crater-js')
    const stagedNative = release.moduleRoots.get('mizchi/crater-browser-native')
    const stagedRoot = release.moduleRoots.get('mizchi/crater')

    assert.equal(readFileSync(path.join(stagedJs, 'top.mbt'), 'utf8'), 'pub fn answer() -> Int32 { 42 }\n')
    assert.ok(existsSync(path.join(stagedNative, 'scripts/prebuild.mjs')))
    assert.ok(!existsSync(path.join(stagedJs, '_build')))
    assert.ok(!existsSync(path.join(stagedRoot, 'js')))
    assert.equal(readFileSync(path.join(stagedRoot, 'README.md'), 'utf8'), 'Release readme\n')
    assert.ok(!existsSync(path.join(stagedJs, 'moon.work')))
    assert.notEqual(path.dirname(stagedJs), stagedRoot)
    assert.equal(loadWorkspaceModules(release.workspaceRoot).length, modules.length)
  } finally {
    release?.cleanup()
    rmSync(source, { recursive: true, force: true })
  }
})

test('native prebuild entry point is owned by the published native module', () => {
  const source = readFileSync(path.join(rootDir, 'browser/native/moon.mod'), 'utf8')
  const script = source.match(/"--moonbit-unstable-prebuild": "([^"]+)"/)?.[1]
  assert.ok(script)
  assert.ok(!script.startsWith('../'))
  assert.ok(existsSync(path.join(rootDir, 'browser/native', script)))
})

function assertBefore(names, before, after) {
  const beforeIndex = names.indexOf(before)
  const afterIndex = names.indexOf(after)
  assert.notEqual(beforeIndex, -1, `${before} should be present`)
  assert.notEqual(afterIndex, -1, `${after} should be present`)
  assert.ok(beforeIndex < afterIndex, `${before} should come before ${after}`)
}

test('parseWorkspaceMembers reads the current workspace member list', () => {
  const members = parseWorkspaceMembers(`
members = [
  ".",
  "./layout",
  "./browser/native",
]
`)
  assert.deepEqual(members, ['.', './layout', './browser/native'])
})

test('workspace releases keep module versions and internal dependency floors in lockstep', () => {
  const modules = loadWorkspaceModules(rootDir)
  const byName = new Map(modules.map((module) => [module.name, module]))
  const releaseVersion = byName.get('mizchi/crater').version

  for (const module of modules) {
    assert.equal(module.version, releaseVersion, `${module.name} must follow the workspace release version`)
    const source = readFileSync(path.join(rootDir, module.manifestRel), 'utf8')
    for (const [, dependency, version] of source.matchAll(/"([^"@]+)@([^"\n]+)"/g)) {
      const local = byName.get(dependency)
      if (local) {
        assert.equal(version, local.version, `${module.name} must require ${dependency}@${local.version}`)
      }
    }
  }
})

test('default publish plan excludes internal modules and respects dependency order', () => {
  const modules = loadWorkspaceModules(rootDir)
  const { orderedModules, skippedLocalDeps } = buildPublishPlan(modules)
  const names = orderedModules.map((module) => module.name)

  assert.ok(!names.includes('mizchi/crater-benchmarks'))
  assert.ok(!names.includes('mizchi/crater-testing'))
  assert.ok(names.includes('mizchi/crater-aomx'))
  assert.equal(skippedLocalDeps.size, 0)

  assertBefore(names, 'mizchi/crater-core', 'mizchi/crater-layout')
  assertBefore(names, 'mizchi/crater-core', 'mizchi/crater-painter')
  assertBefore(names, 'mizchi/crater-core', 'mizchi/crater-renderer')
  assertBefore(names, 'mizchi/crater-core', 'mizchi/crater-dom')
  assertBefore(names, 'mizchi/crater-layout', 'mizchi/crater-webvitals')
  assertBefore(names, 'mizchi/crater-dom', 'mizchi/crater-browser-runtime')
  assertBefore(names, 'mizchi/crater-layout', 'mizchi/crater-painter')
  assertBefore(names, 'mizchi/crater-painter', 'mizchi/crater-renderer')
  assertBefore(names, 'mizchi/crater-renderer', 'mizchi/crater-browser-helpers')
  assertBefore(names, 'mizchi/crater-browser-runtime', 'mizchi/crater-browser')
  assertBefore(names, 'mizchi/crater-browser-helpers', 'mizchi/crater-webdriver-bidi')
  assertBefore(names, 'mizchi/crater-renderer', 'mizchi/crater')
  assertBefore(names, 'mizchi/crater-webvitals', 'mizchi/crater')
  assertBefore(names, 'mizchi/crater-js', 'mizchi/crater-wasm')
})

test('--only-crater-star has no skipped root crater dependency after facade split', () => {
  const modules = loadWorkspaceModules(rootDir)
  const { orderedModules, skippedLocalDeps } = buildPublishPlan(modules, {
    onlyCraterStar: true,
  })
  const names = orderedModules.map((module) => module.name)

  assert.ok(!names.includes('mizchi/crater'))
  assert.equal(skippedLocalDeps.size, 0)
  assert.deepEqual(skippedLocalDeps.get('mizchi/crater-browser') ?? [], [])
  assert.deepEqual(skippedLocalDeps.get('mizchi/crater-js') ?? [], [])
  assert.deepEqual(skippedLocalDeps.get('mizchi/crater-wasm') ?? [], [])
})

test('--include-internal keeps internal modules after their public dependencies', () => {
  const modules = loadWorkspaceModules(rootDir)
  const { orderedModules } = buildPublishPlan(modules, {
    includeInternal: true,
  })
  const names = orderedModules.map((module) => module.name)

  assert.ok(names.includes('mizchi/crater-benchmarks'))
  assert.ok(names.includes('mizchi/crater-testing'))
  assertBefore(names, 'mizchi/crater-browser', 'mizchi/crater-benchmarks')
  assertBefore(names, 'mizchi/crater-renderer', 'mizchi/crater-benchmarks')
  assertBefore(names, 'mizchi/crater-webdriver-bidi', 'mizchi/crater-tools')
  assertBefore(names, 'mizchi/crater-browser-native', 'mizchi/crater-testing')
})

test('check target selection follows preferred-target and wasm fallback', () => {
  const modules = loadWorkspaceModules(rootDir)
  const byName = new Map(modules.map((module) => [module.name, module]))

  assert.equal(resolveCheckTarget(byName.get('mizchi/crater-layout')), 'js')
  assert.equal(resolveCheckTarget(byName.get('mizchi/crater-browser-native')), 'native')
  assert.equal(resolveCheckTarget(byName.get('mizchi/crater-wasm')), 'wasm')
})

test('check command formatting uses dependency order and target-aware invocations', () => {
  const modules = loadWorkspaceModules(rootDir)
  const { orderedModules } = buildPublishPlan(modules)
  const commands = formatCheckCommands(orderedModules)
  const wasmCommand = commands.find(
    ({ module }) => module.name === 'mizchi/crater-wasm',
  )

  assert.ok(wasmCommand)
  assert.equal(
    wasmCommand.command,
    'moon -C wasm check --target wasm -j 1',
  )
})

test('macOS dry-run uses moon package fallback unless forced', () => {
  assert.equal(
    shouldUsePackageFallback({
      platform: 'darwin',
      action: 'dry-run',
      forcePublishDryRun: false,
    }),
    true,
  )
  assert.equal(
    shouldUsePackageFallback({
      platform: 'darwin',
      action: 'dry-run',
      forcePublishDryRun: true,
    }),
    false,
  )
  assert.equal(
    shouldUsePackageFallback({
      platform: 'linux',
      action: 'dry-run',
      forcePublishDryRun: false,
    }),
    false,
  )
})

test('package command formatting mirrors publish order without network-facing dry-run', () => {
  const modules = loadWorkspaceModules(rootDir)
  const { orderedModules } = buildPublishPlan(modules)
  const commands = formatPackageCommands(orderedModules)
  const httpCommand = commands.find(
    ({ module }) => module.name === 'mizchi/crater-browser-http',
  )

  assert.ok(httpCommand)
  assert.equal(
    httpCommand.command,
    'moon -C http package --frozen',
  )
})

test('release workflow exposes manual Moon release actions with credentials secret', () => {
  const workflow = readFileSync(
    path.join(rootDir, '.github/workflows/release-moon.yml'),
    'utf8',
  )

  assert.match(workflow, /workflow_dispatch:/)
  assert.match(workflow, /- publish/)
  assert.match(workflow, /node scripts\/moon-publish-workspace\.mjs --publish/)
  assert.match(workflow, /MOON_CREDENTIALS_JSON/)
  assert.match(workflow, /if: inputs\.mode != 'check'/)
  assert.match(workflow, /libsqlite3-dev/)
})

test('publish retries after registry propagation lag', () => {
  const calls = []
  const sleeps = []
  const logs = []
  const errors = []
  const commands = [{
    module: {
      name: 'mizchi/crater-browser-helpers',
    },
    args: ['-C', 'browser_helpers', 'publish', '--frozen'],
    command: 'moon -C browser_helpers publish --frozen',
  }]
  let publishAttempts = 0

  const exitCode = runCommands(commands, {
    action: 'publish',
    cwd: rootDir,
    stdout: {
      log: (message) => logs.push(message),
    },
    stderr: (message) => errors.push(message),
    sleep: (durationMs) => sleeps.push(durationMs),
    retryDelayMs: 1234,
    spawn: (_command, args) => {
      calls.push(args.join(' '))
      if (args[0] === 'update') {
        return { status: 0, stdout: 'updated\n', stderr: '' }
      }
      publishAttempts += 1
      if (publishAttempts === 1) {
        return {
          status: 255,
          stdout: '',
          stderr:
            'Error: Failed to resolve registry dependency `mizchi/crater-renderer` for module `mizchi/crater-browser-helpers`: module was not found in the registry\n',
        }
      }
      return {
        status: 0,
        stdout: 'published\n',
        stderr: '',
      }
    },
  })

  assert.equal(exitCode, 0)
  assert.deepEqual(calls, [
    '-C browser_helpers publish --frozen',
    'update',
    '-C browser_helpers publish --frozen',
  ])
  assert.deepEqual(sleeps, [1234])
  assert.ok(
    errors.some((message) => message.includes('registry dependency propagation')),
  )
  assert.ok(logs.some((message) => message.includes('retry 2/5')))
})

test('publish retries when registry metadata is present but the version is not satisfiable yet', () => {
  const calls = []
  const sleeps = []
  const commands = [{
    module: {
      name: 'mizchi/crater-browser',
    },
    args: ['-C', 'browser', 'publish', '--frozen'],
    command: 'moon -C browser publish --frozen',
  }]
  let publishAttempts = 0

  const exitCode = runCommands(commands, {
    action: 'publish',
    cwd: rootDir,
    stdout: {
      log: () => {},
    },
    stderr: () => {},
    sleep: (durationMs) => sleeps.push(durationMs),
    retryDelayMs: 4321,
    spawn: (_command, args) => {
      calls.push(args.join(' '))
      if (args[0] === 'update') {
        return { status: 0, stdout: '', stderr: '' }
      }
      publishAttempts += 1
      if (publishAttempts === 1) {
        return {
          status: 255,
          stdout: '',
          stderr:
            'Error: Failed to resolve registry dependency `mizchi/crater` for module `mizchi/crater-browser`: no version satisfies requirement `0.17.0`\n',
        }
      }
      return {
        status: 0,
        stdout: '',
        stderr: '',
      }
    },
  })

  assert.equal(exitCode, 0)
  assert.deepEqual(calls, [
    '-C browser publish --frozen',
    'update',
    '-C browser publish --frozen',
  ])
  assert.deepEqual(sleeps, [4321])
})

test('publish skips duplicate version errors when resuming', () => {
  const errors = []
  const commands = [{
    module: {
      name: 'mizchi/crater-browser-http',
    },
    args: ['-C', 'http', 'publish', '--frozen'],
    command: 'moon -C http publish --frozen',
  }]

  const exitCode = runCommands(commands, {
    action: 'publish',
    cwd: rootDir,
    stdout: {
      log: () => {},
    },
    stderr: (message) => errors.push(message),
    spawn: () => ({
      status: 255,
      stdout: '',
      stderr:
        'Server status: 409 Conflict, detail: Version Error: The version you are attempting to upload (0.17.0) is duplicated with an existing version (0.17.0).\n',
    }),
  })

  assert.equal(exitCode, 0)
  assert.ok(
    errors.some((message) => message.includes('already published at this version')),
  )
})

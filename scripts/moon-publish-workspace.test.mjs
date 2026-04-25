import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  buildPublishPlan,
  formatCheckCommands,
  formatPackageCommands,
  loadWorkspaceModules,
  parseWorkspaceMembers,
  runCommands,
  resolveCheckTarget,
  shouldUsePackageFallback,
} from './moon-publish-workspace.mjs'

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

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

test('default publish plan excludes internal modules and respects dependency order', () => {
  const modules = loadWorkspaceModules(rootDir)
  const { orderedModules, skippedLocalDeps } = buildPublishPlan(modules)
  const names = orderedModules.map((module) => module.name)

  assert.ok(!names.includes('mizchi/crater-benchmarks'))
  assert.ok(!names.includes('mizchi/crater-testing'))
  assert.equal(skippedLocalDeps.size, 0)

  assertBefore(names, 'mizchi/crater-layout', 'mizchi/crater-css')
  assertBefore(names, 'mizchi/crater-layout', 'mizchi/crater-webvitals')
  assertBefore(names, 'mizchi/crater-css', 'mizchi/crater-dom')
  assertBefore(names, 'mizchi/crater-dom', 'mizchi/crater-browser-runtime')
  assertBefore(names, 'mizchi/crater-layout', 'mizchi/crater-painter')
  assertBefore(names, 'mizchi/crater-painter', 'mizchi/crater-renderer')
  assertBefore(names, 'mizchi/crater-renderer', 'mizchi/crater-browser-contract')
  assertBefore(names, 'mizchi/crater-browser-runtime', 'mizchi/crater-browser')
  assertBefore(names, 'mizchi/crater-browser-contract', 'mizchi/crater-webdriver-bidi')
  assertBefore(names, 'mizchi/crater-browser-http', 'mizchi/crater-browser-http-sqlite')
  assertBefore(names, 'mizchi/crater', 'mizchi/crater-browser')
  assertBefore(names, 'mizchi/crater', 'mizchi/crater-js')
  assertBefore(names, 'mizchi/crater-js', 'mizchi/crater-wasm')
})

test('--only-crater-star warns when selected modules still depend on root crater', () => {
  const modules = loadWorkspaceModules(rootDir)
  const { orderedModules, skippedLocalDeps } = buildPublishPlan(modules, {
    onlyCraterStar: true,
  })
  const names = orderedModules.map((module) => module.name)

  assert.ok(!names.includes('mizchi/crater'))
  assert.deepEqual(skippedLocalDeps.get('mizchi/crater-browser') ?? [], [
    'mizchi/crater',
  ])
  assert.deepEqual(skippedLocalDeps.get('mizchi/crater-js') ?? [], [
    'mizchi/crater',
  ])
  assert.deepEqual(skippedLocalDeps.get('mizchi/crater-wasm') ?? [], [
    'mizchi/crater',
  ])
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
  assertBefore(names, 'mizchi/crater-webdriver-bidi', 'mizchi/crater-testing')
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
    'moon check --manifest-path wasm/moon.mod.json --target wasm -j 1',
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
    'moon package --manifest-path http/moon.mod.json --frozen',
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
      name: 'mizchi/crater-browser-http-sqlite',
    },
    args: ['publish', '--manifest-path', 'http_sqlite/moon.mod.json', '--frozen'],
    command: 'moon publish --manifest-path http_sqlite/moon.mod.json --frozen',
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
            'Error: Failed to resolve registry dependency `mizchi/crater-browser-http` for module `mizchi/crater-browser-http-sqlite`: module was not found in the registry\n',
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
    'publish --manifest-path http_sqlite/moon.mod.json --frozen',
    'update',
    'publish --manifest-path http_sqlite/moon.mod.json --frozen',
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
    args: ['publish', '--manifest-path', 'browser/moon.mod.json', '--frozen'],
    command: 'moon publish --manifest-path browser/moon.mod.json --frozen',
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
    'publish --manifest-path browser/moon.mod.json --frozen',
    'update',
    'publish --manifest-path browser/moon.mod.json --frozen',
  ])
  assert.deepEqual(sleeps, [4321])
})

test('publish skips duplicate version errors when resuming', () => {
  const errors = []
  const commands = [{
    module: {
      name: 'mizchi/crater-browser-http',
    },
    args: ['publish', '--manifest-path', 'http/moon.mod.json', '--frozen'],
    command: 'moon publish --manifest-path http/moon.mod.json --frozen',
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

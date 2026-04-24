import test from 'node:test'
import assert from 'node:assert/strict'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  buildPublishPlan,
  formatCheckCommands,
  formatPackageCommands,
  loadWorkspaceModules,
  parseWorkspaceMembers,
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

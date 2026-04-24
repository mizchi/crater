import { readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

export const INTERNAL_MODULES = new Set([
  'mizchi/crater-benchmarks',
  'mizchi/crater-testing',
])

export function parseWorkspaceMembers(source) {
  return [...source.matchAll(/"([^"]+)"/g)].map((match) => match[1])
}

export function normalizeMember(member) {
  if (member === '.') return '.'
  return member.replace(/^\.\//, '')
}

export function classifyModule(name) {
  if (name === 'mizchi/crater') return 'compatibility'
  if (INTERNAL_MODULES.has(name)) return 'internal'
  return 'public'
}

export function loadWorkspaceModules(rootDir) {
  const workspaceSource = readFileSync(path.join(rootDir, 'moon.work'), 'utf8')
  const members = parseWorkspaceMembers(workspaceSource)
  return members.map((member) => {
    const relativeDir = normalizeMember(member)
    const manifestRel =
      relativeDir === '.'
        ? 'moon.mod.json'
        : path.join(relativeDir, 'moon.mod.json')
    const manifest = JSON.parse(
      readFileSync(path.join(rootDir, manifestRel), 'utf8'),
    )
    const localDeps = Object.entries(manifest.deps ?? {})
      .filter(([, spec]) => typeof spec === 'object' && spec !== null && 'path' in spec)
      .map(([name]) => name)
      .sort()
    return {
      manifestRel,
      member,
      name: manifest.name,
      relativeDir,
      localDeps,
      preferredTarget: manifest['preferred-target'] ?? null,
      version: manifest.version ?? null,
      layer: classifyModule(manifest.name),
    }
  })
}

export function buildPublishPlan(
  modules,
  {
    includeInternal = false,
    onlyCraterStar = false,
  } = {},
) {
  const allModuleNames = new Set(modules.map((module) => module.name))
  const selectedModules = modules.filter((module) => {
    if (module.layer === 'internal') return includeInternal
    if (!onlyCraterStar) return true
    return module.name.startsWith('mizchi/crater-')
  })
  const selectedNames = new Set(selectedModules.map((module) => module.name))
  const dependents = new Map(selectedModules.map((module) => [module.name, []]))
  const indegree = new Map(selectedModules.map((module) => [module.name, 0]))
  const skippedLocalDeps = new Map()

  for (const module of selectedModules) {
    for (const dep of module.localDeps) {
      if (selectedNames.has(dep)) {
        indegree.set(module.name, (indegree.get(module.name) ?? 0) + 1)
        dependents.get(dep)?.push(module.name)
      } else if (allModuleNames.has(dep)) {
        const skipped = skippedLocalDeps.get(module.name) ?? []
        skipped.push(dep)
        skippedLocalDeps.set(module.name, skipped)
      }
    }
  }

  const modulesByName = new Map(selectedModules.map((module) => [module.name, module]))
  const ready = selectedModules
    .filter((module) => indegree.get(module.name) === 0)
    .sort(compareModules)
  const orderedModules = []

  while (ready.length > 0) {
    const next = ready.shift()
    if (!next) break
    orderedModules.push(next)
    const downstream = [...(dependents.get(next.name) ?? [])].sort()
    for (const dependentName of downstream) {
      const nextIndegree = (indegree.get(dependentName) ?? 0) - 1
      indegree.set(dependentName, nextIndegree)
      if (nextIndegree === 0) {
        const dependent = modulesByName.get(dependentName)
        if (dependent) {
          ready.push(dependent)
          ready.sort(compareModules)
        }
      }
    }
  }

  if (orderedModules.length !== selectedModules.length) {
    const unresolved = selectedModules
      .map((module) => module.name)
      .filter((name) => !orderedModules.some((module) => module.name === name))
    throw new Error(
      `Workspace publish order has a cycle or unresolved local dependency: ${unresolved.join(', ')}`,
    )
  }

  return {
    orderedModules,
    skippedLocalDeps,
  }
}

export function formatPublishCommands(
  orderedModules,
  {
    frozen = true,
    dryRun = false,
    extraMoonArgs = [],
  } = {},
) {
  return orderedModules.map((module) => {
    const args = ['publish', '--manifest-path', module.manifestRel]
    if (frozen) args.push('--frozen')
    if (dryRun) args.push('--dry-run')
    args.push(...extraMoonArgs)
    return {
      module,
      args,
      command: ['moon', ...args].join(' '),
    }
  })
}

export function formatPackageCommands(
  orderedModules,
  {
    frozen = true,
    extraMoonArgs = [],
  } = {},
) {
  return orderedModules.map((module) => {
    const args = ['package', '--manifest-path', module.manifestRel]
    if (frozen) args.push('--frozen')
    args.push(...extraMoonArgs)
    return {
      module,
      args,
      command: ['moon', ...args].join(' '),
    }
  })
}

export function resolveCheckTarget(module) {
  if (module.preferredTarget) return module.preferredTarget
  if (module.relativeDir === 'wasm') return 'wasm'
  return 'js'
}

export function formatCheckCommands(
  orderedModules,
  {
    extraMoonArgs = [],
  } = {},
) {
  return orderedModules.map((module) => {
    const args = [
      'check',
      '--manifest-path',
      module.manifestRel,
      '--target',
      resolveCheckTarget(module),
      '-j',
      '1',
      ...extraMoonArgs,
    ]
    return {
      module,
      args,
      command: ['moon', ...args].join(' '),
    }
  })
}

function compareModules(a, b) {
  return a.manifestRel.localeCompare(b.manifestRel)
}

function printUsage() {
  console.log(`Usage: node scripts/moon-publish-workspace.mjs [--list|--check|--dry-run|--publish] [options] [-- <moon args>]

Options:
  --list               Print the publish plan only (default)
  --check              Run \`moon check\` for each selected module in publish order
  --dry-run            Run \`moon publish --dry-run\` for each selected module
  --publish            Run \`moon publish\` for each selected module
  --only-crater-star   Select only modules named \`mizchi/crater-*\`
  --include-internal   Include internal modules such as benchmarks/testing
  --no-frozen          Do not pass --frozen to moon publish
  --force-publish-dry-run
                       On macOS, use \`moon publish --dry-run\` instead of the
                       safer \`moon package\` fallback
  -h, --help           Show this help

Notes:
  - The default plan includes public workspace modules plus the root compatibility
    module when it is part of the dependency closure.
  - \`--only-crater-star\` intentionally omits \`mizchi/crater\`. If selected modules
    still depend on it, the script prints a warning and assumes it is already published.
  - On macOS, \`--dry-run\` uses \`moon package\` by default to avoid the current
    Moon CLI panic in \`moon publish --dry-run\`.
`)
}

export function shouldUsePackageFallback({
  platform = process.platform,
  action,
  forcePublishDryRun = false,
}) {
  return action === 'dry-run' && platform === 'darwin' && !forcePublishDryRun
}

export function runCli({
  argv = process.argv.slice(2),
  cwd = process.cwd(),
  platform = process.platform,
  stdout = console,
  stderr = console.error,
} = {}) {
  const separatorIndex = argv.indexOf('--')
  const scriptArgs = separatorIndex === -1 ? argv : argv.slice(0, separatorIndex)
  const extraMoonArgs = separatorIndex === -1 ? [] : argv.slice(separatorIndex + 1)
  let action = 'list'
  let includeInternal = false
  let onlyCraterStar = false
  let frozen = true
  let forcePublishDryRun = false

  for (const arg of scriptArgs) {
    switch (arg) {
      case '--list':
        action = 'list'
        break
      case '--check':
        action = 'check'
        break
      case '--dry-run':
        action = 'dry-run'
        break
      case '--publish':
        action = 'publish'
        break
      case '--include-internal':
        includeInternal = true
        break
      case '--only-crater-star':
        onlyCraterStar = true
        break
      case '--no-frozen':
        frozen = false
        break
      case '--force-publish-dry-run':
        forcePublishDryRun = true
        break
      case '-h':
      case '--help':
        printUsage()
        return 0
      default:
        throw new Error(`Unknown argument: ${arg}`)
    }
  }

  const modules = loadWorkspaceModules(cwd)
  const plan = buildPublishPlan(modules, {
    includeInternal,
    onlyCraterStar,
  })
  const usePackageFallback = shouldUsePackageFallback({
    platform,
    action,
    forcePublishDryRun,
  })
  const commands = action === 'check'
    ? formatCheckCommands(plan.orderedModules, {
        extraMoonArgs,
      })
    : usePackageFallback
      ? formatPackageCommands(plan.orderedModules, {
          frozen,
          extraMoonArgs,
        })
      : formatPublishCommands(plan.orderedModules, {
          dryRun: action === 'dry-run',
          frozen,
          extraMoonArgs,
        })

  stdout.log(
    `Publish plan (${includeInternal ? 'public + internal' : 'public'}${
      onlyCraterStar ? ', crater-* only' : ''
    }):`,
  )
  if (usePackageFallback) {
    stdout.log(
      'note: macOS safe dry-run is using `moon package` to avoid the current `moon publish --dry-run` panic.',
    )
  }
  for (const [index, { module, command }] of commands.entries()) {
    stdout.log(
      `${String(index + 1).padStart(2, ' ')}. ${module.name}  [${module.manifestRel}]`,
    )
    stdout.log(`    ${command}`)
  }

  if (plan.skippedLocalDeps.size > 0) {
    stderr('warning: selected modules depend on workspace modules outside this publish plan:')
    for (const [moduleName, deps] of [...plan.skippedLocalDeps.entries()].sort()) {
      stderr(`  - ${moduleName}: ${deps.sort().join(', ')}`)
    }
  }

  if (action === 'list') return 0

  for (const [index, { module, args, command }] of commands.entries()) {
    stdout.log(`==> [${index + 1}/${commands.length}] ${module.name}`)
    stdout.log(`    ${command}`)
    const result = spawnSync('moon', args, {
      cwd,
      stdio: 'inherit',
    })
    if (result.status !== 0) {
      return result.status ?? 1
    }
  }

  return 0
}

const isEntrypoint =
  process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url

if (isEntrypoint) {
  try {
    const exitCode = runCli()
    process.exitCode = exitCode
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error))
    process.exitCode = 1
  }
}

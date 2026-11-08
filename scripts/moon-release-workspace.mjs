import { execFileSync } from 'node:child_process'
import { copyFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import os from 'node:os'
import path from 'node:path'

export function assertReleaseArchiveEntries(module, entries, prebuildScript) {
  if (!entries.includes('moon.mod')) throw new Error(`${module.name}: archive is missing moon.mod`)
  if (module.name !== 'mizchi/crater' && !entries.some(entry => entry === 'moon.pkg' || entry.endsWith('/moon.pkg'))) {
    throw new Error(`${module.name}: archive contains no MoonBit package`)
  }
  if (prebuildScript && !entries.includes(prebuildScript)) {
    throw new Error(`${module.name}: archive is missing prebuild script ${prebuildScript}`)
  }
}

export function verifyReleaseArchives({ modules, moduleRoots, archiveDir }) {
  for (const module of modules) {
    const archive = path.join(archiveDir, `${module.name.replaceAll('/', '-')}-${module.version}.zip`)
    const entries = execFileSync('unzip', ['-Z1', archive], { encoding: 'utf8' }).trim().split('\n')
    const manifest = execFileSync('unzip', ['-p', archive, 'moon.mod'], { encoding: 'utf8' })
    const prebuildScript = manifest.match(/"--moonbit-unstable-prebuild": "([^"]+)"/)?.[1]
    assertReleaseArchiveEntries(module, entries, prebuildScript)
    const sourceManifest = path.join(moduleRoots.get(module.name), 'moon.mod')
    if (manifest !== readFileSync(sourceManifest, 'utf8')) {
      throw new Error(`${module.name}: packaged manifest differs from release source`)
    }
  }
}

// Parent .moonignore rules also affect nested modules. Flat, isolated copies
// preserve each module's own rules without inheriting the meta-package's rules.
export function prepareReleaseWorkspace({ sourceRoot, modules }) {
  const workspaceRoot = mkdtempSync(path.join(os.tmpdir(), 'crater-moon-release-'))
  const cleanup = () => rmSync(workspaceRoot, { recursive: true, force: true })
  try {
    const files = [...new Set(execFileSync('git', [
      '-C', sourceRoot, 'ls-files', '-co', '--exclude-standard', '-z',
    ], { encoding: 'utf8' }).split('\0').filter(Boolean))]
      .filter(file => existsSync(path.join(sourceRoot, file)))
    const moduleDirs = files
      .filter(file => /(?:^|\/)moon\.mod(?:\.json)?$/.test(file))
      .map(file => path.posix.dirname(file))
      .sort((a, b) => b.length - a.length)
    const moduleRoots = new Map(modules.map(module => [
      module.name, path.join(workspaceRoot, module.name.replaceAll('/', '--')),
    ]))
    const selected = new Map(modules.map(module => [module.relativeDir, moduleRoots.get(module.name)]))
    for (const destination of moduleRoots.values()) mkdirSync(destination, { recursive: true })
    for (const file of files) {
      if (path.posix.basename(file) === 'moon.work') continue
      const owner = moduleDirs.find(dir => dir === '.' || file.startsWith(`${dir}/`))
      const destination = selected.get(owner)
      if (!destination) continue
      const source = path.join(sourceRoot, file)
      if (lstatSync(source).isDirectory()) continue // Git submodule entries.
      const target = path.join(destination, path.posix.relative(owner, file))
      mkdirSync(path.dirname(target), { recursive: true })
      copyFileSync(source, target)
    }
    writeFileSync(path.join(workspaceRoot, 'moon.work'),
      `members = [\n${[...moduleRoots.values()].map(dir => `  ${JSON.stringify(path.basename(dir))},`).join('\n')}\n]\n`)
    return { workspaceRoot, moduleRoots, cleanup }
  } catch (error) {
    cleanup()
    throw error
  }
}

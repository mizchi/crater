workflow(name="crater-tests", max_parallel=1)

# Nodes represent coarse execution groups for affected-test scheduling.
node(id="layout", depends_on=[])
node(id="browser", depends_on=[])
node(id="fullstack", depends_on=["layout", "browser"])

# Paint / VRT suites
task(
  id="paint-vrt",
  node="layout",
  cmd=["pnpm", "exec", "playwright", "test", "tests/paint-vrt.test.ts"],
  srcs=[
    "src/layout/**",
    "src/paint/**",
    "src/renderer/**",
    "src/css/**",
    "src/style/**",
    "src/types/**",
    "tests/helpers/**",
    "real-world/**",
  ],
  trigger="auto",
)

task(
  id="paint-vrt-levels",
  node="layout",
  cmd=["pnpm", "exec", "playwright", "test", "tests/paint-vrt-levels.test.ts"],
  srcs=[
    "src/layout/**",
    "src/paint/**",
    "src/renderer/**",
    "src/css/**",
    "src/style/**",
    "src/types/**",
    "tests/helpers/**",
  ],
  needs=["paint-vrt"],
  trigger="auto",
)

task(
  id="paint-vrt-responsive",
  node="layout",
  cmd=["pnpm", "exec", "playwright", "test", "tests/paint-vrt-responsive.test.ts"],
  srcs=[
    "src/layout/**",
    "src/paint/**",
    "src/renderer/**",
    "src/css/**",
    "src/style/**",
    "src/types/**",
    "tests/helpers/**",
  ],
  needs=["paint-vrt"],
  trigger="auto",
)

task(
  id="wpt-vrt",
  node="layout",
  cmd=["pnpm", "exec", "playwright", "test", "tests/wpt-vrt.test.ts"],
  srcs=[
    "src/layout/**",
    "src/paint/**",
    "src/renderer/**",
    "src/css/**",
    "src/style/**",
    "src/types/**",
    "tests/helpers/**",
    "wpt-tests/**",
  ],
  needs=["paint-vrt"],
  trigger="auto",
)

# Browser protocol and adapter suites
task(
  id="playwright-adapter",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "tests/playwright-adapter.test.ts"],
  srcs=["browser/**", "src/bidi/**", "src/dom/**", "src/js/**", "src/renderer/**"],
  trigger="auto",
)

task(
  id="bidi-e2e",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "tests/bidi-e2e.test.ts"],
  srcs=["browser/**", "src/bidi/**"],
  trigger="auto",
)

task(
  id="preact-compat",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "tests/preact-compat.test.ts"],
  srcs=["browser/**", "src/bidi/**", "src/dom/**", "src/js/**"],
  needs=["playwright-adapter"],
  trigger="auto",
)

# Full-stack scenarios split by file or describe block.
task(
  id="website-loading",
  node="fullstack",
  cmd=[
    "pnpm",
    "exec",
    "playwright",
    "test",
    "tests/website-loading.test.ts",
    "--grep",
    "Website Loading Tests",
  ],
  srcs=["src/layout/**", "src/renderer/**", "src/css/**", "browser/**", "tests/helpers/**"],
  needs=["paint-vrt", "playwright-adapter"],
  trigger="auto",
)

task(
  id="script-execution-edge-cases",
  node="fullstack",
  cmd=[
    "pnpm",
    "exec",
    "playwright",
    "test",
    "tests/website-loading.test.ts",
    "--grep",
    "Script Execution Edge Cases",
  ],
  srcs=["browser/**", "src/bidi/**", "src/dom/**", "src/js/**"],
  needs=["playwright-adapter"],
  trigger="auto",
)

task(
  id="browser-user-scenarios",
  node="fullstack",
  cmd=["pnpm", "exec", "playwright", "test", "tests/browser-user-scenarios.test.ts"],
  srcs=["src/layout/**", "src/renderer/**", "src/css/**", "browser/**", "tests/helpers/**"],
  needs=["paint-vrt", "playwright-adapter"],
  trigger="auto",
)

task(
  id="scroll-issue",
  node="fullstack",
  cmd=["pnpm", "exec", "playwright", "test", "tests/scroll-issue.test.ts"],
  srcs=["src/layout/**", "src/renderer/**", "src/css/**", "browser/**"],
  needs=["paint-vrt", "playwright-adapter"],
  trigger="auto",
)

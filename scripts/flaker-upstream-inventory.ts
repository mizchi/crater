#!/usr/bin/env node

import {
  createReportOutputHandlers,
  parseCliFlags,
  renderUsage,
  type ReportOutputCliOptions,
} from "./script-cli.ts";
import {
  appendReportWrites,
  emitScriptExecutionResult,
  isMainModule,
  type ScriptExecutionResult,
} from "./script-runtime.ts";

export type FlakerInventoryCategory =
  | "metric-ci"
  | "crater-adapter"
  | "crater-domain"
  | "crater-tooling";

export interface FlakerUpstreamGroup {
  id: string;
  title: string;
  category: FlakerInventoryCategory;
  status: "ready-to-upstream" | "keep-in-crater";
  origin: "crater-extracted" | "crater-native";
  files: string[];
  testFiles: string[];
  reason: string;
  nextAction: string;
}

export interface FlakerUpstreamInventory {
  schemaVersion: 1;
  generatedAt: string;
  groups: FlakerUpstreamGroup[];
}

interface FlakerUpstreamInventoryCliArgs extends ReportOutputCliOptions {}

const GROUPS: ReadonlyArray<Omit<FlakerUpstreamGroup, "status"> & {
  status: FlakerUpstreamGroup["status"];
}> = [
  {
    id: "playwright-report-core",
    title: "Playwright normalized report core",
    category: "metric-ci",
    status: "ready-to-upstream",
    origin: "crater-extracted",
    files: [
      "scripts/playwright-report-contract.ts",
      "scripts/playwright-report-summary-core.ts",
      "scripts/playwright-report-diff-core.ts",
    ],
    testFiles: [
      "scripts/playwright-report-contract.test.ts",
      "scripts/playwright-report-summary.test.ts",
      "scripts/playwright-report-diff.test.ts",
    ],
    reason: "Crater 固有の task graph を知らずに summary/diff の契約だけで成立する。",
    nextAction: "metric-ci 側へ contract + core を移し、crater 側 wrapper から参照する。",
  },
  {
    id: "flaker-task-summary-core",
    title: "Flaker task summary contract and core",
    category: "metric-ci",
    status: "ready-to-upstream",
    origin: "crater-extracted",
    files: [
      "scripts/flaker-task-summary-contract.ts",
      "scripts/flaker-task-summary-core.ts",
    ],
    testFiles: [
      "scripts/flaker-task-summary-core.test.ts",
    ],
    reason: "eval/reason 出力契約と task summary builder は crater 固有の task graph を知らずに成立する。",
    nextAction: "metric-ci 側の reporting module に移し、crater では task/workspace loader だけを残す。",
  },
  {
    id: "flaker-batch-summary-core",
    title: "Flaker batch aggregate core",
    category: "metric-ci",
    status: "ready-to-upstream",
    origin: "crater-extracted",
    files: [
      "scripts/flaker-batch-summary-core.ts",
    ],
    testFiles: [
      "scripts/flaker-batch-summary-core.test.ts",
    ],
    reason: "履歴集約ロジックは task summary contract と normalized report だけで成立する。",
    nextAction: "metric-ci 側へ core を移し、crater では artifact loader だけを残す。",
  },
  {
    id: "flaker-batch-plan-core",
    title: "Flaker batch plan core",
    category: "metric-ci",
    status: "ready-to-upstream",
    origin: "crater-extracted",
    files: [
      "scripts/flaker-batch-plan-core.ts",
    ],
    testFiles: [
      "scripts/flaker-batch-plan-core.test.ts",
    ],
    reason: "daily batch plan の pure builder と markdown/matrix renderer は flaker config parser と contract だけで成立する。",
    nextAction: "metric-ci 側へ batch plan core を移し、crater では flaker.star の file loading と CLI wrapper だけを残す。",
  },
  {
    id: "flaker-quarantine-core",
    title: "Repo-tracked quarantine core",
    category: "metric-ci",
    status: "ready-to-upstream",
    origin: "crater-extracted",
    files: [
      "scripts/flaker-quarantine-contract.ts",
      "scripts/flaker-quarantine-parser.ts",
      "scripts/flaker-quarantine-match.ts",
      "scripts/flaker-quarantine-expiry.ts",
      "scripts/flaker-quarantine-summary-core.ts",
      "scripts/flaker-quarantine-report.ts",
    ],
    testFiles: [
      "scripts/flaker-quarantine-parser.test.ts",
      "scripts/flaker-quarantine-match.test.ts",
      "scripts/flaker-quarantine-expiry.test.ts",
      "scripts/flaker-quarantine-summary-core.test.ts",
      "scripts/flaker-quarantine-report.test.ts",
    ],
    reason: "manifest / match / expiry / summary は crater の renderer を知らずに成立する。",
    nextAction: "metric-ci 側へ quarantine core を移し、crater は flaker.star 連携 loader だけを持つ。",
  },
  {
    id: "flaker-config-core",
    title: "Flaker config parser, contract, task resolver, selection, summary, and report core",
    category: "metric-ci",
    status: "ready-to-upstream",
    origin: "crater-extracted",
    files: [
      "scripts/flaker-config-parser.ts",
      "scripts/flaker-config-contract.ts",
      "scripts/flaker-config-task.ts",
      "scripts/flaker-config-summary-core.ts",
      "scripts/flaker-config-selection-core.ts",
      "scripts/flaker-config-report.ts",
    ],
    testFiles: [
      "scripts/flaker-config-parser.test.ts",
      "scripts/flaker-config-task.test.ts",
      "scripts/flaker-config-summary-core.test.ts",
      "scripts/flaker-config-selection-core.test.ts",
      "scripts/flaker-config-report.test.ts",
    ],
    reason: "flaker.star parser / config validation / task resolution / affected selection / report の純粋部分は crater の spec discovery や loader を知らずに成立する。",
    nextAction: "metric-ci 側へ parser + contract + task resolver + core + report を移し、crater では spec discovery / loader / wrapper だけを残す。",
  },
  {
    id: "flaker-config-adapter",
    title: "flaker.star repo adapter",
    category: "crater-adapter",
    status: "keep-in-crater",
    origin: "crater-native",
    files: [
      "scripts/flaker-config-summary.ts",
      "scripts/flaker-config-selection.ts",
      "scripts/flaker-config.ts",
    ],
    testFiles: [
      "scripts/flaker-config-summary.test.ts",
      "scripts/flaker-config-selection.test.ts",
      "scripts/flaker-config.test.ts",
    ],
    reason: "crater 固有の spec discovery, task graph, Playwright ownership を解釈する adapter。",
    nextAction: "repo adapter として維持しつつ、core に寄せられる部分だけ段階的に薄くする。",
  },
  {
    id: "task-runner-adapter",
    title: "Task-scoped flaker runner bridge",
    category: "crater-adapter",
    status: "keep-in-crater",
    origin: "crater-native",
    files: [
      "scripts/flaker-task-config.ts",
      "scripts/flaker-task-run.ts",
      "scripts/flaker-task-runtime.ts",
      "scripts/flaker-task-record-artifacts.ts",
      "scripts/flaker-task-record-plan.ts",
      "scripts/flaker-task-record-execution.ts",
      "scripts/flaker-task-record.ts",
      "scripts/flaker-task-summary.ts",
      "scripts/flaker-batch-plan.ts",
    ],
    testFiles: [
      "scripts/flaker-task-config.test.ts",
      "scripts/flaker-task-run.test.ts",
      "scripts/flaker-task-runtime.test.ts",
      "scripts/flaker-task-record-artifacts.test.ts",
      "scripts/flaker-task-record-plan.test.ts",
      "scripts/flaker-task-record-execution.test.ts",
      "scripts/flaker-task-record.test.ts",
      "scripts/flaker-task-summary.test.ts",
      "scripts/flaker-batch-plan.test.ts",
    ],
    reason: "crater の task layout と CI/workspace 配置を flaker 実行・record・summary・batch plan に変換する bridge であり upstream しない。",
    nextAction: "metric-ci 側の API に合わせて wrapper をさらに薄くし、repo/workspace 依存だけを残す。",
  },
  {
    id: "flaker-report-loader-adapter",
    title: "Artifact/VRT/quarantine loader adapters",
    category: "crater-adapter",
    status: "keep-in-crater",
    origin: "crater-native",
    files: [
      "scripts/flaker-batch-summary-loader.ts",
      "scripts/flaker-quarantine-loader.ts",
      "scripts/vrt-report-loader.ts",
      "scripts/flaker-quarantine-summary.ts",
    ],
    testFiles: [
      "scripts/flaker-batch-summary-loader.test.ts",
      "scripts/flaker-quarantine-loader.test.ts",
      "scripts/vrt-report-loader.test.ts",
    ],
    reason: "artifact path 解決と VRT/quarantine file scan・ownership 解決は crater の workspace/layout に依存する loader 層。",
    nextAction: "pure core は upstream しつつ、repo 上の file scan と ownership 解決だけを local adapter として残す。",
  },
  {
    id: "vrt-report-core",
    title: "VRT artifact report contract and summary core",
    category: "crater-domain",
    status: "keep-in-crater",
    origin: "crater-native",
    files: [
      "scripts/vrt-report-contract.ts",
      "scripts/vrt-report-summary-core.ts",
    ],
    testFiles: [
      "scripts/vrt-report-contract.test.ts",
      "scripts/vrt-report-summary.test.ts",
    ],
    reason: "VRT report schema と diff budget 集約は pure だが、diffRatio/threshold/backend/snapshotKind など renderer domain metadata を含むため crater 側の共有契約として持つ。",
    nextAction: "crater / vrt-harness で同じ report schema を共有しつつ、metric-ci には collect された summary artifact だけを渡す。",
  },
  {
    id: "wpt-vrt-summary-core",
    title: "WPT VRT summary core",
    category: "crater-domain",
    status: "keep-in-crater",
    origin: "crater-native",
    files: [
      "scripts/wpt-vrt-summary-core.ts",
    ],
    testFiles: [
      "scripts/wpt-vrt-summary.test.ts",
    ],
    reason: "WPT VRT は markup/render diff の domain で、metric-ci core ではなく crater / vrt-harness 側の責務。",
    nextAction: "report schema だけ共通化し、VRT 固有の meaning は crater に残す。",
  },
  {
    id: "report-cli-wrappers",
    title: "Report and summary CLI wrappers",
    category: "crater-tooling",
    status: "keep-in-crater",
    origin: "crater-native",
    files: [
      "scripts/playwright-report-summary.ts",
      "scripts/playwright-report-diff.ts",
      "scripts/flaker-batch-summary.ts",
      "scripts/flaker-quarantine.ts",
      "scripts/vrt-report-summary.ts",
      "scripts/wpt-vrt-summary.ts",
    ],
    testFiles: [
      "scripts/playwright-report-summary-cli.test.ts",
      "scripts/vrt-report-summary-cli.test.ts",
      "scripts/playwright-report-diff-cli.test.ts",
      "scripts/flaker-batch-summary.test.ts",
      "scripts/flaker-quarantine.test.ts",
      "scripts/wpt-vrt-summary-cli.test.ts",
    ],
    reason: "CLI façade と collect 互換 artifact 出力は crater の運用入口であり、core とは別に local tooling として持つ。",
    nextAction: "metric-ci 側の CLI が揃ったら wrapper を削るか薄い移譲層へ置き換える。",
  },
  {
    id: "flaker-cli-tooling",
    title: "Compact flaker CLI tooling",
    category: "crater-tooling",
    status: "keep-in-crater",
    origin: "crater-native",
    files: [
      "scripts/flaker-defaults.ts",
      "scripts/flaker-cli-path.ts",
      "scripts/flaker-task-cli.ts",
      "scripts/flaker-entry.ts",
    ],
    testFiles: [
      "scripts/flaker-cli-path.test.ts",
      "scripts/flaker-task-cli.test.ts",
      "scripts/flaker-entry.test.ts",
    ],
    reason: "`just flaker` の compact entrypoint と CLI 解決/parse は crater の operator UX を支える local tooling。",
    nextAction: "compact entrypoint の UX を保ちつつ、内部で参照する adapter/wrapper の数を減らす。",
  },
  {
    id: "upstream-staging-tooling",
    title: "Upstream inventory and staging tooling",
    category: "crater-tooling",
    status: "keep-in-crater",
    origin: "crater-native",
    files: [
      "scripts/flaker-upstream-inventory.ts",
      "scripts/flaker-upstream-export.ts",
    ],
    testFiles: [
      "scripts/flaker-upstream-inventory.test.ts",
      "scripts/flaker-upstream-export.test.ts",
    ],
    reason: "`metric-ci` へ切り出す source 群の棚卸しと staging export は crater 側の同期用 tooling。",
    nextAction: "inventory/export を source-of-truth にして ownership drift を検出し続ける。",
  },
  {
    id: "script-runtime-boundary",
    title: "Shared script runtime and boundary guard",
    category: "crater-tooling",
    status: "keep-in-crater",
    origin: "crater-native",
    files: [
      "scripts/flaker-collected-summary-paths.ts",
      "scripts/script-cli.ts",
      "scripts/script-runtime.ts",
      "scripts/script-path.ts",
      "scripts/script-boundary.test.ts",
    ],
    testFiles: [
      "scripts/flaker-collected-summary-paths.test.ts",
    ],
    reason: "repo 内 script 群の共通基盤であり、collect 互換 artifact path の規約も crater workspace 側の tooling として持つ。",
    nextAction: "local tooling として維持し、boundary test と inventory で core/wrapper と collect path 契約の drift を防ぐ。",
  },
] as const;

function categoryRank(category: FlakerInventoryCategory): number {
  if (category === "metric-ci") return 0;
  if (category === "crater-adapter") return 1;
  if (category === "crater-domain") return 2;
  return 3;
}

function usage(): string {
  return renderUsage({
    summary: "Metric CI upstream inventory",
    command: "node scripts/flaker-upstream-inventory.ts [options]",
    optionLines: [
      "  --json <file>       Write JSON inventory",
      "  --markdown <file>   Write markdown inventory",
    ],
    helpLine: "  --help              Show this help",
  });
}

export function parseFlakerUpstreamInventoryArgs(
  args: string[],
): FlakerUpstreamInventoryCliArgs {
  return parseCliFlags(args, {} as FlakerUpstreamInventoryCliArgs, {
    usage,
    handlers: {
      ...createReportOutputHandlers(),
    },
  });
}

export function buildFlakerUpstreamInventory(): FlakerUpstreamInventory {
  const groups = [...GROUPS.entries()].sort(([aIndex, a], [bIndex, b]) => {
    const categoryDiff = categoryRank(a.category) - categoryRank(b.category);
    if (categoryDiff !== 0) return categoryDiff;
    return aIndex - bIndex;
  });

  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    groups: groups.map(([, group]) => ({
      ...group,
      files: [...group.files],
    })),
  };
}

function escapeCell(value: string): string {
  return value.replace(/\|/g, "\\|");
}

export function renderFlakerUpstreamInventoryMarkdown(
  inventory: FlakerUpstreamInventory,
): string {
  const lines: string[] = [];
  lines.push("# Metric CI Upstream Inventory");
  lines.push("");
  lines.push("| Category | Group | Status | Origin | Files | Tests |");
  lines.push("| --- | --- | --- | --- | ---: | ---: |");
  for (const group of inventory.groups) {
    lines.push(
      `| ${group.category} | ${escapeCell(group.id)} | ${group.status} | ${group.origin} | ${group.files.length} | ${group.testFiles.length} |`,
    );
  }

  for (const group of inventory.groups) {
    lines.push("");
    lines.push(`## ${group.id}`);
    lines.push("");
    lines.push(`- Category: ${group.category}`);
    lines.push(`- Status: ${group.status}`);
    lines.push(`- Origin: ${group.origin}`);
    lines.push(`- Reason: ${group.reason}`);
    lines.push(`- Next: ${group.nextAction}`);
    lines.push("- Source files:");
    for (const file of group.files) {
      lines.push(`  - ${file}`);
    }
    if (group.testFiles.length > 0) {
      lines.push("- Reference tests:");
      for (const testFile of group.testFiles) {
        lines.push(`  - ${testFile}`);
      }
    }
  }

  return `${lines.join("\n")}\n`;
}

export function runFlakerUpstreamInventoryCli(
  args: string[],
  options?: {
    cwd?: string;
  },
): ScriptExecutionResult {
  try {
    const parsed = parseFlakerUpstreamInventoryArgs(args);
    const cwd = options?.cwd ?? process.cwd();
    const inventory = buildFlakerUpstreamInventory();
    const markdown = renderFlakerUpstreamInventoryMarkdown(inventory);
    const writes: ScriptExecutionResult["writes"] = [];
    appendReportWrites(writes, {
      cwd,
      markdownPath: parsed.markdownOutput,
      markdownContent: markdown,
      jsonPath: parsed.jsonOutput,
      jsonValue: inventory,
    });
    return {
      exitCode: 0,
      stdout: markdown,
      writes,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      exitCode: 1,
      stderr: `${message}\n`,
      writes: [],
    };
  }
}

if (isMainModule(import.meta.url)) {
  emitScriptExecutionResult(runFlakerUpstreamInventoryCli(process.argv.slice(2)));
}

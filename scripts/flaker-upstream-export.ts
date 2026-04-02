#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import {
  buildFlakerUpstreamInventory,
  type FlakerUpstreamGroup,
} from "./flaker-upstream-inventory.ts";
import {
  assertRequiredOptions,
  parseCliFlags,
  renderUsage,
} from "./script-cli.ts";
import {
  emitScriptExecutionResult,
  isMainModule,
  type ScriptExecutionResult,
  type ScriptOutputFile,
} from "./script-runtime.ts";

export interface FlakerUpstreamExportCliArgs {
  groupId?: string;
  outputDir?: string;
  exportAll?: boolean;
}

export interface FlakerUpstreamExportFile {
  sourcePath: string;
  stagedPath: string;
  bytes: number;
  kind: "source" | "test";
}

export interface FlakerUpstreamExportManifest {
  schemaVersion: 1;
  generatedAt: string;
  group: FlakerUpstreamGroup;
  stageRoot: string;
  fileCount: number;
  testFileCount: number;
  files: FlakerUpstreamExportFile[];
}

export interface FlakerUpstreamExportStage {
  manifest: FlakerUpstreamExportManifest;
  writes: ScriptOutputFile[];
}

export interface FlakerUpstreamExportBundleManifest {
  schemaVersion: 1;
  generatedAt: string;
  stageRoot: string;
  groupCount: number;
  fileCount: number;
  testFileCount: number;
  groups: FlakerUpstreamGroup[];
}

export interface FlakerUpstreamExportBundleStage {
  manifest: FlakerUpstreamExportBundleManifest;
  writes: ScriptOutputFile[];
}

function usage(): string {
  return renderUsage({
    summary: "Stage a ready-to-upstream metric-ci export group",
    command: "node scripts/flaker-upstream-export.ts [options]",
    optionLines: [
      "  --group <id>        Upstream group id to stage",
      "  --all               Stage every ready-to-upstream group",
      "  --output <dir>      Destination root directory",
    ],
    helpLine: "  --help              Show this help",
  });
}

export function parseFlakerUpstreamExportArgs(
  args: string[],
): FlakerUpstreamExportCliArgs {
  const options = parseCliFlags(args, {} as FlakerUpstreamExportCliArgs, {
    usage,
    handlers: {
      "--group": {
        set: (target, value) => {
          target.groupId = value;
        },
      },
      "--all": {
        takesValue: false,
        set: (target) => {
          target.exportAll = true;
        },
      },
      "--output": {
        set: (target, value) => {
          target.outputDir = value;
        },
      },
    },
  });

  if (options.exportAll && options.groupId) {
    throw new Error("--all cannot be used with --group");
  }

  assertRequiredOptions(options, [{
    select: (candidate) => candidate.outputDir,
    errorMessage: "--output requires a destination directory",
  }]);

  if (!options.exportAll) {
    assertRequiredOptions(options, [{
      select: (candidate) => candidate.groupId,
      errorMessage: "--group requires an upstream group id",
    }]);
  }

  return options;
}

export function resolveFlakerUpstreamGroup(groupId: string): FlakerUpstreamGroup {
  const group = buildFlakerUpstreamInventory().groups.find((candidate) => candidate.id === groupId);
  if (!group) {
    throw new Error(`Unknown upstream group: ${groupId}`);
  }
  if (group.status !== "ready-to-upstream") {
    throw new Error(
      `Group ${groupId} is not ready-to-upstream (status: ${group.status})`,
    );
  }
  return group;
}

export function resolveReadyToUpstreamGroups(): FlakerUpstreamGroup[] {
  return buildFlakerUpstreamInventory().groups.filter((group) => group.status === "ready-to-upstream");
}

export function renderFlakerUpstreamExportMarkdown(
  manifest: FlakerUpstreamExportManifest,
): string {
  const lines: string[] = [];
  lines.push("# Metric CI Upstream Export");
  lines.push("");
  lines.push("| Field | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Group | ${manifest.group.id} |`);
  lines.push(`| Category | ${manifest.group.category} |`);
  lines.push(`| Status | ${manifest.group.status} |`);
  lines.push(`| File count | ${manifest.fileCount} |`);
  lines.push(`| Test files | ${manifest.testFileCount} |`);
  lines.push(`| Stage root | ${manifest.stageRoot} |`);
  lines.push("");
  lines.push("## Context");
  lines.push("");
  lines.push(`- Reason: ${manifest.group.reason}`);
  lines.push(`- Next: ${manifest.group.nextAction}`);
  lines.push("");
  lines.push("## Files");
  lines.push("");
  lines.push("| Kind | Source | Staged | Bytes |");
  lines.push("| --- | --- | --- | ---: |");
  for (const file of manifest.files) {
    lines.push(`| ${file.kind} | ${file.sourcePath} | ${file.stagedPath} | ${file.bytes} |`);
  }
  return `${lines.join("\n")}\n`;
}

export function renderFlakerUpstreamExportBundleMarkdown(
  manifest: FlakerUpstreamExportBundleManifest,
): string {
  const lines: string[] = [];
  lines.push("# Metric CI From Crater");
  lines.push("");
  lines.push("`crater` から切り出した TypeScript 参照実装です。`metric-ci` ではこれを MoonBit で書き直します。");
  lines.push("");
  lines.push("| Field | Value |");
  lines.push("| --- | --- |");
  lines.push(`| Stage root | ${manifest.stageRoot} |`);
  lines.push(`| Groups | ${manifest.groupCount} |`);
  lines.push(`| Source files | ${manifest.fileCount} |`);
  lines.push(`| Test files | ${manifest.testFileCount} |`);
  lines.push("");
  lines.push("## Groups");
  lines.push("");
  lines.push("| Group | Files | Tests | Origin |");
  lines.push("| --- | ---: | ---: | --- |");
  for (const group of manifest.groups) {
    lines.push(`| ${group.id} | ${group.files.length} | ${group.testFiles.length} | ${group.origin} |`);
  }
  lines.push("");
  lines.push("## Notes");
  lines.push("");
  lines.push("- ここに置くのは `metric-ci` 側で実装すべき `crater` 由来の source 群だけ");
  lines.push("- `.test.ts` は MoonBit への書き換えで守るべき参照テスト");
  lines.push("- `crater` 側に残る loader / adapter / VRT domain は含めない");
  return `${lines.join("\n")}\n`;
}

export function buildFlakerUpstreamExportStage(
  group: FlakerUpstreamGroup,
  options: {
    cwd: string;
    outputDir: string;
    readFile?: (targetPath: string) => string;
  },
): FlakerUpstreamExportStage {
  const readFile = options.readFile ?? ((targetPath: string) => fs.readFileSync(targetPath, "utf8"));
  const stageRoot = path.resolve(options.cwd, options.outputDir, group.id);
  const stagedEntries = [
    ...group.files.map((sourceRelativePath) => ({
      sourceRelativePath,
      kind: "source" as const,
    })),
    ...group.testFiles.map((sourceRelativePath) => ({
      sourceRelativePath,
      kind: "test" as const,
    })),
  ];

  const fileWrites = stagedEntries.map(({ sourceRelativePath, kind }) => {
    const sourcePath = path.resolve(options.cwd, sourceRelativePath);
    const stagedPath = path.resolve(stageRoot, sourceRelativePath);
    const content = readFile(sourcePath);
    return {
      sourcePath,
      stagedPath,
      content,
      bytes: Buffer.byteLength(content, "utf8"),
      kind,
    };
  });

  const manifest: FlakerUpstreamExportManifest = {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    group: {
      ...group,
      files: [...group.files],
      testFiles: [...group.testFiles],
    },
    stageRoot,
    fileCount: group.files.length,
    testFileCount: group.testFiles.length,
    files: fileWrites.map((file) => ({
      sourcePath: file.sourcePath,
      stagedPath: file.stagedPath,
      bytes: file.bytes,
      kind: file.kind,
    })),
  };

  const markdown = renderFlakerUpstreamExportMarkdown(manifest);
  const writes: ScriptOutputFile[] = [
    ...fileWrites.map((file) => ({
      path: file.stagedPath,
      content: file.content,
    })),
    {
      path: path.resolve(stageRoot, "manifest.md"),
      content: markdown,
    },
    {
      path: path.resolve(stageRoot, "manifest.json"),
      content: `${JSON.stringify(manifest, null, 2)}\n`,
    },
  ];

  return {
    manifest,
    writes,
  };
}

export function buildFlakerUpstreamExportBundleStage(
  groups: FlakerUpstreamGroup[],
  options: {
    cwd: string;
    outputDir: string;
    readFile?: (targetPath: string) => string;
  },
): FlakerUpstreamExportBundleStage {
  const stages = groups.map((group) =>
    buildFlakerUpstreamExportStage(group, options)
  );
  const stageRoot = path.resolve(options.cwd, options.outputDir);
  const manifest: FlakerUpstreamExportBundleManifest = {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    stageRoot,
    groupCount: stages.length,
    fileCount: stages.reduce((sum, stage) => sum + stage.manifest.fileCount, 0),
    testFileCount: stages.reduce((sum, stage) => sum + stage.manifest.testFileCount, 0),
    groups: stages.map((stage) => ({
      ...stage.manifest.group,
      files: [...stage.manifest.group.files],
      testFiles: [...stage.manifest.group.testFiles],
    })),
  };
  const markdown = renderFlakerUpstreamExportBundleMarkdown(manifest);
  return {
    manifest,
    writes: [
      ...stages.flatMap((stage) => stage.writes),
      {
        path: path.resolve(stageRoot, "README.md"),
        content: markdown,
      },
      {
        path: path.resolve(stageRoot, "manifest.json"),
        content: `${JSON.stringify(manifest, null, 2)}\n`,
      },
    ],
  };
}

export function runFlakerUpstreamExportCli(
  args: string[],
  options?: {
    cwd?: string;
    readFile?: (targetPath: string) => string;
  },
): ScriptExecutionResult {
  try {
    const parsed = parseFlakerUpstreamExportArgs(args);
    const cwd = options?.cwd ?? process.cwd();
    const result = parsed.exportAll
      ? buildFlakerUpstreamExportBundleStage(resolveReadyToUpstreamGroups(), {
        cwd,
        outputDir: parsed.outputDir!,
        readFile: options?.readFile,
      })
      : buildFlakerUpstreamExportStage(resolveFlakerUpstreamGroup(parsed.groupId!), {
        cwd,
        outputDir: parsed.outputDir!,
        readFile: options?.readFile,
      });
    return {
      exitCode: 0,
      stdout: "group" in result.manifest
        ? renderFlakerUpstreamExportMarkdown(result.manifest)
        : renderFlakerUpstreamExportBundleMarkdown(result.manifest),
      writes: result.writes,
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
  emitScriptExecutionResult(runFlakerUpstreamExportCli(process.argv.slice(2)));
}

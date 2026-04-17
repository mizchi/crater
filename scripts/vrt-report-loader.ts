import fs from "node:fs";
import path from "node:path";
import type { LoadedVrtArtifactReport } from "./vrt-report-summary-core.ts";
import {
  readVrtArtifactIdentity,
  readVrtArtifactMetrics,
  readVrtArtifactTitle,
  type VrtArtifactRawReport,
  type VrtStableIdentity,
} from "./vrt-report-contract.ts";

function collectReportFiles(rootDir: string): string[] {
  if (!fs.existsSync(rootDir)) {
    return [];
  }
  const files: string[] = [];
  const stack = [rootDir];

  while (stack.length > 0) {
    const current = stack.pop()!;
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const targetPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(targetPath);
        continue;
      }
      if (entry.isFile() && entry.name === "report.json") {
        files.push(targetPath);
      }
    }
  }

  return files.sort();
}

function readJsonReport(filePath: string): VrtArtifactRawReport | null {
  try {
    const parsed = JSON.parse(fs.readFileSync(filePath, "utf8")) as unknown;
    if (readVrtArtifactMetrics(parsed) === null) {
      return null;
    }
    return parsed as VrtArtifactRawReport;
  } catch {
    return null;
  }
}

function normalizeLabel(rootDir: string, reportPath: string): string {
  const relativeDir = path.relative(rootDir, path.dirname(reportPath));
  return relativeDir.length > 0 ? relativeDir : ".";
}

function collectVariantKeys(identities: Array<VrtStableIdentity | undefined>): string[] {
  return [...new Set(
    identities.flatMap((identity) => Object.keys(identity?.variant ?? {})),
  )].sort((a, b) => a.localeCompare(b));
}

function valueVaries<T>(values: T[]): boolean {
  return new Set(values).size > 1;
}

function buildDuplicateLabel(
  title: string,
  fallbackLabel: string,
  identity: VrtStableIdentity | undefined,
  group: Array<{ fallbackLabel: string; identity?: VrtStableIdentity }>,
): string {
  const identities = group.map((entry) => entry.identity);
  const parts: string[] = [];

  for (const key of collectVariantKeys(identities)) {
    const values = group.map((entry) => entry.identity?.variant[key] ?? "");
    if (!valueVaries(values)) {
      continue;
    }
    const value = identity?.variant[key];
    if (value) {
      parts.push(`${key}=${value}`);
    }
  }

  const shardValues = group.map((entry) => entry.identity?.shard ?? "");
  if (valueVaries(shardValues) && identity?.shard) {
    parts.push(`shard=${identity.shard}`);
  }

  const filterValues = group.map((entry) => entry.identity?.filter ?? "");
  if (parts.length === 0 && valueVaries(filterValues) && identity?.filter && identity.filter !== title) {
    parts.push(`filter=${identity.filter}`);
  }

  if (parts.length > 0) {
    return `${title} [${parts.join(", ")}]`;
  }

  return fallbackLabel !== title ? `${title} @ ${fallbackLabel}` : title;
}

function disambiguateReportLabels(
  reports: Array<LoadedVrtArtifactReport & {
    fallbackLabel: string;
    identity?: VrtStableIdentity;
  }>,
): LoadedVrtArtifactReport[] {
  const groups = new Map<string, Array<typeof reports[number]>>();
  for (const report of reports) {
    const current = groups.get(report.label) ?? [];
    current.push(report);
    groups.set(report.label, current);
  }

  const withDisambiguatedLabels = reports.map((report) => {
    const group = groups.get(report.label) ?? [report];
    if (group.length <= 1) {
      return {
        label: report.label,
        reportPath: report.reportPath,
        report: report.report,
      };
    }
    return {
      label: buildDuplicateLabel(report.label, report.fallbackLabel, report.identity, group),
      reportPath: report.reportPath,
      report: report.report,
    };
  });

  const resolvedCounts = new Map<string, number>();
  for (const report of withDisambiguatedLabels) {
    resolvedCounts.set(report.label, (resolvedCounts.get(report.label) ?? 0) + 1);
  }

  return withDisambiguatedLabels.map((report, index) => {
    if ((resolvedCounts.get(report.label) ?? 0) <= 1) {
      return report;
    }
    const original = reports[index]!;
    return {
      label: `${report.label} @ ${original.fallbackLabel}`,
      reportPath: report.reportPath,
      report: report.report,
    };
  });
}

export function loadVrtArtifactReports(inputDir: string): LoadedVrtArtifactReport[] {
  const rows: Array<LoadedVrtArtifactReport & {
    fallbackLabel: string;
    identity?: VrtStableIdentity;
  }> = [];
  for (const reportPath of collectReportFiles(inputDir)) {
    const report = readJsonReport(reportPath);
    if (!report) {
      continue;
    }
    const fallbackLabel = normalizeLabel(inputDir, reportPath);
    rows.push({
      label: readVrtArtifactTitle(report, fallbackLabel),
      fallbackLabel,
      reportPath,
      report,
      identity: readVrtArtifactIdentity(report),
    });
  }
  return disambiguateReportLabels(rows)
    .sort((a, b) => a.label.localeCompare(b.label));
}

import type { FlakerIssue } from "./flaker-config-contract.ts";
import type {
  FlakerQuarantineConfig,
  FlakerQuarantineExpiryStatus,
  FlakerQuarantineMode,
  FlakerQuarantineScope,
  FlakerQuarantineSummary,
  FlakerResolvedQuarantineEntry,
} from "./flaker-quarantine-contract.ts";
import {
  classifyQuarantineExpiry,
  normalizeToUtcMidnight,
  parseDateOnly,
} from "./flaker-quarantine-expiry.ts";
import { compileTitlePattern } from "./flaker-quarantine-match.ts";

const DEFAULT_EXPIRES_SOON_DAYS = 7;

export interface FlakerQuarantineTaskOwnership {
  id: string;
  specs: string[];
}

export interface BuildFlakerQuarantineSummaryInputs {
  quarantine: FlakerQuarantineConfig;
  tasks: FlakerQuarantineTaskOwnership[];
  existingSpecs: Set<string>;
  now?: Date;
  expiresSoonDays?: number;
}

function createIssue(issue: FlakerIssue): FlakerIssue {
  return issue;
}

function buildModeCounts(): Record<FlakerQuarantineMode, number> {
  return {
    skip: 0,
    allow_flaky: 0,
    allow_failure: 0,
  };
}

function buildScopeCounts(): Record<FlakerQuarantineScope, number> {
  return {
    environment: 0,
    flaky: 0,
    expected_failure: 0,
  };
}

export function buildFlakerQuarantineSummary(
  inputs: BuildFlakerQuarantineSummaryInputs,
): FlakerQuarantineSummary {
  const now = normalizeToUtcMidnight(inputs.now ?? new Date());
  const expiresSoonDays = inputs.expiresSoonDays ?? DEFAULT_EXPIRES_SOON_DAYS;
  const taskById = new Map(inputs.tasks.map((task) => [task.id, task]));
  const errors: FlakerIssue[] = [];
  const warnings: FlakerIssue[] = [];
  const seenIds = new Set<string>();
  const entries: FlakerResolvedQuarantineEntry[] = [];
  const modeCounts = buildModeCounts();
  const scopeCounts = buildScopeCounts();

  for (const entry of inputs.quarantine.entries) {
    modeCounts[entry.mode] += 1;
    scopeCounts[entry.scope] += 1;

    if (seenIds.has(entry.id)) {
      errors.push(createIssue({
        severity: "error",
        code: "duplicate-quarantine-id",
        message: `Duplicate quarantine id: ${entry.id}`,
        taskId: entry.taskId,
        spec: entry.spec,
      }));
    } else {
      seenIds.add(entry.id);
    }

    const task = taskById.get(entry.taskId);
    if (!task) {
      errors.push(createIssue({
        severity: "error",
        code: "unknown-task",
        message: `Quarantine entry references unknown task: ${entry.taskId}`,
        taskId: entry.taskId,
        spec: entry.spec,
      }));
    }

    if (!inputs.existingSpecs.has(entry.spec)) {
      errors.push(createIssue({
        severity: "error",
        code: "missing-spec",
        message: `Quarantine entry references missing spec: ${entry.spec}`,
        taskId: entry.taskId,
        spec: entry.spec,
      }));
    } else if (task && !task.specs.includes(entry.spec)) {
      errors.push(createIssue({
        severity: "error",
        code: "task-does-not-own-spec",
        message: `Task ${entry.taskId} does not own spec ${entry.spec}`,
        taskId: entry.taskId,
        spec: entry.spec,
      }));
    }

    if (!compileTitlePattern(entry.titlePattern)) {
      errors.push(createIssue({
        severity: "error",
        code: "invalid-title-pattern",
        message: `Invalid title pattern for quarantine ${entry.id}: ${entry.titlePattern}`,
        taskId: entry.taskId,
        spec: entry.spec,
      }));
    }

    const introducedAt = parseDateOnly(entry.introducedAt);
    if (!introducedAt) {
      errors.push(createIssue({
        severity: "error",
        code: "invalid-introduced-at",
        message: `Invalid introducedAt for quarantine ${entry.id}: ${entry.introducedAt}`,
        taskId: entry.taskId,
        spec: entry.spec,
      }));
    }

    const expiresAt = parseDateOnly(entry.expiresAt);
    if (!expiresAt) {
      errors.push(createIssue({
        severity: "error",
        code: "invalid-expires-at",
        message: `Invalid expiresAt for quarantine ${entry.id}: ${entry.expiresAt}`,
        taskId: entry.taskId,
        spec: entry.spec,
      }));
    }

    if (introducedAt && expiresAt && introducedAt.getTime() > expiresAt.getTime()) {
      errors.push(createIssue({
        severity: "error",
        code: "invalid-expiry-range",
        message: `introducedAt must be on or before expiresAt for quarantine ${entry.id}`,
        taskId: entry.taskId,
        spec: entry.spec,
      }));
    }

    const expiry = classifyQuarantineExpiry(now, expiresAt, expiresSoonDays);
    const expiryStatus: FlakerQuarantineExpiryStatus = expiry.status;
    const daysUntilExpiry = expiry.daysUntilExpiry;

    if (expiryStatus === "expired") {
      errors.push(createIssue({
        severity: "error",
        code: "expired-quarantine",
        message: `Quarantine ${entry.id} expired on ${entry.expiresAt}`,
        taskId: entry.taskId,
        spec: entry.spec,
      }));
    } else if (expiryStatus === "expires-soon") {
      warnings.push(createIssue({
        severity: "warning",
        code: "expires-soon",
        message: `Quarantine ${entry.id} expires on ${entry.expiresAt}`,
        taskId: entry.taskId,
        spec: entry.spec,
      }));
    }

    entries.push({
      ...entry,
      expiryStatus,
      daysUntilExpiry,
    });
  }

  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    entryCount: inputs.quarantine.entries.length,
    modeCounts,
    scopeCounts,
    entries: entries.sort((a, b) => a.id.localeCompare(b.id)),
    errors,
    warnings,
  };
}

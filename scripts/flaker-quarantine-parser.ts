import path from "node:path";
import type {
  FlakerQuarantineConfig,
  FlakerQuarantineMode,
  FlakerQuarantineScope,
} from "./flaker-quarantine-contract.ts";

function expectRecord(value: unknown, label: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
  return value as Record<string, unknown>;
}

function expectString(record: Record<string, unknown>, key: string, label: string): string {
  const value = record[key];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${label}.${key} must be a non-empty string`);
  }
  return value.trim();
}

function expectEnum<T extends string>(
  value: string,
  allowed: readonly T[],
  label: string,
): T {
  if ((allowed as readonly string[]).includes(value)) {
    return value as T;
  }
  throw new Error(`${label} must be one of: ${allowed.join(", ")}`);
}

function optionalString(
  record: Record<string, unknown>,
  key: string,
): string | undefined {
  const value = record[key];
  if (value === undefined || value === null || value === "") {
    return undefined;
  }
  if (typeof value !== "string") {
    throw new Error(`entry.${key} must be a string when provided`);
  }
  return value.trim();
}

export function parseFlakerQuarantine(source: string): FlakerQuarantineConfig {
  const raw = JSON.parse(source) as unknown;
  const record = expectRecord(raw, "quarantine");
  if (record.schemaVersion !== 1) {
    throw new Error("quarantine.schemaVersion must be 1");
  }
  if (!Array.isArray(record.entries)) {
    throw new Error("quarantine.entries must be an array");
  }

  const entries = record.entries.map((entry, index) => {
    const item = expectRecord(entry, `entry[${index}]`);
    return {
      id: expectString(item, "id", "entry"),
      taskId: expectString(item, "taskId", "entry"),
      spec: expectString(item, "spec", "entry").split(path.sep).join("/"),
      titlePattern: expectString(item, "titlePattern", "entry"),
      mode: expectEnum(
        expectString(item, "mode", "entry"),
        ["skip", "allow_flaky", "allow_failure"] as const satisfies readonly FlakerQuarantineMode[],
        "entry.mode",
      ),
      scope: expectEnum(
        expectString(item, "scope", "entry"),
        ["environment", "flaky", "expected_failure"] as const satisfies readonly FlakerQuarantineScope[],
        "entry.scope",
      ),
      owner: expectString(item, "owner", "entry"),
      reason: expectString(item, "reason", "entry"),
      condition: expectString(item, "condition", "entry"),
      introducedAt: expectString(item, "introducedAt", "entry"),
      expiresAt: expectString(item, "expiresAt", "entry"),
      trackingIssue: optionalString(item, "trackingIssue"),
    };
  });

  return {
    schemaVersion: 1,
    entries,
  };
}

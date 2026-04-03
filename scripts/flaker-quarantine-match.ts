import type {
  FlakerQuarantineConfig,
  FlakerQuarantineEntry,
  FlakerQuarantineMode,
} from "./flaker-quarantine-contract.ts";

export interface QuarantineLookup {
  taskId: string;
  spec: string;
  title: string;
  mode?: FlakerQuarantineMode;
}

export function compileTitlePattern(pattern: string): RegExp | null {
  try {
    return new RegExp(pattern);
  } catch {
    return null;
  }
}

export function findMatchingQuarantine(
  config: FlakerQuarantineConfig,
  lookup: QuarantineLookup,
): FlakerQuarantineEntry | undefined {
  return config.entries.find((entry) => {
    if (entry.taskId !== lookup.taskId) return false;
    if (entry.spec !== lookup.spec) return false;
    if (lookup.mode && entry.mode !== lookup.mode) return false;
    const titlePattern = compileTitlePattern(entry.titlePattern);
    if (!titlePattern) return false;
    return titlePattern.test(lookup.title);
  });
}

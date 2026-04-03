import type { FlakerIssue } from "./flaker-config-contract.ts";

export type FlakerQuarantineMode = "skip" | "allow_flaky" | "allow_failure";
export type FlakerQuarantineScope = "environment" | "flaky" | "expected_failure";
export type FlakerQuarantineExpiryStatus = "active" | "expires-soon" | "expired" | "invalid";

export interface FlakerQuarantineEntry {
  id: string;
  taskId: string;
  spec: string;
  titlePattern: string;
  mode: FlakerQuarantineMode;
  scope: FlakerQuarantineScope;
  owner: string;
  reason: string;
  condition: string;
  introducedAt: string;
  expiresAt: string;
  trackingIssue?: string;
}

export interface FlakerQuarantineConfig {
  schemaVersion: 1;
  entries: FlakerQuarantineEntry[];
}

export interface FlakerResolvedQuarantineEntry extends FlakerQuarantineEntry {
  expiryStatus: FlakerQuarantineExpiryStatus;
  daysUntilExpiry: number | null;
}

export interface FlakerQuarantineSummary {
  schemaVersion: 1;
  generatedAt: string;
  entryCount: number;
  modeCounts: Record<FlakerQuarantineMode, number>;
  scopeCounts: Record<FlakerQuarantineScope, number>;
  entries: FlakerResolvedQuarantineEntry[];
  errors: FlakerIssue[];
  warnings: FlakerIssue[];
}

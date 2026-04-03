import type { FlakerQuarantineExpiryStatus } from "./flaker-quarantine-contract.ts";

export interface QuarantineExpiry {
  status: FlakerQuarantineExpiryStatus;
  daysUntilExpiry: number | null;
}

export function parseDateOnly(value: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return null;
  }
  const parsed = new Date(`${value}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed.toISOString().slice(0, 10) === value ? parsed : null;
}

export function normalizeToUtcMidnight(value: Date): Date {
  return new Date(Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()));
}

export function diffInDays(start: Date, end: Date): number {
  return Math.floor((end.getTime() - start.getTime()) / 86_400_000);
}

export function classifyQuarantineExpiry(
  now: Date,
  expiresAt: Date | null,
  expiresSoonDays: number,
): QuarantineExpiry {
  if (!expiresAt) {
    return {
      status: "invalid",
      daysUntilExpiry: null,
    };
  }

  const daysUntilExpiry = diffInDays(now, expiresAt);
  return {
    status: daysUntilExpiry < 0
      ? "expired"
      : daysUntilExpiry <= expiresSoonDays
      ? "expires-soon"
      : "active",
    daysUntilExpiry,
  };
}

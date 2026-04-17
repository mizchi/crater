export function normalizeStableIdentityVariant(
  variant: Record<string, string> | null | undefined,
): Record<string, string> {
  if (!variant) {
    return {};
  }
  return Object.fromEntries(
    Object.entries(variant)
      .filter((entry) => entry[1].length > 0)
      .sort((a, b) => a[0].localeCompare(b[0])),
  );
}

export function buildStableIdentityKey(
  entries: Array<readonly [string, unknown] | undefined>,
): string {
  const payload: Record<string, unknown> = {};
  for (const entry of entries) {
    if (!entry) {
      continue;
    }
    payload[entry[0]] = entry[1];
  }
  return JSON.stringify(payload);
}

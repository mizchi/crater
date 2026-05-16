/**
 * Implements the CSS Fonts Level 4 §5.2 font weight matching algorithm
 * plus the pure FONT_FILE_MAP helpers that surface declared weight slots
 * before any filesystem lookup.
 *
 * Used by start-with-font.ts to route numeric font-weight (e.g. 500) to the
 * loaded face that best matches, instead of collapsing to a regular/bold bool.
 *
 * Implements: paint.font-weight-numeric (GitHub issue #48), Layer B.
 */

export interface FontFileMapEntry {
  regular: string[];
  bold: string[];
  byWeight?: Record<number, string[]>;
}

/**
 * Returns the candidate file names for a given CSS weight from a FONT_FILE_MAP
 * entry. Weights 400 and 700 fall back to the regular / bold slots so the
 * declared byWeight map can omit them. Returns an empty array when no
 * candidates are declared.
 */
export function selectWeightCandidates(
  entry: FontFileMapEntry,
  weight: number,
): readonly string[] {
  if (weight === 400) return entry.regular;
  if (weight === 700) return entry.bold;
  return entry.byWeight?.[weight] ?? [];
}

/**
 * Returns the set of weights a FONT_FILE_MAP entry declares candidates for,
 * including the implicit 400 / 700 slots when the regular / bold lists are
 * non-empty. Sorted ascending.
 */
export function declaredWeightsForEntry(entry: FontFileMapEntry): number[] {
  const weights = new Set<number>();
  if (entry.regular.length > 0) weights.add(400);
  if (entry.bold.length > 0) weights.add(700);
  if (entry.byWeight) {
    for (const key of Object.keys(entry.byWeight)) {
      const n = Number(key);
      if (Number.isFinite(n) && (entry.byWeight[n] ?? []).length > 0) {
        weights.add(n);
      }
    }
  }
  return [...weights].sort((a, b) => a - b);
}

export function pickNearestFontWeight(
  available: readonly number[],
  requested: number,
): number | null {
  if (available.length === 0) return null;

  const sorted = [...new Set(available)].sort((a, b) => a - b);

  if (requested >= 400 && requested <= 500) {
    const inRangeAscending = sorted.filter(
      (w) => w >= requested && w <= 500,
    );
    if (inRangeAscending.length > 0) return inRangeAscending[0];
    const belowRequested = sorted.filter((w) => w < requested);
    if (belowRequested.length > 0) return belowRequested[belowRequested.length - 1];
    const above500 = sorted.filter((w) => w > 500);
    if (above500.length > 0) return above500[0];
    return null;
  }

  if (requested < 400) {
    const atOrBelow = sorted.filter((w) => w <= requested);
    if (atOrBelow.length > 0) return atOrBelow[atOrBelow.length - 1];
    const above = sorted.filter((w) => w > requested);
    if (above.length > 0) return above[0];
    return null;
  }

  const atOrAbove = sorted.filter((w) => w >= requested);
  if (atOrAbove.length > 0) return atOrAbove[0];
  const below = sorted.filter((w) => w < requested);
  if (below.length > 0) return below[below.length - 1];
  return null;
}

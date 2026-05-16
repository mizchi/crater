/**
 * Implements the CSS Fonts Level 4 §5.2 font weight matching algorithm.
 *
 * Given the set of weights actually loaded for a family, pick the one nearest
 * to the requested weight using the spec's tie-breaking rules.
 *
 * Used by start-with-font.ts to route numeric font-weight (e.g. 500) to the
 * loaded face that best matches, instead of collapsing to a regular/bold bool.
 *
 * Implements: paint.font-weight-numeric (GitHub issue #48).
 */

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

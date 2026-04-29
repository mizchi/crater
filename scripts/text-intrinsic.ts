/**
 * Text intrinsic measurement function factory.
 * Shared between wpt-runner.ts and BiDi server font loader.
 */

export type ExternalTextIntrinsicFn = (
  text: string,
  fontSize: number,
  lineHeight: number,
  whiteSpace: string,
  writingMode: string,
  fontFamily: string,
  availableWidth: number,
  availableHeight: number,
) => { minWidth: number; maxWidth: number; minHeight: number; maxHeight: number };

type TextIntrinsicResult = ReturnType<ExternalTextIntrinsicFn>;

const TEXT_MEASURE_CACHE_LIMIT = 20_000;
const TEXT_INTRINSIC_CACHE_LIMIT = 10_000;

function hasFiniteNumber(v: unknown): v is number {
  return typeof v === "number" && Number.isFinite(v);
}

function resolveMeasuredAdvance(
  measured: unknown,
  text: string,
  fontSize: number,
  fontFamily: string,
): number {
  if (text.length === 0) return 0;
  if (hasFiniteNumber(measured) && measured > 0) return measured;
  if (fontFamily.toLowerCase().includes("ahem")) {
    return text.length * (fontSize > 0 ? fontSize : 16);
  }
  return text.length * (fontSize > 0 ? fontSize * 0.5 : 8);
}

export function createTextIntrinsicFnFromMeasureText(
  measureText: (text: string, fontSize: number, fontFamily: string) => number,
): ExternalTextIntrinsicFn {
  const measureCache = new Map<string, number>();
  const intrinsicCache = new Map<string, TextIntrinsicResult>();
  const cacheGetOrSet = <T>(
    cache: Map<string, T>,
    limit: number,
    key: string,
    compute: () => T,
  ): T => {
    const cached = cache.get(key);
    if (cached !== undefined) return cached;
    const value = compute();
    if (cache.size >= limit) cache.clear();
    cache.set(key, value);
    return value;
  };
  return (
    text: string,
    fontSize: number,
    lineHeight: number,
    whiteSpace: string,
    writingMode: string,
    fontFamily: string,
    availableWidth: number,
    availableHeight: number,
  ) => {
    const intrinsicKey = [
      text,
      fontSize,
      lineHeight,
      whiteSpace,
      writingMode,
      fontFamily,
      availableWidth,
      availableHeight,
    ].join("\u0000");
    return cacheGetOrSet(intrinsicCache, TEXT_INTRINSIC_CACHE_LIMIT, intrinsicKey, () => {
      const effectiveLineHeight = lineHeight > 0 ? lineHeight : (fontSize > 0 ? fontSize : 16);
      const measure = (s: string): number => {
        const measureKey = `${fontSize}\u0000${fontFamily}\u0000${s}`;
        return cacheGetOrSet(measureCache, TEXT_MEASURE_CACHE_LIMIT, measureKey, () => {
          const measured = measureText(s, fontSize, fontFamily);
          return resolveMeasuredAdvance(measured, s, fontSize, fontFamily);
        });
      };
      const whiteSpaceMode = whiteSpace.toLowerCase();
      const preserveSpaces =
        whiteSpaceMode === "pre" ||
        whiteSpaceMode === "pre-wrap" ||
        whiteSpaceMode === "break-spaces";
      const preserveLineBreaks =
        whiteSpaceMode === "pre" ||
        whiteSpaceMode === "pre-wrap" ||
        whiteSpaceMode === "pre-line" ||
        whiteSpaceMode === "break-spaces";
      const normalizedText = text.replace(/\r\n?/g, "\n");
      const lineSource = preserveLineBreaks
        ? normalizedText
        : normalizedText.replace(/\s+/g, " ").trim();
      const rawLines = preserveLineBreaks ? lineSource.split("\n") : [lineSource];
      const normalizeLine = (line: string): string => {
        if (preserveSpaces) return line;
        return line.replace(/[ \t\f\v\r]+/g, " ").trim();
      };
      const normalizedLines = rawLines.map(normalizeLine);
      const hasRenderableText = normalizedLines.some((line) => line.length > 0);
      if (!hasRenderableText && !preserveLineBreaks) {
        return { minWidth: 0, maxWidth: 0, minHeight: 0, maxHeight: 0 };
      }
      const maxWidth = normalizedLines.reduce((acc, line) => Math.max(acc, measure(line)), 0);
      const minWordWidth = normalizedLines.reduce((acc, line) => {
        const words = line.split(/\s+/).filter(Boolean);
        if (words.length === 0) return acc;
        return Math.max(acc, ...words.map((word) => measure(word)));
      }, 0);
      const noWrap = whiteSpaceMode.includes("nowrap") || whiteSpaceMode === "pre";
      const spaceWidth = measure(" ");
      const wrapEpsilon = 0.01;
      const isVertical = writingMode.toLowerCase().includes("vertical");
      const availableInline = isVertical ? availableHeight : availableWidth;
      const lineSize = isVertical ? (fontSize > 0 ? fontSize * 0.5 : 8) : effectiveLineHeight;
      const _colsAvailable = noWrap
        ? Number.MAX_SAFE_INTEGER
        : availableInline > 0
          ? Math.max(1, Math.floor(availableInline / lineSize))
          : 0;
      let wrappedLines = 0;
      for (const rawLine of rawLines) {
        const line = normalizeLine(rawLine);
        if (noWrap || availableInline <= 0) {
          wrappedLines += 1;
          continue;
        }
        const words = line.split(/\s+/).filter(Boolean);
        if (words.length === 0) {
          wrappedLines += 1;
          continue;
        }
        let current = 0;
        for (const word of words) {
          const width = measure(word);
          if (current === 0) {
            current = width;
            continue;
          }
          const next = current + spaceWidth + width;
          if (next <= availableInline + wrapEpsilon) {
            current = next;
          } else {
            wrappedLines += 1;
            current = width;
          }
        }
        wrappedLines += 1;
      }
      const minLineCount = preserveLineBreaks ? rawLines.length : 1;
      const minHeight = Math.max(minLineCount, 1) * effectiveLineHeight;
      const maxHeight = Math.max(wrappedLines, 1) * effectiveLineHeight;
      if (isVertical) {
        const maxWrappedHeight = noWrap
          ? maxWidth
          : availableInline > 0
            ? Math.min(maxWidth, _colsAvailable * lineSize)
            : maxWidth;
        return {
          minWidth: minHeight,
          maxWidth: maxHeight,
          minHeight: minWordWidth,
          maxHeight: maxWrappedHeight,
        };
      }
      return { minWidth: minWordWidth, maxWidth, minHeight, maxHeight };
    });
  };
}

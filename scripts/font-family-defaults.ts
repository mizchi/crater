export const DEFAULT_TEXT_FONT_FAMILY = "serif, times new roman";

export function resolveEffectiveFontFamily(fontFamily?: string | null): string {
  const normalized = fontFamily?.trim();
  return normalized && normalized.length > 0 ? normalized : DEFAULT_TEXT_FONT_FAMILY;
}

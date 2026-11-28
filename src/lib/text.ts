/** Compose decomposed Hangul for display without rewriting imported filenames or data. */
export function normalizeDisplayText(text: string): string {
  return text.normalize("NFC");
}

import { loadAppearance, loadPageScale, type Appearance } from "./appearance";

function loadNumber(key: string, fallback: number, min: number, max: number) {
  const value = Number(localStorage.getItem(key));
  return Number.isFinite(value) && value >= min && value <= max ? value : fallback;
}

/** Shared UI preferences, persisted by the root component. */
export const ui = $state({
  appearance: loadAppearance() as Appearance,
  pageScale: loadPageScale(),
  readerTextSize: loadNumber("sori-reader-size", 16, 12, 28),
  readerLineHeight: loadNumber("sori-reader-line", 40, 20, 64),
  transcriptLineHeight: loadNumber("sori-transcript-line", 28, 18, 48),
  readingFont: (localStorage.getItem("sori-reading-font") === "inter" ? "inter" : "noto") as
    "noto" | "inter",
});

export function persistUi() {
  localStorage.setItem("sori-appearance", ui.appearance);
  localStorage.setItem("sori-page-scale", String(ui.pageScale));
  localStorage.setItem("sori-reader-size", String(ui.readerTextSize));
  localStorage.setItem("sori-reader-line", String(ui.readerLineHeight));
  localStorage.setItem("sori-transcript-line", String(ui.transcriptLineHeight));
  localStorage.setItem("sori-reading-font", ui.readingFont);
}

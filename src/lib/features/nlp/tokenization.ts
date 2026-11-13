import { invoke } from "@tauri-apps/api/core";

export type KoreanToken = {
  /** Analyzed morpheme form. Conjugated forms can differ from the original surface. */
  form: string;
  tag: string;
  surface: string;
  /** UTF-16 code-unit offsets into the original text, suitable for text.slice(start, end). */
  start: number;
  end: number;
  wordIndex: number;
  sentenceIndex: number;
};

/** Analyze a passage of up to 16 KiB of UTF-8 text using bundled offline Kiwi resources. */
export function tokenizeText(text: string) {
  return invoke<KoreanToken[]>("tokenize_text", { text });
}

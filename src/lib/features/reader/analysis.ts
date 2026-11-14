import { invoke } from "@tauri-apps/api/core";
import type { KoreanToken } from "../nlp/tokenization";

export type WordAnalysis = {
  word: string;
  context: string;
  morphemes: KoreanToken[];
};

export function analyzeDocumentWord(id: number, start: number, end: number) {
  return invoke<WordAnalysis>("analyze_document_word", { id, start, end });
}

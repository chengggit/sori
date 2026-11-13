import { invoke } from "@tauri-apps/api/core";

export type SaveVocabulary = {
  word: string;
  normalizedForm?: string | null;
  documentId: number;
  context: string;
};

export type VocabularyEntry = {
  id: number;
  word: string;
  normalizedForm: string | null;
  documentId: number | null;
  sourceTitle: string;
  context: string;
  /** Unix time in seconds. */
  createdAt: number;
};

export function saveVocabulary(input: SaveVocabulary) {
  return invoke<VocabularyEntry>("save_vocabulary", { input });
}

export function listVocabulary() {
  return invoke<VocabularyEntry[]>("list_vocabulary");
}

export function removeVocabulary(id: number) {
  return invoke<void>("remove_vocabulary", { id });
}

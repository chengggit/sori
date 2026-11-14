import { invoke } from "@tauri-apps/api/core";
import type { DictionaryDefinition } from "../dictionary/dictionary";

export type SaveVocabulary = {
  word: string;
  normalizedForm?: string | null;
  documentId: number;
  context: string;
  definition?: DictionaryDefinition | null;
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
  definition: DictionaryDefinition | null;
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

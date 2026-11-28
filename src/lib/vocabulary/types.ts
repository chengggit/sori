import type { DictionaryDefinition } from "$lib/dictionary/lookup";
export type VocabularyEntry = {
  id: number;
  word: string;
  normalizedForm: string | null;
  documentId: number | null;
  sourceTitle: string;
  context: string;
  createdAt: number;
  definition: DictionaryDefinition | null;
  tags: string[];
};
export type WordDraft = { word: string; meaning: string; note: string; tags: string[] };
export const sortOptions = ["Recent", "Oldest", "A–Z", "Z–A"] as const;
export type WordSort = (typeof sortOptions)[number];

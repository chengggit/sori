import { invoke } from "@tauri-apps/api/core";
export { dictionaryForm } from "../reader/breakdown";

export type DictionaryDefinition = {
  term: string;
  partOfSpeech: string;
  text: string;
  sourceUrl: string;
  hanja?: string | null;
  custom?: boolean;
  note?: string | null;
};

export const dictionaryLicense = "https://creativecommons.org/licenses/by-sa/4.0/";

// Cache successful lookups for this app session, including missing entries.
const cache = new Map<string, DictionaryDefinition[]>();
export async function lookupDictionary(term: string) {
  const query = term.trim();
  const cached = cache.get(query);
  if (cached) return cached;
  const result = await invoke<DictionaryDefinition[]>("lookup_dictionary", { term: query });
  if (cache.size >= 200) cache.delete(cache.keys().next().value!);
  cache.set(query, result);
  return result;
}

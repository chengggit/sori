import { platform } from "../../platform";

export type DictionaryProvider = "wiktionary" | "krdict";

export type DictionaryDefinition = {
  term: string;
  partOfSpeech: string;
  text: string;
  sourceUrl: string;
  hanja?: string | null;
  custom?: boolean;
  note?: string | null;
};

export type DictionarySettings = { provider: DictionaryProvider; hasKey: boolean };

export function lookupWord(term: string, provider: DictionaryProvider) {
  return platform.invoke<DictionaryDefinition[]>("dictionary:lookup", { term, provider });
}

export function dictionarySettings() {
  return platform.invoke<DictionarySettings>("dictionary:settings");
}

export function saveDictionaryKey(key: string) {
  return platform.invoke<null>("dictionary:saveKey", { key });
}

export function selectDictionary(provider: DictionaryProvider) {
  return platform.invoke<null>("dictionary:select", { provider });
}

export function removeDictionaryKey() {
  return platform.invoke<null>("dictionary:removeKey");
}

export function openExternal(url: string) {
  return platform.invoke<null>("shell:openExternal", { url });
}

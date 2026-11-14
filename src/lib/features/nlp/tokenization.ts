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

const storageKey = "sori-token-cache";
const memoryCache = new Map<string, KoreanToken[]>();
const maxEntries = 80;

function cacheKey(text: string) {
  let hash = 2166136261;
  for (let index = 0; index < text.length; index += 1) {
    hash ^= text.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return `${text.length}:${hash >>> 0}`;
}

function readPersistentCache() {
  try {
    const value = JSON.parse(localStorage.getItem(storageKey) ?? "{}");
    return value && typeof value === "object" ? (value as Record<string, KoreanToken[]>) : {};
  } catch {
    return {};
  }
}

function writePersistentCache(cache: Record<string, KoreanToken[]>) {
  try {
    localStorage.setItem(storageKey, JSON.stringify(cache));
  } catch {
    // Tokenization remains functional when storage is unavailable or full.
  }
}

/** Analyze a passage of up to 16 KiB of UTF-8 text using bundled offline Kiwi resources. */
export function tokenizeText(text: string) {
  const key = cacheKey(text);
  const memory = memoryCache.get(key);
  if (memory) return Promise.resolve(memory);
  const persistent = readPersistentCache()[key];
  if (persistent) {
    memoryCache.set(key, persistent);
    return Promise.resolve(persistent);
  }
  return invoke<KoreanToken[]>("tokenize_text", { text }).then((tokens) => {
    memoryCache.delete(key);
    memoryCache.set(key, tokens);
    while (memoryCache.size > maxEntries) memoryCache.delete(memoryCache.keys().next().value!);
    const cache = readPersistentCache();
    cache[key] = tokens;
    const keys = Object.keys(cache);
    for (const oldKey of keys.slice(0, Math.max(0, keys.length - maxEntries))) delete cache[oldKey];
    writePersistentCache(cache);
    return tokens;
  });
}

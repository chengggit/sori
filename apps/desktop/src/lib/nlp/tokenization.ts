import { platform } from '../../platform';

/** Analyzed morpheme form. Conjugated forms can differ from the surface. */
export type KoreanToken = {
  form: string;
  tag: string;
  surface: string;
  /** UTF-16 offsets into the original text, suitable for text.slice(start, end). */
  start: number;
  end: number;
  wordIndex: number;
  sentenceIndex: number;
};

const storageKey = 'sori-token-cache';
const memoryCache = new Map<string, KoreanToken[]>();
const maxEntries = 80;

function readPersistentCache(): Record<string, KoreanToken[]> {
  try {
    const value: unknown = JSON.parse(localStorage.getItem(storageKey) ?? '{}');
    return value && typeof value === 'object' ? (value as Record<string, KoreanToken[]>) : {};
  } catch {
    return {};
  }
}

function writePersistentCache(cache: Record<string, KoreanToken[]>) {
  try {
    localStorage.setItem(storageKey, JSON.stringify(cache));
  } catch {
    // Analysis still works when storage is unavailable or full.
  }
}

/** Analyze up to 16 KiB of Korean text with the bundled offline Kiwi analyzer. */
export async function tokenizeText(text: string): Promise<KoreanToken[]> {
  if (!text.trim()) return [];
  // Full text as key: the old FNV-1a + length key could collide across passages.
  const key = text;
  const memory = memoryCache.get(key);
  if (memory) return memory;

  const persistent = readPersistentCache()[key];
  if (persistent) {
    memoryCache.set(key, persistent);
    return persistent;
  }

  const reply = await platform.invoke<KoreanToken[]>('analyzeText', { text });
  if (!reply.ok) throw new Error(reply.error || 'Korean analysis failed.');
  const tokens = reply.data ?? [];

  memoryCache.delete(key);
  memoryCache.set(key, tokens);
  while (memoryCache.size > maxEntries) memoryCache.delete(memoryCache.keys().next().value!);

  const cache = readPersistentCache();
  cache[key] = tokens;
  const keys = Object.keys(cache);
  for (const oldKey of keys.slice(0, Math.max(0, keys.length - maxEntries))) delete cache[oldKey];
  writePersistentCache(cache);
  return tokens;
}

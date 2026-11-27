import type { KoreanToken } from "../nlp/tokenization";

export type TokenBlock = {
  text: string;
  start: number;
  end: number;
  morphemes: KoreanToken[];
};

export type WordRange = { start: number; end: number };

export function readingPassages(text: string) {
  const passages: { text: string; start: number }[] = [];
  let start = 0;
  while (start < text.length) {
    let end = Math.min(start + 2048, text.length);
    if (end < text.length) {
      const whitespace = [...text.slice(start, end).matchAll(/\s+/gu)].at(-1);
      if (whitespace && whitespace.index > 1024) end = start + whitespace.index + whitespace[0].length;
      if (text.charCodeAt(end) >= 0xdc00 && text.charCodeAt(end) <= 0xdfff) end -= 1;
    }
    passages.push({ text: text.slice(start, end), start });
    start = end;
  }
  return passages;
}

function isHangul(unit: number) {
  return (
    (unit >= 0x1100 && unit <= 0x11ff) ||
    (unit >= 0x3131 && unit <= 0x318e) ||
    (unit >= 0xa960 && unit <= 0xa97c) ||
    (unit >= 0xac00 && unit <= 0xd7a3) ||
    (unit >= 0xd7b0 && unit <= 0xd7c6) ||
    (unit >= 0xd7cb && unit <= 0xd7fb)
  );
}

function isDigit(unit: number) {
  return unit >= 0x30 && unit <= 0x39;
}

/** Include immediately attached numbers, with grouping commas or decimal points. */
function attachedNumberStart(units: Uint16Array, end: number) {
  let start = end;
  while (start > 0 && isDigit(units[start - 1])) {
    start -= 1;
    if (
      start >= 2 &&
      (units[start - 1] === 0x2c || units[start - 1] === 0x2e) &&
      isDigit(units[start - 2])
    ) {
      start -= 1;
    }
  }
  return start;
}

/**
 * Clickable ranges for Korean runs, matching Qt's `reader.rs::word_ranges`.
 * Offsets are UTF-16 code units, so they can be used directly with slice().
 */
export function wordRanges(text: string, tokens: KoreanToken[]): WordRange[] {
  const units = Uint16Array.from({ length: text.length }, (_, index) => text.charCodeAt(index));
  const groups = new Map<string, KoreanToken[]>();
  for (const token of tokens) {
    const key = `${token.sentenceIndex}:${token.wordIndex}`;
    const group = groups.get(key);
    if (group) group.push(token);
    else groups.set(key, [token]);
  }

  const ranges: WordRange[] = [];
  for (const group of groups.values()) {
    const end = Math.max(...group.map((token) => token.end));
    let offset = Math.min(...group.map((token) => token.start));
    while (offset < end) {
      let runEnd = offset + 1;
      while (runEnd < end && isHangul(units[runEnd]) === isHangul(units[offset])) runEnd += 1;
      if (isHangul(units[offset])) {
        ranges.push({ start: attachedNumberStart(units, offset), end: runEnd });
      }
      offset = runEnd;
    }
  }
  return ranges.sort((left, right) => left.start - right.start);
}

/** Split text into plain segments and clickable Korean word blocks. */
export function tokenBlocks(text: string, tokens: KoreanToken[]): TokenBlock[] {
  const blocks: TokenBlock[] = [];
  const ranges = wordRanges(text, tokens);
  let cursor = 0;
  for (const range of ranges) {
    if (range.start < cursor) continue;
    if (range.start > cursor) {
      blocks.push({
        text: text.slice(cursor, range.start),
        start: cursor,
        end: range.start,
        morphemes: [],
      });
    }
    blocks.push({
      text: text.slice(range.start, range.end),
      start: range.start,
      end: range.end,
      morphemes: tokens.filter((token) => token.start < range.end && token.end > range.start),
    });
    cursor = range.end;
  }
  if (cursor < text.length) {
    blocks.push({ text: text.slice(cursor), start: cursor, end: text.length, morphemes: [] });
  }
  return blocks;
}

const partOfSpeechLabels: Record<string, string> = {
  NNG: "Noun",
  NNP: "Proper noun",
  NNB: "Dependent noun",
  NP: "Pronoun",
  NR: "Numeral",
  VV: "Verb",
  VA: "Adjective",
  VX: "Auxiliary",
  VCP: "Copula",
  VCN: "Negative copula",
  MM: "Determiner",
  MAG: "Adverb",
  MAJ: "Conjunctive adverb",
  IC: "Interjection",
  XPN: "Prefix",
  XSN: "Noun suffix",
  XSV: "Verb suffix",
  XSA: "Adjective suffix",
  XR: "Root",
  SL: "Foreign word",
  SH: "Hanja",
  SN: "Number",
};

export function partOfSpeechLabel(tag: string) {
  const base = tag.split("-")[0];
  if (base.startsWith("J")) return "Particle";
  if (base.startsWith("E")) return "Ending";
  return partOfSpeechLabels[base] ?? (base.startsWith("S") ? "Punctuation" : "Other");
}

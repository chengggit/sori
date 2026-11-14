import type { KoreanToken } from "../nlp/tokenization";

export type TokenBlock = {
  text: string;
  start: number;
  end: number;
  morphemes: KoreanToken[];
};

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

/** Keep whole written words clickable and render punctuation and whitespace as plain text. */
export function tokenBlocks(text: string, tokens: KoreanToken[]): TokenBlock[] {
  return [...text.matchAll(/[\p{L}\p{M}\p{N}]+|[^\p{L}\p{M}\p{N}]+/gu)].map((match) => {
    const start = match.index;
    const end = start + match[0].length;
    return {
      text: match[0],
      start,
      end,
      morphemes: /[\p{L}\p{N}]/u.test(match[0])
        ? tokens.filter((token) => token.start < end && token.end > start)
        : [],
    };
  });
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

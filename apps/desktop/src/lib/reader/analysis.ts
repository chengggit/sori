import type { KoreanToken } from '../nlp/tokenization';

export type Analysis = {
  word: string;
  context: string;
  tokens: KoreanToken[];
  normalizedForm?: string;
  lookupTerms?: string[];
};

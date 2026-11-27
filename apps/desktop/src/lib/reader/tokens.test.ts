import { describe, expect, it } from 'vitest';
import type { KoreanToken } from '../nlp/tokenization';
import { partOfSpeechLabel, readingPassages, tokenBlocks } from './tokens';

function token(form: string, tag: string, start: number, end: number): KoreanToken {
  return { form, tag, surface: form, start, end, wordIndex: 0, sentenceIndex: 0 };
}

describe('tokenBlocks', () => {
  it('keeps Korean words clickable and punctuation plain', () => {
    const text = '학교에 갔어요!';
    const tokens = [
      token('학교', 'NNG', 0, 2),
      token('에', 'JKB', 2, 3),
      token('가', 'VV', 4, 5),
      token('았', 'EP', 5, 6),
      token('어요', 'EF', 6, 8),
    ];
    const blocks = tokenBlocks(text, tokens);
    expect(blocks[0]).toMatchObject({ text: '학교에', start: 0, end: 3 });
    expect(blocks[0].morphemes).toHaveLength(2);
    expect(blocks.find((block) => block.text === '!')?.morphemes).toEqual([]);
  });

  it('does not attach numeric groups to Korean words', () => {
    const blocks = tokenBlocks('3,000회', [token('회', 'NNG', 5, 6)]);
    expect(blocks[0].text).toBe('3,000회');
    expect(blocks[0].morphemes.every((morpheme) => morpheme.form === '회')).toBe(true);
  });
});

describe('readingPassages', () => {
  it('splits long text without splitting surrogate pairs', () => {
    const passages = readingPassages('가'.repeat(3000));
    expect(passages).toHaveLength(2);
    expect(passages[0].start).toBe(0);
    expect(passages[1].start).toBeGreaterThan(0);
  });
});

describe('partOfSpeechLabel', () => {
  it('labels particles, endings and known tags', () => {
    expect(partOfSpeechLabel('JX')).toBe('Particle');
    expect(partOfSpeechLabel('EF')).toBe('Ending');
    expect(partOfSpeechLabel('VV')).toBe('Verb');
    expect(partOfSpeechLabel('SN')).toBe('Number');
  });
});

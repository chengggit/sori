import { describe, expect, it } from 'vitest';
import type { KoreanToken } from '../nlp/tokenization';
import { dictionaryForm, wholeWordTerms, wordBreakdown } from './breakdown';

function token(form: string, tag: string): KoreanToken {
  return { form, tag, surface: form, start: 0, end: form.length, wordIndex: 0, sentenceIndex: 0 };
}

describe('breakdown', () => {
  it('forms dictionary entries for particles and verbs', () => {
    expect(dictionaryForm(token('은', 'JX'))).toBe('-은');
    expect(dictionaryForm(token('가다', 'VV'))).toBe('가다다');
    expect(dictionaryForm(token('학교', 'NNG'))).toBe('학교');
  });

  it('derives lookup terms up to the first particle', () => {
    const terms = wholeWordTerms('공부했어요', [token('공부', 'NNG'), token('하', 'XSV'), token('았', 'EP')]);
    expect(terms).toContain('공부했어요');
    expect(terms).toContain('공부하다');
  });

  it('merges 하 into a preceding noun and explains common endings', () => {
    const parts = wordBreakdown([token('공부', 'NNG'), token('하', 'XSV'), token('았', 'EP')]);
    expect(parts[0]).toMatchObject({ form: '공부하', term: '공부하다', tag: 'VV' });
    expect(parts[1].explanation).toMatch(/Past tense/);
  });
});

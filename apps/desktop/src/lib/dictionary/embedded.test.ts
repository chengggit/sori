import { describe, expect, it } from 'vitest';
import { embeddedLookupUrl, validCustomEmbed } from './embedded';

describe('embedded dictionary URLs', () => {
  it('accepts only safe HTTPS templates', () => {
    expect(validCustomEmbed('https://dict.example/{word}')).toBe(true);
    expect(validCustomEmbed('http://dict.example/{word}')).toBe(false);
    expect(validCustomEmbed('https://user@dict.example/{word}')).toBe(false);
  });

  it('substitutes the encoded word', () => {
    expect(embeddedLookupUrl('naver-ko', '한국어')).toContain('%ED%95%9C%EA%B5%AD%EC%96%B4');
    expect(embeddedLookupUrl('custom', '한국어', 'https://dict.example/{word}')).toBe(
      'https://dict.example/%ED%95%9C%EA%B5%AD%EC%96%B4',
    );
    expect(embeddedLookupUrl('custom', '한국어', 'not a url')).toBe('');
  });
});

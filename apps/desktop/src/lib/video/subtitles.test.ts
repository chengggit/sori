import { describe, expect, it } from 'vitest';
import { activeSubtitleCues, parseSubtitles } from './subtitles';

describe('parseSubtitles', () => {
  it('parses mixed SRT/VTT, strips tags and sorts by start', () => {
    const input =
      'WEBVTT\r\n\r\n2\r\n00:04,000 --> 00:05,000\r\nSecond\r\n\r\n' +
      '00:01.500 --> 00:02.000 align:start\r\n<b>한국어</b><br>&amp; English\r\n\r\n' +
      '00:03.000 --> 00:02.000\r\nIgnore';
    const cues = parseSubtitles(input);
    expect(cues).toHaveLength(2);
    expect(cues[0]).toMatchObject({ start: 1.5, end: 2, text: '한국어\n& English' });
    expect(cues[1].text).toBe('Second');
  });

  it('ignores headers, invalid timings and empty text', () => {
    const cues = parseSubtitles('WEBVTT\n\nNOTE ignore\n\nSTYLE\n\n00:01.000 --> 00:02.000\n<b></b>');
    expect(cues).toEqual([]);
  });

  it('finds active cues at a given time', () => {
    const cues = [
      { start: 0, end: 1, text: 'a' },
      { start: 1, end: 3, text: 'b' },
      { start: 4, end: 5, text: 'c' },
    ];
    expect(activeSubtitleCues(cues, 2)).toEqual([cues[1]]);
  });
});

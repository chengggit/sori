import { describe, expect, it } from 'vitest';
import { unwrapData, type Response } from './envelope';

describe('unwrapData', () => {
  it('returns the payload of a successful response', () => {
    const response: Response<string> = { ok: true, data: 'pong', error: '' };
    expect(unwrapData(response)).toBe('pong');
  });

  it('surfaces the error of a failed response', () => {
    const response: Response<string> = { ok: false, data: null, error: 'No word selected' };
    expect(() => unwrapData(response)).toThrow('No word selected');
  });

  it('rejects a successful response with no data', () => {
    const response: Response<string> = { ok: true, data: null, error: '' };
    expect(() => unwrapData(response)).toThrow('No data returned');
  });
});

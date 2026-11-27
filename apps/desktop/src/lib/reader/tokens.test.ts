import { describe, expect, it } from "vitest";
import type { KoreanToken } from "../nlp/tokenization";
import { partOfSpeechLabel, readingPassages, tokenBlocks, wordRanges } from "./tokens";

function token(form: string, tag: string, start: number, end: number): KoreanToken {
  return { form, tag, surface: form, start, end, wordIndex: 0, sentenceIndex: 0 };
}

describe("tokenBlocks", () => {
  it("keeps Korean words clickable and punctuation plain", () => {
    const text = "학교에 갔어요!";
    const tokens = [
      token("학교", "NNG", 0, 2),
      token("에", "JKB", 2, 3),
      token("가", "VV", 4, 5),
      token("았", "EP", 5, 6),
      token("어요", "EF", 6, 8),
    ];
    const blocks = tokenBlocks(text, tokens);
    expect(blocks[0]).toMatchObject({ text: "학교에", start: 0, end: 3 });
    expect(blocks[0].morphemes).toHaveLength(2);
    expect(blocks.find((block) => block.text === "!")?.morphemes).toEqual([]);
  });

  it("does not attach numeric groups to Korean words", () => {
    const blocks = tokenBlocks("3,000회", [token("회", "NNG", 5, 6)]);
    expect(blocks[0].text).toBe("3,000회");
    expect(blocks[0].morphemes.every((morpheme) => morpheme.form === "회")).toBe(true);
  });
});

describe("wordRanges", () => {
  it("matches the Qt reader.rs vector for attached numbers", () => {
    const text = "😀 Hello, 학교에! KAIST는. 3000회, 2년, 3,000회, 1.5년, 20.";
    const at = (value: string) => text.indexOf(value);
    const grouped = (form: string, start: number, group: number): KoreanToken => ({
      form,
      tag: "NNG",
      surface: text.slice(start, start + form.length),
      start,
      end: start + form.length,
      wordIndex: group,
      sentenceIndex: 0,
    });
    const tokens = [
      grouped("학교", at("학교"), 0),
      grouped("에", at("학교") + 2, 0),
      grouped("는", at("KAIST는") + 5, 1),
      grouped("회", at("3000회") + 4, 2),
      grouped("년", at("2년") + 1, 3),
      grouped("회", at("3,000회") + 5, 4),
      grouped("년", at("1.5년") + 3, 5),
    ];
    const clickable = wordRanges(text, tokens).map((range) => text.slice(range.start, range.end));
    expect(clickable).toEqual(["학교에", "는", "3000회", "2년", "3,000회", "1.5년"]);
  });
});

describe("readingPassages", () => {
  it("splits long text without splitting surrogate pairs", () => {
    const passages = readingPassages("가".repeat(3000));
    expect(passages).toHaveLength(2);
    expect(passages[0].start).toBe(0);
    expect(passages[1].start).toBeGreaterThan(0);
  });
});

describe("partOfSpeechLabel", () => {
  it("labels particles, endings and known tags", () => {
    expect(partOfSpeechLabel("JX")).toBe("Particle");
    expect(partOfSpeechLabel("EF")).toBe("Ending");
    expect(partOfSpeechLabel("VV")).toBe("Verb");
    expect(partOfSpeechLabel("SN")).toBe("Number");
  });
});

import { describe, it, expect } from "vitest";
import {
  displayWord,
  filterEntries,
  formatMeaning,
  partOfSpeech,
  savedDate,
  typeOptions,
} from "./entries";
import type { VocabularyEntry } from "./types";
const entry = (overrides: Partial<VocabularyEntry> = {}): VocabularyEntry => ({
  id: 1,
  word: "개발했다고",
  normalizedForm: "개발하다",
  documentId: null,
  sourceTitle: "KAIST",
  context: "새로운 기술을 개발했다고 밝혔다.",
  createdAt: 100,
  definition: {
    term: "개발하다",
    partOfSpeech: "verb",
    text: "develop; exploit",
    sourceUrl: "",
    note: "Science vocabulary",
  },
  tags: ["reading"],
  ...overrides,
});
describe("saved vocabulary presentation", () => {
  it("searches both Korean forms, saved meaning/note, tags and orphaned source snapshots", () => {
    const word = entry();
    for (const query of [
      "개발했다고",
      "개발하다".normalize("NFD"),
      " exploit ",
      "SCIENCE",
      "reading",
      "KAIST",
      "새로운 기술",
    ])
      expect(filterEntries([word], query, "All types", "Recent")).toEqual([word]);
    expect(displayWord(entry({ normalizedForm: "한글".normalize("NFD") }))).toBe("한글");
    expect(displayWord(entry({ normalizedForm: " " }))).toBe("개발했다고");
    expect(filterEntries([word], "missing", "All types", "Recent")).toEqual([]);
  });
  it("prefers the saved dictionary class over tags and supports class tags without a definition", () => {
    const verb = entry({ tags: ["nouns"] });
    const noun = entry({ id: 2, definition: null, tags: ["reading", "Nouns"] });
    expect(partOfSpeech(verb)).toBe("verb");
    expect(partOfSpeech(noun)).toBe("noun");
    expect(typeOptions([verb, noun, noun])).toEqual(["All types", "Noun", "Verb"]);
    expect(filterEntries([verb, noun], "", "Noun", "Recent")).toEqual([noun]);
  });
  it("sorts ties consistently without changing the stored list", () => {
    const words = [
      entry({ id: 1, normalizedForm: "Beta", createdAt: 1 }),
      entry({ id: 2, normalizedForm: "Alpha" }),
      entry({ id: 3, normalizedForm: "Gamma" }),
    ];
    expect(filterEntries(words, "", "All types", "Recent").map((x) => x.id)).toEqual([3, 2, 1]);
    expect(filterEntries(words, "", "All types", "Oldest").map((x) => x.id)).toEqual([1, 2, 3]);
    expect(filterEntries(words, "", "All types", "A–Z").map((x) => x.id)).toEqual([2, 1, 3]);
    expect(filterEntries(words, "", "All types", "Z–A").map((x) => x.id)).toEqual([3, 1, 2]);
    expect(words.map((x) => x.id)).toEqual([1, 2, 3]);
    expect(
      formatMeaning(
        entry({
          definition: {
            term: "",
            partOfSpeech: "",
            text: " first\n\n second  meaning ",
            sourceUrl: "",
          },
        }),
      ),
    ).toBe("first; second meaning");
  });
  it("uses local calendar days and Unix seconds for saved dates", () => {
    const now = new Date(2026, 10, 28, 0, 5);
    expect(savedDate(new Date(2026, 10, 28, 0, 1).getTime() / 1000, now)).toBe("Today");
    expect(savedDate(new Date(2026, 10, 27, 23, 59).getTime() / 1000, now)).toBe("Yesterday");
    expect(savedDate(new Date(2026, 10, 25).getTime() / 1000, now)).toBe("3 days ago");
    expect(savedDate(new Date(2026, 10, 29).getTime() / 1000, now)).not.toBe("Today");
    expect(savedDate(0, now)).toBe("");
    expect(savedDate(NaN, now)).toBe("");
  });
});

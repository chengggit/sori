import assert from "node:assert/strict";
import test from "node:test";
import { readingPassages, tokenBlocks, partOfSpeechLabel } from "../src/lib/features/reader/tokens.ts";
import { wordBreakdown, wholeWordTerms } from "../src/lib/features/reader/breakdown.ts";

test("whole-word lookup keeps compounds and restores inflected dictionary forms", () => {
  assert.deepEqual(wholeWordTerms("친환경", [
    { form: "친", tag: "XPN" }, { form: "환경", tag: "NNG" },
  ]), ["친환경"]);
  assert.deepEqual(wholeWordTerms("있었다", [
    { form: "있", tag: "VA" }, { form: "었", tag: "EP" }, { form: "다", tag: "EF" },
  ]), ["있었다", "있다"]);
  assert.deepEqual(wholeWordTerms("공부했어요", [
    { form: "공부", tag: "NNG" }, { form: "하", tag: "XSV" },
    { form: "었", tag: "EP" }, { form: "어요", tag: "EF" },
  ]), ["공부했어요", "공부하다"]);
  assert.deepEqual(wholeWordTerms("친환경은", [
    { form: "친", tag: "XPN" }, { form: "환경", tag: "NNG" }, { form: "은", tag: "JX" },
  ]), ["친환경은", "친환경"]);
  assert.deepEqual(wholeWordTerms("갔어요", [
    { form: "가", tag: "VV-I" }, { form: "었", tag: "EP" }, { form: "어요", tag: "EF" },
  ]), ["갔어요", "가다"]);
  assert.deepEqual(wholeWordTerms("학교", []), ["학교"]);
  assert.deepEqual(wholeWordTerms("다", [{ form: "다", tag: "EF" }]), ["다"]);
});

test("breakdown shows dictionary forms and POS-specific grammar explanations", () => {
  const parts = wordBreakdown([
    { form: "있", tag: "VA" },
    { form: "었", tag: "EP" },
    { form: "다", tag: "EF" },
  ]);
  assert.deepEqual(parts.map((part) => part.term), ["있다", "-었", "-다"]);
  assert.match(parts[1].explanation, /Past tense/);
  assert.match(parts[2].explanation, /Plain-style/);
  assert.equal(parts[0].explanation, null);
  assert.equal(wordBreakdown([{ form: "은", tag: "NNG" }])[0].explanation, null);
  assert.equal(wordBreakdown([{ form: "은", tag: "JX" }])[0].explanation, "Topic or contrast marker");
  assert.equal(wordBreakdown([{ form: "가", tag: "VV-I" }])[0].term, "가다");
});

test("derivational suffixes stay with their lexical base in 해결하기", () => {
  const tokens = [
    { form: "해결", tag: "NNG" },
    { form: "하", tag: "XSV" },
    { form: "기", tag: "ETN" },
  ];
  assert.deepEqual(wholeWordTerms("해결하기", tokens), ["해결하기", "해결하다"]);
  const parts = wordBreakdown(tokens);
  assert.deepEqual(parts.map((part) => part.term), ["해결하다", "-기"]);
  assert.equal(parts[0].tag, "VV");
  assert.match(parts[1].explanation, /noun/);
  const standalone = wordBreakdown([{ form: "하", tag: "XSV" }])[0];
  assert.equal(standalone.term, "-하");
  assert.match(standalone.explanation, /Forms a verb/);
});

const token = (form, start, end) => ({ form, start, end });

test("renders a whole spaced word while preserving its morphemes and source offsets", () => {
  const text = "😀 마음만큼은\n";
  const pieces = tokenBlocks(text, [token("마음", 3, 5), token("만큼", 5, 7), token("은", 7, 8)]);
  assert.equal(pieces.map((piece) => piece.text).join(""), text);
  assert.deepEqual(
    pieces.filter((piece) => piece.morphemes.length).map((piece) => piece.text),
    ["마음만큼은"],
  );
  assert.equal(pieces.find((piece) => piece.text === "마음만큼은").morphemes.length, 3);
});

test("overlapping contraction morphemes share one original spelling", () => {
  const pieces = tokenBlocks("갔어요", [token("가", 0, 1), token("었", 0, 1), token("어요", 1, 3)]);
  assert.equal(pieces.map((piece) => piece.text).join(""), "갔어요");
  assert.equal(pieces.length, 1);
  assert.equal(pieces[0].morphemes.length, 3);
});

test("spaces separate word boxes and word-type labels explain common Kiwi tags", () => {
  const pieces = tokenBlocks("마음만큼은  커요.\n", [
    token("마음", 0, 2),
    token("만큼", 2, 4),
    token("은", 4, 5),
    token("크", 7, 9),
  ]);
  assert.deepEqual(
    pieces.filter((piece) => piece.morphemes.length).map((piece) => piece.text),
    ["마음만큼은", "커요"],
  );
  assert.equal(pieces.map((piece) => piece.text).join(""), "마음만큼은  커요.\n");
  assert.equal(partOfSpeechLabel("NNG"), "Noun");
  assert.equal(partOfSpeechLabel("VV-I"), "Verb");
  assert.equal(partOfSpeechLabel("JX"), "Particle");
  assert.equal(partOfSpeechLabel("EF"), "Ending");
});

test("punctuation and symbols stay outside clickable word boxes", () => {
  const text = "“마음만큼은,” (커요!) 😀";
  const pieces = tokenBlocks(text, [
    token("마음", 1, 3),
    token("만큼", 3, 5),
    token("은", 5, 6),
    token(",", 6, 7),
    token("크", 10, 12),
    token("!", 12, 13),
  ]);
  assert.equal(pieces.map((piece) => piece.text).join(""), text);
  assert.deepEqual(
    pieces.filter((piece) => piece.morphemes.length).map((piece) => piece.text),
    ["마음만큼은", "커요"],
  );
  assert(
    pieces
      .filter((piece) => !/[\p{L}\p{N}]/u.test(piece.text))
      .every((piece) => piece.morphemes.length === 0),
  );
});

test("long passages fit the Kiwi limit and preserve valid Unicode and absolute offsets", () => {
  for (const text of ["", "😀".repeat(3000), "한글 마음만큼은\n".repeat(20000), "a".repeat(16000)]) {
    const passages = readingPassages(text);
    assert.equal(passages.map((passage) => passage.text).join(""), text);
    for (const passage of passages) {
      assert.equal(text.slice(passage.start, passage.start + passage.text.length), passage.text);
      assert(Buffer.byteLength(passage.text) <= 16 * 1024);
      assert(passage.text.isWellFormed());
    }
  }
});

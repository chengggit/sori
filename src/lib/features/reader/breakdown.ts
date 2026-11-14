import type { KoreanToken } from "../nlp/tokenization";

export function dictionaryForm(token: KoreanToken) {
  const tag = token.tag.split("-")[0];
  if (/^[JE]/.test(tag) || ["XSN", "XSV", "XSA"].includes(tag)) return `-${token.form}`;
  return ["VV", "VA", "VX", "VCP", "VCN"].includes(tag) ? `${token.form}다` : token.form;
}

export function wholeWordTerms(word: string, tokens: KoreanToken[]) {
  // Keep prefixes, nouns, and derivational suffixes together. Inflection and
  // attached particles mark the end of the lexical form.
  const boundary = tokens.findIndex((token) => /^[JE]/.test(token.tag));
  const lexical = boundary < 0 ? tokens : tokens.slice(0, boundary);
  let lemma = lexical.map((token) => token.form).join("");
  const lastTag = lexical.at(-1)?.tag.split("-")[0] ?? "";
  if (["VV", "VA", "VX", "VCP", "VCN", "XSV", "XSA"].includes(lastTag)) lemma += "다";
  return [...new Set([word.trim(), lemma].filter((term) => term && [...term].length <= 100))];
}

// These describe common functions, keyed by both form and Kiwi POS to avoid
// confusing an ending with a noun or a different grammatical use of the same form.
const grammar: Record<string, Record<string, string>> = {
  EP: {
    었: "Past tense / completed state",
    았: "Past tense / completed state",
    였: "Past tense / completed state",
    겠: "Intention, prediction, or supposition",
    시: "Honorific marker for the subject",
    으시: "Honorific marker for the subject",
  },
  EF: {
    다: "Plain-style statement ending",
    ㄴ다: "Plain-style statement ending",
    는다: "Plain-style statement ending",
    어요: "Polite conversational ending",
    아요: "Polite conversational ending",
    여요: "Polite conversational ending",
    습니다: "Formal polite statement ending",
    ㅂ니다: "Formal polite statement ending",
  },
  JKS: { 이: "Subject marker", 가: "Subject marker" },
  JKO: { 을: "Object marker", 를: "Object marker" },
  JKG: { 의: "Possession or relation marker" },
  JX: { 은: "Topic or contrast marker", 는: "Topic or contrast marker", 도: "Also / too", 만: "Only" },
  ETN: {
    기: "Turns the action into a noun (doing / the act of doing)",
    음: "Turns the action or state into a noun",
    ㅁ: "Turns the action or state into a noun",
  },
  XSV: {
    하: "Forms a verb meaning to do the preceding action",
    되: "Forms a verb meaning to become or be acted on",
  },
  XSA: { 하: "Forms an adjective from the preceding noun or root" },
};

export function wordBreakdown(tokens: KoreanToken[]) {
  const parts: { form: string; tag: string; term: string; explanation: string | null }[] = [];
  for (const token of tokens) {
    const tag = token.tag.split("-")[0];
    const previous = parts.at(-1);
    if (["XSV", "XSA"].includes(tag) && previous && /^(NNG|NNP|XR)$/.test(previous.tag)) {
      previous.form += token.form;
      previous.term = `${previous.form}다`;
      previous.tag = tag === "XSV" ? "VV" : "VA";
      previous.explanation = null;
    } else {
      parts.push({
        form: token.form,
        tag: token.tag,
        term: dictionaryForm(token),
        explanation: grammar[tag]?.[token.form] ?? null,
      });
    }
  }
  return parts;
}

import { normalizeDisplayText } from "../text";
import type { VocabularyEntry, WordSort } from "./types";
const wordClasses = [
  "noun",
  "verb",
  "adjective",
  "adverb",
  "pronoun",
  "determiner",
  "particle",
  "conjunction",
  "interjection",
  "numeral",
];
export function partOfSpeech(entry: VocabularyEntry) {
  const type = (entry.definition?.partOfSpeech ?? "").trim().toLowerCase();
  if (type) return type;
  return (
    (entry.tags ?? [])
      .map((tag) => tag.trim().toLowerCase().replace(/s$/u, ""))
      .find((tag) => wordClasses.includes(tag)) ?? ""
  );
}
export function capitalize(value: string) {
  return value ? value[0].toUpperCase() + value.slice(1) : "";
}
export function displayWord(entry: VocabularyEntry) {
  return normalizeDisplayText(entry.normalizedForm?.trim() || entry.word);
}
export function formatMeaning(entry: VocabularyEntry) {
  return (entry.definition?.text ?? "")
    .trim()
    .replace(/\s*\n+\s*/gu, "; ")
    .replace(/[ \t]+/gu, " ");
}
export function typeOptions(entries: VocabularyEntry[]) {
  return [
    "All types",
    ...[...new Set(entries.map((entry) => capitalize(partOfSpeech(entry))).filter(Boolean))].sort(
      (a, b) => a.localeCompare(b),
    ),
  ];
}
export function filterEntries(entries: VocabularyEntry[], query: string, type: string, sort: WordSort) {
  const needle = normalizeDisplayText(query.trim()).toLocaleLowerCase();
  const filtered = entries.filter(
    (entry) =>
      (type === "All types" || partOfSpeech(entry) === type.toLowerCase()) &&
      (!needle ||
        [
          entry.word,
          entry.normalizedForm,
          entry.definition?.text,
          entry.definition?.note,
          entry.context,
          entry.sourceTitle,
          ...entry.tags,
        ].some((value) => value && normalizeDisplayText(value).toLocaleLowerCase().includes(needle))),
  );
  return filtered.sort((a, b) =>
    sort === "Oldest"
      ? a.createdAt - b.createdAt || a.id - b.id
      : sort === "A–Z"
        ? displayWord(a).localeCompare(displayWord(b))
        : sort === "Z–A"
          ? displayWord(b).localeCompare(displayWord(a))
          : b.createdAt - a.createdAt || b.id - a.id,
  );
}
export function savedDate(timestamp: number, now = new Date()) {
  if (!Number.isFinite(timestamp) || timestamp <= 0) return "";
  const saved = new Date(timestamp * 1000);
  if (!Number.isFinite(saved.getTime())) return "";
  const day = (date: Date) => Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
  const days = Math.round((day(now) - day(saved)) / 86400000);
  if (days === 0) return "Today";
  if (days === 1) return "Yesterday";
  if (days > 1 && days < 7) return `${days} days ago`;
  return saved.toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    ...(saved.getFullYear() === now.getFullYear() ? {} : { year: "numeric" }),
  });
}

export type SubtitleCue = { start: number; end: number; text: string };

function timestamp(value: string): number {
  const match = /^(?:(\d{2,}):)?([0-5]\d):([0-5]\d)[.,](\d{3})$/.exec(value);
  if (!match) return NaN;
  const [, hours, minutes, seconds, milliseconds] = match;
  return (
    Number(hours ?? 0) * 3600 + Number(minutes) * 60 + Number(seconds) + Number(milliseconds) / 1000
  );
}

function plainText(text: string) {
  const entities: Record<string, string> = {
    amp: "&",
    lt: "<",
    gt: ">",
    nbsp: " ",
    lrm: "\u200e",
    rlm: "\u200f",
  };
  return text
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<[^>\n]*>/g, "")
    .replace(/&(amp|lt|gt|nbsp|lrm|rlm);/g, (entity, name: string) => entities[name] ?? entity)
    .trim();
}

export function parseSubtitles(source: string): SubtitleCue[] {
  const cues: SubtitleCue[] = [];
  for (const block of source
    .replace(/^\uFEFF/, "")
    .replace(/\r\n?/g, "\n")
    .split(/\n[ \t]*\n+/)) {
    const lines = block.trim().split("\n");
    if (/^(WEBVTT|NOTE|STYLE|REGION)(?:\s|$)/.test(lines[0])) continue;
    const timingLine = lines[0].includes("-->") ? 0 : 1;
    const timing = /^(\S+)\s+-->\s+(\S+)/.exec(lines[timingLine]?.trim() ?? "");
    if (!timing) continue;
    const start = timestamp(timing[1]);
    const end = timestamp(timing[2]);
    const text = plainText(lines.slice(timingLine + 1).join("\n"));
    if (Number.isFinite(start) && Number.isFinite(end) && end > start && text) {
      cues.push({ start, end, text });
    }
  }
  return cues.sort((left, right) => left.start - right.start);
}

export function activeSubtitleCues(cues: SubtitleCue[], seconds: number) {
  const active: SubtitleCue[] = [];
  for (const cue of cues) {
    if (cue.start > seconds) break;
    if (cue.end > seconds) active.push(cue);
  }
  return active;
}

import type { WordSource } from "$lib/analysis/state.svelte";
import { platform } from "../../platform";

export type VideoSource = { id: string; url: string; name: string };

export type ProbeResult = {
  container?: string;
  video?: string;
  audio?: string[];
  tracks?: { index: number; language: string; label: string }[];
  error?: string;
};

export function exposeVideo(path: string) {
  return platform.invoke<VideoSource>("video:expose", { path });
}

export function probeVideo(id: string) {
  return platform.invoke<ProbeResult>("video:probe", { id });
}

export function videoTrack(id: string, index: number) {
  return platform.invoke<string>("video:track", { id, index });
}

export function attachSubtitles(id: string) {
  return platform.invoke<{ name: string; text: string; path: string } | null>("video:attach", { id });
}

export function openVideoPicker() {
  return platform.invoke<string | null>("dialog:openVideo");
}

export type TextTranscript = { title?: string; content?: string; position?: number };
export function readTextTranscript(source: WordSource) {
  return platform.invoke<TextTranscript>("video:readTranscript", source);
}
export async function attachTextTranscript(source: WordSource) {
  const picked = await platform.invoke<string | null>("dialog:openTranscript");
  if (!picked.ok || !picked.data) return { ...picked, data: null };
  return platform.invoke<TextTranscript>("video:saveTranscript", { ...source, path: picked.data });
}
export function removeTextTranscript(source: WordSource) {
  return platform.invoke<null>("video:removeTranscript", source);
}
export function saveTextPosition(source: WordSource, position: number) {
  return platform.invoke<null>("video:saveTranscriptPosition", { ...source, position });
}

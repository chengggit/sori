import type { VocabularyEntry } from "../vocabulary/types";
import type { Response } from "../../envelope";
import { platform } from "../../platform";

export type DocumentSummary = { id: number; title: string; pdf: boolean };
export type VideoSummary = {
  id: number;
  title: string;
  displayTitle: string;
  seconds: number;
  duration: number;
  thumbnailUrl: string | null;
  watchedAt: number | null;
};
export type YouTubeHistoryEntry = {
  youtubeId: string;
  title: string;
  channel: string;
  seconds: number;
  duration: number;
  watchedAt: number;
  thumbnailUrl: string;
};
export type LibraryState = {
  documents: DocumentSummary[];
  videos: VideoSummary[];
  vocabulary: VocabularyEntry[];
  youtubeHistory: YouTubeHistoryEntry[];
  error: string;
};

export type DocumentView = {
  content: string;
  pdfPath: string | null;
  position: number;
};

export type VocabularyDraft = {
  word: string;
  normalizedForm?: string | null;
  context: string;
  definition?: unknown;
  tags?: string[];
};

export type VocabularyEdit = {
  normalizedForm: string;
  meaning: string;
  note: string;
  tags: string[];
};

export function loadLibraryState() {
  return platform.invoke<LibraryState>("library:state");
}

export function addDocument(title: string, content: string) {
  return platform.invoke<null>("document:add", { title, content });
}

export function importDocument(path: string) {
  return platform.invoke<null>("document:import", { path });
}

export function updateDocument(id: number, title: string, content: string) {
  return platform.invoke<null>("document:update", { id, title, content });
}

export function removeDocument(id: number) {
  return platform.invoke<null>("document:remove", { id });
}

export function readDocument(id: number): Promise<Response<DocumentView>> {
  return platform.invoke<DocumentView>("document:read", { id });
}

export function saveDocumentProgress(id: number, position: number) {
  return platform.invoke<null>("progress:saveDocument", { id, position });
}

export function importVideo(path: string): Promise<Response<{ id: number }>> {
  return platform.invoke<{ id: number }>("video:import", { path });
}

export function readVideo(
  id: number,
): Promise<Response<{ path: string; seconds: number; sidecar: string | null }>> {
  return platform.invoke<{ path: string; seconds: number; sidecar: string | null }>("video:read", {
    id,
  });
}

export function saveVideoSubtitles(id: number, path: string) {
  return platform.invoke<{ text: string }>("video:saveSubtitles", { id, path });
}

export function removeVideo(id: number) {
  return platform.invoke<null>("video:remove", { id });
}

export function saveVideoProgress(id: number, seconds: number, duration: number) {
  return platform.invoke<null>("video:saveProgress", { id, seconds, duration });
}

export function saveWord(
  kind: "local" | "document" | "youtube",
  id: number | string,
  draft: VocabularyDraft,
  title = "",
) {
  return platform.invoke<unknown>("vocabulary:save", { kind, id, input: draft, title });
}

export function findWord(
  kind: "local" | "document" | "youtube",
  id: number | string,
  word: string,
  context: string,
) {
  return platform.invoke<unknown>("vocabulary:find", { kind, id, word, context });
}

export function editWord(id: number, input: VocabularyEdit) {
  return platform.invoke<null>("vocabulary:edit", { id, input });
}

export function removeWord(id: number) {
  return platform.invoke<null>("vocabulary:remove", { id });
}

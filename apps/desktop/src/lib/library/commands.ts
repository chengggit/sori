import type { Response } from '../../envelope';
import { platform } from '../../platform';

export type LibraryState = {
  documents: unknown[];
  videos: unknown[];
  vocabulary: unknown[];
  youtubeHistory: unknown[];
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

export function loadLibraryState() {
  return platform.invoke<LibraryState>('library:state');
}

export function addDocument(title: string, content: string) {
  return platform.invoke<null>('document:add', { title, content });
}

export function importDocument(path: string) {
  return platform.invoke<null>('document:import', { path });
}

export function updateDocument(id: number, title: string, content: string) {
  return platform.invoke<null>('document:update', { id, title, content });
}

export function removeDocument(id: number) {
  return platform.invoke<null>('document:remove', { id });
}

export function readDocument(id: number): Promise<Response<DocumentView>> {
  return platform.invoke<DocumentView>('document:read', { id });
}

export function saveDocumentProgress(id: number, position: number) {
  return platform.invoke<null>('progress:saveDocument', { id, position });
}

export function importVideo(path: string): Promise<Response<{ id: number }>> {
  return platform.invoke<{ id: number }>('video:import', { path });
}

export function readVideo(id: number) {
  return platform.invoke<unknown>('video:read', { id });
}

export function removeVideo(id: number) {
  return platform.invoke<null>('video:remove', { id });
}

export function saveVideoProgress(id: number, seconds: number, duration: number) {
  return platform.invoke<null>('video:saveProgress', { id, seconds, duration });
}

export function saveWord(kind: 'local' | 'document', id: number, draft: VocabularyDraft) {
  return platform.invoke<unknown>('vocabulary:save', { kind, id, input: draft });
}

export function findWord(kind: 'local' | 'document', id: number, word: string, context: string) {
  return platform.invoke<unknown>('vocabulary:find', { kind, id, word, context });
}

export function editWord(id: number, input: VocabularyDraft) {
  return platform.invoke<null>('vocabulary:edit', { id, input });
}

export function removeWord(id: number) {
  return platform.invoke<null>('vocabulary:remove', { id });
}

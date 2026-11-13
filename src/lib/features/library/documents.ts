import { invoke } from "@tauri-apps/api/core";

export type LibraryItem = { id: number; title: string };

export function listDocuments() {
  return invoke<LibraryItem[]>("list_documents");
}

export async function importDocument(file: File) {
  if (file.size > 2 * 1024 * 1024) throw new Error("Choose a text file no larger than 2 MiB.");
  const bytes = Array.from(new Uint8Array(await file.arrayBuffer()));
  await invoke("import_document", { filename: file.name, bytes });
}

export function readDocument(id: number) {
  return invoke<string>("read_document", { id });
}

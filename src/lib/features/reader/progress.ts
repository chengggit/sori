import { invoke } from "@tauri-apps/api/core";

// Serialize writes per document, including saves from a reader that just closed.
const pending = new Map<number, Promise<void>>();

export async function readReadingProgress(id: number) {
  await pending.get(id);
  return invoke<number>("read_reading_progress", { id });
}

export function saveReadingProgress(id: number, position: number) {
  const write = (pending.get(id) ?? Promise.resolve())
    .catch(() => {})
    .then(() => invoke<void>("save_reading_progress", { id, position }));
  pending.set(id, write);
  void write
    .finally(() => {
      if (pending.get(id) === write) pending.delete(id);
    })
    .catch(() => {});
  return write;
}

export function trackReadingProgress(
  element: HTMLElement,
  initial: number,
  save: (position: number) => Promise<void>,
  reportError: (message: string) => void,
) {
  let position = initial;
  let saved = initial;
  let timer: ReturnType<typeof setTimeout> | undefined;

  function record() {
    clearTimeout(timer);
    timer = undefined;
    if (position === saved) return;
    const current = position;
    saved = current;
    void save(current).then(
      () => reportError(""),
      (error) => {
        saved = -1;
        reportError(`Could not save reading position. ${String(error)}`);
      },
    );
  }

  function onScroll() {
    const range = element.scrollHeight - element.clientHeight;
    // Keep the previous position if the entire document fits after a resize.
    if (range <= 0) return;
    position = Math.min(1, Math.max(0, element.scrollTop / range));
    timer ??= setTimeout(record, 500);
  }

  element.scrollTop = initial * Math.max(0, element.scrollHeight - element.clientHeight);
  element.addEventListener("scroll", onScroll);
  window.addEventListener("pagehide", record);
  return () => {
    element.removeEventListener("scroll", onScroll);
    window.removeEventListener("pagehide", record);
    record();
  };
}

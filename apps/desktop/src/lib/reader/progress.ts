/**
 * Scroll tracking with debounced saves. Reading-progress commands arrive with
 * the Reader feature (step 8); this pure DOM helper is already reusable.
 */
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
    // Keep the previous position if the document fits after a resize.
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

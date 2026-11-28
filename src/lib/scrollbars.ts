const HIDDEN_DELAY_MS = 700;

/** Reveal native scrollbar thumbs only while their container is actively scrolling. */
export function startAutoHideScrollbars() {
  const timers = new WeakMap<Element, ReturnType<typeof setTimeout>>();

  function onScroll(event: Event) {
    const target = event.target;
    let element: Element;
    if (target === document) {
      element = document.documentElement;
    } else if (target instanceof Element) {
      element = target;
    } else {
      return;
    }
    element.classList.add("is-scrolling");
    const previous = timers.get(element);
    if (previous) clearTimeout(previous);
    timers.set(
      element,
      setTimeout(() => {
        element.classList.remove("is-scrolling");
        timers.delete(element);
      }, HIDDEN_DELAY_MS),
    );
  }

  document.addEventListener("scroll", onScroll, true);
  return () => document.removeEventListener("scroll", onScroll, true);
}

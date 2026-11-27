import type { Command, DesktopBridge } from "./bridge";
import type { Response } from "./envelope";

/** Keeps Electron integration behind a typed renderer interface. */
export interface Platform {
  invoke<T>(command: Command, payload?: Record<string, unknown>): Promise<Response<T>>;
  onEvent(event: string, listener: (payload: unknown) => void): () => void;
}

function bridge(): DesktopBridge | undefined {
  if (typeof window === "undefined") return undefined;
  return (window as Window & { sori?: DesktopBridge }).sori;
}

async function native<T>(call: () => Promise<T>): Promise<Response<T>> {
  try {
    return { ok: true, data: await call(), error: "" };
  } catch (cause) {
    return {
      ok: false,
      data: null,
      error: cause instanceof Error ? cause.message : String(cause),
    };
  }
}

const desktopPlatform: Platform = {
  async invoke<T>(command: Command, payload: Record<string, unknown> = {}) {
    const host = bridge();
    if (!host) return { ok: false, data: null, error: "Desktop bridge unavailable." };
    switch (command) {
      case "app:ping":
        return host.invoke<Response<T>>("app:ping");
      case "dev:emit":
        return host.invoke<Response<T>>("dev:emit", payload);
      case "dialog:openDocument":
        return native(() => host.invoke<T>("dialog:openDocument"));
      case "dialog:openVideo":
        return native(() => host.invoke<T>("dialog:openVideo"));
      case "video:expose":
        return native(() => host.invoke<T>("video:expose", payload.path));
      case "video:probe":
        return native(() => host.invoke<T>("video:probe", payload.id));
      case "video:track":
        return native(() => host.invoke<T>("video:track", payload.id, payload.index));
      case "video:attach":
        return native(() => host.invoke<T>("video:attach", payload.id));
      case "shell:openExternal":
        return native(() => host.invoke<T>("shell:openExternal", payload.url));
      case "analyzeText":
        return host.invoke<Response<T>>("core:invoke", command, payload);
      default:
        return host.invoke<Response<T>>("core:invoke", command, payload);
    }
  },
  onEvent(event, listener) {
    const host = bridge();
    if (!host) return () => {};
    return host.onEvent("core:event", (payload) => {
      if ((payload as { name?: string })?.name === event) listener(payload);
    });
  },
};

/** Browser implementation placeholder: native-only commands stay unavailable. */
export const webPlatform: Platform = {
  async invoke() {
    return { ok: false, data: null, error: "Desktop bridge unavailable in browser mode." };
  },
  onEvent() {
    return () => {};
  },
};

export const platform: Platform = bridge() ? desktopPlatform : webPlatform;

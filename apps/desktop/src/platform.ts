import type { Command, DesktopBridge } from './bridge';
import type { Response } from './envelope';

/** The seam between UI/domain logic and the host. Web can implement this later. */
export interface Platform {
  invoke<T>(command: Command, payload?: Record<string, unknown>): Promise<Response<T>>;
  onEvent(event: string, listener: (payload: unknown) => void): () => void;
}

function bridge(): DesktopBridge | undefined {
  if (typeof window === 'undefined') return undefined;
  return (window as Window & { sori?: DesktopBridge }).sori;
}

const desktopPlatform: Platform = {
  async invoke<T>(command: Command, payload: Record<string, unknown> = {}) {
    const host = bridge();
    if (!host) return { ok: false, data: null, error: 'Desktop bridge unavailable.' };
    switch (command) {
      case 'app:ping':
        return host.invoke<Response<T>>('app:ping');
      case 'dev:emit':
        return host.invoke<Response<T>>('dev:emit', payload);
      case 'analyzeText':
        return host.invoke<Response<T>>('core:invoke', command, payload);
      default:
        return {
          ok: false,
          data: null,
          error: `Command ${command} is not available yet.`,
        };
    }
  },
  onEvent(event, listener) {
    const host = bridge();
    if (!host) return () => {};
    return host.onEvent('core:event', (payload) => {
      if ((payload as { name?: string })?.name === event) listener(payload);
    });
  },
};

/** Browser implementation placeholder: native-only commands stay unavailable. */
export const webPlatform: Platform = {
  async invoke() {
    return { ok: false, data: null, error: 'Desktop bridge unavailable in browser mode.' };
  },
  onEvent() {
    return () => {};
  },
};

export const platform: Platform = bridge() ? desktopPlatform : webPlatform;

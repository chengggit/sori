export type Command = 'app:ping' | 'core:invoke';

export interface DesktopBridge {
  invoke<T>(channel: Command, ...args: unknown[]): Promise<T>;
  onEvent(channel: string, listener: (payload: unknown) => void): () => void;
}

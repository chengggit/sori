export type Command = 'app:ping' | 'core:invoke' | 'dev:emit' | 'analyzeText';

export interface DesktopBridge {
  invoke<T>(channel: Command, ...args: unknown[]): Promise<T>;
  onEvent(channel: string, listener: (payload: unknown) => void): () => void;
}

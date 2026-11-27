export type Command =
  | "app:ping"
  | "core:invoke"
  | "dev:emit"
  | "dialog:openDocument"
  | "dialog:openVideo"
  | "video:expose"
  | "video:probe"
  | "video:track"
  | "video:attach"
  | "analyzeText"
  | "library:state"
  | "document:add"
  | "document:import"
  | "document:update"
  | "document:remove"
  | "document:read"
  | "progress:saveDocument"
  | "video:import"
  | "video:read"
  | "video:remove"
  | "video:saveProgress"
  | "video:saveSubtitles"
  | "vocabulary:save"
  | "vocabulary:find"
  | "vocabulary:edit"
  | "vocabulary:remove";

export interface DesktopBridge {
  invoke<T>(channel: Command, ...args: unknown[]): Promise<T>;
  onEvent(channel: string, listener: (payload: unknown) => void): () => void;
}

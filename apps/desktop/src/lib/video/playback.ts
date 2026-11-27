export type PlaybackControls = {
  play(): void;
  pause(): void;
  seek(seconds: number): void;
};

export type PlaybackEvents = {
  onTime(seconds: number): void;
  onSave(seconds: number, duration?: number, completed?: boolean): void;
  onControls(controls: PlaybackControls | undefined): void;
};

import { invoke } from "@tauri-apps/api/core";

export type LocalVideo = { id: number; title: string };
export type SubtitleTrack = {
  index: number;
  language: string | null;
  title: string | null;
  text: boolean;
};
export type LocalVideoDetails = LocalVideo & {
  path: string;
  playbackUrl: string | null;
  mpvAvailable: boolean;
  seconds: number;
  sidecar: string | null;
  tracks: SubtitleTrack[];
  probeError: string | null;
};

export const importVideo = () => invoke<number | null>("import_video");
export const listVideos = () => invoke<LocalVideo[]>("list_videos");
export const openVideo = (id: number) => invoke<LocalVideoDetails>("open_video", { id });
export const openRemuxStream = (id: number, seconds: number) =>
  invoke<{ url: string; start: number; duration: number }>("open_remux_stream", { id, seconds });
export const removeVideo = (id: number) => invoke<void>("remove_video", { id });
export const saveVideoProgress = (id: number, seconds: number) =>
  invoke<void>("save_video_progress", { id, seconds });
export const readVideoSubtitles = (id: number, index: number) =>
  invoke<string>("read_video_subtitles", { id, index });
export const saveVideoSidecar = (id: number, text: string) =>
  invoke<void>("save_video_sidecar", { id, text });

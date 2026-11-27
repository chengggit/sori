import { platform } from "../../platform";

export type VideoSource = { id: string; url: string; name: string };

export type ProbeResult = {
  container?: string;
  video?: string;
  audio?: string[];
  tracks?: { index: number; language: string; label: string }[];
  error?: string;
};

export function exposeVideo(path: string) {
  return platform.invoke<VideoSource>("video:expose", { path });
}

export function probeVideo(id: string) {
  return platform.invoke<ProbeResult>("video:probe", { id });
}

export function videoTrack(id: string, index: number) {
  return platform.invoke<string>("video:track", { id, index });
}

export function attachSubtitles(id: string) {
  return platform.invoke<{ name: string; text: string } | null>("video:attach", { id });
}

export function openVideoPicker() {
  return platform.invoke<string | null>("dialog:openVideo");
}

import { platform } from "../../platform";
import {
  readVideo,
  saveVideoProgress,
  saveVideoSubtitles,
  loadLibraryState,
} from "$lib/library/commands";
import {
  exposeVideo,
  probeVideo,
  videoTrack,
  attachSubtitles,
  readTextTranscript,
  attachTextTranscript,
  removeTextTranscript,
  type VideoSource,
  type ProbeResult,
  type TextTranscript,
} from "./commands";
import {
  fetchMetadata,
  fetchTranscript,
  readTranscript,
  saveYouTubeProgress,
} from "$lib/youtube/commands";
import { parseSubtitles, type SubtitleCue } from "./subtitles";
import type { WordSource } from "$lib/analysis/state.svelte";

export class WatchSession {
  source = $state<VideoSource | null>(null);
  probe = $state<ProbeResult | null>(null);
  title = $state("");
  channel = "";
  start = $state(0);
  loading = $state(true);
  error = $state("");
  trackError = $state("");
  transcriptError = $state("");
  primary = $state("off");
  secondary = $state("off");
  primaryCues = $state<SubtitleCue[]>([]);
  secondaryCues = $state<SubtitleCue[]>([]);
  attached = $state<SubtitleCue[]>([]);
  attachedName = $state("Attached file");
  text = $state<TextTranscript>({});
  showingText = $state(false);
  importing = $state(false);
  private pending = $state({ primary: false, secondary: false });
  private fetching = $state(false);
  get trackLoading() {
    return this.pending.primary || this.pending.secondary || this.fetching;
  }
  private requests = { primary: 0, secondary: 0 };
  private alive = true;
  constructor(
    readonly videoId: number,
    readonly youtubeId: string,
  ) {}
  get wordSource(): WordSource {
    return this.youtubeId
      ? { kind: "youtube", id: this.youtubeId, title: this.title }
      : { kind: "local", id: this.videoId };
  }
  get options() {
    return [
      { value: "off", label: "Off" },
      ...(this.youtubeId
        ? [{ value: "youtube", label: "YouTube captions" }]
        : (this.probe?.tracks ?? []).map((track) => ({
            value: `index:${track.index}`,
            label: `${track.index} · ${track.label || track.language || "Subtitle"}`,
          }))),
      ...(this.attached.length ? [{ value: "attached", label: this.attachedName }] : []),
    ];
  }
  destroy() {
    this.alive = false;
    this.requests.primary++;
    this.requests.secondary++;
  }
  async load() {
    const text = readTextTranscript(this.wordSource).then((reply) => {
      if (!this.alive) return;
      if (reply.ok) {
        this.text = reply.data ?? {};
        this.showingText = !!this.text.content;
      } else this.transcriptError = reply.error;
    });
    if (this.youtubeId) {
      const [state, captions] = await Promise.all([loadLibraryState(), readTranscript(this.youtubeId)]);
      if (!this.alive) return;
      const history = state.ok
        ? ((state.data?.youtubeHistory ?? []) as {
            youtubeId: string;
            seconds: number;
            title: string;
            channel: string;
          }[])
        : [];
      const saved = history.find((item) => item.youtubeId === this.youtubeId);
      this.start = saved?.seconds ?? 0;
      this.title = saved?.title || "YouTube video";
      this.channel = saved?.channel || "";
      void fetchMetadata(this.youtubeId).then((info) => {
        if (!this.alive || !info.ok || !info.data) return;
        this.title = info.data.title || this.title;
        this.channel = info.data.channel || this.channel;
      });
      if (captions.ok && captions.data) this.setYouTubeCues(captions.data);
    } else {
      const saved = await readVideo(this.videoId);
      if (!this.alive) return;
      if (!saved.ok || !saved.data) {
        this.error = saved.error || "Video not found.";
        this.loading = false;
        return;
      }
      this.start = saved.data.seconds;
      if (saved.data.sidecar) {
        this.attached = parseSubtitles(saved.data.sidecar);
        this.primaryCues = this.attached;
        this.primary = "attached";
      }
      const opened = await exposeVideo(saved.data.path);
      if (!this.alive) return;
      if (!opened.ok || !opened.data) {
        this.error = opened.error || "Could not open video.";
        this.loading = false;
        return;
      }
      this.source = opened.data;
      this.title = opened.data.name.replace(/\.[^.]+$/, "").normalize("NFC");
      const info = await probeVideo(opened.data.id);
      if (!this.alive) return;
      if (!info.ok) this.trackError = info.error;
      else {
        this.probe = info.data;
        this.trackError = info.data?.error || "";
      }
      const korean = this.probe?.tracks?.find((t) =>
        /\b(ko|kor|korean)\b/i.test(`${t.language} ${t.label}`),
      );
      const english = this.probe?.tracks?.find((t) =>
        /\b(en|eng|english)\b/i.test(`${t.language} ${t.label}`),
      );
      await Promise.all([
        this.primary === "off" && korean ? this.selectTrack("primary", `index:${korean.index}`) : null,
        english && english.index !== korean?.index
          ? this.selectTrack("secondary", `index:${english.index}`)
          : null,
      ]);
    }
    await text;
    if (this.alive) this.loading = false;
  }
  async selectTrack(which: "primary" | "secondary", value: string) {
    const request = ++this.requests[which];
    this[which] = value;
    this.pending[which] = false;
    this.trackError = "";
    if (value === "off" || value === "attached") {
      this[`${which}Cues`] = value === "off" ? [] : this.attached;
      return;
    }
    if (!this.source || !value.startsWith("index:")) return;
    this.pending[which] = true;
    const reply = await videoTrack(this.source.id, Number(value.slice(6)));
    if (!this.alive || request !== this.requests[which]) return;
    this.pending[which] = false;
    if (!reply.ok) {
      this.trackError = reply.error;
      this[`${which}Cues`] = [];
    } else this[`${which}Cues`] = parseSubtitles(reply.data ?? "");
  }
  async attachSubtitles() {
    if (!this.source || this.importing) return;
    this.importing = true;
    this.trackError = "";
    const reply = await attachSubtitles(this.source.id);
    if (!this.alive) return;
    this.importing = false;
    if (!reply.ok) {
      this.trackError = reply.error;
      return;
    }
    if (!reply.data) return;
    const cues = parseSubtitles(reply.data.text);
    if (!cues.length) {
      this.trackError = "No readable timed subtitles found in this file.";
      return;
    }
    const saved = await saveVideoSubtitles(this.videoId, reply.data.path);
    if (!this.alive) return;
    if (!saved.ok) {
      this.trackError = saved.error;
      return;
    }
    this.attached = cues;
    this.attachedName = reply.data.name;
    await this.selectTrack("primary", "attached");
  }
  private setYouTubeCues(data: unknown) {
    const cues = (data as { cues?: SubtitleCue[] })?.cues;
    if (Array.isArray(cues)) {
      this.primaryCues = cues;
      this.primary = cues.length ? "youtube" : "off";
    }
  }
  async fetchCaptions() {
    if (this.trackLoading) return;
    this.fetching = true;
    this.trackError = "";
    const reply = await fetchTranscript(this.youtubeId);
    if (!this.alive) return;
    this.fetching = false;
    if (!reply.ok) this.trackError = reply.error;
    else {
      this.setYouTubeCues(reply.data);
      if (this.primaryCues.length) {
        const cached = await platform.invoke("youtube:cacheTranscript", {
          id: this.youtubeId,
          data: reply.data,
        });
        if (this.alive && !cached.ok) this.trackError = cached.error;
      }
      if (!this.primaryCues.length) this.trackError = "No timed captions found.";
    }
  }
  async attachText() {
    if (this.importing) return;
    this.importing = true;
    this.transcriptError = "";
    const reply = await attachTextTranscript(this.wordSource);
    if (!this.alive) return;
    this.importing = false;
    if (!reply.ok) this.transcriptError = reply.error;
    else if (reply.data) {
      this.text = reply.data;
      this.showingText = true;
    }
  }
  async removeText() {
    const reply = await removeTextTranscript(this.wordSource);
    if (!this.alive) return;
    if (!reply.ok) this.transcriptError = reply.error;
    else {
      this.text = {};
      this.showingText = false;
    }
  }
  async save(seconds: number, duration: number) {
    if (!Number.isFinite(seconds) || !Number.isFinite(duration) || duration <= 0) return;
    const reply = this.youtubeId
      ? await saveYouTubeProgress(this.youtubeId, this.title, this.channel, seconds, duration)
      : await saveVideoProgress(this.videoId, seconds, duration);
    if (this.alive && !reply.ok) this.error = reply.error;
  }
}

import {
  dictionarySettings,
  removeDictionaryKey,
  saveDictionaryKey,
  selectDictionary,
  type DictionaryProvider,
} from "$lib/dictionary/lookup";
import { removeYouTubeKey, saveYouTubeKey, youtubeSettings } from "$lib/youtube/commands";
import type { Response } from "../../envelope";

export class SettingsModel {
  provider = $state<DictionaryProvider>("wiktionary");
  krdictKey = $state("");
  youtubeKey = $state("");
  hasKrdictKey = $state(false);
  hasYoutubeKey = $state(false);
  hasYoutubeSavedKey = $state(false);
  dictionary = $state({ loading: true, busy: false, ready: false, error: "", message: "" });
  youtube = $state({ loading: true, busy: false, ready: false, error: "", message: "" });
  private active = true;
  dispose() {
    this.active = false;
    this.krdictKey = this.youtubeKey = "";
  }
  async loadDictionary() {
    this.dictionary.loading = true;
    const reply = await dictionarySettings();
    if (!this.active) return;
    this.dictionary.loading = false;
    this.dictionary.error = reply.ok ? "" : reply.error;
    if (reply.ok && reply.data) {
      this.dictionary.ready = true;
      this.provider = reply.data.provider;
      this.hasKrdictKey = reply.data.hasKey;
    }
  }
  async loadYoutube() {
    this.youtube.loading = true;
    const reply = await youtubeSettings();
    if (!this.active) return;
    this.youtube.loading = false;
    this.youtube.error = reply.ok ? "" : reply.error;
    if (reply.ok && reply.data) {
      this.youtube.ready = true;
      this.hasYoutubeKey = reply.data.hasKey;
      this.hasYoutubeSavedKey = reply.data.saved;
    }
  }
  private async mutate(
    section: "dictionary" | "youtube",
    command: () => Promise<Response<null>>,
    message: string,
  ) {
    const state = this[section];
    if (state.busy || state.loading || !state.ready) return;
    state.busy = true;
    state.error = state.message = "";
    const reply = await command();
    if (!this.active) return;
    if (!reply.ok) state.error = reply.error;
    else {
      if (section === "dictionary") {
        this.krdictKey = "";
        await this.loadDictionary();
      } else {
        this.youtubeKey = "";
        await this.loadYoutube();
      }
      if (!this.active) return;
      state.message = message;
    }
    state.busy = false;
  }
  chooseProvider(provider: DictionaryProvider) {
    return this.mutate("dictionary", () => selectDictionary(provider), "Analysis dictionary updated.");
  }
  saveKrdict() {
    return this.mutate(
      "dictionary",
      () => saveDictionaryKey(this.krdictKey.trim()),
      "KRDict API key saved.",
    );
  }
  removeKrdict() {
    return this.mutate("dictionary", removeDictionaryKey, "KRDict key removed.");
  }
  saveYoutube() {
    return this.mutate(
      "youtube",
      () => saveYouTubeKey(this.youtubeKey.trim()),
      "YouTube API key saved.",
    );
  }
  removeYoutube() {
    return this.mutate("youtube", removeYouTubeKey, "Saved YouTube key removed.");
  }
}

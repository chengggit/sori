import type { Analysis } from "../reader/analysis";
import { wholeWordTerms } from "../reader/breakdown";
import { dictionarySettings, lookupWord, type DictionaryDefinition } from "../dictionary/lookup";
import { editWord, findWord, removeWord, saveWord } from "../library/commands";

export type WordSource =
  { kind: "document" | "local"; id: number } | { kind: "youtube"; id: string; title: string };
export type SavedWord = {
  id: number;
  word: string;
  normalizedForm: string | null;
  definition: DictionaryDefinition | null;
  tags: string[];
};
export type { WordDraft } from "../vocabulary/types";
import type { WordDraft } from "../vocabulary/types";

export class AnalysisModel {
  definitions = $state<DictionaryDefinition[]>([]);
  selected = $state<DictionaryDefinition | null>(null);
  saved = $state<SavedWord | null>(null);
  loading = $state(false);
  error = $state("");
  saveError = $state("");
  saving = $state(false);
  matchedTerm = $state("");
  private selection = 0;
  private lookupRequest = 0;
  private analysis!: Analysis;
  private source?: WordSource;
  destroy() {
    this.selection++;
    this.lookupRequest++;
  }
  start(analysis: Analysis, source?: WordSource) {
    this.analysis = analysis;
    this.source = source;
    const selection = ++this.selection;
    this.saved = null;
    this.selected = null;
    this.saveError = "";
    this.saving = false;
    void this.lookup();
    if (source)
      void findWord(source.kind, source.id, analysis.word, analysis.context || analysis.word).then(
        (reply) => {
          if (selection !== this.selection) return;
          if (reply.ok) this.saved = reply.data as SavedWord | null;
          else this.saveError = reply.error;
        },
      );
  }
  async lookup(
    terms = this.analysis.lookupTerms ?? wholeWordTerms(this.analysis.word, this.analysis.tokens),
  ) {
    const request = ++this.lookupRequest;
    this.loading = true;
    this.error = "";
    this.definitions = [];
    this.selected = null;
    this.matchedTerm = "";
    const settings = await dictionarySettings();
    if (request !== this.lookupRequest) return;
    if (!settings.ok || !settings.data) {
      this.error = settings.error || "Could not load dictionary settings.";
      this.loading = false;
      return;
    }
    for (const term of terms) {
      let reply = await lookupWord(term, settings.data.provider);
      if (request !== this.lookupRequest) return;
      if (reply.ok && !reply.data?.length && settings.data.provider === "krdict") {
        reply = await lookupWord(term, "wiktionary");
        if (request !== this.lookupRequest) return;
      }
      if (!reply.ok) {
        this.error = reply.error;
        break;
      }
      if (reply.data?.length) {
        this.definitions = reply.data;
        this.selected = reply.data[0];
        this.matchedTerm = term;
        break;
      }
    }
    this.loading = false;
  }
  async save(draft: WordDraft) {
    if (!this.source || this.saving) return false;
    if (!draft.meaning && draft.note) {
      this.saveError = "Enter a meaning to save a note.";
      return false;
    }
    const selection = this.selection;
    this.saving = true;
    this.saveError = "";
    const definition: DictionaryDefinition = {
      ...(this.selected ?? { term: draft.word, partOfSpeech: "", sourceUrl: "" }),
      text: draft.meaning,
      note: draft.note || null,
      custom: !this.selected || draft.meaning !== this.selected.text,
    };
    const reply = this.saved
      ? await editWord(this.saved.id, {
          normalizedForm: draft.word,
          meaning: draft.meaning,
          note: draft.note,
          tags: draft.tags,
        })
      : await saveWord(
          this.source.kind,
          this.source.id,
          {
            word: this.analysis.word,
            normalizedForm: draft.word,
            context: this.analysis.context || this.analysis.word,
            definition: draft.meaning ? definition : null,
            tags: draft.tags,
          },
          this.source.kind === "youtube" ? this.source.title : "",
        );
    if (selection !== this.selection) return false;
    this.saving = false;
    if (!reply.ok) {
      this.saveError = reply.error;
      return false;
    }
    const found = await findWord(
      this.source.kind,
      this.source.id,
      this.analysis.word,
      this.analysis.context || this.analysis.word,
    );
    if (selection !== this.selection) return false;
    if (!found.ok) {
      this.saveError = found.error;
      return false;
    }
    this.saved = found.data as SavedWord | null;
    return true;
  }
  async remove() {
    if (!this.saved || this.saving) return false;
    const selection = this.selection;
    this.saving = true;
    this.saveError = "";
    const reply = await removeWord(this.saved.id);
    if (selection !== this.selection) return false;
    this.saving = false;
    if (!reply.ok) {
      this.saveError = reply.error;
      return false;
    }
    this.saved = null;
    return true;
  }
}

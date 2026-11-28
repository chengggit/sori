import { loadLibraryState, editWord, removeWord } from "$lib/library/commands";
import { filterEntries, typeOptions } from "./entries";
import type { VocabularyEntry, WordDraft, WordSort } from "./types";
export class VocabularyModel {
  entries = $state<VocabularyEntry[]>([]);
  query = $state("");
  typeFilter = $state("All types");
  sort = $state<WordSort>("Recent");
  selectedId = $state<number | null>(null);
  loading = $state(true);
  refreshing = $state(false);
  busy = $state(false);
  error = $state("");
  editError = $state("");
  removeError = $state("");
  private active = true;
  private generation = 0;
  get types() {
    return typeOptions(this.entries);
  }
  get filtered() {
    return filterEntries(this.entries, this.query, this.typeFilter, this.sort);
  }
  get selected() {
    return this.entries.find((entry) => entry.id === this.selectedId) ?? null;
  }
  get countLabel() {
    const total = this.entries.length,
      count = this.filtered.length;
    return `${this.query.trim() || this.typeFilter !== "All types" ? `${count} of ` : ""}${total} ${total === 1 ? "saved word" : "saved words"}`;
  }
  clearFilters() {
    this.query = "";
    this.typeFilter = "All types";
  }
  dispose() {
    this.active = false;
    this.generation++;
  }
  async load() {
    const generation = ++this.generation;
    this.refreshing = true;
    const reply = await loadLibraryState();
    if (!this.active || generation !== this.generation) return;
    this.loading = false;
    this.refreshing = false;
    if (!reply.ok || !reply.data) {
      this.error = reply.error || "Could not load saved words.";
      return;
    }
    this.entries = reply.data.vocabulary ?? [];
    this.error = reply.data.error || "";
    if (!this.types.includes(this.typeFilter)) this.typeFilter = "All types";
    if (!this.entries.some((entry) => entry.id === this.selectedId)) this.selectedId = null;
  }
  async save(id: number, draft: WordDraft) {
    if (this.busy) return false;
    this.busy = true;
    this.editError = "";
    const reply = await editWord(id, {
      normalizedForm: draft.word,
      meaning: draft.meaning,
      note: draft.note,
      tags: draft.tags,
    });
    if (!this.active) return false;
    if (!reply.ok) {
      this.busy = false;
      this.editError = reply.error;
      return false;
    }
    await this.load();
    if (!this.active) return false;
    this.busy = false;
    return true;
  }
  async remove(id: number) {
    if (this.busy) return false;
    this.busy = true;
    this.removeError = "";
    const reply = await removeWord(id);
    if (!this.active) return false;
    if (!reply.ok) {
      this.busy = false;
      this.removeError = reply.error;
      return false;
    }
    this.entries = this.entries.filter((entry) => entry.id !== id);
    if (this.selectedId === id) this.selectedId = null;
    await this.load();
    if (!this.active) return false;
    this.busy = false;
    return true;
  }
}

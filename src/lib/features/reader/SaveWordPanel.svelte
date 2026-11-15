<script lang="ts">
  import { onMount } from "svelte";
  import { X } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import type { DictionaryDefinition } from "../dictionary/dictionary";
  import type { VocabularyEntry } from "../vocabulary/vocabulary";

  let { word, definition, saved, saving, error, onSave, onRemove, onClose }: {
    word: string;
    definition: DictionaryDefinition | null;
    saved?: VocabularyEntry;
    saving: boolean;
    error: string;
    onSave: (draft: { word: string; meaning: string; note: string; tags: string[] }) => void;
    onRemove: () => void;
    onClose: () => void;
  } = $props();

  // Drafts belong to this opening of the panel and survive tab switches.
  let wordDraft = $state("");
  let meaningDraft = $state("");
  let noteDraft = $state("");
  let tagsDraft = $state("");
  let wordInput: HTMLInputElement;
  onMount(() => {
    wordDraft = saved?.normalizedForm || saved?.word || definition?.term || word;
    meaningDraft = saved?.definition?.text ?? definition?.text ?? "";
    noteDraft = saved?.definition?.note ?? definition?.note ?? "";
    tagsDraft = saved?.tags.join(", ") ?? "";
    wordInput.focus();
  });
</script>

<svelte:window onkeydown={(event) => {
  if (event.key === "Escape" && !saving) {
    event.preventDefault();
    onClose();
  }
}} />

<section aria-label={saved ? "Saved word" : "Save word"} class="absolute inset-x-0 bottom-0 z-20 max-h-[80%] overflow-y-auto rounded-t-xl border-t bg-popover p-4 shadow-xl sm:p-5">
  <div class="mb-4 flex items-center justify-between gap-2">
    <h3 class="font-semibold">{saved ? "Saved word" : "Save word"}</h3>
    <Button variant="ghost" size="icon-sm" aria-label="Close save panel" disabled={saving} onclick={onClose}><X /></Button>
  </div>
  <form class="grid gap-4" onsubmit={(event) => {
    event.preventDefault();
    if (!saved && !saving) onSave({
      word: wordDraft.trim(), meaning: meaningDraft.trim(), note: noteDraft.trim(),
      tags: [...new Set(tagsDraft.split(",").map((tag) => tag.trim()).filter(Boolean))],
    });
  }}>
    <label class="grid gap-1.5 text-sm font-medium">
      Word
      <input bind:this={wordInput} bind:value={wordDraft} required maxlength="100" readonly={!!saved} disabled={saving} lang="ko" class="rounded-md border bg-background px-3 py-2 font-normal" />
    </label>
    <label class="grid gap-1.5 text-sm font-medium">
      Meanings
      <textarea bind:value={meaningDraft} required maxlength="8000" rows="3" readonly={!!saved} disabled={saving} placeholder="Add a meaning for this word" class="resize-y rounded-md border bg-background px-3 py-2 font-normal"></textarea>
    </label>
    <label class="grid gap-1.5 text-sm font-medium">
      Tags
      <input bind:value={tagsDraft} readonly={!!saved} disabled={saving} maxlength="1100" placeholder="e.g. reading, verbs, science" class="rounded-md border bg-background px-3 py-2 font-normal" />
      <span class="text-xs font-normal text-muted-foreground">Separate tags with commas.</span>
    </label>
    <details>
      <summary class="cursor-pointer text-sm text-muted-foreground">Note (optional)</summary>
      <textarea aria-label="Note" bind:value={noteDraft} rows="2" maxlength="4000" readonly={!!saved} disabled={saving} class="mt-2 w-full resize-y rounded-md border bg-background px-3 py-2 text-sm"></textarea>
    </details>
    {#if error}<p role="alert" class="text-sm text-destructive">{error}</p>{/if}
    <div class="flex justify-end gap-2">
      {#if saved}
        <Button type="button" variant="outline" disabled={saving} onclick={onRemove}>{saving ? "Removing…" : "Remove saved word"}</Button>
      {:else}
        <Button type="button" variant="ghost" disabled={saving} onclick={onClose}>Cancel</Button>
        <Button type="submit" disabled={saving || !wordDraft.trim() || !meaningDraft.trim()}>{saving ? "Saving…" : "Save word"}</Button>
      {/if}
    </div>
  </form>
</section>

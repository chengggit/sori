<script lang="ts">
  import { onMount } from "svelte";
  import { X } from "@lucide/svelte";
  import { Input } from "$lib/components/ui/input";
  import { Button } from "$lib/components/ui/button";
  import type { WordDraft } from "./state.svelte";
  let {
    initial,
    saved,
    saving,
    error,
    onSave,
    onRemove,
    onClose,
  }: {
    initial: WordDraft;
    saved: boolean;
    saving: boolean;
    error: string;
    onSave: (draft: WordDraft) => Promise<boolean>;
    onRemove: () => Promise<boolean>;
    onClose: () => void;
  } = $props();
  let word = $state("");
  let meaning = $state("");
  let tags = $state("");
  let note = $state("");
  let input: HTMLInputElement | null = $state(null);
  onMount(() => {
    word = initial.word;
    meaning = initial.meaning;
    tags = initial.tags.join(", ");
    note = initial.note;
    input?.focus();
  });
</script>

<section class="save-editor" aria-label="Save word" data-testid="save-word-editor">
  <header class="mb-5 flex items-center justify-between">
    <h3 class="font-semibold">{saved ? "Saved word" : "Save word"}</h3>
    <Button
      variant="ghost"
      size="icon-sm"
      aria-label="Close save panel"
      disabled={saving}
      onclick={onClose}
    >
      <X size={15} />
    </Button>
  </header>
  <form
    class="grid gap-3"
    onsubmit={async (event) => {
      event.preventDefault();
      if (
        await onSave({
          word: word.trim(),
          meaning: meaning.trim(),
          note: note.trim(),
          tags: [
            ...new Set(
              tags
                .split(",")
                .map((tag) => tag.trim())
                .filter(Boolean),
            ),
          ],
        })
      )
        onClose();
    }}
  >
    <label class="grid gap-2 text-sm">
      Word<Input
        bind:ref={input}
        bind:value={word}
        disabled={saving}
        required
        maxlength={100}
        lang="ko"
        class="rounded-xl bg-background font-[family-name:var(--font-korean)]"
      />
    </label>
    <label class="grid gap-2 text-sm">
      Meanings<textarea
        bind:value={meaning}
        disabled={saving}
        maxlength={8000}
        rows="3"
        placeholder="Add a meaning (optional)"
        class="resize-y rounded-xl border border-input bg-background p-3 text-sm"></textarea>
    </label>
    <label class="grid gap-2 text-sm">
      Tags<Input
        aria-label="Tags"
        bind:value={tags}
        disabled={saving}
        maxlength={1100}
        placeholder="e.g. reading, verbs, science"
        class="rounded-xl bg-background"
      /><span class="text-xs text-muted-foreground">Separate tags with commas.</span>
    </label>
    <details>
      <summary class="cursor-pointer text-sm text-muted-foreground">Note (optional)</summary><textarea
        aria-label="Note"
        bind:value={note}
        disabled={saving}
        maxlength={4000}
        rows="2"
        class="mt-2 w-full rounded-xl border border-input bg-background p-3 text-sm"></textarea>
    </details>
    {#if error}<p role="alert" class="text-sm text-destructive">{error}</p>{/if}
    <div class="flex flex-wrap justify-end gap-2">
      {#if saved}<Button
          type="button"
          variant="destructive"
          disabled={saving}
          onclick={async () => {
            if (await onRemove()) onClose();
          }}
        >
          Remove saved word
        </Button>{/if}
      <Button type="button" variant="outline" disabled={saving} onclick={onClose}>Cancel</Button>
      <Button type="submit" disabled={saving || !word.trim()}>
        {saving ? "Saving…" : saved ? "Save changes" : "Save word"}
      </Button>
    </div>
  </form>
</section>

<style>
  .save-editor {
    flex-shrink: 0;
    max-height: 80%;
    overflow-y: auto;
    padding: 16px 20px 20px;
    border: 1px solid var(--border);
    border-radius: 12px 12px 0 0;
    background: var(--card);
  }
</style>

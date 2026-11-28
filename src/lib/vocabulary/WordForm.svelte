<script lang="ts">
  import { onMount } from "svelte";
  import { Input } from "$lib/components/ui/input";
  import { Button } from "$lib/components/ui/button";
  import type { WordDraft } from "./types";
  let {
    initial,
    saved = false,
    saving,
    error,
    onSave,
    onRemove,
    onClose,
    mode = "panel",
  }: {
    initial: WordDraft;
    saved?: boolean;
    saving: boolean;
    error: string;
    onSave: (draft: WordDraft) => Promise<boolean>;
    onRemove?: () => Promise<boolean>;
    onClose: () => void;
    mode?: "panel" | "edit";
  } = $props();
  let word = $state(""),
    meaning = $state(""),
    tags = $state(""),
    note = $state("");
  let input: HTMLInputElement | null = $state(null);
  onMount(() => {
    word = initial.word;
    meaning = initial.meaning;
    tags = initial.tags.join(", ");
    note = initial.note;
    input?.focus();
  });
</script>

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
    {mode === "edit" ? "Dictionary form" : "Word"}<Input
      bind:ref={input}
      bind:value={word}
      disabled={saving}
      required={mode === "panel"}
      maxlength={100}
      lang="ko"
      class="rounded-xl bg-background font-[family-name:var(--font-korean)]"
    />
  </label>
  <label class="grid gap-2 text-sm">
    {mode === "edit" ? "Meaning" : "Meanings"}<textarea
      aria-label={mode === "edit" ? "Meaning" : "Meanings"}
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
    />{#if mode === "panel"}<span class="text-xs text-muted-foreground">
        Separate tags with commas.
      </span>{/if}
  </label>
  {#snippet noteField()}
    <textarea
      aria-label="Note"
      bind:value={note}
      disabled={saving}
      maxlength={4000}
      rows="2"
      class="w-full rounded-xl border border-input bg-background p-3 text-sm"></textarea>
  {/snippet}
  {#if mode === "edit"}
    <label class="grid gap-2 text-sm">Note{@render noteField()}</label>
  {:else}
    <details open={!!initial.note}>
      <summary class="mb-2 cursor-pointer text-sm text-muted-foreground">Note (optional)</summary>
      {@render noteField()}
    </details>
  {/if}
  {#if error}<p role="alert" class="text-sm text-destructive">{error}</p>{/if}
  <div class="flex flex-wrap justify-end gap-2">
    {#if saved && onRemove}<Button
        type="button"
        variant="destructive"
        disabled={saving}
        onclick={async () => {
          if (await onRemove?.()) onClose();
        }}
      >
        Remove saved word
      </Button>{/if}
    <Button type="button" variant="outline" disabled={saving} onclick={onClose}>Cancel</Button>
    <Button
      data-testid={mode === "edit" ? "save-vocabulary" : undefined}
      type="submit"
      disabled={saving || (mode === "panel" && !word.trim())}
    >
      {saving ? "Saving…" : saved ? "Save changes" : "Save word"}
    </Button>
  </div>
</form>

<script lang="ts">
  import { X } from "@lucide/svelte";
  import WordForm from "$lib/vocabulary/WordForm.svelte";
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
  <WordForm {initial} {saved} {saving} {error} {onSave} {onRemove} {onClose} />
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

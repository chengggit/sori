<script lang="ts">
  import { Pencil, Search, Trash2, X } from "@lucide/svelte";
  import { onMount } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import { editWord, loadLibraryState, removeWord, type VocabularyEdit } from "$lib/library/commands";

  type Definition = {
    term?: string;
    partOfSpeech?: string;
    text?: string;
    sourceUrl?: string;
    hanja?: string | null;
    custom?: boolean;
    note?: string | null;
  };

  type VocabularyEntry = {
    id: number;
    word: string;
    normalizedForm: string | null;
    documentId: number | null;
    sourceTitle: string;
    context: string;
    createdAt: number;
    definition: Definition | null;
    tags: string[];
  };

  const sortOptions = ["Recent", "Oldest", "A–Z", "Z–A"] as const;
  const wordClasses = [
    "noun",
    "verb",
    "adjective",
    "adverb",
    "pronoun",
    "determiner",
    "particle",
    "conjunction",
    "interjection",
    "numeral",
  ];

  let entries = $state<VocabularyEntry[]>([]);
  let query = $state("");
  let typeFilter = $state("All types");
  let sort = $state<(typeof sortOptions)[number]>("Recent");
  let error = $state("");
  let details = $state<VocabularyEntry | null>(null);
  let editing = $state<VocabularyEntry | null>(null);
  let normalizedForm = $state("");
  let meaning = $state("");
  let note = $state("");
  let tags = $state("");
  let deleting = $state<VocabularyEntry | null>(null);
  let busy = $state(false);

  function partOfSpeech(entry: VocabularyEntry) {
    const value = (entry.definition?.partOfSpeech ?? "").trim().toLowerCase();
    if (value) return value;
    for (const tag of entry.tags ?? []) {
      const normalized = tag.trim().toLowerCase().replace(/s$/, "");
      if (wordClasses.includes(normalized)) return normalized;
    }
    return "";
  }

  function capitalize(value: string) {
    return value ? value.charAt(0).toUpperCase() + value.slice(1) : "";
  }

  function displayWord(entry: VocabularyEntry) {
    const normalized = (entry.normalizedForm ?? "").trim();
    return normalized && normalized !== entry.word ? normalized : entry.word;
  }

  function formatMeaning(entry: VocabularyEntry) {
    return (entry.definition?.text ?? "")
      .trim()
      .replace(/\s*\n+\s*/g, "; ")
      .replace(/[ \t]+/g, " ");
  }

  const typeOptions = $derived([
    "All types",
    ...[...new Set(entries.map((entry) => capitalize(partOfSpeech(entry))).filter(Boolean))].sort(
      (a, b) => a.localeCompare(b),
    ),
  ]);

  const filtered = $derived.by(() => {
    const needle = query.trim().normalize().toLowerCase();
    const result = entries.filter((entry) => {
      if (typeFilter !== "All types" && partOfSpeech(entry) !== typeFilter.toLowerCase()) return false;
      if (!needle) return true;
      return [
        entry.word,
        entry.normalizedForm,
        entry.definition?.text,
        entry.definition?.note,
        entry.context,
        entry.sourceTitle,
        ...(entry.tags ?? []),
      ]
        .filter((value): value is string => Boolean(value))
        .some((value) => value.toLowerCase().includes(needle));
    });
    const created = (entry: VocabularyEntry) => Number(entry.createdAt) || 0;
    result.sort((a, b) => {
      if (sort === "Oldest") return created(a) - created(b) || a.id - b.id;
      if (sort === "A–Z") return displayWord(a).localeCompare(displayWord(b));
      if (sort === "Z–A") return displayWord(b).localeCompare(displayWord(a));
      return created(b) - created(a) || b.id - a.id;
    });
    return result;
  });

  async function load() {
    const state = await loadLibraryState();
    if (!state.ok) {
      error = state.error;
      return;
    }
    entries = (state.data?.vocabulary ?? []) as VocabularyEntry[];
    error = state.data?.error ?? "";
    if (!typeOptions.includes(typeFilter)) typeFilter = "All types";
  }

  onMount(() => {
    void load();
  });

  function startEdit(entry: VocabularyEntry) {
    editing = entry;
    normalizedForm = entry.normalizedForm ?? entry.word;
    meaning = entry.definition?.text ?? "";
    note = entry.definition?.note ?? "";
    tags = entry.tags.join(", ");
    error = "";
  }

  async function saveEdit() {
    if (!editing || busy || !normalizedForm.trim()) return;
    busy = true;
    error = "";
    try {
      const input: VocabularyEdit = {
        normalizedForm: normalizedForm.trim(),
        meaning,
        note,
        tags: [
          ...new Set(
            tags
              .split(",")
              .map((tag) => tag.trim())
              .filter(Boolean),
          ),
        ],
      };
      const saved = await editWord(editing.id, input);
      if (!saved.ok) {
        error = saved.error;
        return;
      }
      editing = null;
      await load();
    } finally {
      busy = false;
    }
  }

  async function confirmDelete() {
    if (!deleting || busy) return;
    busy = true;
    error = "";
    try {
      const removed = await removeWord(deleting.id);
      if (!removed.ok) {
        error = removed.error;
        return;
      }
      if (details?.id === deleting.id) details = null;
      deleting = null;
      await load();
    } finally {
      busy = false;
    }
  }
</script>

<div class="flex flex-col gap-4">
  <div class="flex flex-wrap items-center gap-2">
    <div class="relative w-full max-w-sm">
      <Search class="absolute left-2.5 top-2.5 text-muted-foreground" size={16} />
      <Input
        class="pl-8"
        placeholder="Search vocabulary"
        aria-label="Search vocabulary"
        bind:value={query}
      />
    </div>
    <select
      class="h-9 rounded-md border border-input bg-transparent px-2 text-sm"
      aria-label="Filter by type"
      bind:value={typeFilter}
    >
      {#each typeOptions as option (option)}
        <option value={option}>{option}</option>
      {/each}
    </select>
    <select
      class="h-9 rounded-md border border-input bg-transparent px-2 text-sm"
      aria-label="Sort vocabulary"
      bind:value={sort}
    >
      {#each sortOptions as option (option)}
        <option value={option}>{option}</option>
      {/each}
    </select>
    <span class="ml-auto text-sm text-muted-foreground" data-testid="vocabulary-count">
      {filtered.length} of {entries.length}
      {entries.length === 1 ? "saved word" : "saved words"}
    </span>
  </div>

  {#if error}
    <p class="text-sm text-destructive" role="alert" data-testid="vocabulary-error">{error}</p>
  {/if}

  {#if editing}
    <section class="rounded-lg border border-border bg-card p-4" data-testid="vocabulary-editor">
      <div class="mb-3 flex items-center justify-between">
        <h2 class="text-base font-semibold">Edit “{editing.word}”</h2>
        <Button
          variant="ghost"
          size="icon-sm"
          aria-label="Close editor"
          onclick={() => (editing = null)}
        >
          <X />
        </Button>
      </div>
      <div class="flex flex-col gap-3">
        <Input aria-label="Dictionary form" bind:value={normalizedForm} />
        <textarea
          class="min-h-20 w-full rounded-md border border-input bg-transparent p-2"
          aria-label="Meaning"
          placeholder="Meaning"
          bind:value={meaning}></textarea>
        <textarea
          class="min-h-20 w-full rounded-md border border-input bg-transparent p-2"
          aria-label="Note"
          placeholder="Note"
          bind:value={note}></textarea>
        <Input aria-label="Tags" placeholder="Tags, comma separated" bind:value={tags} />
        <Button
          onclick={saveEdit}
          disabled={busy || !normalizedForm.trim()}
          data-testid="save-vocabulary"
        >
          Save changes
        </Button>
      </div>
    </section>
  {/if}

  {#if filtered.length === 0}
    <p
      class="rounded-lg border border-border bg-card p-8 text-center text-muted-foreground"
      data-testid="empty-vocabulary"
    >
      {query || typeFilter !== "All types" ? "No matching words" : "No saved words yet"}
    </p>
  {:else}
    <ul class="grid gap-2 lg:grid-cols-2" data-testid="vocabulary-list">
      {#each filtered as entry (entry.id)}
        <li class="rounded-lg border border-border bg-card p-3">
          <div class="flex items-start gap-2">
            <button
              type="button"
              class="flex-1 text-left"
              data-testid={`vocabulary-${entry.id}`}
              onclick={() => (details = entry)}
            >
              <span class="font-[family-name:var(--font-korean)] text-lg">{displayWord(entry)}</span>
              {#if partOfSpeech(entry)}
                <span class="ml-2 rounded bg-accent-soft px-1.5 py-0.5 text-xs">
                  {capitalize(partOfSpeech(entry))}
                </span>
              {/if}
              {#if formatMeaning(entry)}
                <span class="mt-1 block text-sm text-muted-foreground">{formatMeaning(entry)}</span>
              {/if}
            </button>
            <Button
              variant="ghost"
              size="icon-sm"
              aria-label={`Edit ${entry.word}`}
              onclick={() => startEdit(entry)}
            >
              <Pencil />
            </Button>
            <Button
              variant="ghost"
              size="icon-sm"
              aria-label={`Remove ${entry.word}`}
              onclick={() => (deleting = entry)}
            >
              <Trash2 />
            </Button>
          </div>
          {#if entry.tags.length}
            <p class="mt-2 flex flex-wrap gap-1">
              {#each entry.tags as tag (tag)}
                <span class="rounded bg-muted px-1.5 py-0.5 text-xs">{tag}</span>
              {/each}
            </p>
          {/if}
        </li>
      {/each}
    </ul>
  {/if}

  {#if details}
    <section class="rounded-lg border border-border bg-card p-4" data-testid="vocabulary-details">
      <div class="mb-2 flex items-center justify-between">
        <h2 class="text-lg font-semibold">{displayWord(details)}</h2>
        <Button
          variant="ghost"
          size="icon-sm"
          aria-label="Close details"
          onclick={() => (details = null)}
        >
          <X />
        </Button>
      </div>
      <p class="text-sm text-muted-foreground">From {details.sourceTitle}</p>
      <p class="mt-2 whitespace-pre-wrap font-[family-name:var(--font-korean)]">{details.context}</p>
      {#if details.definition?.note}
        <p class="mt-2 text-sm">Note: {details.definition.note}</p>
      {/if}
      <Button class="mt-3" variant="outline" onclick={() => details && startEdit(details)}>Edit</Button>
    </section>
  {/if}

  {#if deleting}
    <div
      class="rounded-lg border border-destructive bg-card p-4"
      role="alertdialog"
      data-testid="vocabulary-delete"
    >
      <p class="mb-3 text-sm">Remove “{deleting.word}” from Vocabulary?</p>
      <div class="flex gap-2">
        <Button variant="outline" onclick={() => (deleting = null)}>Cancel</Button>
        <Button variant="destructive" onclick={confirmDelete} disabled={busy}>Remove</Button>
      </div>
    </div>
  {/if}
</div>

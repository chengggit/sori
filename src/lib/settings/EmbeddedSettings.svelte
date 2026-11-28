<script lang="ts">
  import { ArrowUp, ArrowDown, GripVertical, X, Plus } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import { embedSettings } from "$lib/dictionary/embed-settings";
  import { embeddedProviders, validCustomEmbed } from "$lib/dictionary/embedded";
  let customUrl = $state(""),
    error = $state(""),
    dragged = $state<string | null>(null);
  const installed = $derived([
    ...embeddedProviders.map((p) => ({ id: p.value as string, label: p.label as string })),
    ...$embedSettings.custom.map((p) => ({ id: p.id, label: new URL(p.url).hostname })),
  ]);
  const rows = $derived([
    ...$embedSettings.enabled,
    ...installed.map((p) => p.id).filter((id) => !$embedSettings.enabled.includes(id)),
  ]);
  function label(id: string) {
    return installed.find((p) => p.id === id)?.label ?? id;
  }
  function toggle(id: string) {
    embedSettings.update((s) => ({
      ...s,
      enabled: s.enabled.includes(id) ? s.enabled.filter((p) => p !== id) : [...s.enabled, id],
    }));
  }
  function move(id: string, to: number) {
    const enabled = [...$embedSettings.enabled],
      from = enabled.indexOf(id);
    if (from < 0 || to < 0 || to >= enabled.length) return;
    enabled.splice(from, 1);
    enabled.splice(to, 0, id);
    embedSettings.update((s) => ({ ...s, enabled }));
  }
  function add(event: SubmitEvent) {
    event.preventDefault();
    const url = customUrl.trim();
    if (!validCustomEmbed(url)) {
      error = "Enter an HTTPS address without a username or password.";
      return;
    }
    if ($embedSettings.custom.some((p) => p.url === url)) {
      error = "That dictionary is already listed.";
      return;
    }
    const id = `custom-${crypto.randomUUID()}`;
    embedSettings.update((s) => ({ enabled: [...s.enabled, id], custom: [...s.custom, { id, url }] }));
    customUrl = error = "";
  }
</script>

<section class="settings-form" data-testid="embed-settings" aria-label="Embedded lookup tabs">
  <div>
    <h3>Embedded lookup tabs</h3>
    <p class="hint">
      Enable dictionaries for Reader and Watch. Drag enabled tabs or use the arrows to reorder them.
    </p>
  </div>
  <ul class="embed-list">
    {#each rows as id (id)}
      {@const index = $embedSettings.enabled.indexOf(id)}
      <li
        draggable={index >= 0}
        ondragstart={() => (dragged = id)}
        ondragend={() => (dragged = null)}
        ondragover={(event) => {
          if (index >= 0) event.preventDefault();
        }}
        ondrop={(event) => {
          event.preventDefault();
          if (dragged) move(dragged, index);
          dragged = null;
        }}
      >
        <GripVertical size={14} class="text-muted-foreground" />
        <label>
          <input type="checkbox" checked={index >= 0} onchange={() => toggle(id)} />{label(id)}
        </label>
        {#if index >= 0}
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label={`Move ${label(id)} up`}
            disabled={index === 0}
            onclick={() => move(id, index - 1)}
          >
            <ArrowUp size={14} />
          </Button>
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label={`Move ${label(id)} down`}
            disabled={index === $embedSettings.enabled.length - 1}
            onclick={() => move(id, index + 1)}
          >
            <ArrowDown size={14} />
          </Button>
        {/if}
        {#if id.startsWith("custom-")}
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label={`Remove ${label(id)}`}
            onclick={() =>
              embedSettings.update((s) => ({
                enabled: s.enabled.filter((p) => p !== id),
                custom: s.custom.filter((p) => p.id !== id),
              }))}
          >
            <X size={14} />
          </Button>
        {/if}
      </li>
    {/each}
  </ul>
  <form onsubmit={add} class="settings-form">
    <label>
      Custom lookup URL<Input
        aria-label="Custom lookup URL"
        bind:value={customUrl}
        placeholder={"https://example.com/search?q={word}"}
      />
    </label>
    <p class="hint">Use {"{word}"} for the selected word. HTTPS addresses are supported.</p>
    {#if error}<p role="alert" class="text-destructive text-sm">{error}</p>{/if}
    <Button type="submit" variant="outline" class="justify-self-start" disabled={!customUrl.trim()}>
      <Plus size={14} />Add tab
    </Button>
  </form>
</section>

<style>
  .embed-list {
    display: grid;
    gap: 4px;
  }
  li {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 0;
    min-width: 0;
  }
  li[draggable="true"] {
    cursor: grab;
  }
  li label {
    display: flex;
    align-items: center;
    gap: 8px;
    flex: 1;
    min-width: 0;
    overflow-wrap: anywhere;
    font-size: 13px;
  }
  input[type="checkbox"] {
    flex-shrink: 0;
    accent-color: var(--dashboard-accent);
    width: 16px;
    height: 16px;
  }
</style>

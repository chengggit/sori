<script lang="ts">
  import { Bookmark, Compass, History, House, Library, PanelLeft } from '@lucide/svelte';
  import type { Snippet } from 'svelte';
  import { appearanceOptions, clampPageScale, type Appearance } from '$lib/appearance';
  import { cn } from '$lib/utils';

  let {
    page,
    appearance,
    dark,
    pageScale,
    onPage,
    onAppearance,
    onScale,
    children,
  }: {
    page: string;
    appearance: Appearance;
    dark: boolean;
    pageScale: number;
    onPage: (page: string) => void;
    onAppearance: (value: Appearance) => void;
    onScale: (value: number) => void;
    children?: Snippet;
  } = $props();

  const links = [
    { page: 'home', label: 'Home', icon: House },
    { page: 'explore', label: 'Explore', icon: Compass },
    { page: 'library', label: 'My Library', icon: Library },
    { page: 'vocabulary', label: 'Vocabulary', icon: Bookmark },
    { page: 'history', label: 'History', icon: History },
  ];

  let collapsed = $state(localStorage.getItem('sori-sidebar-collapsed') === 'true');
  $effect(() => localStorage.setItem('sori-sidebar-collapsed', String(collapsed)));

  const title = $derived(links.find((link) => link.page === page)?.label ?? 'Home');
</script>

<div class="flex h-screen overflow-hidden">
  <aside
    data-testid="sidebar"
    aria-label="Navigation"
    class={cn(
      'flex shrink-0 flex-col gap-6 border-r border-sidebar-border bg-sidebar px-2.5 py-3.5 transition-[width] duration-200 ease-out',
      collapsed ? 'w-14' : 'w-52',
    )}
  >
    <div class="flex min-h-9 items-center justify-between pl-2.5 pr-0.5">
      {#if !collapsed}<strong class="text-lg tracking-wide">sori</strong>{/if}
      <button
        type="button"
        class="flex size-9 items-center justify-center rounded-lg hover:bg-neutral-hover"
        aria-label="Toggle sidebar"
        onclick={() => (collapsed = !collapsed)}
      >
        <PanelLeft size={16} />
      </button>
    </div>

    <nav class="flex flex-col gap-0.5">
      {#each links as link (link.page)}
        {@const Icon = link.icon}
        <button
          type="button"
          data-testid={`nav-${link.page}`}
          title={link.label}
          aria-current={page === link.page ? 'page' : undefined}
          class={cn(
            'flex h-[34px] w-full items-center gap-3 rounded-[14px] px-3 text-left hover:bg-neutral-hover',
            page === link.page && 'bg-sidebar-selection text-dashboard-accent',
          )}
          onclick={() => onPage(link.page)}
        >
          <Icon size={16} class="shrink-0" />
          {#if !collapsed}<span>{link.label}</span>{/if}
        </button>
      {/each}
    </nav>

    <div class="mt-auto flex flex-col gap-2 px-1">
      <p class="m-0 text-[11px] text-muted-foreground">Appearance</p>
      <div class="flex flex-wrap gap-1" role="group" aria-label="Theme">
        {#each appearanceOptions as option (option.value)}
          <button
            type="button"
            data-testid={`theme-${option.value}`}
            class={cn(
              'rounded-lg border border-border bg-card px-2 py-1 text-[11px] hover:bg-neutral-hover',
              appearance === option.value && 'bg-accent-soft',
            )}
            onclick={() => onAppearance(option.value)}
          >
            {option.label}
          </button>
        {/each}
      </div>
      <label class="flex flex-col gap-1 text-[11px] text-muted-foreground">
        <span>Zoom {Math.round(pageScale * 100)}%</span>
        <input
          type="range"
          min="0.5"
          max="1.5"
          step="0.1"
          value={pageScale}
          aria-label="Page zoom"
          oninput={(event) => onScale(clampPageScale(Number(event.currentTarget.value)))}
        />
      </label>
      <p class="m-0 text-[11px] text-muted-foreground" data-testid="theme-state">
        {dark ? 'Dark' : 'Light'}
      </p>
    </div>
  </aside>

  <main data-testid="page-content" class="flex-1 overflow-auto p-7">
    <h1 data-testid="page-title" class="m-0 mb-4 text-3xl">{title}</h1>
    {#if children}
      {@render children()}
    {:else}
      <p class="text-muted-foreground">Page shell — feature work continues in later migration steps.</p>
      <p><a href="#bridge">Dev bridge</a> · <a href="#analysis">Analysis</a></p>
    {/if}
  </main>
</div>

<style>
  @media (max-width: 720px) {
    aside {
      width: 3.5rem !important;
    }
    aside span {
      display: none;
    }
  }
</style>

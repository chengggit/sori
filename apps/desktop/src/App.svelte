<script lang="ts">
  import { onMount } from 'svelte';
  import AnalysisPage from './AnalysisPage.svelte';
  import AppShell from './AppShell.svelte';
  import BridgePage from './BridgePage.svelte';
  import LibraryPage from './LibraryPage.svelte';
  import ReaderPage from './ReaderPage.svelte';
  import { loadAppearance, loadPageScale, type Appearance } from '$lib/appearance';

  let route = $state(location.hash);
  let appearance = $state<Appearance>(loadAppearance());
  let pageScale = $state(loadPageScale());
  let systemDark = $state(window.matchMedia('(prefers-color-scheme: dark)').matches);

  const dark = $derived(appearance === 'dark' || (appearance === 'system' && systemDark));
  const path = $derived(route.replace(/^#\/?/, '').split('?')[0]);
  const page = $derived(path.split('/')[0] || 'home');
  const readerId = $derived(Number(new URLSearchParams(route.split('?')[1] ?? '').get('id')) || 0);

  $effect(() => {
    document.documentElement.classList.toggle('dark', dark);
    document.documentElement.style.zoom = String(pageScale);
    localStorage.setItem('sori-appearance', appearance);
    localStorage.setItem('sori-page-scale', String(pageScale));
  });

  function goTo(next: string) {
    location.hash = `#/${next}`;
    route = location.hash;
  }

  onMount(() => {
    const onHashChange = () => {
      route = location.hash;
    };
    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const onThemeChange = (event: MediaQueryListEvent) => {
      systemDark = event.matches;
    };
    window.addEventListener('hashchange', onHashChange);
    media.addEventListener('change', onThemeChange);
    return () => {
      window.removeEventListener('hashchange', onHashChange);
      media.removeEventListener('change', onThemeChange);
    };
  });
</script>

{#if route === '#bridge'}
  <BridgePage />
{:else if route === '#analysis'}
  <AnalysisPage />
{:else}
  <AppShell
    {page}
    {appearance}
    {dark}
    {pageScale}
    onPage={goTo}
    onAppearance={(value) => (appearance = value)}
    onScale={(value) => (pageScale = value)}
    titleOverride={page === 'reader' ? 'Reader' : undefined}
  >
    {#if page === 'library'}
      <LibraryPage />
    {:else if page === 'reader'}
      <ReaderPage documentId={readerId} onBack={() => goTo('library')} />
    {/if}
  </AppShell>
{/if}

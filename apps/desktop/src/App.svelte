<script lang="ts">
  import { onMount } from 'svelte';
  import BridgePage from './BridgePage.svelte';
  import { platform } from './platform';

  let status = $state('Checking desktop bridge…');
  let route = $state(location.hash);

  onMount(() => {
    const onHashChange = () => {
      route = location.hash;
    };
    window.addEventListener('hashchange', onHashChange);

    void platform.invoke<string>('app:ping').then((reply) => {
      status = reply.ok ? String(reply.data) : reply.error;
    });

    return () => window.removeEventListener('hashchange', onHashChange);
  });
</script>

{#if route === '#bridge'}
  <BridgePage />
{:else}
  <main>
    <h1>Sori</h1>
    <p class="subtitle">Electron scaffold</p>
    <p class="status" data-testid="status">{status}</p>
    <p><a href="#bridge">Dev bridge</a></p>
  </main>
{/if}

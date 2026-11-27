<script lang="ts">
  import { onMount } from 'svelte';
  import type { DesktopBridge } from './bridge';
  import { unwrapData, type Response } from './envelope';

  let status = $state('Checking desktop bridge…');

  onMount(async () => {
    const bridge = (window as Window & { sori?: DesktopBridge }).sori;
    if (!bridge) {
      status = 'Desktop bridge unavailable (browser mode).';
      return;
    }
    try {
      const reply = await bridge.invoke<Response<string>>('app:ping');
      status = unwrapData(reply);
    } catch (error) {
      status = error instanceof Error ? error.message : String(error);
    }
  });
</script>

<main>
  <h1>Sori</h1>
  <p class="subtitle">Electron scaffold</p>
  <p class="status" data-testid="status">{status}</p>
</main>

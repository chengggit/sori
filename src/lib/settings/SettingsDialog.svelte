<script lang="ts">
  import * as Sheet from "$lib/components/ui/sheet";
  import SettingsContent from "./SettingsContent.svelte";
  let { open = $bindable(false) }: { open?: boolean } = $props();
  let busy = $state(false);
</script>

<Sheet.Root bind:open>
  <Sheet.Content
    class="max-w-[720px] h-[560px] max-h-[calc(var(--app-height)-2rem)] rounded-2xl border-0 gap-0 p-0 overflow-hidden"
    overlayProps={{ style: "backdrop-filter:none;" }}
    showCloseButton={!busy}
    onEscapeKeydown={(event) => {
      if (busy) event.preventDefault();
    }}
    onInteractOutside={(event) => {
      if (busy) event.preventDefault();
    }}
  >
    <Sheet.Header class="border-b border-border p-5 shrink-0">
      <Sheet.Title class="text-lg">Settings</Sheet.Title><Sheet.Description class="sr-only">
        Appearance, reading, dictionaries and connections.
      </Sheet.Description>
    </Sheet.Header>
    {#if open}<SettingsContent onBusy={(value) => (busy = value)} />{/if}
  </Sheet.Content>
</Sheet.Root>

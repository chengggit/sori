<script lang="ts">
  import { Play } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import * as Sheet from "$lib/components/ui/sheet";
  import { parseYouTubeLink } from "$lib/dashboard/youtube";
  let { open = $bindable(false), from }: { open?: boolean; from?: "explore" } = $props();
  let link = $state(""),
    error = $state("");
  $effect(() => {
    if (open) error = "";
  });
  function submit(event: SubmitEvent) {
    event.preventDefault();
    const id = parseYouTubeLink(link);
    if (!id) {
      error = "Paste a valid YouTube video link.";
      return;
    }
    open = false;
    link = "";
    location.hash = `#/watch?v=${id}${from ? `&from=${from}` : ""}`;
  }
</script>

<Sheet.Root bind:open>
  <Sheet.Content
    overlayProps={{ style: "backdrop-filter: none;" }}
    class="max-w-md rounded-2xl border-transparent gap-0 pb-0"
  >
    <Sheet.Header>
      <Sheet.Title class="text-base font-semibold">Open a YouTube video</Sheet.Title><Sheet.Description>
        Paste a video link to watch it in Sori.
      </Sheet.Description>
    </Sheet.Header>
    <form class="space-y-3 px-4 pb-4" onsubmit={submit}>
      <Input
        aria-label="YouTube link"
        placeholder="Paste a YouTube video link"
        bind:value={link}
        oninput={() => (error = "")}
      />
      {#if error}<p role="alert" class="text-sm text-destructive">{error}</p>{/if}
      <Button type="submit" class="bg-accent-soft text-dashboard-accent hover:bg-accent-soft">
        <Play /> Open video
      </Button>
    </form>
  </Sheet.Content>
</Sheet.Root>

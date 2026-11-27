<script lang="ts">
  import { Search } from "@lucide/svelte";
  import { Input } from "$lib/components/ui/input";
  import { Button } from "$lib/components/ui/button";
  let { onSearch }: { onSearch: (query: string) => void } = $props();
  let query = $state("");
</script>

<form
  role="search"
  class="flex w-full max-w-lg gap-2"
  onsubmit={(event) => {
    event.preventDefault();
    onSearch(query);
  }}
>
  <Input aria-label="Search YouTube" placeholder="Search YouTube" bind:value={query} />
  <Button variant="outline" size="icon" type="submit" aria-label="Search"><Search size={16} /></Button>
</form>

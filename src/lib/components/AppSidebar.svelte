<script lang="ts">
  import { Bookmark, Compass, History, House, Library, Settings } from "@lucide/svelte";
  import { resolve } from "$app/paths";
  import { page } from "$app/state";
  import * as Sidebar from "$lib/components/ui/sidebar";

  let { openSettings }: { openSettings: () => void } = $props();
  const sidebar = Sidebar.useSidebar();
  const links = [
    { label: "Home", icon: House, href: resolve("/") },
    { label: "Explore", icon: Compass, href: resolve("/explore") },
    { label: "My Library", icon: Library, href: resolve("/library") },
    { label: "History", icon: History, href: resolve("/history") },
    { label: "Vocabulary", icon: Bookmark, href: resolve("/vocabulary") },
  ];
  let current = $derived(
    page.url.pathname === resolve("/read")
      ? "My Library"
      : (links.find(({ href }) => href === page.url.pathname)?.label ?? "Home"),
  );
</script>

<Sidebar.Root collapsible="icon" class="border-sidebar-border">
  <Sidebar.Header class="p-4 group-data-[collapsible=icon]:p-2">
    <div class="flex h-9 items-center justify-between group-data-[collapsible=icon]:justify-center">
      <a
        href={resolve("/")}
        class="flex items-center gap-2 px-2 text-lg font-bold group-data-[collapsible=icon]:hidden"
        aria-label="Sori home"
      >
        sori
      </a>
      <Sidebar.Trigger />
    </div>
  </Sidebar.Header>

  <Sidebar.Content class="pt-4">
    <Sidebar.Group class="px-3.5 group-data-[collapsible=icon]:px-2">
      <nav aria-label="Main navigation" class="border-b border-sidebar-border pb-6">
        <Sidebar.Menu class="gap-1">
          {#each links as { label, icon: Icon, href } (label)}
            <Sidebar.MenuItem>
              <Sidebar.MenuButton
                isActive={current === label}
                tooltipContent={label}
                class="h-[34px] rounded-xl px-3 text-[13px] data-active:text-dashboard-accent"
              >
                {#snippet child({ props })}
                  <a
                    {...props}
                    {href}
                    aria-current={current === label ? "page" : undefined}
                    aria-label={label}
                    onclick={() => sidebar.setOpenMobile(false)}
                  >
                    <Icon />
                    <span class="group-data-[collapsible=icon]:hidden">{label}</span>
                  </a>
                {/snippet}
              </Sidebar.MenuButton>
            </Sidebar.MenuItem>
          {/each}
        </Sidebar.Menu>
      </nav>
    </Sidebar.Group>
  </Sidebar.Content>

  <Sidebar.Footer class="px-4 pb-8 group-data-[collapsible=icon]:px-2">
    <Sidebar.Menu>
      <Sidebar.MenuItem>
        <Sidebar.MenuButton
          onclick={openSettings}
          aria-label="Settings"
          tooltipContent="Settings"
          class="h-[34px] rounded-xl px-3 text-[13px]"
        >
          <Settings />
          <span class="group-data-[collapsible=icon]:hidden">Settings</span>
        </Sidebar.MenuButton>
      </Sidebar.MenuItem>
    </Sidebar.Menu>
  </Sidebar.Footer>
</Sidebar.Root>

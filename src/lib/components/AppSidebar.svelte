<script lang="ts">
  import { Bookmark, Compass, History, House, Library, Settings, SunMoon } from "@lucide/svelte";
  import * as Sidebar from "$lib/components/ui/sidebar";

  let {
    page,
    openSettings,
    openAppearance,
  }: { page: string; openSettings: () => void; openAppearance: () => void } = $props();
  const sidebar = Sidebar.useSidebar();
  const links = [
    { label: "Home", icon: House, href: "#/home" },
    { label: "Explore", icon: Compass, href: "#/explore" },
    { label: "My Library", icon: Library, href: "#/library" },
    { label: "History", icon: History, href: "#/history" },
    { label: "Vocabulary", icon: Bookmark, href: "#/vocabulary" },
  ];
  const current = $derived(
    page === "reader" || page === "watch"
      ? "My Library"
      : (links.find(({ href }) => href === `#/${page}`)?.label ??
          (page === "settings" ? "Settings" : "Home")),
  );
</script>

<Sidebar.Root data-testid="sidebar" collapsible="icon" class="border-sidebar-border">
  <Sidebar.Header class="p-4 group-data-[collapsible=icon]:p-2">
    <div class="flex h-9 items-center justify-between group-data-[collapsible=icon]:justify-center">
      <a
        href={"#/home"}
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
                    data-testid={`nav-${href.slice(2)}`}
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
          onclick={() => {
            sidebar.setOpenMobile(false);
            openSettings();
          }}
          data-testid="nav-settings"
          isActive={page === "settings"}
          aria-current={page === "settings" ? "page" : undefined}
          aria-label="Settings"
          tooltipContent="Settings"
          class="h-[34px] rounded-xl px-3 text-[13px]"
        >
          <Settings />
          <span class="group-data-[collapsible=icon]:hidden">Settings</span>
        </Sidebar.MenuButton>
      </Sidebar.MenuItem>
      <Sidebar.MenuItem>
        <Sidebar.MenuButton
          aria-label="Appearance"
          tooltipContent="Appearance"
          onclick={() => {
            sidebar.setOpenMobile(false);
            openAppearance();
          }}
          class="h-[34px] rounded-xl px-3 text-[13px]"
        >
          <SunMoon /><span class="group-data-[collapsible=icon]:hidden">Appearance</span>
        </Sidebar.MenuButton>
      </Sidebar.MenuItem>
    </Sidebar.Menu>
  </Sidebar.Footer>
</Sidebar.Root>

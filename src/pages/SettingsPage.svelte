<script lang="ts">
  import SettingsContent from "$lib/settings/SettingsContent.svelte";
</script>

<div class="settings-page">
  <SettingsContent />
</div>

<style>
  .settings-page {
    max-width: 960px;
    height: calc(var(--app-height) - 7rem);
    min-height: 280px;
    background: var(--card);
    border-radius: 16px;
    overflow: hidden;
  }
</style>

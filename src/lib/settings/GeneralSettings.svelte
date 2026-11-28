<script lang="ts">
  import { appearanceOptions, clampPageScale } from "$lib/appearance";
  import { ui } from "$lib/ui-state.svelte";
</script>

<section class="settings-form" data-testid="appearance-settings" aria-label="General settings">
  <fieldset>
    <legend>Appearance</legend>
    <div class="theme-options" role="group" aria-label="Theme">
      {#each appearanceOptions as option (option.value)}
        <button
          type="button"
          aria-pressed={ui.appearance === option.value}
          data-testid={`settings-theme-${option.value}`}
          onclick={() => (ui.appearance = option.value)}
        >
          {option.label}
        </button>
      {/each}
    </div>
  </fieldset>
  <label>
    Application zoom <span class="setting-value">{Math.round(ui.pageScale * 100)}%</span>
    <input
      type="range"
      min="0.5"
      max="1.5"
      step="0.1"
      value={ui.pageScale}
      aria-label="Page zoom"
      oninput={(event) => (ui.pageScale = clampPageScale(Number(event.currentTarget.value)))}
    />
    <span class="hint">Ctrl/Cmd + Shift + Plus / Minus to zoom, 0 to reset.</span>
  </label>
  <label>
    Reading font
    <select bind:value={ui.readingFont}>
      <option value="noto">Noto Sans KR</option><option value="inter">Inter</option>
    </select>
  </label>
  <label>
    Reader text size <span class="setting-value">{ui.readerTextSize}px</span><input
      aria-label="Reader text size"
      type="range"
      min="12"
      max="28"
      step="1"
      bind:value={ui.readerTextSize}
    />
  </label>
  <label>
    Reader line height <span class="setting-value">{ui.readerLineHeight}px</span><input
      aria-label="Reader line height"
      type="range"
      min="20"
      max="64"
      step="2"
      bind:value={ui.readerLineHeight}
    />
  </label>
  <label>
    Transcript line height <span class="setting-value">{ui.transcriptLineHeight}px</span><input
      aria-label="Transcript line height"
      type="range"
      min="18"
      max="48"
      step="2"
      bind:value={ui.transcriptLineHeight}
    />
  </label>
</section>

<style>
  .theme-options {
    display: flex;
    gap: 6px;
  }
  .theme-options button {
    flex: 1;
    border-radius: 8px;
    padding: 8px 12px;
    background: var(--neutral-hover);
    font-size: 13px;
  }
  .theme-options button[aria-pressed="true"] {
    background: var(--accent-soft);
    color: var(--dashboard-accent);
    font-weight: 600;
  }
</style>

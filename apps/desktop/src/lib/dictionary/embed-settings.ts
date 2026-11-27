import { writable } from 'svelte/store';
import { embeddedProviders, validCustomEmbed } from './embedded';

export type EmbedSettings = {
  enabled: string[];
  custom: { id: string; url: string }[];
};

export const embedSettings = writable<EmbedSettings>({
  enabled: ['naver-ko', 'papago'],
  custom: [],
});

export function loadEmbedSettings() {
  try {
    const saved = JSON.parse(localStorage.getItem('sori-embeds') ?? 'null');
    if (saved && Array.isArray(saved.enabled)) {
      const enabled = saved.enabled.map((provider: unknown) =>
        provider === 'naver' || provider === 'krdict' ? 'naver-ko' : provider,
      );
      const custom: { id: string; url: string }[] = [];
      for (const item of Array.isArray(saved.custom) ? saved.custom : []) {
        if (
          typeof item?.id === 'string' &&
          item.id.startsWith('custom-') &&
          typeof item.url === 'string' &&
          validCustomEmbed(item.url) &&
          !custom.some((entry) => entry.id === item.id)
        ) {
          custom.push({ id: item.id, url: item.url });
        }
      }
      if (typeof saved.customUrl === 'string' && validCustomEmbed(saved.customUrl)) {
        custom.push({ id: 'custom-legacy', url: saved.customUrl });
        if (enabled.includes('custom')) enabled.push('custom-legacy');
      }
      embedSettings.set({
        enabled: [...embeddedProviders.map((provider) => provider.value), ...custom.map((item) => item.id)].filter(
          (id) => enabled.includes(id),
        ),
        custom,
      });
    }
  } catch {
    // Retain defaults when stored preferences are unavailable.
  }
  return embedSettings.subscribe((settings) => {
    try {
      localStorage.setItem('sori-embeds', JSON.stringify(settings));
    } catch {
      // Storage may be unavailable.
    }
  });
}

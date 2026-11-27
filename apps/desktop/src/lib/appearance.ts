export type Appearance = 'system' | 'light' | 'dark';

const minScale = 0.5;
const maxScale = 1.5;

export const appearanceOptions: { value: Appearance; label: string }[] = [
  { value: 'system', label: 'System' },
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
];

export function loadAppearance(): Appearance {
  const saved = localStorage.getItem('sori-appearance');
  return saved === 'light' || saved === 'dark' || saved === 'system' ? saved : 'system';
}

export function loadPageScale(): number {
  const saved = Number(localStorage.getItem('sori-page-scale'));
  return Number.isFinite(saved) && saved >= minScale && saved <= maxScale ? saved : 1;
}

export function clampPageScale(value: number): number {
  return Math.max(minScale, Math.min(maxScale, value));
}

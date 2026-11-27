# Design

Sori is a calm, content-focused workspace for Korean immersion. Reading and
watching should feel comfortable for long sessions, with learning tools close
at hand. This guide defines shared principles; component code holds specific
layouts and measurements.

## Content first

- Give media and Korean text the strongest visual priority.
- Reveal analysis, definitions, and vocabulary tools in context.
- Keep frequent actions easy to reach and secondary controls unobtrusive.
- Use clear hierarchy and whitespace; avoid unnecessary decoration and nesting.

## Consistency

- Reuse `src/lib/components/` and the OKLCH tokens in `theme.css`.
- Tailwind 4, Lucide icons, and shadcn-svelte conventions come from the original
  Svelte app; keep the same spacing, typography, colors and control behavior.
- Use Inter for UI and Noto Sans KR for Korean reading text by default.
- Design light and dark themes together, with comfortable line height and contrast.

## Adaptability

- Support window resizing, application zoom, and independent reader typography
  without overlap or clipped controls.
- Reflow related controls together when space is tight.
- Let users adjust supporting panels while keeping the main content usable.
- Keep media zoom independent of the surrounding interface.

## Preserve context

- Retain selection, scroll position, progress, and user-adjusted layout where
  appropriate.
- Opening learning tools should preserve the user's playback state.
- Appending results must not move existing content or reset the user's position.
- Respect manual navigation; automatic scrolling should not fight the user.

## Feedback and control

- Show loading, errors, and empty states where the action occurs.
- Distinguish no content, no matches, and a failed operation.
- Give immediate feedback for actions, including clear drag and drop previews.
- Use subtle motion to explain changes without distracting from the content.
- Avoid confirmation dialogs for reversible actions.

## Accessibility

- Support keyboard navigation with visible focus and clear control labels.
- Provide hover, pressed, and disabled states without relying on color alone.
- Keep text legible and interactive targets comfortable to use.
- Check changed flows in both themes, at narrow widths, and with application zoom.

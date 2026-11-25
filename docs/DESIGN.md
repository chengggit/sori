# Design

Sori uses Qt Quick/QML for a clean, content-focused desktop interface suitable
for extended reading and watching sessions.

## Shared system

Use reusable components from `qml/components/` and semantic tokens from
`qml/style/Theme.qml`. Qt Quick Controls and Layouts provide the UI primitives.
Keep light and dark themes consistent. Use the shared spacing, typography,
radius, control-size, and color tokens rather than duplicating styles.

Inter is the UI font; Noto Sans KR is used for Korean reading content. Preserve
comfortable line height and readable subtitle contrast. Every interactive
control should provide visible hover, pressed, focus, and disabled feedback.

## Layout

The desktop sidebar supports expanded and collapsed states. Pages share a
centered frame capped at 1528px, with a 32px inset on narrower windows and 28px
vertical padding. Respect application zoom and reasonable desktop resizing.
Avoid unnecessary nested containers and prevent overflow at narrow sizes.

## Library and discovery

My Library groups text and videos into horizontal shelves. Use page-shaped
covers for text/PDFs and 16:9 thumbnails for videos, with consistent metadata
and progress. Home combines Continue Watching with subscribed-channel videos;
Explore supports YouTube search. Appending a page must preserve existing order,
visible delegates, and scroll position.

Use shared empty-state cards and explicit import actions. Distinguish an empty
library from a search with no matches and from a failed operation.

## Reader and Watch

Keep content primary. Show word analysis, dictionary tabs, and vocabulary tools
contextually in the shared sidebar. Preserve selection context and reading
position when panels resize the content. PDFs support book and scroll views,
with zoom controls that do not resize the surrounding interface.
PDF toolbar groups page navigation on the left and zoom/view controls on the right.
At narrow widths, the zoom/view group moves together onto a second row.
The reading area clips its content at the analysis sidebar boundary.
The analysis and vocabulary details sidebars resize by dragging their left edge,
from 320px up to 70% of the available width (and smaller when the window requires
it). Each panel retains its chosen width when closed and reopened during the session.

Watch uses familiar playback controls and interactive primary subtitles. In
fullscreen, a quick definition can hand off to the analysis sidebar while
preserving the video's paused/playing state. Timed transcripts follow playback;
manual scrolling pauses following until resumed or idle. Untimed TXT transcripts
scroll independently and remember their own position.

## Vocabulary and settings

Vocabulary cards show the word, linguistic information, selected meaning, and
source. Search, type filters, and sorting support browsing; a details sidebar
shows full saved context. Editing uses the shared vocabulary form. Settings
group appearance, dictionaries, channels, and connections into categories.
Embedded dictionary rows have a trailing six-dot grip; drag it vertically or
use its Up/Down keys to change the saved tab order, including disabled tabs.
During dragging, the row lifts with a shadow and follows the pointer above a
placeholder. Neighboring rows slide aside to preview the drop position;
releasing commits the new order.

Show loading, error, and empty states where the action occurs. Do not silently
replace failed operations with incomplete behavior. Avoid confirmation dialogs
for reversible actions. Keep transitions subtle, keyboard operation usable,
and changes focused on the requested feature.

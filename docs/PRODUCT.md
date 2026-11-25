# Product

Sori is a local-first desktop app for learning Korean through media.
Users choose their own content, read or watch it, explore Korean words, and save
vocabulary with its original context.

## Principles

- Prioritize immersion and independent learning.
- Core reading, watching, analysis, and vocabulary work offline without accounts or AI.
- Users own their content, library, and learning data.
- Reading and watching share one vocabulary collection.
- Online services are optional.

## Current scope

| Area       | Capabilities                                                                                     |
| ---------- | ------------------------------------------------------------------------------------------------ |
| Library    | Import, organize, inspect, resume, and remove supported local media                              |
| Reading    | Read TXT/PDF content, select Korean words, and retain reading progress                           |
| Watching   | Play local videos with interactive subtitles and retain playback progress                        |
| Analysis   | Analyze Korean words and morphemes locally with Kiwi                                             |
| Vocabulary | Save words and selected meanings, browse/edit entries, review source context, and remove entries |
| Storage    | Persist library, vocabulary, and progress locally                                                |

## Dictionaries

- Wiktionary provides online Korean-to-English definitions without an API key.
- KRDict is an alternative API provider requiring a key. Empty results fall back
  to Wiktionary; provider errors remain visible.
- Saved meanings and attribution remain available offline.
- Full entries open in the browser. Embedded tabs support Naver, KRDict, Papago,
  and custom lookup URLs, with a saved, user-controlled order.
- Embedded KRDict uses its mobile website without an API key.

Online definitions are separate from local morphological analysis.

## YouTube

- Play pasted embeddable links online without a developer API key.
- Search and channel discovery use a configured YouTube Data API key.
- Fetch existing captions through the optional transcript helper.

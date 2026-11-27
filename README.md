# Sori

Sori (소리) means **"sound"** in Korean. It's a free, open-source desktop app
for learning Korean by reading and watching videos. You can use your own
content, look up words, and save them with the context you found them in.

## Why “Sori”?

I got interested in Korean because I liked how it sounded and the words
flowed together. I originally called it
[Garak (가락)](https://korean.dict.naver.com/koendict/#/entry/koen/e5aa6c196d7a45aca1c1af56a93c36c6),
but Sori felt easier to say and sounded better to me.

## What you can do

- **Read** text files and PDFs, with book and scrolling views.
- **Watch** local videos with interactive subtitles, or play embeddable YouTube videos.
- **Explore words** through local Korean morphological analysis, definitions, and dictionaries.
- **Collect vocabulary** with meanings, notes, tags, and the context you found it in.
- **Pick up where you left off** with saved reading and playback progress.

Your library, vocabulary, and progress are stored locally. Core reading,
playback, and Korean analysis work offline without an account. Online
dictionary lookups and YouTube features need an internet connection.

## Getting started

See [DEVELOPING.md](DEVELOPING.md) to build and run from source. The app uses
Electron, Svelte and Rust; packages ship for Linux, Windows and macOS.

The [usage guide](docs/USAGE.md) covers reading, playback controls, and
dictionaries. [MIGRATION.md](MIGRATION.md) records the move from Qt to Electron.

## Contributing

Contributions are welcome. Start with
[CONTRIBUTING.md](CONTRIBUTING.md), and open an issue for larger changes.

## AI usage disclosure

This project was created with the assistance of AI. Codex was used to help with
coding, debugging, and documentation. I decide what goes into Sori and how it
should feel, and test and iterate on the app as I build it.

## Acknowledgements

- [Lute](https://github.com/LuteOrg/lute-v3), which inspired me to build Sori.
- [Kiwi](https://github.com/bab2min/Kiwi), the Korean morphological analyzer.
- [pdf.js](https://mozilla.github.io/pdf.js/), [Electron](https://www.electronjs.org/)
  and [Svelte](https://svelte.dev/).

Font and icon notices: [Inter](assets/OFL-Inter.txt),
[Noto Sans KR](assets/OFL-NotoSansKR.txt), and [Lucide](assets/LUCIDE-LICENSE.txt).

## License

Sori is licensed under [GPL-3.0](LICENSE).

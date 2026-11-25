# Sori

Sori (소리) means **“sound”** in Korean. It's a free, open-source desktop app
for learning Korean by reading and watching videos. You can use your own
content, look up words, and save them with the context you found them in.

## Why “Sori”?

I got interested in Korean because I liked how it sounded and how the words
flowed together. I wanted the name to have something to do with that.

I originally called it
[Garak (가락)](https://korean.dict.naver.com/koendict/#/entry/koen/e5aa6c196d7a45aca1c1af56a93c36c6),
which means “tune” or “melody.” I liked the meaning, but Sori felt easier to say
and sounded better to me, so I went with that instead.

## What you can do

- **Read** text files and PDFs, with book and scrolling views.
- **Watch** local videos with interactive subtitles, or play embeddable YouTube videos.
- **Explore words** through Korean morphological analysis, definitions, and embedded dictionaries.
- **Collect vocabulary** with meanings, notes, tags, and the context you found it in.
- **Pick up where you left off** with saved reading and playback progress.

Your library, vocabulary, and progress are stored locally. Core reading,
playback, and Korean analysis work offline without an account.
Online dictionary lookups and YouTube features need an internet connection.

## Getting started

See [DEVELOPING.md](DEVELOPING.md) to build and run Sori from source.
The [usage guide](docs/USAGE.md) covers reading, playback controls, and dictionaries.

## Contributing

Sori is a personal project, and contributions are welcome. A small fix, a clearer
explanation, or a bug report can all help make it better.

[CONTRIBUTING.md](CONTRIBUTING.md) is a good place to start. You're also welcome
to [open an issue](https://github.com/chengggit/sori/issues) to share an idea,
report a problem, or ask a question.

## AI usage disclosure

This project was created with the assistance of AI. Codex was used to help with coding, debugging, and documentation.
I decide what goes into Sori and how it should feel, and test and iterate on the
app as I build it.

## Acknowledgements

Huge thanks to these projects and the people behind them:

- [Lute](https://github.com/LuteOrg/lute-v3), which inspired me to build Sori.
- [Kiwi](https://github.com/bab2min/Kiwi), the Korean morphological analyzer
  behind Sori's local word analysis.
- [kiwi-rs](https://github.com/JAICHANGPARK/kiwi-rs), which makes Kiwi available
  from Rust.

Font and icon notices: [Inter](assets/OFL-Inter.txt),
[Noto Sans KR](assets/OFL-NotoSansKR.txt), and [Lucide](assets/LUCIDE-LICENSE.txt).

## License

Sori is licensed under [GPL-3.0](LICENSE).

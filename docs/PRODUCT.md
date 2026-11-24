Sori is a local-first Korean language immersion application that helps learners improve their language skills through authentic Korean content.

Users can watch videos, read books and articles, interact with Korean text, and mine vocabulary from the media they consume.

Sori prioritizes immersion and independent learning over structured lessons or gamification.

## 2. Core Principles

- **Immersion-first:** Learn Korean through meaningful, authentic content.
- **Content freedom:** Users choose and import their own learning materials.
- **Local-first:** Core functionality works offline without an account.
- **Unified experience:** Reading and watching share a consistent vocabulary-learning workflow.
- **User control:** Users own their library, vocabulary, and learning data.
- **Optional AI:** AI enhances the experience but is not required.

## 3. Core Experiences

### Reading

Users can import Korean reading materials, including books, news, and articles.

The reading experience should support:

- Displaying imported text in a comfortable reading interface.
- Selecting or interacting with Korean words.
- Korean morphological analysis using Kiwi.
- Saving vocabulary encountered while reading.
- Remembering reading progress.

### Watching

Users can import Korean videos and associated subtitles.

The watching experience should support:

- Video playback with synchronized Korean subtitles.
- Interactive subtitle text.
- Korean morphological analysis using Kiwi.
- Saving vocabulary encountered while watching.
- Remembering playback progress.

### Vocabulary

Reading and watching share a common vocabulary collection.

Users should be able to:

- Save words from either experience.
- Browse previously saved vocabulary.
- Review the original context in which a word appeared.
- Remove saved vocabulary.

Wiktionary is the default online Korean-to-English dictionary, with no API key setup.
The reader displays definitions in its analysis panel and can save one selected
meaning with the vocabulary entry for offline access. Full entries can open in the system browser. Reader also supports embedded
Naver, Papago, and custom dictionary tabs when Qt WebEngine Quick is available. KRDict is an optional online provider. Selected meanings remain available offline.
Downloadable dictionaries and advanced review systems are deferred.

## 4. Media Library

The library serves as the central place for users' imported content.

It should support:

- Importing supported local media.
- Organizing reading and watching materials.
- Resuming previously opened content.
- Viewing basic content metadata.
- Removing content from the library.

The interface should make it easy to continue learning without unnecessary navigation.

## 5. MVP Scope

The first release should deliver one complete learning workflow for both reading and watching.

### Required

- Desktop application using Qt Quick/QML with a Rust core.
- Local media library.
- Import and display Korean text-based content.
- Import and play local videos with subtitles.
- Korean tokenization using Kiwi.
- Interactive words in reading content and subtitles.
- Save and manage vocabulary.
- Persist library data, vocabulary, and progress locally.

### Deferred

- Downloadable offline dictionary packs.
- AI transcription and subtitle generation.
- Word-level subtitle alignment.
- YouTube downloading.
- Advanced spaced repetition.
- Cloud synchronization and accounts.
- Subscription and payment systems.
- Mobile applications.
- Additional learning languages.

## 6. MVP Success Criteria

A user can import Korean reading material or a subtitled video, open it, interact with Korean words, save vocabulary, and return later without losing their progress or saved words.

Both reading and watching must function without cloud services or AI processing for supported local media. Home can also play embeddable YouTube links online. Automatic YouTube discovery is optional and requires a configured developer API key.

## 7. Future Direction

Sori may eventually expand into a broader language immersion platform with additional media formats, AI-powered processing, vocabulary review, and optional cloud synchronization.

These possibilities should not complicate the initial MVP.

## 8. Product Philosophy

Sori is a tool for learning through content, not a platform that dictates what users should study.

**The content is the lesson. Sori provides the tools to understand it.**

-- Keep this schema at version 1 during pre-release development.
-- Fold changes into this file until released builds need incremental migrations.
CREATE TABLE IF NOT EXISTS documents (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS vocabulary (
    id INTEGER PRIMARY KEY,
    word TEXT NOT NULL CHECK (length(trim(word)) > 0),
    normalized_form TEXT CHECK (normalized_form IS NULL OR length(trim(normalized_form)) > 0),
    document_id INTEGER REFERENCES documents(id) ON DELETE SET NULL,
    source_title TEXT NOT NULL,
    context TEXT NOT NULL CHECK (length(trim(context)) > 0),
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    UNIQUE (document_id, word, context)
);

-- Retain saved words and context when the source document is removed.
CREATE INDEX IF NOT EXISTS vocabulary_document_id ON vocabulary(document_id);

CREATE TABLE IF NOT EXISTS vocabulary_meanings (
    vocabulary_id INTEGER PRIMARY KEY REFERENCES vocabulary(id) ON DELETE CASCADE,
    definition_json TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS vocabulary_tags (
    vocabulary_id INTEGER NOT NULL REFERENCES vocabulary(id) ON DELETE CASCADE,
    tag TEXT NOT NULL,
    PRIMARY KEY (vocabulary_id, tag)
);

CREATE TABLE IF NOT EXISTS reading_progress (
    document_id INTEGER PRIMARY KEY REFERENCES documents(id) ON DELETE CASCADE,
    position REAL NOT NULL CHECK (position >= 0 AND position <= 1),
    updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS videos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    seconds REAL NOT NULL DEFAULT 0,
    duration REAL NOT NULL DEFAULT 0,
    thumbnail TEXT,
    sidecar TEXT
);

CREATE TABLE IF NOT EXISTS local_watch_history (
    video_id INTEGER PRIMARY KEY REFERENCES videos(id) ON DELETE CASCADE,
    watched_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS video_vocabulary (
    vocabulary_id INTEGER PRIMARY KEY REFERENCES vocabulary(id) ON DELETE CASCADE,
    video_id INTEGER REFERENCES videos(id) ON DELETE CASCADE,
    youtube_id TEXT,
    CHECK ((video_id IS NULL) <> (youtube_id IS NULL))
);

CREATE INDEX IF NOT EXISTS video_vocabulary_video_id ON video_vocabulary(video_id);
CREATE INDEX IF NOT EXISTS video_vocabulary_youtube_id ON video_vocabulary(youtube_id);

PRAGMA user_version = 1;

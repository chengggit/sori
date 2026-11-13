CREATE TABLE vocabulary (
    id INTEGER PRIMARY KEY,
    word TEXT NOT NULL CHECK (length(trim(word)) > 0),
    normalized_form TEXT CHECK (normalized_form IS NULL OR length(trim(normalized_form)) > 0),
    document_id INTEGER REFERENCES documents(id) ON DELETE SET NULL,
    source_title TEXT NOT NULL,
    context TEXT NOT NULL CHECK (length(trim(context)) > 0),
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    UNIQUE (document_id, word, context)
);

-- Retain saved words and their context when the original document is removed.
-- New saves require an existing document. Only source deletion clears this link.
CREATE INDEX vocabulary_document_id ON vocabulary(document_id);

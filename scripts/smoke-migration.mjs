import { mkdtempSync, rmSync } from 'node:fs';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const require = createRequire(import.meta.url);
const addon = require(join(root, 'apps', 'desktop', 'native', 'sori-node.node'));

const directory = mkdtempSync(join(tmpdir(), 'sori-migration-'));
const databasePath = join(directory, 'library.sqlite3');
try {
  // A pre-release library: no pdf_path, duration or thumbnail columns, and
  // none of the newer tables. CREATE TABLE IF NOT EXISTS alone cannot add them.
  const old = new DatabaseSync(databasePath);
  // Mirrors src-tauri/src/schema.sql from the pre-Qt Sori release.
  old.exec(`
    CREATE TABLE documents (id INTEGER PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL);
    INSERT INTO documents VALUES (7, '한국어', '안녕하세요');
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
    CREATE INDEX vocabulary_document_id ON vocabulary(document_id);
    CREATE TABLE vocabulary_meanings (
      vocabulary_id INTEGER PRIMARY KEY REFERENCES vocabulary(id) ON DELETE CASCADE,
      definition_json TEXT NOT NULL
    );
    CREATE TABLE vocabulary_tags (
      vocabulary_id INTEGER NOT NULL REFERENCES vocabulary(id) ON DELETE CASCADE,
      tag TEXT NOT NULL,
      PRIMARY KEY (vocabulary_id, tag)
    );
    CREATE TABLE reading_progress (
      document_id INTEGER PRIMARY KEY REFERENCES documents(id) ON DELETE CASCADE,
      position REAL NOT NULL CHECK (position >= 0 AND position <= 1),
      updated_at INTEGER NOT NULL DEFAULT (unixepoch())
    );
    CREATE TABLE videos (
      id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT NOT NULL UNIQUE,
      title TEXT NOT NULL, seconds REAL NOT NULL DEFAULT 0, sidecar TEXT
    );
    INSERT INTO videos (path, title, seconds) VALUES ('/tmp/old.mkv', 'Old', 12.5);
    CREATE TABLE video_vocabulary (
      vocabulary_id INTEGER PRIMARY KEY REFERENCES vocabulary(id) ON DELETE CASCADE,
      video_id INTEGER REFERENCES videos(id) ON DELETE CASCADE,
      youtube_id TEXT,
      CHECK ((video_id IS NULL) <> (youtube_id IS NULL))
    );
    PRAGMA user_version = 1;
  `);
  old.close();

  addon.initLibrary(directory);
  const reply = JSON.parse(await addon.invoke('library:state', '{}'));
  if (!reply.ok || reply.data.documents.length !== 1) throw new Error('Old library did not open.');

  const upgraded = new DatabaseSync(databasePath);
  const columns = (table) =>
    upgraded.prepare(`PRAGMA table_info(${table})`).all().map((column) => column.name);
  for (const [table, column] of [
    ['documents', 'pdf_path'],
    ['videos', 'duration'],
    ['videos', 'thumbnail'],
  ]) {
    if (!columns(table).includes(column)) throw new Error(`${table}.${column} was not migrated.`);
  }
  for (const table of ['video_transcripts', 'youtube_transcripts', 'app_settings']) {
    const found = upgraded.prepare("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?").get(table);
    if (!found) throw new Error(`${table} was not created.`);
  }
  const title = upgraded.prepare('SELECT title FROM documents WHERE id=7').get().title;
  if (title !== '한국어') throw new Error('Existing data was lost.');
  upgraded.close();

  console.log('Migration smoke: OK');
} finally {
  rmSync(directory, { recursive: true, force: true });
}

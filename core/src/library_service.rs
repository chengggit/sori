use crate::{db::Database, documents, progress, video_library, vocabulary, youtube};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::path::{Path, PathBuf};

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DocumentView {
    pub content: String,
    pub pdf_path: Option<String>,
    pub position: f64,
}
#[derive(Serialize)]
pub struct ImportedVideo {
    pub id: i64,
}
#[derive(Serialize)]
pub struct SubtitleText {
    pub text: String,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct VocabularyDraft {
    word: String,
    normalized_form: Option<String>,
    context: String,
    definition: Option<crate::dictionary::Definition>,
    #[serde(default)]
    tags: Vec<String>,
}
impl VocabularyDraft {
    fn video(self, source: vocabulary::VideoSource) -> vocabulary::SaveVideoVocabulary {
        vocabulary::SaveVideoVocabulary {
            source,
            word: self.word,
            normalized_form: self.normalized_form,
            context: self.context,
            definition: self.definition,
            tags: self.tags,
        }
    }
    fn document(self, id: i64) -> vocabulary::SaveVocabulary {
        vocabulary::SaveVocabulary {
            document_id: id,
            word: self.word,
            normalized_form: self.normalized_form,
            context: self.context,
            definition: self.definition,
            tags: self.tags,
        }
    }
}

#[derive(Default)]
pub struct Changes {
    pub library: bool,
    pub videos: bool,
    pub history: bool,
    pub vocabulary: bool,
}

#[derive(Default)]
pub struct LibraryService {
    pub database: Option<Database>,
    pub documents: Vec<Value>,
    pub videos: Vec<Value>,
    pub vocabulary: Vec<Value>,
    pub youtube_history: Vec<Value>,
    pub error: String,
    pub changes: Changes,
}

impl LibraryService {
    pub fn initialize(&mut self, directory: String) -> Result<(), String> {
        if self.database.is_some() {
            return Ok(());
        }
        match Database::initialize(PathBuf::from(directory)) {
            Ok(database) => {
                self.database = Some(database);
                self.refresh()?;
                self.refresh_videos()?;
                self.refresh_youtube_history()?;
                self.refresh_vocabulary()?;
                Ok(())
            }
            Err(error) => {
                self.error = error.clone();
                self.changes.library = true;
                Err(error)
            }
        }
    }

    pub fn import_document(&mut self, path: String) -> Result<(), String> {
        let result = self
            .database
            .as_ref()
            .ok_or_else(|| "Could not open the library database.".to_string())
            .and_then(|database| crate::document_import::import_file(database, Path::new(&path)));
        match result {
            Ok(()) => {
                self.refresh()?;
                Ok(())
            }
            Err(error) => Err(error),
        }
    }

    pub fn add_document(&mut self, title: String, content: String) -> Result<(), String> {
        let title = title.trim();
        let title = if title.is_empty() {
            "Pasted text"
        } else {
            title
        };
        self.change(|connection| {
            documents::import(connection, &format!("{title}.txt"), content.as_bytes())
        })
    }

    pub fn update_document(
        &mut self,
        id: i64,
        title: String,
        content: String,
    ) -> Result<(), String> {
        self.change(|connection| documents::update(connection, id, &title, &content))
    }

    pub fn remove_document(&mut self, id: i64) -> Result<(), String> {
        let pdf_path = documents::read_pdf_path(&self.connection()?, id)?;
        let result = self.change(|connection| documents::remove(connection, id));
        if result.is_ok() {
            if let (Some(database), Some(path)) = (&self.database, pdf_path) {
                let path = Path::new(&path);
                if path.starts_with(database.pdf_directory()) {
                    let _ = std::fs::remove_file(path);
                }
            }
            self.refresh_vocabulary()?;
        }
        result
    }

    pub fn read_document(&self, id: i64) -> Result<DocumentView, String> {
        let connection = self.connection()?;
        Ok(DocumentView {
            content: documents::read(&connection, id)?,
            pdf_path: documents::read_pdf_path(&connection, id)?,
            position: progress::read(&connection, id)?,
        })
    }

    pub fn save_reading_progress(&self, id: i64, position: f64) -> Result<(), String> {
        self.connection()
            .and_then(|connection| progress::save(&connection, id, position))
    }

    pub fn import_video(&mut self, path: String) -> Result<ImportedVideo, String> {
        match self
            .connection()
            .and_then(|connection| video_library::import(&connection, Path::new(&path)))
        {
            Ok(id) => {
                self.refresh_videos()?;
                Ok(ImportedVideo { id })
            }
            Err(error) => Err(error),
        }
    }

    pub fn read_video(&self, id: i64) -> Result<video_library::SavedVideo, String> {
        self.connection()
            .and_then(|connection| video_library::read(&connection, id))
    }

    pub fn remove_video(&mut self, id: i64) -> Result<(), String> {
        let result = self.change_videos(|connection| video_library::remove(connection, id));
        if result.is_ok() {
            if let Some(database) = &self.database {
                let _ = std::fs::remove_file(video_library::thumbnail_path(
                    &database.thumbnail_directory(),
                    id,
                ));
            }
        }
        result
    }

    pub fn save_video_progress(
        &mut self,
        id: i64,
        seconds: f64,
        duration: f64,
    ) -> Result<(), String> {
        match self.connection().and_then(|connection| {
            video_library::save_progress(&connection, id, seconds, duration)?;
            video_library::summary(&connection, id)
        }) {
            Ok(summary) => {
                update_cached_entry(&mut self.videos, "id", json!(summary));
                self.changes.videos = true;
                Ok(())
            }
            Err(error) => Err(error),
        }
    }

    pub fn save_youtube_progress(
        &mut self,
        id: String,
        title: String,
        channel: String,
        seconds: f64,
        duration: f64,
    ) -> Result<(), String> {
        match self.connection().and_then(|connection| {
            youtube::save_watch_progress(&connection, &id, &title, &channel, seconds, duration)?;
            youtube::watch_entry(&connection, &id)
        }) {
            Ok(entry) => {
                update_cached_entry(&mut self.youtube_history, "youtubeId", entry);
                self.changes.history = true;
                Ok(())
            }
            Err(error) => Err(error),
        }
    }

    pub fn read_youtube_transcript(&self, id: String) -> Result<Value, String> {
        self.connection()
            .and_then(|db| crate::youtube_transcript::read(&db, &id))
    }

    pub fn cache_youtube_transcript(&self, id: String, data: Value) -> Result<(), String> {
        self.connection()
            .and_then(|db| crate::youtube_transcript::cache(&db, &id, data))
    }

    pub fn attach_youtube_transcript(&self, id: String, path: String) -> Result<Value, String> {
        self.connection()
            .and_then(|db| crate::youtube_transcript::attach(&db, &id, Path::new(&path)))
    }

    pub fn save_youtube_transcript_position(
        &self,
        id: String,
        position: f64,
    ) -> Result<(), String> {
        self.connection()
            .and_then(|db| crate::youtube_transcript::save_position(&db, &id, position))
    }

    pub fn remove_youtube_text_transcript(&self, id: String) -> Result<(), String> {
        self.connection()
            .and_then(|db| crate::youtube_transcript::remove_text(&db, &id))
    }

    pub fn find_youtube_word(
        &self,
        id: String,
        word: String,
        context: String,
    ) -> Result<Option<vocabulary::VocabularyEntry>, String> {
        vocabulary::find_video_entry(
            &self.connection()?,
            vocabulary::VideoSource::Youtube {
                id,
                title: String::new(),
            },
            &word,
            &context,
        )
    }

    pub fn save_youtube_word(
        &mut self,
        id: String,
        title: String,
        input: Value,
    ) -> Result<vocabulary::VocabularyEntry, String> {
        let draft: VocabularyDraft =
            serde_json::from_value(input).map_err(|error| error.to_string())?;
        let entry = vocabulary::save_video(
            &self.connection()?,
            draft.video(vocabulary::VideoSource::Youtube { id, title }),
        )?;
        self.refresh_vocabulary()?;
        Ok(entry)
    }

    pub fn read_video_transcript(&self, id: i64) -> Result<Value, String> {
        self.connection()
            .and_then(|connection| crate::video_transcript::read(&connection, id))
    }

    pub fn save_video_transcript(&self, id: i64, path: String) -> Result<Value, String> {
        self.connection().and_then(|connection| {
            crate::video_transcript::attach(&connection, id, Path::new(&path))
        })
    }

    pub fn save_transcript_position(&self, id: i64, position: f64) -> Result<(), String> {
        self.connection().and_then(|connection| {
            crate::video_transcript::save_position(&connection, id, position)
        })
    }

    pub fn remove_video_transcript(&self, id: i64) -> Result<(), String> {
        self.connection()
            .and_then(|connection| crate::video_transcript::remove(&connection, id))
    }

    pub fn save_video_subtitles(&self, id: i64, path: String) -> Result<SubtitleText, String> {
        self.connection()
            .and_then(|connection| video_library::save_sidecar(&connection, id, Path::new(&path)))
            .map(|text| SubtitleText { text })
    }

    pub fn save_word(
        &mut self,
        kind: String,
        id: i64,
        input: Value,
    ) -> Result<vocabulary::VocabularyEntry, String> {
        let draft: VocabularyDraft =
            serde_json::from_value(input).map_err(|error| error.to_string())?;
        let connection = self.connection()?;
        let entry = match kind.as_str() {
            "local" => vocabulary::save_video(
                &connection,
                draft.video(vocabulary::VideoSource::Local { id }),
            ),
            "document" => vocabulary::save(&connection, draft.document(id)),
            _ => Err("Unknown vocabulary source.".into()),
        }?;
        self.refresh_vocabulary()?;
        Ok(entry)
    }

    pub fn find_word(
        &self,
        kind: String,
        id: i64,
        word: String,
        context: String,
    ) -> Result<Option<vocabulary::VocabularyEntry>, String> {
        let connection = self.connection()?;
        match kind.as_str() {
            "local" => vocabulary::find_video_entry(
                &connection,
                vocabulary::VideoSource::Local { id },
                &word,
                &context,
            ),
            "document" => vocabulary::find_document_entry(&connection, id, &word, &context),
            _ => Err("Unknown vocabulary source.".into()),
        }
    }

    pub fn edit_word(&mut self, id: i64, input: Value) -> Result<(), String> {
        self.change_vocabulary(|connection| {
            let input = serde_json::from_value(input).map_err(|error| error.to_string())?;
            vocabulary::edit(connection, id, input).map(|_| ())
        })
    }

    pub fn remove_word(&mut self, id: i64) -> Result<(), String> {
        self.change_vocabulary(|connection| vocabulary::remove(connection, id))
    }

    pub fn connection(&self) -> Result<Connection, String> {
        self.database
            .as_ref()
            .ok_or_else(|| "Could not open the library database.".to_string())?
            .connect()
    }

    pub fn change(
        &mut self,
        operation: impl FnOnce(&Connection) -> Result<(), String>,
    ) -> Result<(), String> {
        match self
            .connection()
            .and_then(|connection| operation(&connection))
        {
            Ok(()) => {
                self.refresh()?;
                Ok(())
            }
            Err(error) => Err(error),
        }
    }

    pub fn refresh(&mut self) -> Result<(), String> {
        let items = self
            .connection()
            .and_then(|connection| documents::list(&connection))
            .inspect_err(|error| {
                self.error = error.clone();
                self.changes.library = true;
            })?;
        self.documents = items.into_iter().map(|item| json!(item)).collect();
        self.changes.library = true;
        Ok(())
    }

    pub fn change_videos(
        &mut self,
        operation: impl FnOnce(&Connection) -> Result<(), String>,
    ) -> Result<(), String> {
        match self
            .connection()
            .and_then(|connection| operation(&connection))
        {
            Ok(()) => {
                self.refresh_videos()?;
                Ok(())
            }
            Err(error) => Err(error),
        }
    }

    pub fn refresh_youtube_history(&mut self) -> Result<(), String> {
        let items = self
            .connection()
            .and_then(|connection| youtube::watch_history(&connection))
            .inspect_err(|error| {
                self.error = error.clone();
                self.changes.library = true;
            })?;
        self.youtube_history = items;
        self.changes.history = true;
        Ok(())
    }

    pub fn refresh_videos(&mut self) -> Result<(), String> {
        let items = self
            .connection()
            .and_then(|connection| video_library::list(&connection))
            .inspect_err(|error| {
                self.error = error.clone();
                self.changes.library = true;
            })?;
        self.videos = items.into_iter().map(|item| json!(item)).collect();
        self.changes.videos = true;
        Ok(())
    }

    pub fn change_vocabulary(
        &mut self,
        operation: impl FnOnce(&Connection) -> Result<(), String>,
    ) -> Result<(), String> {
        match self
            .connection()
            .and_then(|connection| operation(&connection))
        {
            Ok(()) => {
                self.refresh_vocabulary()?;
                Ok(())
            }
            Err(error) => Err(error),
        }
    }

    pub fn refresh_vocabulary(&mut self) -> Result<(), String> {
        let items = self
            .connection()
            .and_then(|connection| vocabulary::list(&connection))
            .inspect_err(|error| {
                self.error = error.clone();
                self.changes.library = true;
            })?;
        self.vocabulary = items.into_iter().map(|item| json!(item)).collect();
        self.changes.vocabulary = true;
        Ok(())
    }
}

fn update_cached_entry(entries: &mut Vec<Value>, key: &str, entry: Value) {
    if let Some(index) = entries.iter().position(|cached| cached[key] == entry[key]) {
        entries[index] = entry;
    } else {
        entries.insert(0, entry);
    }
    // Stable sorting preserves existing order for timestamps in the same second.
    entries.sort_by(|left, right| right["watchedAt"].as_i64().cmp(&left["watchedAt"].as_i64()));
}

#[cfg(test)]
mod tests {
    use super::*;
    struct Fixture {
        directory: PathBuf,
        service: LibraryService,
    }
    impl Fixture {
        fn new() -> Self {
            let directory = std::env::temp_dir().join(format!(
                "sori-service-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            let mut service = LibraryService::default();
            service
                .initialize(directory.to_string_lossy().into())
                .unwrap();
            Self { directory, service }
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.directory);
        }
    }

    #[test]
    fn local_workflow_and_errors_are_independent_of_qt() {
        let mut fixture = Fixture::new();
        let service = &mut fixture.service;
        service
            .add_document("Book".into(), "학교에 가요.".into())
            .unwrap();
        let id = service.documents[0]["id"].as_i64().unwrap();
        service.save_reading_progress(id, 0.5).unwrap();
        assert_eq!(service.read_document(id).unwrap().position, 0.5);
        let draft =
            json!({"word":"학교", "context":"학교에 가요.", "normalizedForm":null, "tags":[]});
        assert!(service
            .find_word("document".into(), id, "학교".into(), "학교에 가요.".into())
            .unwrap()
            .is_none());
        assert!(service.save_word("typo".into(), id, draft.clone()).is_err());
        assert!(service.vocabulary.is_empty());
        let entry = service.save_word("document".into(), id, draft).unwrap();
        assert_eq!(
            service
                .find_word("document".into(), id, "학교".into(), "학교에 가요.".into())
                .unwrap()
                .unwrap()
                .id,
            entry.id
        );
        service.remove_document(id).unwrap();
        assert!(service.read_document(id).is_err());
        assert_eq!(service.vocabulary[0]["word"], "학교");
        assert!(service.changes.library && service.changes.vocabulary);
    }

    #[test]
    fn refresh_failure_is_returned_and_keeps_previous_cache() {
        let mut fixture = Fixture::new();
        let service = &mut fixture.service;
        service.add_document("Book".into(), "학교".into()).unwrap();
        let expected = service.documents.clone();
        service
            .connection()
            .unwrap()
            .execute("ALTER TABLE documents RENAME COLUMN title TO old_title", [])
            .unwrap();
        assert!(service.refresh().is_err());
        assert!(!service.error.is_empty());
        assert_eq!(service.documents, expected);
        let directory = fixture.directory.clone();
        let mut reopened = LibraryService::default();
        assert!(reopened
            .initialize(directory.to_string_lossy().into())
            .is_err());
    }

    #[test]
    fn checkpoints_replace_only_the_changed_cached_entry() {
        let mut entries = vec![
            json!({"id": 1, "watchedAt": 5, "title": "First"}),
            json!({"id": 2, "watchedAt": 4, "title": "Second"}),
        ];
        update_cached_entry(
            &mut entries,
            "id",
            json!({"id": 2, "watchedAt": 6, "seconds": 10}),
        );
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0]["id"], 2);
        assert_eq!(entries[1]["title"], "First");
        update_cached_entry(
            &mut entries,
            "id",
            json!({"id": 2, "watchedAt": 6, "seconds": 11}),
        );
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0]["seconds"], 11);
    }
}

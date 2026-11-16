use crate::{db::Database, documents, progress, video_library, vocabulary};
use qtbridge::{qobject, QmlObject};
use rusqlite::Connection;
use serde_json::{json, Value};
use std::collections::{HashMap, HashSet};
use std::io::Read;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

const THUMBNAIL_RETRY_DELAY: Duration = Duration::from_secs(60);

#[derive(Default)]
pub struct Library {
    database: Option<Database>,
    documents: Vec<Value>,
    videos: Vec<Value>,
    vocabulary: Vec<Value>,
    pending_thumbnails: HashSet<i64>,
    last_thumbnail_attempt: HashMap<i64, Instant>,
    error: String,
}

#[qobject(Singleton, ConvertToCamelCase)]
impl Library {
    qproperty!("documents", Member = documents, Notify = library_changed);
    qproperty!("videos", Member = videos, Notify = videos_changed);
    qproperty!(
        "recentVideos",
        Read = recent_videos,
        Notify = videos_changed
    );
    qproperty!("error", Member = error, Notify = library_changed);
    qproperty!(
        "vocabulary",
        Member = vocabulary,
        Notify = vocabulary_changed
    );

    #[qsignal]
    fn library_changed(&mut self);

    #[qsignal]
    fn videos_changed(&mut self);

    #[qsignal]
    fn vocabulary_changed(&mut self);

    fn recent_videos(&self) -> Vec<Value> {
        self.videos
            .iter()
            .filter(|video| {
                !video["watchedAt"].is_null() || video["seconds"].as_f64().unwrap_or_default() > 0.0
            })
            .cloned()
            .collect()
    }

    #[qslot]
    fn initialize(&mut self, directory: String) {
        if self.database.is_some() {
            return;
        }
        match Database::initialize(PathBuf::from(directory)) {
            Ok(database) => {
                self.database = Some(database);
                self.refresh();
                self.refresh_videos();
                self.refresh_vocabulary();
            }
            Err(error) => {
                self.error = error;
                self.library_changed();
            }
        }
    }

    #[qslot]
    fn import_document(&mut self, path: String) -> String {
        self.change(|connection| {
            let path = Path::new(&path);
            let filename = path
                .file_name()
                .and_then(|name| name.to_str())
                .ok_or("Choose a .txt file.")?;
            let file = std::fs::File::open(path).map_err(|error| error.to_string())?;
            let mut bytes = Vec::new();
            file.take(documents::MAX_TEXT_BYTES as u64 + 1)
                .read_to_end(&mut bytes)
                .map_err(|error| error.to_string())?;
            documents::import(connection, filename, &bytes)
        })
    }

    #[qslot]
    fn add_document(&mut self, title: String, content: String) -> String {
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

    #[qslot]
    fn update_document(&mut self, id: i64, title: String, content: String) -> String {
        self.change(|connection| documents::update(connection, id, &title, &content))
    }

    #[qslot]
    fn remove_document(&mut self, id: i64) -> String {
        let error = self.change(|connection| documents::remove(connection, id));
        if error.is_empty() {
            self.refresh_vocabulary();
        }
        error
    }

    #[qslot]
    fn read_document(&self, id: i64) -> Value {
        let read = || -> Result<Value, String> {
            let connection = self.connection()?;
            Ok(json!({
                "content": documents::read(&connection, id)?,
                "position": progress::read(&connection, id)?,
            }))
        };
        read().unwrap_or_else(|error| json!({ "error": error }))
    }

    #[qslot]
    fn save_reading_progress(&self, id: i64, position: f64) -> String {
        self.connection()
            .and_then(|connection| progress::save(&connection, id, position))
            .err()
            .unwrap_or_default()
    }

    #[qslot]
    fn import_video(&mut self, path: String) -> Value {
        match self
            .connection()
            .and_then(|connection| video_library::import(&connection, Path::new(&path)))
        {
            Ok(id) => {
                self.refresh_videos();
                json!({ "id": id })
            }
            Err(error) => json!({ "error": error }),
        }
    }

    #[qslot]
    fn read_video(&self, id: i64) -> Value {
        self.connection()
            .and_then(|connection| video_library::read(&connection, id))
            .map(|video| json!(video))
            .unwrap_or_else(|error| json!({ "error": error }))
    }

    #[qslot]
    fn remove_video(&mut self, id: i64) -> String {
        let error = self.change_videos(|connection| video_library::remove(connection, id));
        if error.is_empty() {
            self.last_thumbnail_attempt.remove(&id);
            if let Some(database) = &self.database {
                let _ = std::fs::remove_file(video_library::thumbnail_path(
                    &database.thumbnail_directory(),
                    id,
                ));
            }
        }
        error
    }

    #[qslot]
    fn save_video_progress(&mut self, id: i64, seconds: f64, duration: f64) -> String {
        let error = self.change_videos(|connection| {
            video_library::save_progress(connection, id, seconds, duration)
        });
        if error.is_empty() {
            self.ensure_video_thumbnail(id);
        }
        error
    }

    #[qslot]
    fn ensure_video_thumbnail(&mut self, id: i64) {
        if self.pending_thumbnails.contains(&id)
            || self
                .last_thumbnail_attempt
                .get(&id)
                .is_some_and(|attempt| attempt.elapsed() < THUMBNAIL_RETRY_DELAY)
        {
            return;
        }
        let Some(database) = self.database.clone() else {
            return;
        };
        let Ok(metadata) = database
            .connect()
            .and_then(|connection| video_library::metadata(&connection, id))
        else {
            return;
        };
        let has_thumbnail = metadata
            .thumbnail
            .as_deref()
            .map(Path::new)
            .is_some_and(video_library::has_thumbnail);
        if metadata.duration > 0.0 && has_thumbnail {
            return;
        }

        self.pending_thumbnails.insert(id);
        let output = video_library::thumbnail_path(&database.thumbnail_directory(), id);
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let probed_duration = if metadata.duration <= 0.0 {
                video_library::probe_duration(&metadata.path).unwrap_or(0.0)
            } else {
                0.0
            };
            let thumbnail = if has_thumbnail {
                None
            } else {
                video_library::prepare_thumbnail(
                    &metadata.path,
                    &output,
                    metadata.duration.max(probed_duration),
                )
                .ok()
                .map(|()| output.as_path())
            };
            let result = if probed_duration > 0.0 || thumbnail.is_some() {
                database.connect().and_then(|connection| {
                    video_library::update_metadata(&connection, id, probed_duration, thumbnail)
                })
            } else {
                Ok(false)
            };
            if matches!(result, Ok(false)) && thumbnail.is_some() {
                // The entry was removed while the worker was decoding the frame.
                let _ = std::fs::remove_file(&output);
            }
            let _ = handle.invoke_mut(move |model| {
                model.pending_thumbnails.remove(&id);
                if model
                    .videos
                    .iter()
                    .any(|video| video["id"].as_i64() == Some(id))
                {
                    model.last_thumbnail_attempt.insert(id, Instant::now());
                }
                if matches!(result, Ok(true)) {
                    model.refresh_videos();
                }
            });
        });
    }

    #[qslot]
    fn save_video_subtitles(&self, id: i64, path: String) -> Value {
        self.connection()
            .and_then(|connection| video_library::save_sidecar(&connection, id, Path::new(&path)))
            .map(|text| json!({ "text": text }))
            .unwrap_or_else(|error| json!({ "error": error }))
    }

    #[qslot]
    fn save_word(&mut self, kind: String, id: i64, mut input: Value) -> Value {
        let result = self.connection().and_then(|connection| {
            let fields = input.as_object_mut().ok_or("Invalid vocabulary entry.")?;
            if kind == "local" {
                fields.insert("source".into(), json!({"kind": "local", "id": id}));
                let input = serde_json::from_value(input).map_err(|error| error.to_string())?;
                vocabulary::save_video(&connection, input)
            } else {
                fields.insert("documentId".into(), json!(id));
                let input = serde_json::from_value(input).map_err(|error| error.to_string())?;
                vocabulary::save(&connection, input)
            }
        });
        match result {
            Ok(entry) => {
                self.refresh_vocabulary();
                json!(entry)
            }
            Err(error) => json!({ "error": error }),
        }
    }

    #[qslot]
    fn find_word(&self, kind: String, id: i64, word: String, context: String) -> Value {
        if kind == "local" {
            return self
                .connection()
                .and_then(|connection| {
                    vocabulary::find_video_entry(
                        &connection,
                        vocabulary::VideoSource::Local { id },
                        &word,
                        &context,
                    )
                })
                .map(|entry| json!(entry))
                .unwrap_or_default();
        }
        self.vocabulary
            .iter()
            .find(|entry| {
                entry["documentId"].as_i64() == Some(id)
                    && entry["word"] == word.trim()
                    && entry["context"] == context.trim()
            })
            .cloned()
            .unwrap_or_default()
    }

    #[qslot]
    fn edit_word(&mut self, id: i64, input: Value) -> String {
        self.change_vocabulary(|connection| {
            let input = serde_json::from_value(input).map_err(|error| error.to_string())?;
            vocabulary::edit(connection, id, input).map(|_| ())
        })
    }

    #[qslot]
    fn remove_word(&mut self, id: i64) -> String {
        self.change_vocabulary(|connection| vocabulary::remove(connection, id))
    }
}

impl Library {
    fn connection(&self) -> Result<Connection, String> {
        self.database
            .as_ref()
            .ok_or_else(|| "Could not open the library database.".to_string())?
            .connect()
    }

    fn change(&mut self, operation: impl FnOnce(&Connection) -> Result<(), String>) -> String {
        match self
            .connection()
            .and_then(|connection| operation(&connection))
        {
            Ok(()) => {
                self.refresh();
                String::new()
            }
            Err(error) => error,
        }
    }

    fn refresh(&mut self) {
        match self
            .connection()
            .and_then(|connection| documents::list(&connection))
        {
            Ok(items) => {
                self.documents = items.into_iter().map(|item| json!(item)).collect();
                self.error.clear();
            }
            Err(error) => self.error = error,
        }
        self.library_changed();
    }

    fn change_videos(
        &mut self,
        operation: impl FnOnce(&Connection) -> Result<(), String>,
    ) -> String {
        match self
            .connection()
            .and_then(|connection| operation(&connection))
        {
            Ok(()) => {
                self.refresh_videos();
                String::new()
            }
            Err(error) => error,
        }
    }

    fn refresh_videos(&mut self) {
        match self
            .connection()
            .and_then(|connection| video_library::list(&connection))
        {
            Ok(items) => {
                self.videos = items.into_iter().map(|item| json!(item)).collect();
                self.videos_changed();
            }
            Err(error) => {
                self.error = error;
                self.library_changed();
            }
        }
    }

    fn change_vocabulary(
        &mut self,
        operation: impl FnOnce(&Connection) -> Result<(), String>,
    ) -> String {
        match self
            .connection()
            .and_then(|connection| operation(&connection))
        {
            Ok(()) => {
                self.refresh_vocabulary();
                String::new()
            }
            Err(error) => error,
        }
    }

    fn refresh_vocabulary(&mut self) {
        match self
            .connection()
            .and_then(|connection| vocabulary::list(&connection))
        {
            Ok(items) => {
                self.vocabulary = items.into_iter().map(|item| json!(item)).collect();
                self.vocabulary_changed();
            }
            Err(error) => {
                self.error = error;
                self.library_changed();
            }
        }
    }
}

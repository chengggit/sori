use crate::{db::Database, documents, progress, video_library};
use qtbridge::qobject;
use rusqlite::Connection;
use serde_json::{json, Value};
use std::io::Read;
use std::path::{Path, PathBuf};

#[derive(Default)]
pub struct Library {
    database: Option<Database>,
    documents: Vec<Value>,
    videos: Vec<Value>,
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

    #[qsignal]
    fn library_changed(&mut self);

    #[qsignal]
    fn videos_changed(&mut self);

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
        self.change(|connection| documents::remove(connection, id))
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
        self.change_videos(|connection| video_library::remove(connection, id))
    }

    #[qslot]
    fn save_video_progress(&mut self, id: i64, seconds: f64) -> String {
        self.change_videos(|connection| video_library::save_progress(connection, id, seconds))
    }

    #[qslot]
    fn save_video_subtitles(&self, id: i64, path: String) -> Value {
        self.connection()
            .and_then(|connection| video_library::save_sidecar(&connection, id, Path::new(&path)))
            .map(|text| json!({ "text": text }))
            .unwrap_or_else(|error| json!({ "error": error }))
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
}

use crate::{db::Database, documents, progress};
use qtbridge::qobject;
use rusqlite::Connection;
use serde_json::{json, Value};
use std::io::Read;
use std::path::{Path, PathBuf};

#[derive(Default)]
pub struct Library {
    database: Option<Database>,
    documents: Vec<Value>,
    error: String,
}

#[qobject(Singleton, ConvertToCamelCase)]
impl Library {
    qproperty!("documents", Member = documents, Notify = library_changed);
    qproperty!("error", Member = error, Notify = library_changed);

    #[qsignal]
    fn library_changed(&mut self);

    #[qslot]
    fn initialize(&mut self, directory: String) {
        if self.database.is_some() {
            return;
        }
        match Database::initialize(PathBuf::from(directory)) {
            Ok(database) => {
                self.database = Some(database);
                self.refresh();
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
}

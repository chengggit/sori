use rusqlite::Connection;
use std::{path::PathBuf, time::Duration};

/// Each operation owns a connection; shared application state contains only its path.
#[derive(Clone)]
pub struct Database {
    path: PathBuf,
}

impl Database {
    pub async fn run<T: Send + 'static>(
        &self,
        operation: impl FnOnce(&Connection) -> Result<T, String> + Send + 'static,
    ) -> Result<T, String> {
        let database = self.clone();
        tauri::async_runtime::spawn_blocking(move || operation(&database.connect()?))
            .await
            .map_err(|error| format!("Database operation failed: {error}"))?
    }

    pub fn initialize(directory: PathBuf) -> Result<Self, String> {
        std::fs::create_dir_all(&directory).map_err(|error| error.to_string())?;
        // Preserve the location used by the original text library.
        let database = Self {
            path: directory.join("library.sqlite3"),
        };
        initialize_schema(&mut database.connect()?)?;
        Ok(database)
    }

    pub fn connect(&self) -> Result<Connection, String> {
        let connection = Connection::open(&self.path).map_err(|error| error.to_string())?;
        connection
            .busy_timeout(Duration::from_secs(5))
            .map_err(|error| error.to_string())?;
        connection
            .pragma_update(None, "foreign_keys", true)
            .map_err(|error| error.to_string())?;
        Ok(connection)
    }
}

fn initialize_schema(connection: &mut Connection) -> Result<(), String> {
    let transaction = connection
        .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
        .map_err(|error| error.to_string())?;
    transaction
        .execute_batch(include_str!("schema.sql"))
        .map_err(|error| error.to_string())?;
    transaction.commit().map_err(|error| error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn initializes_existing_document_library() {
        let mut connection = Connection::open_in_memory().unwrap();
        connection.execute_batch(
            "CREATE TABLE documents (id INTEGER PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL);
             INSERT INTO documents VALUES (7, '한국어', '안녕하세요');",
        ).unwrap();
        initialize_schema(&mut connection).unwrap();
        initialize_schema(&mut connection).unwrap();
        let document: (i64, String, String) = connection
            .query_row("SELECT id, title, content FROM documents", [], |row| {
                Ok((row.get(0)?, row.get(1)?, row.get(2)?))
            })
            .unwrap();
        assert_eq!(document, (7, "한국어".into(), "안녕하세요".into()));
        let version: i64 = connection
            .pragma_query_value(None, "user_version", |row| row.get(0))
            .unwrap();
        assert_eq!(version, 1);
    }

    #[test]
    fn keeps_development_databases_at_version_one() {
        for previous_version in [0, 1, 2, 3] {
            let mut connection = Connection::open_in_memory().unwrap();
            connection
                .execute_batch(include_str!("schema.sql"))
                .unwrap();
            connection
                .pragma_update(None, "user_version", previous_version)
                .unwrap();
            crate::documents::import(&connection, "책.txt", "학교에 갔어요.".as_bytes()).unwrap();
            let document = &crate::documents::list(&connection).unwrap()[0];
            let saved = crate::vocabulary::save(
                &connection,
                crate::vocabulary::SaveVocabulary {
                    word: "학교".into(),
                    normalized_form: None,
                    document_id: document.id,
                    context: "학교에 갔어요.".into(),
                },
            )
            .unwrap();
            crate::progress::save(&connection, document.id, 0.75).unwrap();
            initialize_schema(&mut connection).unwrap();
            initialize_schema(&mut connection).unwrap();
            let version: i64 = connection
                .pragma_query_value(None, "user_version", |row| row.get(0))
                .unwrap();
            assert_eq!(version, 1);
            assert_eq!(
                crate::vocabulary::list(&connection).unwrap()[0].id,
                saved.id
            );
            assert_eq!(
                crate::progress::read(&connection, document.id).unwrap(),
                0.75
            );
            assert_eq!(saved.source_title, "책");
            assert_eq!(
                crate::documents::read(&connection, document.id).unwrap(),
                "학교에 갔어요."
            );
        }
    }

    #[test]
    fn failed_initialization_rolls_back_schema_and_version() {
        let mut connection = Connection::open_in_memory().unwrap();
        connection
            .execute("CREATE TABLE vocabulary (id INTEGER PRIMARY KEY)", [])
            .unwrap();
        assert!(initialize_schema(&mut connection).is_err());
        let version: i64 = connection
            .pragma_query_value(None, "user_version", |row| row.get(0))
            .unwrap();
        assert_eq!(version, 0);
        assert!(!connection.table_exists(None, "documents").unwrap());
    }

    #[test]
    fn documents_survive_database_reinitialization() {
        let directory = std::env::temp_dir().join(format!(
            "sori-db-test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let database = Database::initialize(directory.clone()).unwrap();
        {
            let connection = database.connect().unwrap();
            crate::documents::import(&connection, "한국어.txt", "안녕하세요".as_bytes()).unwrap();
            let document_id = crate::documents::list(&connection).unwrap()[0].id;
            crate::progress::save(&connection, document_id, 0.6).unwrap();
            crate::vocabulary::save(
                &connection,
                crate::vocabulary::SaveVocabulary {
                    word: "안녕하세요".into(),
                    normalized_form: None,
                    document_id,
                    context: "안녕하세요".into(),
                },
            )
            .unwrap();
            let foreign_keys: bool = connection
                .pragma_query_value(None, "foreign_keys", |row| row.get(0))
                .unwrap();
            assert!(foreign_keys);
        }
        let reopened = Database::initialize(directory.clone()).unwrap();
        let connection = reopened.connect().unwrap();
        let items = crate::documents::list(&connection).unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(
            crate::progress::read(&connection, items[0].id).unwrap(),
            0.6
        );
        assert_eq!(
            crate::documents::read(&connection, items[0].id).unwrap(),
            "안녕하세요"
        );
        let vocabulary = crate::vocabulary::list(&connection).unwrap();
        assert_eq!(vocabulary.len(), 1);
        assert_eq!(vocabulary[0].word, "안녕하세요");
        assert_eq!(vocabulary[0].document_id, Some(items[0].id));
        crate::vocabulary::remove(&connection, vocabulary[0].id).unwrap();
        drop(connection);
        let connection = Database::initialize(directory.clone())
            .unwrap()
            .connect()
            .unwrap();
        assert!(crate::vocabulary::list(&connection).unwrap().is_empty());
        drop(connection);
        std::fs::remove_dir_all(directory).unwrap();
    }
}

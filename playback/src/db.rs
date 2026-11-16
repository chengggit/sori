use rusqlite::Connection;
use std::{path::PathBuf, time::Duration};

/// Each operation owns a connection; shared application state contains only its path.
#[derive(Clone)]
pub struct Database {
    path: PathBuf,
}

impl Database {
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
        drop(connection);
        std::fs::remove_dir_all(directory).unwrap();
    }
}

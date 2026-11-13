use rusqlite::{Connection, params};
use serde::Serialize;
use tauri::{AppHandle, Manager};

const MAX_TEXT_BYTES: usize = 2 * 1024 * 1024;

#[derive(Serialize)]
pub struct LibraryItem {
    id: i64,
    title: String,
}

fn database(app: &AppHandle) -> Result<Connection, String> {
    let directory = app
        .path()
        .app_data_dir()
        .map_err(|error| error.to_string())?;
    std::fs::create_dir_all(&directory).map_err(|error| error.to_string())?;
    let database =
        Connection::open(directory.join("library.sqlite3")).map_err(|error| error.to_string())?;
    database
        .execute_batch(
            "CREATE TABLE IF NOT EXISTS documents (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT NOT NULL
        );",
        )
        .map_err(|error| error.to_string())?;
    Ok(database)
}

#[tauri::command]
pub async fn list_documents(app: AppHandle) -> Result<Vec<LibraryItem>, String> {
    let database = database(&app)?;
    let mut statement = database
        .prepare("SELECT id, title FROM documents ORDER BY id DESC")
        .map_err(|error| error.to_string())?;
    statement
        .query_map([], |row| {
            Ok(LibraryItem {
                id: row.get(0)?,
                title: row.get(1)?,
            })
        })
        .map_err(|error| error.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn import_document(
    app: AppHandle,
    filename: String,
    bytes: Vec<u8>,
) -> Result<(), String> {
    let (title, extension) = filename.rsplit_once('.').ok_or("Choose a .txt file.")?;
    if title.trim().is_empty() || !extension.eq_ignore_ascii_case("txt") {
        return Err("Choose a .txt file.".into());
    }
    if bytes.len() > MAX_TEXT_BYTES {
        return Err("Choose a text file no larger than 2 MiB.".into());
    }

    let content = std::str::from_utf8(&bytes).map_err(|_| "Choose a UTF-8 text file.")?;
    let content = content.strip_prefix('\u{feff}').unwrap_or(content);
    if content.trim().is_empty() {
        return Err("This text file is empty.".into());
    }

    database(&app)?
        .execute(
            "INSERT INTO documents (title, content)
         SELECT ?1, ?2 WHERE NOT EXISTS (
             SELECT 1 FROM documents WHERE title = ?1 AND content = ?2
         )",
            params![title, content],
        )
        .map_err(|error| error.to_string())?;
    Ok(())
}

#[tauri::command]
pub async fn read_document(app: AppHandle, id: i64) -> Result<String, String> {
    database(&app)?
        .query_row("SELECT content FROM documents WHERE id = ?1", [id], |row| {
            row.get(0)
        })
        .map_err(|error| error.to_string())
}

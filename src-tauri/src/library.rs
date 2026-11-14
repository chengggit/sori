use crate::{
    db::Database,
    documents::{self, LibraryItem},
    progress,
};
use tauri::State;

#[tauri::command]
pub async fn update_document(
    database: State<'_, Database>,
    id: i64,
    title: String,
    content: String,
) -> Result<(), String> {
    database
        .run(move |connection| documents::update(connection, id, &title, &content))
        .await
}

#[tauri::command]
pub async fn delete_document(database: State<'_, Database>, id: i64) -> Result<(), String> {
    database
        .run(move |connection| documents::remove(connection, id))
        .await
}

#[tauri::command]
pub async fn list_documents(database: State<'_, Database>) -> Result<Vec<LibraryItem>, String> {
    database.run(documents::list).await
}

#[tauri::command]
pub async fn read_reading_progress(database: State<'_, Database>, id: i64) -> Result<f64, String> {
    database
        .run(move |connection| progress::read(connection, id))
        .await
}

#[tauri::command]
pub async fn save_reading_progress(
    database: State<'_, Database>,
    id: i64,
    position: f64,
) -> Result<(), String> {
    database
        .run(move |connection| progress::save(connection, id, position))
        .await
}

#[tauri::command]
pub async fn import_document(
    database: State<'_, Database>,
    filename: String,
    bytes: Vec<u8>,
) -> Result<(), String> {
    database
        .run(move |connection| documents::import(connection, &filename, &bytes))
        .await
}

#[tauri::command]
pub async fn read_document(database: State<'_, Database>, id: i64) -> Result<String, String> {
    database
        .run(move |connection| documents::read(connection, id))
        .await
}

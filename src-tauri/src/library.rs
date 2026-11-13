use crate::{
    db::Database,
    documents::{self, LibraryItem},
};
use tauri::State;

#[tauri::command]
pub async fn list_documents(database: State<'_, Database>) -> Result<Vec<LibraryItem>, String> {
    database.run(documents::list).await
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

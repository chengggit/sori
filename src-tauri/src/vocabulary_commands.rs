use crate::{
    db::Database,
    vocabulary::{
        self, EditVocabulary, SaveVideoVocabulary, SaveVocabulary, VideoSource, VocabularyEntry,
    },
};
use tauri::State;

#[tauri::command]
pub async fn find_video_vocabulary(
    database: State<'_, Database>,
    source: VideoSource,
    word: String,
    context: String,
) -> Result<Option<VocabularyEntry>, String> {
    database
        .run(move |connection| vocabulary::find_video_entry(connection, source, &word, &context))
        .await
}

#[tauri::command]
pub async fn save_video_vocabulary(
    database: State<'_, Database>,
    input: SaveVideoVocabulary,
) -> Result<VocabularyEntry, String> {
    database
        .run(move |connection| vocabulary::save_video(connection, input))
        .await
}

#[tauri::command]
pub async fn save_vocabulary(
    database: State<'_, Database>,
    input: SaveVocabulary,
) -> Result<VocabularyEntry, String> {
    database
        .run(move |connection| vocabulary::save(connection, input))
        .await
}

#[tauri::command]
pub async fn list_vocabulary(
    database: State<'_, Database>,
) -> Result<Vec<VocabularyEntry>, String> {
    database.run(vocabulary::list).await
}

#[tauri::command]
pub async fn remove_vocabulary(database: State<'_, Database>, id: i64) -> Result<(), String> {
    database
        .run(move |connection| vocabulary::remove(connection, id))
        .await
}

#[tauri::command]
pub async fn edit_vocabulary(
    database: State<'_, Database>,
    id: i64,
    input: EditVocabulary,
) -> Result<VocabularyEntry, String> {
    database
        .run(move |connection| vocabulary::edit(connection, id, input))
        .await
}

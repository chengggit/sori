use crate::nlp::{KoreanAnalyzer, KoreanToken};
use tauri::State;

#[tauri::command]
pub async fn analyze_document_word(
    database: State<'_, crate::db::Database>,
    analyzer: State<'_, KoreanAnalyzer>,
    id: i64,
    start: usize,
    end: usize,
) -> Result<crate::reader::WordAnalysis, String> {
    let database = database.inner().clone();
    let analyzer = analyzer.inner().clone();
    tauri::async_runtime::spawn_blocking(move || {
        let text = crate::documents::read(&database.connect()?, id)?;
        crate::reader::analyze(&analyzer, &text, start, end)
    })
    .await
    .map_err(|error| format!("Word analysis failed: {error}"))?
}

#[tauri::command]
pub async fn tokenize_text(
    analyzer: State<'_, KoreanAnalyzer>,
    text: String,
) -> Result<Vec<KoreanToken>, String> {
    let analyzer = analyzer.inner().clone();
    tauri::async_runtime::spawn_blocking(move || analyzer.analyze(text))
        .await
        .map_err(|error| format!("Korean analysis failed: {error}"))?
}

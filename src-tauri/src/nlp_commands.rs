use crate::nlp::{KoreanAnalyzer, KoreanToken};
use tauri::State;

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

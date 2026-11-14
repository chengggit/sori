mod db;
mod dictionary;
mod documents;
mod library;
mod nlp;
mod nlp_commands;
mod progress;
mod reader;
mod vocabulary;
mod vocabulary_commands;

use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            let database = db::Database::initialize(app.path().app_data_dir()?)
                .map_err(std::io::Error::other)?;
            app.manage(database);
            app.manage(dictionary::Dictionary::new()?);
            let resources = app
                .path()
                .resolve("resources/kiwi", tauri::path::BaseDirectory::Resource)?;
            app.manage(nlp::KoreanAnalyzer::start(resources).map_err(std::io::Error::other)?);
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            library::list_documents,
            library::update_document,
            library::delete_document,
            library::import_document,
            library::read_document,
            library::read_reading_progress,
            library::save_reading_progress,
            nlp_commands::tokenize_text,
            nlp_commands::analyze_document_word,
            dictionary::lookup_dictionary,
            vocabulary_commands::save_vocabulary,
            vocabulary_commands::list_vocabulary,
            vocabulary_commands::remove_vocabulary
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

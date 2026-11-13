mod db;
mod documents;
mod library;
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
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            library::list_documents,
            library::import_document,
            library::read_document,
            vocabulary_commands::save_vocabulary,
            vocabulary_commands::list_vocabulary,
            vocabulary_commands::remove_vocabulary
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

mod library;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            library::list_documents,
            library::import_document,
            library::read_document
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

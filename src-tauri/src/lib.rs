mod db;
mod dictionary;
mod documents;
mod library;
mod nlp;
mod nlp_commands;
mod progress;
mod reader;
mod video;
#[cfg(target_os = "linux")]
mod video_http;
mod vocabulary;
mod vocabulary_commands;

use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = tauri::Builder::default();
    #[cfg(desktop)]
    let builder = builder.plugin(tauri_plugin_dialog::init());
    #[cfg(all(target_os = "linux", feature = "tauri-plugin-video"))]
    let builder = builder.plugin(tauri_plugin_video::init());
    builder
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            #[cfg(all(target_os = "linux", feature = "tauri-plugin-video"))]
            app.add_capability(r#"{"identifier":"mpv-prototype","windows":["main"],"permissions":["video:default"]}"#)?;
            let database = db::Database::initialize(app.path().app_data_dir()?)
                .map_err(std::io::Error::other)?;
            app.manage(database);
            #[cfg(target_os = "linux")]
            app.manage(video_http::VideoServerState::default());
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
            vocabulary_commands::edit_vocabulary,
            vocabulary_commands::remove_vocabulary,
            vocabulary_commands::save_video_vocabulary,
            vocabulary_commands::find_video_vocabulary,
            video::import_video,
            video::list_videos,
            video::open_video,
            video::open_remux_stream,
            video::remove_video,
            video::save_video_progress,
            video::read_video_subtitles,
            video::save_video_sidecar
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

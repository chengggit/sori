//! Rust domain core for the Electron app.
//!
//! The Qt-specific models and mpv renderer were left in the legacy `core/`
//! crate. This crate keeps the domain services and exposes one JSON command
//! dispatcher to the napi-rs addon.

// Commands are wired in one migration step at a time; most services are not
// reachable from the dispatcher yet. Remove this once step 15 is complete.
#![allow(dead_code)]

mod bridge;
mod db;
mod dictionary;
mod document_import;
mod documents;
mod krdict;
mod library_jobs;
mod library_service;
mod nlp;
mod process;
mod progress;
mod subtitles;
mod video_library;
mod video_transcript;
mod vocabulary;
mod youtube;
mod youtube_transcript;

use std::{
    path::PathBuf,
    sync::{Mutex, MutexGuard, OnceLock},
};

use serde_json::{json, Value};

use crate::library_service::LibraryService;

static ANALYZER: OnceLock<Mutex<nlp::KoreanAnalyzer>> = OnceLock::new();
static LIBRARY: OnceLock<Mutex<LibraryService>> = OnceLock::new();

/// Initialize native resources once. Safe to call again after success.
pub fn init(resources: PathBuf) -> Result<(), String> {
    if ANALYZER.get().is_some() {
        return Ok(());
    }
    let analyzer = nlp::KoreanAnalyzer::start(resources)?;
    ANALYZER
        .set(Mutex::new(analyzer))
        .map_err(|_| "Korean analyzer was already initialized.".to_string())
}

/// Open (and migrate) the library database in `directory`. Safe to call again.
pub fn init_library(directory: PathBuf) -> Result<(), String> {
    if LIBRARY.get().is_some() {
        return Ok(());
    }
    let mut service = LibraryService::default();
    service.initialize(directory.to_string_lossy().into_owned())?;
    LIBRARY
        .set(Mutex::new(service))
        .map_err(|_| "Library was already initialized.".to_string())
}

fn analyzer() -> Result<&'static Mutex<nlp::KoreanAnalyzer>, String> {
    ANALYZER
        .get()
        .ok_or_else(|| "Korean analysis is not initialized.".to_string())
}

fn library() -> Result<MutexGuard<'static, LibraryService>, String> {
    LIBRARY
        .get()
        .ok_or_else(|| "Library is not initialized.".to_string())?
        .lock()
        .map_err(|_| "Library lock is poisoned.".to_string())
}

fn text(payload: &Value, name: &str) -> Result<String, String> {
    payload
        .get(name)
        .and_then(Value::as_str)
        .map(str::to_owned)
        .ok_or_else(|| format!("Provide {name}."))
}

fn number(payload: &Value, name: &str) -> Result<i64, String> {
    payload
        .get(name)
        .and_then(Value::as_i64)
        .ok_or_else(|| format!("Provide {name} as an integer."))
}

fn fraction(payload: &Value, name: &str) -> Result<f64, String> {
    payload
        .get(name)
        .and_then(Value::as_f64)
        .ok_or_else(|| format!("Provide {name} as a number."))
}

fn input(payload: &Value) -> Result<Value, String> {
    payload
        .get("input")
        .cloned()
        .ok_or_else(|| "Provide input.".to_string())
}

/// Single entry point for the Node addon. Uses the same `{ok, data, error}`
/// envelope as the Qt bridge so the renderer contract does not change.
pub fn invoke(command: &str, payload: &Value) -> Value {
    match command {
        "app:ping" => bridge::reply(Ok("pong")),
        "analyzeText" => {
            let Ok(text) = text(payload, "text") else {
                return bridge::reply::<Value>(Err("Provide text to analyze.".into()));
            };
            let result = analyzer().and_then(|analyzer| {
                analyzer
                    .lock()
                    .map_err(|_| "Korean analyzer lock is poisoned.".to_string())
                    .and_then(|analyzer| analyzer.analyze(text))
            });
            bridge::reply(result)
        }
        "library:state" => bridge::reply(library().map(|library| {
            json!({
                "documents": &library.documents,
                "videos": &library.videos,
                "vocabulary": &library.vocabulary,
                "youtubeHistory": &library.youtube_history,
                "error": &library.error,
            })
        })),
        "document:add" => bridge::reply((|| {
            let title = text(payload, "title")?;
            let content = text(payload, "content")?;
            library()?.add_document(title, content)
        })()),
        "document:import" => bridge::reply((|| {
            let path = text(payload, "path")?;
            library()?.import_document(path)
        })()),
        "document:update" => bridge::reply((|| {
            let id = number(payload, "id")?;
            let title = text(payload, "title")?;
            let content = text(payload, "content")?;
            library()?.update_document(id, title, content)
        })()),
        "document:remove" => bridge::reply((|| {
            let id = number(payload, "id")?;
            library()?.remove_document(id)
        })()),
        "document:read" => bridge::reply((|| {
            let id = number(payload, "id")?;
            library()?.read_document(id)
        })()),
        "progress:saveDocument" => bridge::reply((|| {
            let id = number(payload, "id")?;
            let position = fraction(payload, "position")?;
            library()?.save_reading_progress(id, position)
        })()),
        "video:import" => bridge::reply((|| {
            let path = text(payload, "path")?;
            library()?.import_video(path)
        })()),
        "video:read" => bridge::reply((|| {
            let id = number(payload, "id")?;
            library()?.read_video(id)
        })()),
        "video:remove" => bridge::reply((|| {
            let id = number(payload, "id")?;
            library()?.remove_video(id)
        })()),
        "video:saveProgress" => bridge::reply((|| {
            let id = number(payload, "id")?;
            let seconds = fraction(payload, "seconds")?;
            let duration = fraction(payload, "duration")?;
            library()?.save_video_progress(id, seconds, duration)
        })()),
        "vocabulary:save" => bridge::reply((|| {
            let kind = text(payload, "kind")?;
            let id = number(payload, "id")?;
            let input = input(payload)?;
            library()?.save_word(kind, id, input)
        })()),
        "vocabulary:find" => bridge::reply((|| {
            let kind = text(payload, "kind")?;
            let id = number(payload, "id")?;
            let word = text(payload, "word")?;
            let context = text(payload, "context")?;
            library()?.find_word(kind, id, word, context)
        })()),
        "vocabulary:edit" => bridge::reply((|| {
            let id = number(payload, "id")?;
            let input = input(payload)?;
            library()?.edit_word(id, input)
        })()),
        "vocabulary:remove" => bridge::reply((|| {
            let id = number(payload, "id")?;
            library()?.remove_word(id)
        })()),
        other => bridge::reply::<Value>(Err(format!("Unknown command: {other}"))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn ping_uses_the_shared_envelope() {
        assert_eq!(
            invoke("app:ping", &json!({})),
            json!({ "ok": true, "data": "pong", "error": "" })
        );
    }

    #[test]
    fn unknown_commands_fail_visibly() {
        assert_eq!(invoke("no:such:command", &json!({})), json!({
            "ok": false, "data": null, "error": "Unknown command: no:such:command"
        }));
    }

    #[test]
    fn analysis_requires_initialization_and_input() {
        assert_eq!(
            invoke("analyzeText", &json!({})),
            json!({ "ok": false, "data": null, "error": "Provide text to analyze." })
        );
        assert_eq!(invoke("analyzeText", &json!({"text": "한국어"}))["ok"], false);
    }

    #[test]
    fn library_commands_require_initialization() {
        assert_eq!(invoke("library:state", &json!({}))["ok"], false);
        assert_eq!(invoke("document:read", &json!({"id": 1}))["ok"], false);
    }
}

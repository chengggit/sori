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
mod reader;
mod subtitles;
mod video_library;
mod video_transcript;
mod vocabulary;
mod youtube;
mod youtube_transcript;

use std::{path::PathBuf, sync::{Mutex, OnceLock}};

use serde_json::Value;

static ANALYZER: OnceLock<Mutex<nlp::KoreanAnalyzer>> = OnceLock::new();

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

fn analyzer() -> Result<&'static Mutex<nlp::KoreanAnalyzer>, String> {
    ANALYZER
        .get()
        .ok_or_else(|| "Korean analysis is not initialized.".to_string())
}

/// Single entry point for the Node addon. Uses the same `{ok, data, error}`
/// envelope as the Qt bridge so the renderer contract does not change.
pub fn invoke(command: &str, payload: &Value) -> Value {
    match command {
        "app:ping" => bridge::reply(Ok("pong")),
        "analyzeText" => {
            let Some(text) = payload.get("text").and_then(Value::as_str) else {
                return bridge::reply::<Value>(Err("Provide text to analyze.".into()));
            };
            let result = analyzer().and_then(|analyzer| {
                analyzer
                    .lock()
                    .map_err(|_| "Korean analyzer lock is poisoned.".to_string())
                    .and_then(|analyzer| analyzer.analyze(text.to_string()))
            });
            bridge::reply(result)
        }
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
}

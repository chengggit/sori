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
    // The saved key is kept in memory because the YouTube client is a global.
    let saved_key = youtube::read_saved_api_key(&service.connection()?)?;
    youtube::set_saved_api_key(saved_key);
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
        "video:thumbnail" => bridge::reply((|| {
            let id = number(payload, "id")?;
            library()?.prepare_video_thumbnail(id)
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
        "video:saveSubtitles" => bridge::reply((|| {
            let id = number(payload, "id")?;
            let path = text(payload, "path")?;
            library()?.save_video_subtitles(id, path)
        })()),
        "video:readTranscript"
        | "video:saveTranscript"
        | "video:removeTranscript"
        | "video:saveTranscriptPosition" => bridge::reply((|| {
            let youtube = match text(payload, "kind")?.as_str() {
                "local" => false,
                "youtube" => true,
                _ => return Err("Choose a local video or YouTube transcript.".into()),
            };
            match (command, youtube) {
                ("video:readTranscript", false) => {
                    library()?.read_video_transcript(number(payload, "id")?)
                }
                ("video:readTranscript", true) => {
                    library()?.read_youtube_transcript(text(payload, "id")?)
                }
                ("video:saveTranscript", false) => {
                    library()?.save_video_transcript(number(payload, "id")?, text(payload, "path")?)
                }
                ("video:saveTranscript", true) => library()?
                    .attach_youtube_transcript(text(payload, "id")?, text(payload, "path")?),
                ("video:removeTranscript", false) => library()?
                    .remove_video_transcript(number(payload, "id")?)
                    .map(|_| Value::Null),
                ("video:removeTranscript", true) => library()?
                    .remove_youtube_text_transcript(text(payload, "id")?)
                    .map(|_| Value::Null),
                ("video:saveTranscriptPosition", false) => library()?
                    .save_transcript_position(
                        number(payload, "id")?,
                        fraction(payload, "position")?,
                    )
                    .map(|_| Value::Null),
                ("video:saveTranscriptPosition", true) => library()?
                    .save_youtube_transcript_position(
                        text(payload, "id")?,
                        fraction(payload, "position")?,
                    )
                    .map(|_| Value::Null),
                _ => unreachable!(),
            }
        })()),
        "vocabulary:save" => bridge::reply((|| {
            let kind = text(payload, "kind")?;
            let input = input(payload)?;
            if kind == "youtube" {
                library()?.save_youtube_word(text(payload, "id")?, text(payload, "title")?, input)
            } else {
                library()?.save_word(kind, number(payload, "id")?, input)
            }
        })()),
        "vocabulary:find" => bridge::reply((|| {
            let kind = text(payload, "kind")?;
            let word = text(payload, "word")?;
            let context = text(payload, "context")?;
            if kind == "youtube" {
                library()?.find_youtube_word(text(payload, "id")?, word, context)
            } else {
                library()?.find_word(kind, number(payload, "id")?, word, context)
            }
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
        "dictionary:lookup" => bridge::reply((|| {
            let term = text(payload, "term")?;
            let provider = payload
                .get("provider")
                .and_then(Value::as_str)
                .unwrap_or("wiktionary");
            match provider {
                "wiktionary" => {
                    let dictionary = dictionary::Dictionary::new()
                        .map_err(|error| format!("Could not start dictionary lookup: {error}"))?;
                    dictionary.lookup(&term)
                }
                "krdict" => {
                    let (key, _) = krdict::read_settings(&library()?.connection()?)?;
                    let key = key.ok_or_else(|| "Save a KRDict API key first.".to_string())?;
                    krdict::lookup(&term, &key)
                }
                _ => Err("Choose Wiktionary or KRDict.".into()),
            }
        })()),
        "dictionary:settings" => bridge::reply((|| {
            let (key, provider) = krdict::read_settings(&library()?.connection()?)?;
            Ok(json!({ "provider": provider, "hasKey": key.is_some() }))
        })()),
        "dictionary:saveKey" => bridge::reply((|| {
            let key = text(payload, "key")?;
            krdict::save_key(&library()?.connection()?, &key).map(|_| ())
        })()),
        "dictionary:select" => bridge::reply((|| {
            let provider = text(payload, "provider")?;
            krdict::select(&library()?.connection()?, &provider)
        })()),
        "dictionary:removeKey" => bridge::reply((|| {
            let mut connection = library()?.connection()?;
            krdict::remove_key(&mut connection)
        })()),
        "youtube:metadata" => bridge::reply((|| {
            let id = text(payload, "id")?;
            youtube::fetch_metadata(&id)
        })()),
        "youtube:duration" => bridge::reply((|| {
            let id = text(payload, "id")?;
            youtube::fetch_duration(&id)
        })()),
        "youtube:search" => bridge::reply((|| {
            let query = text(payload, "query")?;
            let page = payload
                .get("page")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string();
            youtube::search(&query, &page)
        })()),
        "youtube:resolve" => bridge::reply((|| {
            let input = text(payload, "input")?;
            youtube::resolve_channel(&input)
        })()),
        "youtube:feed" => bridge::reply((|| {
            let database = library()?
                .database
                .clone()
                .ok_or_else(|| "Could not open the library database.".to_string())?;
            let tokens = payload.get("tokens").cloned().unwrap_or_else(|| json!({}));
            youtube::subscription_feed(&database, &tokens)
        })()),
        "youtube:addSubscription" => bridge::reply((|| {
            let input = text(payload, "input")?;
            let channel = youtube::resolve_channel(&input)?;
            youtube::add_subscription(
                &library()?.connection()?,
                &channel.channel_id,
                &channel.title,
                &channel.uploads_playlist_id,
            )
        })()),
        "youtube:removeSubscription" => bridge::reply((|| {
            let id = text(payload, "id")?;
            youtube::remove_subscription(&library()?.connection()?, &id)
        })()),
        "youtube:subscriptions" => bridge::reply((|| {
            youtube::subscriptions(&library()?.connection()?)
        })()),
        "youtube:saveProgress" => bridge::reply((|| {
            let id = text(payload, "id")?;
            let title = text(payload, "title")?;
            let channel = text(payload, "channel")?;
            let seconds = fraction(payload, "seconds")?;
            let duration = fraction(payload, "duration")?;
            library()?.save_youtube_progress(id, title, channel, seconds, duration)
        })()),
        "youtube:fetchTranscript" => bridge::reply((|| {
            let id = text(payload, "id")?;
            let language = payload
                .get("language")
                .and_then(Value::as_str)
                .unwrap_or("ko")
                .to_string();
            youtube_transcript::fetch(&id, &language)
        })()),
        "youtube:transcript" => bridge::reply((|| {
            let id = text(payload, "id")?;
            youtube_transcript::read(&library()?.connection()?, &id)
        })()),
        "youtube:cacheTranscript" => bridge::reply((|| {
            let id = text(payload, "id")?;
            let data = input(payload)?;
            youtube_transcript::cache(&library()?.connection()?, &id, data)
        })()),
        "youtube:settings" => bridge::reply(Ok(json!({
            "hasKey": youtube::has_api_key(),
            "saved": youtube::has_saved_api_key(),
        }))),
        "youtube:saveKey" => bridge::reply((|| {
            let key = text(payload, "key")?;
            let saved = youtube::store_api_key(&library()?.connection()?, &key)?;
            youtube::set_saved_api_key(Some(saved));
            Ok(())
        })()),
        "youtube:removeKey" => bridge::reply((|| {
            youtube::remove_saved_api_key(&library()?.connection()?)?;
            youtube::set_saved_api_key(None);
            Ok(())
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

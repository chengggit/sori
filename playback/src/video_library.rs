use rusqlite::{params, Connection, OptionalExtension};
use serde::Serialize;
use std::io::Read;
use std::path::Path;

const MAX_SUBTITLE_BYTES: usize = 8 * 1024 * 1024;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct VideoSummary {
    id: i64,
    title: String,
    seconds: f64,
    watched_at: Option<i64>,
}

#[derive(Serialize)]
pub struct SavedVideo {
    path: String,
    seconds: f64,
    sidecar: Option<String>,
}

pub fn import(connection: &Connection, path: &Path) -> Result<i64, String> {
    const EXTENSIONS: &[&str] = &["mp4", "m4v", "mov", "mkv", "webm", "avi", "ts"];
    let path = path
        .canonicalize()
        .ok()
        .filter(|path| path.is_file())
        .ok_or("Choose a readable local video file.")?;
    let extension = path.extension().and_then(|ext| ext.to_str()).unwrap_or("");
    if !EXTENSIONS.contains(&extension.to_ascii_lowercase().as_str()) {
        return Err("Choose an MP4, MOV, MKV, WebM, AVI or TS video.".into());
    }
    let title = path
        .file_stem()
        .and_then(|stem| stem.to_str())
        .unwrap_or("Local video");
    let path = path
        .to_str()
        .ok_or("The video path must be valid Unicode.")?;
    connection
        .query_row(
            "INSERT INTO videos (path, title) VALUES (?1, ?2)
             ON CONFLICT (path) DO UPDATE SET path = excluded.path RETURNING id",
            params![path, title],
            |row| row.get(0),
        )
        .map_err(|error| error.to_string())
}

pub fn list(connection: &Connection) -> Result<Vec<VideoSummary>, String> {
    let mut statement = connection
        .prepare(
            "SELECT v.id, v.title, v.seconds, h.watched_at
             FROM videos v LEFT JOIN local_watch_history h ON v.id = h.video_id
             ORDER BY h.watched_at DESC, v.id DESC",
        )
        .map_err(|error| error.to_string())?;
    let rows = statement
        .query_map([], |row| {
            Ok(VideoSummary {
                id: row.get(0)?,
                title: row.get(1)?,
                seconds: row.get(2)?,
                watched_at: row.get(3)?,
            })
        })
        .map_err(|error| error.to_string())?;
    rows.collect::<Result<Vec<_>, _>>()
        .map_err(|error| error.to_string())
}

pub fn read(connection: &Connection, id: i64) -> Result<SavedVideo, String> {
    let video = connection
        .query_row(
            "SELECT path, seconds, sidecar FROM videos WHERE id = ?1",
            [id],
            |row| {
                Ok(SavedVideo {
                    path: row.get(0)?,
                    seconds: row.get(1)?,
                    sidecar: row.get(2)?,
                })
            },
        )
        .optional()
        .map_err(|error| error.to_string())?
        .ok_or("Video not found.")?;
    if !Path::new(&video.path).is_file() {
        return Err("The original video was moved or removed.".into());
    }
    Ok(video)
}

pub fn remove(connection: &Connection, id: i64) -> Result<(), String> {
    connection
        .execute("DELETE FROM videos WHERE id = ?1", [id])
        .map_err(|error| error.to_string())?;
    Ok(())
}

pub fn save_progress(connection: &Connection, id: i64, seconds: f64) -> Result<(), String> {
    if !seconds.is_finite() || seconds < 0.0 {
        return Err("Invalid video position.".into());
    }
    let transaction = connection
        .unchecked_transaction()
        .map_err(|error| error.to_string())?;
    let changed = transaction
        .execute(
            "UPDATE videos SET seconds = ?1 WHERE id = ?2",
            params![seconds, id],
        )
        .map_err(|error| error.to_string())?;
    if changed == 0 {
        return Err("Video not found.".into());
    }
    transaction
        .execute(
            "INSERT INTO local_watch_history (video_id, watched_at) VALUES (?1, unixepoch())
             ON CONFLICT (video_id) DO UPDATE SET watched_at = excluded.watched_at",
            [id],
        )
        .map_err(|error| error.to_string())?;
    transaction.commit().map_err(|error| error.to_string())
}

pub fn save_sidecar(connection: &Connection, id: i64, path: &Path) -> Result<String, String> {
    if !path.is_file() {
        return Err("Choose a readable subtitle file.".into());
    }
    let file = std::fs::File::open(path).map_err(|error| error.to_string())?;
    let mut bytes = Vec::new();
    file.take(MAX_SUBTITLE_BYTES as u64 + 1)
        .read_to_end(&mut bytes)
        .map_err(|error| error.to_string())?;
    if bytes.len() > MAX_SUBTITLE_BYTES {
        return Err("The subtitle file exceeds 8 MiB.".into());
    }
    let text = String::from_utf8(bytes).map_err(|_| "Choose a UTF-8 subtitle file.")?;
    if crate::subtitles::parse(text.trim_start_matches('\u{feff}')).is_empty() {
        return Err("Choose an SRT or VTT file with at least one cue.".into());
    }
    let changed = connection
        .execute(
            "UPDATE videos SET sidecar = ?1 WHERE id = ?2",
            params![text, id],
        )
        .map_err(|error| error.to_string())?;
    if changed == 0 {
        return Err("Video not found.".into());
    }
    Ok(text)
}

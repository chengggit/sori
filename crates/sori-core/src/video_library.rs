use regex::Regex;
use rusqlite::{params, Connection, OptionalExtension};
use serde::Serialize;
use std::fs::{self, OpenOptions};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::LazyLock;

const MAX_SUBTITLE_BYTES: usize = 8 * 1024 * 1024;
const MAX_THUMBNAIL_BYTES: usize = 2 * 1024 * 1024;
static THUMBNAIL_SEQUENCE: AtomicU64 = AtomicU64::new(0);

static RELEASE_SUFFIX: LazyLock<Regex> = LazyLock::new(|| {
    let video_tag = r"x26[45]|h\.?26[45]|hevc|avc|web[- ]?dl|webrip|bluray|brrip|bdrip|hdrip|dvdrip|remux|1080p|720p|2160p|480p";
    Regex::new(&format!(
        r"(?ix)
        [\s._-]+ (?:nf[\s._-]+)? \[?
        (?:{video_tag}) \b
        (?: [\s._-]* (?:\[[^\]]*\]|\]|{video_tag}|aac(?:[25]\.[01])?|ddp?(?:[25]\.[01])?|e?ac3|nf|proper|repack) )*
        [\s._-]* $",
    ))
    .expect("valid release noise expression")
});

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct VideoSummary {
    id: i64,
    title: String,
    display_title: String,
    seconds: f64,
    duration: f64,
    thumbnail_url: Option<String>,
    watched_at: Option<i64>,
}

#[derive(Serialize)]
pub struct SavedVideo {
    path: String,
    seconds: f64,
    sidecar: Option<String>,
}

pub struct VideoMetadata {
    pub path: String,
    pub duration: f64,
    pub thumbnail: Option<String>,
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
            "SELECT v.id, v.title, v.seconds, v.duration, v.thumbnail, h.watched_at
             FROM videos v LEFT JOIN local_watch_history h ON v.id = h.video_id
             ORDER BY h.watched_at DESC, v.id DESC",
        )
        .map_err(|error| error.to_string())?;
    let rows = statement
        .query_map([], summary_row)
        .map_err(|error| error.to_string())?;
    rows.collect::<Result<Vec<_>, _>>()
        .map_err(|error| error.to_string())
}

fn summary_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<VideoSummary> {
    let title: String = row.get(1)?;
    Ok(VideoSummary {
        id: row.get(0)?,
        display_title: display_title(&title),
        title,
        seconds: row.get(2)?,
        duration: row.get(3)?,
        thumbnail_url: row
            .get::<_, Option<String>>(4)?
            .and_then(|path| url::Url::from_file_path(path).ok().map(String::from)),
        watched_at: row.get(5)?,
    })
}

pub fn summary(connection: &Connection, id: i64) -> Result<VideoSummary, String> {
    connection.query_row(
        "SELECT v.id, v.title, v.seconds, v.duration, v.thumbnail, h.watched_at
         FROM videos v LEFT JOIN local_watch_history h ON v.id = h.video_id WHERE v.id = ?1",
        [id], summary_row,
    ).map_err(|error| error.to_string())
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

pub fn metadata(connection: &Connection, id: i64) -> Result<VideoMetadata, String> {
    connection
        .query_row(
            "SELECT path, duration, thumbnail FROM videos WHERE id = ?1",
            [id],
            |row| {
                Ok(VideoMetadata {
                    path: row.get(0)?,
                    duration: row.get(1)?,
                    thumbnail: row.get(2)?,
                })
            },
        )
        .optional()
        .map_err(|error| error.to_string())?
        .ok_or_else(|| "Video not found.".to_string())
}

pub fn remove(connection: &Connection, id: i64) -> Result<(), String> {
    connection
        .execute("DELETE FROM videos WHERE id = ?1", [id])
        .map_err(|error| error.to_string())?;
    Ok(())
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
    if !crate::subtitles::has_cues(&text) {
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

pub fn save_progress(
    connection: &Connection,
    id: i64,
    seconds: f64,
    duration: f64,
) -> Result<(), String> {
    if !seconds.is_finite() || seconds < 0.0 {
        return Err("Invalid video position.".into());
    }
    let duration = if duration.is_finite() && duration > 0.0 {
        duration
    } else {
        0.0
    };
    let transaction = connection
        .unchecked_transaction()
        .map_err(|error| error.to_string())?;
    let changed = transaction
        .execute(
            "UPDATE videos
             SET seconds = ?1, duration = CASE WHEN ?3 > 0 THEN ?3 ELSE duration END
             WHERE id = ?2",
            params![seconds, id, duration],
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

pub fn update_metadata(
    connection: &Connection,
    id: i64,
    duration: f64,
    thumbnail: Option<&Path>,
) -> Result<bool, String> {
    let thumbnail = thumbnail
        .map(|path| {
            path.to_str()
                .ok_or("The thumbnail path must be valid Unicode.")
        })
        .transpose()?;
    connection
        .execute(
            "UPDATE videos
             SET duration = CASE WHEN duration <= 0 AND ?2 > 0 THEN ?2 ELSE duration END,
                 thumbnail = COALESCE(?3, thumbnail)
             WHERE id = ?1",
            params![id, duration, thumbnail],
        )
        .map(|changed| changed > 0)
        .map_err(|error| error.to_string())
}

pub fn has_thumbnail(path: &Path) -> bool {
    fs::metadata(path).is_ok_and(|file| file.is_file() && file.len() > 0)
}

pub fn thumbnail_path(directory: &Path, id: i64) -> PathBuf {
    directory.join(format!("{id}.jpg"))
}

pub fn prepare_thumbnail(path: &str, output: &Path, duration: f64) -> Result<(), String> {
    if has_thumbnail(output) {
        return Ok(());
    }
    let seek = (duration * 0.1).clamp(0.0, 30.0);
    let frame = if seek > 0.0 {
        capture_at(path, seek).or_else(|_| capture_at(path, 0.0))?
    } else {
        capture_at(path, 0.0)?
    };
    let directory = output.parent().ok_or("Missing thumbnail directory.")?;
    fs::create_dir_all(directory).map_err(|error| error.to_string())?;
    let sequence = THUMBNAIL_SEQUENCE.fetch_add(1, Ordering::Relaxed);
    let temporary = output.with_extension(format!("{}-{sequence}.tmp", std::process::id()));
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&temporary)
        .map_err(|error| error.to_string())?;
    let written = file.write_all(&frame);
    drop(file);
    written
        .and_then(|_| fs::rename(&temporary, output))
        .map_err(|error| {
            let _ = fs::remove_file(&temporary);
            error.to_string()
        })
}

pub fn probe_duration(path: &str) -> Result<f64, String> {
    let output = crate::subtitles::command_output(
        "ffprobe",
        [
            "-v",
            "error",
            "-protocol_whitelist",
            "file",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            "-i",
            path,
        ],
        1024,
    )?;
    String::from_utf8_lossy(&output)
        .trim()
        .parse::<f64>()
        .ok()
        .filter(|duration| duration.is_finite() && *duration > 0.0)
        .ok_or_else(|| "FFprobe did not return a duration.".into())
}

fn capture_at(path: &str, seek: f64) -> Result<Vec<u8>, String> {
    let frame = crate::subtitles::command_output(
        "ffmpeg",
        [
            "-v",
            "error",
            "-nostdin",
            "-ss",
            &format!("{seek:.3}"),
            "-protocol_whitelist",
            "file",
            "-i",
            path,
            "-map",
            "0:V:0",
            "-frames:v",
            "1",
            "-vf",
            "scale=640:360:force_original_aspect_ratio=decrease:force_divisible_by=2",
            "-q:v",
            "3",
            "-f",
            "mjpeg",
            "pipe:1",
        ],
        MAX_THUMBNAIL_BYTES,
    )?;
    if !frame.starts_with(&[0xff, 0xd8]) || !frame.ends_with(&[0xff, 0xd9]) {
        return Err("FFmpeg did not return a complete thumbnail frame.".into());
    }
    Ok(frame)
}

pub fn display_title(title: &str) -> String {
    let Some(suffix) = RELEASE_SUFFIX.find(title) else {
        return title.trim().to_string();
    };
    let cleaned = title[..suffix.start()]
        .replace(['.', '_'], " ")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ");
    let cleaned = cleaned
        .trim_matches(|character: char| character == '-' || character == '_' || character == ' ');
    if cleaned.is_empty() {
        title.trim().to_string()
    } else {
        cleaned.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn checkpoint_summary_matches_library_listing() {
        let connection = Connection::open_in_memory().unwrap();
        connection.execute_batch(include_str!("schema.sql")).unwrap();
        connection.execute("INSERT INTO videos(path,title) VALUES('example.mkv','Example')", []).unwrap();
        let id = connection.last_insert_rowid();
        save_progress(&connection, id, 12.0, 60.0).unwrap();
        assert_eq!(serde_json::to_value(summary(&connection, id).unwrap()).unwrap(),
            serde_json::to_value(list(&connection).unwrap().remove(0)).unwrap());
        assert!(summary(&connection, id + 1).is_err());
    }

    #[test]
    fn cleans_release_names_for_display() {
        assert_eq!(
            display_title("Take.Charge.of.My.Heart.S01E02.NF.x264.1080p[MkvDrama.net]"),
            "Take Charge of My Heart S01E02"
        );
        assert_eq!(
            display_title("한국어.브이로그_[1080p].WEB-DL"),
            "한국어 브이로그"
        );
    }

    #[test]
    fn keeps_plain_titles() {
        assert_eq!(display_title("Local video"), "Local video");
        assert_eq!(
            display_title("Mr. Kim [Director's cut]"),
            "Mr. Kim [Director's cut]"
        );
        assert_eq!(display_title("NF Live"), "NF Live");
        assert_eq!(display_title("  ...  "), "...");
    }

    #[test]
    fn metadata_backfill_preserves_player_duration_and_progress() {
        let connection = Connection::open_in_memory().unwrap();
        connection
            .execute_batch(include_str!("schema.sql"))
            .unwrap();
        connection
            .execute(
                "INSERT INTO videos (id, path, title) VALUES (1, '/tmp/video.mkv', 'Video')",
                [],
            )
            .unwrap();

        assert!(update_metadata(&connection, 1, 100.0, None).unwrap());
        assert_eq!(metadata(&connection, 1).unwrap().duration, 100.0);
        save_progress(&connection, 1, 29.0, 98.0).unwrap();
        #[cfg(windows)]
        let (thumbnail, expected_url) = (
            Path::new("C:/sori-test/cache #1/1.jpg"),
            "file:///C:/sori-test/cache%20%231/1.jpg",
        );
        #[cfg(not(windows))]
        let (thumbnail, expected_url) = (
            Path::new("/tmp/cache #1/1.jpg"),
            "file:///tmp/cache%20%231/1.jpg",
        );
        assert!(update_metadata(&connection, 1, 100.0, Some(thumbnail)).unwrap());
        save_progress(&connection, 1, 30.0, f64::NAN).unwrap();

        let videos = list(&connection).unwrap();
        assert_eq!(videos[0].duration, 98.0);
        assert_eq!(videos[0].seconds, 30.0);
        assert_eq!(videos[0].thumbnail_url.as_deref(), Some(expected_url));
        assert!(videos[0].watched_at.is_some());

        remove(&connection, 1).unwrap();
        assert!(!update_metadata(&connection, 1, 100.0, None).unwrap());
    }
}

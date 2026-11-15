use crate::db::Database;
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use std::{
    io::Read,
    path::{Path, PathBuf},
    process::{Command, Stdio},
};
use tauri::{AppHandle, Manager, State};
#[cfg(desktop)]
use tauri_plugin_dialog::DialogExt;

const MAX_SUBTITLE_BYTES: usize = 8 * 1024 * 1024;
const VIDEO_EXTENSIONS: &[&str] = &["mp4", "m4v", "mov", "mkv", "webm", "avi"];
const TEXT_CODECS: &[&str] = &["subrip", "ass", "ssa", "mov_text", "webvtt", "text"];
pub(crate) const INPUT_FORMATS: &str = "mov,matroska,webm,avi";

#[derive(Serialize)]
pub struct VideoSummary {
    id: i64,
    title: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct VideoDetails {
    id: i64,
    title: String,
    path: String,
    playback_url: Option<String>,
    mpv_available: bool,
    seconds: f64,
    sidecar: Option<String>,
    tracks: Vec<SubtitleTrack>,
    probe_error: Option<String>,
}

#[derive(Serialize)]
pub struct RemuxPlayback {
    url: String,
    start: f64,
    duration: f64,
}

#[cfg(target_os = "linux")]
fn remux_timing(path: &Path, requested: f64) -> Result<(f64, f64), String> {
    #[derive(Deserialize)]
    struct Timing {
        packets: Vec<Packet>,
        format: Format,
    }
    #[derive(Deserialize)]
    struct Packet {
        pts_time: String,
    }
    #[derive(Deserialize)]
    struct Format {
        duration: String,
        start_time: Option<String>,
    }
    let mut command = Command::new("ffprobe");
    command
        .args([
            "-v",
            "error",
            "-protocol_whitelist",
            "file",
            "-format_whitelist",
            INPUT_FORMATS,
            "-select_streams",
            "V:0",
            "-read_intervals",
            &format!("{requested:.6}%+#1"),
            "-show_entries",
            "packet=pts_time:format=start_time,duration",
            "-of",
            "json",
            "-i",
        ])
        .arg(path);
    let bytes = command_output(command, "ffprobe", 1024 * 1024)?;
    let timing: Timing = serde_json::from_slice(&bytes).map_err(|error| error.to_string())?;
    let duration: f64 = timing
        .format
        .duration
        .parse()
        .map_err(|_| "Invalid video duration.")?;
    let origin = timing
        .format
        .start_time
        .as_deref()
        .and_then(|value| value.parse::<f64>().ok())
        .unwrap_or(0.0);
    let keyframe = timing
        .packets
        .first()
        .and_then(|packet| packet.pts_time.parse::<f64>().ok())
        .filter(|value| value.is_finite())
        .ok_or("No video frame found at this position.")?;
    if !duration.is_finite() || duration <= 0.0 || requested >= duration {
        return Err("Choose a position within the video.".into());
    }
    Ok(((keyframe - origin).clamp(0.0, duration), duration))
}

#[tauri::command]
pub async fn open_remux_stream(
    app: AppHandle,
    database: State<'_, Database>,
    id: i64,
    seconds: f64,
) -> Result<RemuxPlayback, String> {
    #[cfg(not(target_os = "linux"))]
    {
        let _ = (app, database, id, seconds);
        Err("Experimental MP4 remuxing is available on Linux.".into())
    }
    #[cfg(target_os = "linux")]
    {
        if !seconds.is_finite() || seconds < 0.0 {
            return Err("Invalid playback position.".into());
        }
        let (path, start, duration) = database
            .run(move |connection| {
                let path = video_path(connection, id)?;
                let (start, duration) = remux_timing(&path, seconds)?;
                Ok((path, start, duration))
            })
            .await?;
        let url = app
            .state::<crate::video_http::VideoServerState>()
            .remux_url(&path, seconds)?;
        Ok(RemuxPlayback {
            url,
            start,
            duration,
        })
    }
}

fn expose_video(app: &AppHandle, path: &str) -> Result<Option<String>, String> {
    #[cfg(target_os = "linux")]
    {
        // WebKitGTK can read and seek HTTP media using its GStreamer pipeline.
        app.state::<crate::video_http::VideoServerState>()
            .url(Path::new(path))
            .map(Some)
    }
    #[cfg(not(target_os = "linux"))]
    {
        app.asset_protocol_scope()
            .allow_file(path)
            .map_err(|error| error.to_string())?;
        Ok(None)
    }
}

#[derive(Deserialize)]
struct Probe {
    streams: Vec<Stream>,
}

#[derive(Deserialize)]
struct Stream {
    index: u32,
    #[serde(default)]
    codec_name: String,
    #[serde(default)]
    tags: TrackTags,
}

#[derive(Default, Deserialize)]
struct TrackTags {
    language: Option<String>,
    title: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SubtitleTrack {
    index: u32,
    language: Option<String>,
    title: Option<String>,
    text: bool,
}

fn command_output(mut command: Command, program: &str, limit: usize) -> Result<Vec<u8>, String> {
    let mut child = command
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .stdout(Stdio::piped())
        .spawn()
        .map_err(|error| {
            if error.kind() == std::io::ErrorKind::NotFound {
                "Install FFmpeg and make ffmpeg and ffprobe available on PATH.".to_string()
            } else {
                format!("Could not start {program}: {error}")
            }
        })?;
    let mut bytes = Vec::new();
    let result = child
        .stdout
        .take()
        .unwrap()
        .take(limit as u64 + 1)
        .read_to_end(&mut bytes);
    if result.is_err() || bytes.len() > limit {
        let _ = child.kill();
    }
    let status = child.wait().map_err(|error| error.to_string())?;
    result.map_err(|error| error.to_string())?;
    if bytes.len() > limit {
        return Err("The subtitle data exceeds the size limit.".into());
    }
    if !status.success() {
        return Err(format!(
            "{program} could not read subtitles from this file."
        ));
    }
    Ok(bytes)
}

fn probe(path: &Path) -> Result<Vec<SubtitleTrack>, String> {
    let mut command = Command::new("ffprobe");
    command
        .args([
            "-v",
            "error",
            "-protocol_whitelist",
            "file",
            "-format_whitelist",
            INPUT_FORMATS,
            "-select_streams",
            "s",
            "-show_entries",
            "stream=index,codec_name:stream_tags=language,title",
            "-of",
            "json",
            "-i",
        ])
        .arg(path);
    let bytes = command_output(command, "ffprobe", 1024 * 1024)?;
    let data: Probe = serde_json::from_slice(&bytes).map_err(|error| error.to_string())?;
    Ok(data
        .streams
        .into_iter()
        .map(|stream| SubtitleTrack {
            index: stream.index,
            language: stream.tags.language,
            title: stream.tags.title,
            text: TEXT_CODECS.contains(&stream.codec_name.as_str()),
        })
        .collect())
}

fn extract(path: &Path, index: u32) -> Result<String, String> {
    let mut command = Command::new("ffmpeg");
    command
        .args([
            "-v",
            "error",
            "-nostdin",
            "-protocol_whitelist",
            "file",
            "-format_whitelist",
            INPUT_FORMATS,
            "-i",
        ])
        .arg(path)
        .args([
            "-map",
            &format!("0:{index}"),
            "-c:s",
            "webvtt",
            "-f",
            "webvtt",
            "pipe:1",
        ]);
    String::from_utf8(command_output(command, "ffmpeg", MAX_SUBTITLE_BYTES)?)
        .map_err(|_| "Subtitle text is not valid UTF-8.".into())
}

fn video_path(database: &Connection, id: i64) -> Result<PathBuf, String> {
    let path: String = database
        .query_row("SELECT path FROM videos WHERE id = ?1", [id], |row| {
            row.get(0)
        })
        .optional()
        .map_err(|error| error.to_string())?
        .ok_or("Video not found.")?;
    Ok(PathBuf::from(path))
}

#[tauri::command]
pub async fn import_video(
    app: AppHandle,
    database: State<'_, Database>,
) -> Result<Option<i64>, String> {
    #[cfg(not(desktop))]
    {
        let _ = (app, database);
        return Err("Video import is available on desktop.".into());
    }
    #[cfg(desktop)]
    {
        let (send, receive) = std::sync::mpsc::channel();
        app.dialog()
            .file()
            .add_filter("Video", VIDEO_EXTENSIONS)
            .pick_file(move |path| {
                let _ = send.send(path);
            });
        database
            .run(move |connection| {
                let Some(path) = receive.recv().map_err(|error| error.to_string())? else {
                    return Ok(None);
                };
                let path = path.into_path().map_err(|error| error.to_string())?;
                let path = path.canonicalize().map_err(|error| error.to_string())?;
                if !path.is_file()
                    || !path
                        .extension()
                        .and_then(|value| value.to_str())
                        .is_some_and(|ext| {
                            VIDEO_EXTENSIONS.contains(&ext.to_ascii_lowercase().as_str())
                        })
                {
                    return Err("Choose an MP4, MOV, MKV, WebM, or AVI video.".into());
                }
                let title = path
                    .file_stem()
                    .and_then(|value| value.to_str())
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
                    .map(Some)
                    .map_err(|error| error.to_string())
            })
            .await
    }
}

#[tauri::command]
pub async fn list_videos(database: State<'_, Database>) -> Result<Vec<VideoSummary>, String> {
    database
        .run(|connection| {
            let mut stmt = connection
                .prepare("SELECT id, title FROM videos ORDER BY id DESC")
                .map_err(|error| error.to_string())?;
            stmt.query_map([], |row| {
                Ok(VideoSummary {
                    id: row.get(0)?,
                    title: row.get(1)?,
                })
            })
            .map_err(|error| error.to_string())?
            .collect::<rusqlite::Result<Vec<_>>>()
            .map_err(|error| error.to_string())
        })
        .await
}

#[tauri::command]
pub async fn open_video(
    app: AppHandle,
    database: State<'_, Database>,
    id: i64,
) -> Result<VideoDetails, String> {
    let mut video = database
        .run(move |connection| {
            let (path, title, seconds, sidecar): (String, String, f64, Option<String>) = connection
                .query_row(
                    "SELECT path, title, seconds, sidecar FROM videos WHERE id = ?1",
                    [id],
                    |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?)),
                )
                .optional()
                .map_err(|error| error.to_string())?
                .ok_or("Video not found.")?;
            let file = Path::new(&path);
            if !file.is_file() {
                return Err("The original video was moved or removed.".into());
            }
            let (tracks, probe_error) = match probe(file) {
                Ok(tracks) => (tracks, None),
                Err(error) => (Vec::new(), Some(error)),
            };
            Ok(VideoDetails {
                id,
                title,
                path,
                playback_url: None,
                mpv_available: cfg!(all(target_os = "linux", feature = "tauri-plugin-video")),
                seconds,
                sidecar,
                tracks,
                probe_error,
            })
        })
        .await?;
    video.playback_url = expose_video(&app, &video.path)?;
    Ok(video)
}

#[tauri::command]
pub async fn remove_video(database: State<'_, Database>, id: i64) -> Result<(), String> {
    database
        .run(move |connection| {
            connection
                .execute("DELETE FROM videos WHERE id = ?1", [id])
                .map_err(|error| error.to_string())?;
            Ok(())
        })
        .await
}

#[tauri::command]
pub async fn save_video_progress(
    database: State<'_, Database>,
    id: i64,
    seconds: f64,
) -> Result<(), String> {
    if !seconds.is_finite() || seconds < 0.0 {
        return Err("Invalid video position.".into());
    }
    database
        .run(move |connection| {
            connection
                .execute(
                    "UPDATE videos SET seconds = ?1 WHERE id = ?2",
                    params![seconds, id],
                )
                .map_err(|error| error.to_string())?;
            Ok(())
        })
        .await
}

#[tauri::command]
pub async fn read_video_subtitles(
    database: State<'_, Database>,
    id: i64,
    index: u32,
) -> Result<String, String> {
    database
        .run(move |connection| {
            let path = video_path(connection, id)?;
            if !probe(&path)?
                .iter()
                .any(|track| track.index == index && track.text)
            {
                return Err("Select a supported text subtitle track.".into());
            }
            extract(&path, index)
        })
        .await
}

#[tauri::command]
pub async fn save_video_sidecar(
    database: State<'_, Database>,
    id: i64,
    text: String,
) -> Result<(), String> {
    if text.len() > MAX_SUBTITLE_BYTES {
        return Err("The subtitle file exceeds 8 MiB.".into());
    }
    database
        .run(move |connection| {
            connection
                .execute(
                    "UPDATE videos SET sidecar = ?1 WHERE id = ?2",
                    params![text, id],
                )
                .map_err(|error| error.to_string())?;
            Ok(())
        })
        .await
}

use qtbridge::{qobject, QmlObject};
use regex::Regex;
use std::collections::HashMap;
use reqwest::blocking::Client;
use rusqlite::{params, Connection, OptionalExtension};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::io::Read;
use std::path::PathBuf;
use std::sync::{OnceLock, RwLock};
use std::time::Duration;
use url::Url;

static CLIENT: OnceLock<Result<Client, String>> = OnceLock::new();
static SAVED_API_KEY: RwLock<Option<String>> = RwLock::new(None);

#[derive(Default)]
pub struct YouTube {
    request: i32,
    database: Option<crate::db::Database>,
    settings_error: String,
}

#[qobject(Singleton, ConvertToCamelCase)]
impl YouTube {
    qproperty!(
        "configured",
        Read = configured,
        Notify = configuration_changed
    );
    qproperty!("savedKey", Read = saved_key, Notify = configuration_changed);
    qproperty!(
        "settingsError",
        Member = settings_error,
        Notify = configuration_changed
    );
    qproperty!(
        "subscriptions",
        Read = subscription_list,
        Notify = subscriptions_changed
    );

    #[qsignal]
    fn configuration_changed(&mut self);

    #[qsignal]
    fn subscriptions_changed(&mut self);

    #[qsignal]
    fn subscription_feed_finished(&mut self, request: i32, result: &Value);

    #[qslot]
    fn initialize(&mut self, directory: String) {
        let result =
            crate::db::Database::initialize(PathBuf::from(directory)).and_then(|database| {
                let key = read_saved_api_key(&database.connect()?)?;
                self.database = Some(database);
                *SAVED_API_KEY
                    .write()
                    .unwrap_or_else(|poison| poison.into_inner()) = key;
                Ok(())
            });
        self.settings_error = result.err().unwrap_or_default();
        self.configuration_changed();
        self.subscriptions_changed();
    }

    fn saved_key(&self) -> bool {
        SAVED_API_KEY
            .read()
            .unwrap_or_else(|poison| poison.into_inner())
            .is_some()
    }

    #[qslot]
    fn save_api_key(&mut self, key: String) -> String {
        let result = self
            .database
            .as_ref()
            .ok_or_else(|| "Settings are not available.".to_string())
            .and_then(|database| {
                let key = store_api_key(&database.connect()?, &key)?;
                *SAVED_API_KEY
                    .write()
                    .unwrap_or_else(|poison| poison.into_inner()) = Some(key);
                Ok(())
            });
        let error = result.err().unwrap_or_default();
        if error.is_empty() {
            self.configuration_changed();
        }
        error
    }

    #[qslot]
    fn remove_api_key(&mut self) -> String {
        let result = self
            .database
            .as_ref()
            .ok_or_else(|| "Settings are not available.".to_string())
            .and_then(|database| {
                remove_saved_api_key(&database.connect()?)?;
                *SAVED_API_KEY
                    .write()
                    .unwrap_or_else(|poison| poison.into_inner()) = None;
                Ok(())
            });
        let error = result.err().unwrap_or_default();
        if error.is_empty() {
            self.configuration_changed();
        }
        error
    }

    #[qsignal]
    fn search_finished(&mut self, request: i32, result: &Value);

    #[qsignal]
    fn transcript_finished(&mut self, request: i32, result: &Value);

    #[qslot]
    fn fetch_transcript(&mut self, id: String, language: String) -> i32 {
        self.request = self.request.wrapping_add(1).max(1);
        let request = self.request;
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let result = crate::youtube_transcript::fetch(&id, &language)
                .unwrap_or_else(|error| json!({"error": error}));
            let _ = handle.invoke_mut(move |model| model.transcript_finished(request, &result));
        });
        request
    }

    fn configured(&self) -> bool {
        has_api_key()
    }

    #[qslot]
    fn resolve_link(&self, link: String) -> String {
        video_id(&link)
            .and_then(|id| watch_url(&id))
            .unwrap_or_default()
    }

    #[qslot]
    fn search(&mut self, query: String, page: String) -> i32 {
        self.request = self.request.wrapping_add(1).max(1);
        let request = self.request;
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let result = search(&query, &page)
                .map(|result| json!(result))
                .unwrap_or_else(|error| json!({"error": error}));
            let _ = handle.invoke_mut(move |model| model.search_finished(request, &result));
        });
        request
    }

    fn connection(&self) -> Result<Connection, String> {
        self.database
            .as_ref()
            .ok_or_else(|| "Settings are not available.".to_string())?
            .connect()
    }

    fn subscription_list(&self) -> Value {
        let entries = self
            .connection()
            .and_then(|connection| subscriptions(&connection))
            .unwrap_or_default();
        json!(entries)
    }

    #[qslot]
    fn resolve_channel(&self, input: String) -> Value {
        match resolve_channel(&input) {
            Ok(channel) => json!(channel),
            Err(error) => json!({ "error": error }),
        }
    }

    #[qslot]
    fn add_subscription(&mut self, id: String, title: String, playlist: String) -> String {
        let error = self
            .connection()
            .and_then(|connection| add_subscription(&connection, &id, &title, &playlist))
            .err()
            .unwrap_or_default();
        if error.is_empty() {
            self.subscriptions_changed();
        }
        error
    }

    #[qslot]
    fn remove_subscription(&mut self, id: String) -> String {
        let error = self
            .connection()
            .and_then(|connection| remove_subscription(&connection, &id))
            .err()
            .unwrap_or_default();
        if error.is_empty() {
            self.subscriptions_changed();
        }
        error
    }

    fn request_feed(&mut self, tokens: Value) -> i32 {
        self.request = self.request.wrapping_add(1).max(1);
        let request = self.request;
        let database = self.database.clone();
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let result = database
                .ok_or_else(|| "Settings are not available.".to_string())
                .and_then(|database| subscription_feed(&database, &tokens))
                .unwrap_or_else(|error| json!({"error": error}));
            let _ = handle.invoke_mut(move |model| {
                model.subscription_feed_finished(request, &result)
            });
        });
        request
    }

    #[qslot]
    fn subscription_feed(&mut self) -> i32 {
        self.request_feed(json!({}))
    }

    #[qslot]
    fn subscription_feed_page(&mut self, tokens: Value) -> i32 {
        self.request_feed(tokens)
    }
}

pub fn has_api_key() -> bool {
    api_key().is_some()
}

fn api_key() -> Option<String> {
    SAVED_API_KEY
        .read()
        .unwrap_or_else(|poison| poison.into_inner())
        .clone()
        .or_else(|| {
            std::env::var("SORI_YOUTUBE_API_KEY")
                .ok()
                .map(|key| key.trim().to_owned())
                .filter(|key| !key.is_empty())
                .or_else(|| {
                    let path = env_file()?;
                    let settings = std::fs::read_to_string(path).ok()?;
                    key_from_settings(&settings, "SORI_YOUTUBE_API_KEY")
                        .or_else(|| key_from_settings(&settings, "VITE_YOUTUBE_API_KEY"))
                })
        })
}

fn read_saved_api_key(connection: &Connection) -> Result<Option<String>, String> {
    connection
        .query_row(
            "SELECT value FROM app_settings WHERE key = 'youtube_api_key'",
            [],
            |row| row.get(0),
        )
        .optional()
        .map_err(|error| error.to_string())
}

fn store_api_key(connection: &Connection, input: &str) -> Result<String, String> {
    let key = input.trim();
    if key.is_empty()
        || key.len() > 512
        || !key
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'-'))
    {
        return Err("Enter an API key without spaces or punctuation.".into());
    }
    #[cfg(unix)]
    if let Some(path) = connection
        .path()
        .filter(|path| !path.is_empty() && *path != ":memory:")
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))
            .map_err(|_| "Could not protect the local API key settings.".to_string())?;
    }
    connection
        .execute(
            "INSERT INTO app_settings (key, value) VALUES ('youtube_api_key', ?1)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            [key],
        )
        .map_err(|error| error.to_string())?;
    Ok(key.to_owned())
}

fn remove_saved_api_key(connection: &Connection) -> Result<(), String> {
    connection
        .execute("DELETE FROM app_settings WHERE key = 'youtube_api_key'", [])
        .map_err(|error| error.to_string())?;
    Ok(())
}

/// Resolve `.env.local` independently of the directory Sori was launched from.
fn env_file() -> Option<PathBuf> {
    if let Some(path) = std::env::var_os("SORI_ENV_FILE") {
        let path = PathBuf::from(path);
        if path.is_file() {
            return Some(path);
        }
    }
    let mut candidates = Vec::new();
    if let Ok(directory) = std::env::current_dir() {
        candidates.extend(
            directory
                .ancestors()
                .take(6)
                .map(|ancestor| ancestor.join(".env.local")),
        );
    }
    if let Ok(executable) = std::env::current_exe() {
        candidates.extend(
            executable
                .ancestors()
                .skip(1)
                .take(6)
                .map(|ancestor| ancestor.join(".env.local")),
        );
    }
    candidates.into_iter().find(|path| path.is_file())
}

fn key_from_settings(settings: &str, name: &str) -> Option<String> {
    settings.lines().rev().find_map(|line| {
        let line = line.trim();
        let (key, value) = line
            .strip_prefix("export ")
            .unwrap_or(line)
            .split_once('=')?;
        if key.trim() != name {
            return None;
        }
        let value = value.trim();
        let value = value
            .strip_prefix('"')
            .and_then(|value| value.strip_suffix('"'))
            .or_else(|| {
                value
                    .strip_prefix('\'')
                    .and_then(|value| value.strip_suffix('\''))
            })
            .unwrap_or(value);
        (!value.is_empty()).then(|| value.to_owned())
    })
}

fn valid_id(id: &str) -> bool {
    id.len() == 11
        && id
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
}

pub fn watch_url(id: &str) -> Option<String> {
    valid_id(id).then(|| format!("https://www.youtube.com/watch?v={id}"))
}

fn client() -> Result<&'static Client, String> {
    CLIENT
        .get_or_init(|| {
            Client::builder()
                .user_agent("Sori/0.1 (Korean immersion desktop app)")
                .timeout(Duration::from_secs(15))
                .redirect(reqwest::redirect::Policy::none())
                .build()
                .map_err(|error| error.to_string())
        })
        .as_ref()
        .map_err(Clone::clone)
}

#[derive(Deserialize)]
struct OEmbedResponse {
    #[serde(default)]
    title: String,
    #[serde(default)]
    author_name: String,
}

pub struct Metadata {
    pub title: String,
    pub channel: String,
}

pub fn fetch_metadata(id: &str) -> Result<Metadata, String> {
    if !valid_id(id) {
        return Err("Invalid YouTube video ID.".into());
    }
    let mut url = Url::parse("https://www.youtube.com/oembed").expect("constant oEmbed URL");
    url.query_pairs_mut().extend_pairs([
        ("url", format!("https://www.youtube.com/watch?v={id}")),
        ("format", "json".to_owned()),
    ]);
    let response = client()?
        .get(url)
        .send()
        .map_err(|_| "Could not reach YouTube.".to_string())?;
    let status = response.status();
    const MAX_METADATA_BYTES: usize = 64 * 1024;
    let mut body = Vec::new();
    response
        .take(MAX_METADATA_BYTES as u64 + 1)
        .read_to_end(&mut body)
        .map_err(|_| "Could not read the YouTube response.".to_string())?;
    if !status.is_success() || body.len() > MAX_METADATA_BYTES {
        return Err("YouTube did not return video details.".into());
    }
    parse_metadata(&body)
}

fn parse_metadata(body: &[u8]) -> Result<Metadata, String> {
    let response: OEmbedResponse = serde_json::from_slice(body)
        .map_err(|_| "Could not read the YouTube video details.".to_string())?;
    let title = decode_title(response.title.trim());
    if title.is_empty() {
        return Err("YouTube did not return a video title.".into());
    }
    Ok(Metadata {
        title,
        channel: decode_title(response.author_name.trim()),
    })
}

pub fn update_metadata(
    connection: &Connection,
    id: &str,
    title: &str,
    channel: &str,
) -> Result<(), String> {
    if !valid_id(id) {
        return Err("Invalid YouTube video ID.".into());
    }
    connection
        .execute(
            "UPDATE youtube_watch_history SET title = ?2, channel = ?3 WHERE video_id = ?1",
            params![id, title.trim(), channel.trim()],
        )
        .map_err(|error| error.to_string())?;
    Ok(())
}

static DURATION_PATTERN: OnceLock<Regex> = OnceLock::new();

#[derive(Deserialize)]
struct VideosResponse {
    #[serde(default)]
    items: Vec<VideoResource>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct VideoResource {
    #[serde(default)]
    content_details: Option<ContentDetails>,
}

#[derive(Deserialize)]
struct ContentDetails {
    #[serde(default)]
    duration: String,
}

pub fn fetch_duration(id: &str) -> Result<f64, String> {
    if !valid_id(id) {
        return Err("Invalid YouTube video ID.".into());
    }
    let key = api_key().ok_or("Add a YouTube API key in Settings to load video durations.")?;
    let mut url =
        Url::parse("https://www.googleapis.com/youtube/v3/videos").expect("constant videos URL");
    url.query_pairs_mut().extend_pairs([
        ("part", "contentDetails".to_owned()),
        ("id", id.to_owned()),
        ("key", key),
    ]);

    let response = client()?
        .get(url)
        .send()
        .map_err(|_| "Could not reach YouTube.".to_string())?;
    let status = response.status();
    const MAX_DURATION_BYTES: usize = 64 * 1024;
    let mut body = Vec::new();
    response
        .take(MAX_DURATION_BYTES as u64 + 1)
        .read_to_end(&mut body)
        .map_err(|_| "Could not read the YouTube response.".to_string())?;
    if !status.is_success() || body.len() > MAX_DURATION_BYTES {
        return Err("YouTube did not return the video duration.".into());
    }
    parse_duration_response(&body)
}

fn parse_duration_response(body: &[u8]) -> Result<f64, String> {
    let response: VideosResponse = serde_json::from_slice(body)
        .map_err(|_| "Could not read the YouTube video details.".to_string())?;
    response
        .items
        .first()
        .and_then(|item| item.content_details.as_ref())
        .and_then(|details| parse_iso_duration(&details.duration))
        .ok_or_else(|| "YouTube did not return the video duration.".to_string())
}

fn parse_iso_duration(text: &str) -> Option<f64> {
    let pattern = DURATION_PATTERN.get_or_init(|| {
        Regex::new(r"^P(?:(\d+)D)?T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$")
            .expect("constant duration pattern")
    });
    let captures = pattern.captures(text.trim())?;
    let part = |index: usize| {
        captures
            .get(index)
            .and_then(|value| value.as_str().parse::<f64>().ok())
            .unwrap_or(0.0)
    };
    let seconds = part(1) * 86_400.0 + part(2) * 3_600.0 + part(3) * 60.0 + part(4);
    (seconds.is_finite() && seconds > 0.0).then_some(seconds)
}

pub fn update_duration(connection: &Connection, id: &str, duration: f64) -> Result<(), String> {
    if !valid_id(id) {
        return Err("Invalid YouTube video ID.".into());
    }
    if !duration.is_finite() || duration <= 0.0 {
        return Err("Invalid YouTube video duration.".into());
    }
    connection
        .execute(
            "UPDATE youtube_watch_history SET duration = ?2
             WHERE video_id = ?1 AND seconds <= ?2",
            params![id, duration],
        )
        .map_err(|error| error.to_string())?;
    Ok(())
}

pub fn watch_history(connection: &Connection) -> Result<Vec<Value>, String> {
    let mut statement = connection
        .prepare(
            "SELECT video_id, title, channel, seconds, duration, watched_at
                  FROM youtube_watch_history ORDER BY watched_at DESC, rowid DESC",
        )
        .map_err(|error| error.to_string())?;
    let entries = statement
        .query_map([], |row| {
            let id: String = row.get(0)?;
            Ok(json!({
                "youtubeId": id,
                "title": row.get::<_, String>(1)?,
                "channel": row.get::<_, String>(2)?,
                "seconds": row.get::<_, f64>(3)?,
                "duration": row.get::<_, f64>(4)?,
                "watchedAt": row.get::<_, i64>(5)?,
                "thumbnailUrl": format!("https://i.ytimg.com/vi/{id}/mqdefault.jpg"),
            }))
        })
        .map_err(|error| error.to_string())?;
    entries
        .collect::<Result<_, _>>()
        .map_err(|error| error.to_string())
}

pub fn save_watch_progress(
    connection: &Connection,
    id: &str,
    title: &str,
    channel: &str,
    seconds: f64,
    duration: f64,
) -> Result<(), String> {
    if !valid_id(id) || !seconds.is_finite() || seconds < 0.0 {
        return Err("Invalid YouTube playback position.".into());
    }
    let duration = if duration.is_finite() {
        duration.max(0.0)
    } else {
        0.0
    };
    connection.execute(
        "INSERT INTO youtube_watch_history (video_id, title, channel, seconds, duration, watched_at)
         VALUES (?1, ?2, ?3, ?4, ?5, unixepoch())
         ON CONFLICT(video_id) DO UPDATE SET title = excluded.title, channel = excluded.channel,
             seconds = excluded.seconds, watched_at = excluded.watched_at,
             duration = CASE WHEN excluded.duration > 0 THEN excluded.duration ELSE duration END",
        params![id, title, channel, seconds, duration],
    ).map_err(|error| error.to_string())?;
    Ok(())
}

fn video_id(link: &str) -> Option<String> {
    let url = Url::parse(link.trim()).ok()?;
    if !matches!(url.scheme(), "http" | "https") {
        return None;
    }
    let id = match url.host_str()? {
        "youtu.be" => url.path().strip_prefix('/')?.to_owned(),
        "youtube.com" | "www.youtube.com" | "m.youtube.com" if url.path() == "/watch" => url
            .query_pairs()
            .find(|(key, _)| key == "v")?
            .1
            .into_owned(),
        "youtube.com" | "www.youtube.com" | "m.youtube.com" => {
            let mut parts = url.path_segments()?;
            match (parts.next(), parts.next(), parts.next()) {
                (Some("shorts" | "live" | "embed"), Some(id), None) => id.to_owned(),
                _ => return None,
            }
        }
        _ => return None,
    };
    valid_id(&id).then_some(id)
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SearchResponse {
    #[serde(default)]
    items: Vec<SearchItem>,
    next_page_token: Option<String>,
}

#[derive(Deserialize)]
struct SearchItem {
    id: SearchId,
    snippet: Snippet,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SearchId {
    video_id: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Snippet {
    title: String,
    channel_title: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SearchPage {
    videos: Vec<SearchVideo>,
    next_page: String,
}

#[derive(Serialize)]
struct SearchVideo {
    id: String,
    title: String,
    channel: String,
}

fn decode_title(title: &str) -> String {
    // The API HTML-escapes some titles and channel names.
    scraper::Html::parse_fragment(title)
        .root_element()
        .text()
        .collect::<String>()
}

fn parse_search(body: &[u8]) -> Result<SearchPage, String> {
    let result: SearchResponse =
        serde_json::from_slice(body).map_err(|_| "Could not read the YouTube results.")?;
    let videos = result
        .items
        .into_iter()
        .filter(|item| valid_id(&item.id.video_id))
        .map(|item| SearchVideo {
            id: item.id.video_id,
            title: decode_title(&item.snippet.title),
            channel: decode_title(&item.snippet.channel_title),
        })
        .collect();
    Ok(SearchPage {
        videos,
        next_page: result.next_page_token.unwrap_or_default(),
    })
}

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Subscription {
    channel_id: String,
    title: String,
    uploads_playlist_id: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct FeedVideo {
    id: String,
    title: String,
    channel: String,
    published_at: String,
}

fn subscriptions(connection: &Connection) -> Result<Vec<Subscription>, String> {
    let mut statement = connection
        .prepare(
            "SELECT channel_id, title, uploads_playlist_id FROM youtube_subscriptions
         ORDER BY added_at DESC",
        )
        .map_err(|error| error.to_string())?;
    let entries = statement
        .query_map([], |row| {
            Ok(Subscription {
                channel_id: row.get(0)?,
                title: row.get(1)?,
                uploads_playlist_id: row.get(2)?,
            })
        })
        .map_err(|error| error.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|error| error.to_string());
    entries
}

fn add_subscription(
    connection: &Connection,
    id: &str,
    title: &str,
    playlist: &str,
) -> Result<(), String> {
    if id.trim().is_empty() || title.trim().is_empty() || playlist.trim().is_empty() {
        return Err("Could not resolve that channel.".into());
    }
    connection
        .execute(
            "INSERT INTO youtube_subscriptions (channel_id, title, uploads_playlist_id)
         VALUES (?1, ?2, ?3) ON CONFLICT(channel_id) DO UPDATE SET
         title = excluded.title, uploads_playlist_id = excluded.uploads_playlist_id",
            params![id.trim(), title.trim(), playlist.trim()],
        )
        .map_err(|error| error.to_string())?;
    Ok(())
}

fn remove_subscription(connection: &Connection, id: &str) -> Result<(), String> {
    connection
        .execute("DELETE FROM youtube_subscriptions WHERE channel_id = ?1", [id])
        .map_err(|error| error.to_string())?;
    Ok(())
}

enum ChannelInput {
    Id(String),
    Handle(String),
    User(String),
    Query(String),
}

fn channel_input(input: &str) -> ChannelInput {
    let value = input.trim();
    if let Ok(url) = Url::parse(value) {
        let segments: Vec<String> = url
            .path_segments()
            .map(|parts| parts.map(str::to_owned).collect())
            .unwrap_or_default();
        for (index, segment) in segments.iter().enumerate() {
            if segment == "channel" {
                if let Some(id) = segments.get(index + 1) {
                    return ChannelInput::Id(id.clone());
                }
            }
            if let Some(handle) = segment.strip_prefix('@') {
                return ChannelInput::Handle(handle.to_owned());
            }
            if matches!(segment.as_str(), "c" | "user") {
                if let Some(name) = segments.get(index + 1) {
                    return if segment == "c" {
                        ChannelInput::Query(name.clone())
                    } else {
                        ChannelInput::User(name.clone())
                    };
                }
            }
        }
    }
    if let Some(handle) = value.strip_prefix('@') {
        return ChannelInput::Handle(handle.trim().to_owned());
    }
    if value.len() == 24 && value.starts_with("UC") {
        return ChannelInput::Id(value.to_owned());
    }
    ChannelInput::Query(value.to_owned())
}

fn api_error(status: u16, body: &[u8]) -> String {
    let response = serde_json::from_slice::<Value>(body).unwrap_or_default();
    let error = response
        .pointer("/error/errors/0/reason")
        .and_then(Value::as_str);
    match (status, error) {
        (_, Some("quotaExceeded" | "dailyLimitExceeded")) => {
            "The daily YouTube quota has been reached.".into()
        }
        (429, _) | (_, Some("rateLimitExceeded" | "userRateLimitExceeded")) => {
            "YouTube is limiting requests. Try again shortly.".into()
        }
        (400, Some("keyInvalid" | "API_KEY_INVALID")) => "The YouTube API key is not valid.".into(),
        (403, Some("accessNotConfigured")) => {
            "The YouTube Data API is not enabled for this key.".into()
        }
        _ => "YouTube did not return the requested data.".into(),
    }
}

fn get_json(url: Url) -> Result<Value, String> {
    let response = client()?
        .get(url)
        .send()
        .map_err(|_| "Could not reach YouTube.".to_string())?;
    let status = response.status().as_u16();
    const MAX_BYTES: usize = 1024 * 1024;
    let mut body = Vec::new();
    response
        .take(MAX_BYTES as u64 + 1)
        .read_to_end(&mut body)
        .map_err(|_| "Could not read the YouTube response.".to_string())?;
    if body.len() > MAX_BYTES {
        return Err("The YouTube response was too large.".into());
    }
    if !(200..300).contains(&status) {
        return Err(api_error(status, &body));
    }
    serde_json::from_slice(&body).map_err(|_| "Could not read the YouTube response.".into())
}

fn channel_from_api(items: &[Value], fallback_id: &str) -> Result<Subscription, String> {
    let item = items
        .first()
        .ok_or("No channel matched that name or link.")?;
    let id = item["id"]
        .as_str()
        .map(str::to_owned)
        .or_else(|| item["id"]["channelId"].as_str().map(str::to_owned))
        .unwrap_or_else(|| fallback_id.to_owned());
    let title = decode_title(item["snippet"]["title"].as_str().unwrap_or_default());
    let playlist = item["contentDetails"]["relatedPlaylists"]["uploads"]
        .as_str()
        .unwrap_or_default()
        .to_owned();
    if id.is_empty() || title.is_empty() || playlist.is_empty() {
        return Err("That channel does not expose an uploads playlist.".into());
    }
    Ok(Subscription {
        channel_id: id,
        title,
        uploads_playlist_id: playlist,
    })
}

fn resolve_channel(input: &str) -> Result<Subscription, String> {
    let input = input.trim();
    if input.is_empty() || input.len() > 250 {
        return Err("Enter a channel name, handle, or link.".into());
    }
    let key = api_key().ok_or("Add a YouTube API key in Settings first.")?;
    let input_kind = channel_input(input);
    let mut url =
        Url::parse("https://www.googleapis.com/youtube/v3/channels").expect("constant channels URL");
    let mut fallback_id = String::new();
    {
        let mut pairs = url.query_pairs_mut();
        pairs.extend_pairs([("part", "snippet,contentDetails"), ("key", &key)]);
        match &input_kind {
            ChannelInput::Id(id) => {
                fallback_id = id.clone();
                pairs.append_pair("id", id);
            }
            ChannelInput::Handle(handle) => {
                pairs.append_pair("forHandle", handle);
            }
            ChannelInput::User(user) => {
                pairs.append_pair("forUsername", user);
            }
            ChannelInput::Query(query) => {
                let mut search = Url::parse("https://www.googleapis.com/youtube/v3/search")
                    .expect("constant search URL");
                search.query_pairs_mut().extend_pairs([
                    ("part", "snippet"),
                    ("type", "channel"),
                    ("q", query),
                    ("maxResults", "1"),
                    ("key", &key),
                ]);
                let result = get_json(search)?;
                let items = result["items"].as_array().ok_or("No channel found.")?;
                let id = items
                    .first()
                    .and_then(|item| item["id"]["channelId"].as_str())
                    .ok_or("No channel matched that name.")?;
                fallback_id = id.to_owned();
                pairs.append_pair("id", id);
            }
        }
    }
    let result = get_json(url)?;
    let items = result["items"].as_array().ok_or("No channel found.")?;
    channel_from_api(items, &fallback_id)
}

fn parse_duration(value: &str) -> Option<u64> {
    let pattern = Regex::new(r"^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$").ok()?;
    let captures = pattern.captures(value)?;
    let hours = captures
        .get(1)
        .and_then(|value| value.as_str().parse::<u64>().ok())
        .unwrap_or(0);
    let minutes = captures
        .get(2)
        .and_then(|value| value.as_str().parse::<u64>().ok())
        .unwrap_or(0);
    let seconds = captures
        .get(3)
        .and_then(|value| value.as_str().parse::<u64>().ok())
        .unwrap_or(0);
    if captures.get(1).is_none() && captures.get(2).is_none() && captures.get(3).is_none() {
        return None;
    }
    Some(hours * 3600 + minutes * 60 + seconds)
}

fn short_by_title(title: &str) -> bool {
    let lower = title.to_lowercase();
    lower.contains("#shorts")
        || lower.contains("쇼츠")
        || lower.split_whitespace().any(|word| word == "shorts")
}

fn live_by_title(title: &str) -> bool {
    let lower = title.to_lowercase();
    lower.contains("라이브")
        || lower.contains("#live")
        || lower.split_whitespace().any(|word| word == "live")
}

struct VideoDetails {
    seconds: Option<u64>,
    live: bool,
    completed_live: bool,
}

/// Drop Shorts and live broadcasts using one videos.list call per 50 videos.
/// Title keywords are a fallback when the details are unavailable.
fn filter_uploads(videos: Vec<FeedVideo>, key: &str) -> Vec<FeedVideo> {
    let candidates: Vec<FeedVideo> = videos
        .into_iter()
        .filter(|video| !short_by_title(&video.title) && !live_by_title(&video.title))
        .collect();
    if candidates.is_empty() {
        return candidates;
    }

    let mut details: HashMap<String, VideoDetails> = HashMap::new();
    for chunk in candidates.chunks(50) {
        let ids = chunk
            .iter()
            .map(|video| video.id.as_str())
            .collect::<Vec<_>>()
            .join(",");
        let mut url =
            Url::parse("https://www.googleapis.com/youtube/v3/videos").expect("constant videos URL");
        url.query_pairs_mut().extend_pairs([
            ("part", "snippet,contentDetails,liveStreamingDetails"),
            ("id", &ids),
            ("key", key),
        ]);
        if let Ok(result) = get_json(url) {
            if let Some(items) = result["items"].as_array() {
                for item in items {
                    if let Some(id) = item["id"].as_str() {
                        details.insert(
                            id.to_owned(),
                            VideoDetails {
                                seconds: item["contentDetails"]["duration"]
                                    .as_str()
                                    .and_then(parse_duration),
                                live: item["snippet"]["liveBroadcastContent"].as_str()
                                    != Some("none"),
                                completed_live: item["liveStreamingDetails"]["actualEndTime"]
                                    .as_str()
                                    .is_some(),
                            },
                        );
                    }
                }
            }
        }
    }
    candidates
        .into_iter()
        .filter(|video| match details.get(&video.id) {
            Some(info) => !info.live
                && !info.completed_live
                && info.seconds.map_or(true, |seconds| seconds > 180),
            None => true,
        })
        .collect()
}

fn channel_uploads(
    channel: &Subscription,
    key: &str,
    page_token: &str,
) -> Result<(Vec<FeedVideo>, String), String> {
    let mut url = Url::parse("https://www.googleapis.com/youtube/v3/playlistItems")
        .expect("constant playlistItems URL");
    {
        let mut pairs = url.query_pairs_mut();
        pairs.extend_pairs([
            ("part", "snippet"),
            ("playlistId", &channel.uploads_playlist_id),
            ("maxResults", "12"),
            ("key", key),
        ]);
        if !page_token.is_empty() {
            pairs.append_pair("pageToken", page_token);
        }
    }
    let result = get_json(url)?;
    let next_page = result["nextPageToken"].as_str().unwrap_or_default().to_owned();
    let items = result["items"].as_array().ok_or("No uploads returned.")?;
    let videos: Vec<FeedVideo> = items
        .iter()
        .filter_map(|item| {
            let id = item["snippet"]["resourceId"]["videoId"].as_str()?;
            if !valid_id(id) {
                return None;
            }
            Some(FeedVideo {
                id: id.to_owned(),
                title: decode_title(item["snippet"]["title"].as_str().unwrap_or_default()),
                channel: channel.title.clone(),
                published_at: item["snippet"]["publishedAt"]
                    .as_str()
                    .unwrap_or_default()
                    .to_owned(),
            })
        })
        .collect();
    Ok((filter_uploads(videos, key), next_page))
}

fn subscription_feed(
    database: &crate::db::Database,
    tokens: &Value,
) -> Result<Value, String> {
    let key = api_key().ok_or("Add a YouTube API key in Settings to discover videos.")?;
    let channels = subscriptions(&database.connect()?)?;
    if channels.is_empty() {
        return Err("Add a channel in Settings to build your feed.".into());
    }
    let loading_more = tokens.as_object().is_some_and(|entries| !entries.is_empty());
    let mut videos = Vec::new();
    let mut next_tokens = serde_json::Map::new();
    for channel in &channels {
        let token = tokens
            .get(&channel.channel_id)
            .and_then(Value::as_str)
            .unwrap_or_default();
        if loading_more && token.is_empty() {
            continue;
        }
        if let Ok((mut uploaded, next)) = channel_uploads(channel, &key, token) {
            videos.append(&mut uploaded);
            if !next.is_empty() {
                next_tokens.insert(channel.channel_id.clone(), json!(next));
            }
        }
    }
    videos.sort_by(|left, right| right.published_at.cmp(&left.published_at));
    Ok(json!({"videos": videos, "nextPageTokens": Value::Object(next_tokens)}))
}

fn search(query: &str, page: &str) -> Result<SearchPage, String> {
    let key = api_key().ok_or("Add a YouTube API key in Settings to discover videos.")?;
    let query = query.trim();
    if query.is_empty() || query.chars().count() > 250 {
        return Err("Enter a search of up to 250 characters.".into());
    }

    let client = client()?;
    let mut url =
        Url::parse("https://www.googleapis.com/youtube/v3/search").expect("constant search URL");
    url.query_pairs_mut().extend_pairs([
        ("part", "snippet"),
        ("type", "video"),
        ("q", query),
        ("relevanceLanguage", "ko"),
        ("videoEmbeddable", "true"),
        ("maxResults", "12"),
        ("key", &key),
    ]);
    if !page.is_empty() {
        url.query_pairs_mut().append_pair("pageToken", page);
    }

    let response = client
        .get(url)
        .send()
        .map_err(|_| "Could not reach YouTube.")?;
    let status = response.status();
    const MAX_RESULTS_BYTES: usize = 1024 * 1024;
    let mut body = Vec::new();
    response
        .take(MAX_RESULTS_BYTES as u64 + 1)
        .read_to_end(&mut body)
        .map_err(|_| "Could not read the YouTube response.")?;
    if body.len() > MAX_RESULTS_BYTES {
        return Err("The YouTube response was too large.".into());
    }
    if !status.is_success() {
        let response = serde_json::from_slice::<Value>(&body).unwrap_or_default();
        let error = response
            .pointer("/error/errors/0/reason")
            .and_then(Value::as_str);
        return Err(match (status.as_u16(), error) {
            (_, Some("quotaExceeded" | "dailyLimitExceeded")) => {
                "The daily YouTube search quota has been reached."
            }
            (429, _) | (_, Some("rateLimitExceeded" | "userRateLimitExceeded")) => {
                "YouTube is limiting requests. Try again shortly."
            }
            (400, Some("keyInvalid" | "API_KEY_INVALID")) => "The YouTube API key is not valid.",
            (403, Some("accessNotConfigured")) => {
                "The YouTube Data API is not enabled for this key."
            }
            (403, Some("ipRefererBlocked" | "refererBlocked")) => {
                "YouTube blocked this key for this app."
            }
            (403, _) => "YouTube denied the search. Check the API key and its restrictions.",
            _ => "YouTube did not return search results.",
        }
        .into());
    }
    parse_search(&body)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn api_key_settings_persist_replace_and_remove_without_exposing_values() {
        let directory = std::env::temp_dir().join(format!(
            "sori-key-settings-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let database = crate::db::Database::initialize(directory.clone()).unwrap();
        let connection = database.connect().unwrap();
        assert!(read_saved_api_key(&connection).unwrap().is_none());
        assert_eq!(
            store_api_key(&connection, "  test_key-123  ").unwrap(),
            "test_key-123"
        );
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            assert_eq!(
                std::fs::metadata(connection.path().unwrap())
                    .unwrap()
                    .permissions()
                    .mode()
                    & 0o777,
                0o600
            );
        }
        drop(connection);
        let connection = database.connect().unwrap();
        assert_eq!(
            read_saved_api_key(&connection).unwrap().as_deref(),
            Some("test_key-123")
        );
        for invalid in ["", "   ", "not a key", "key\nline", "key?value", "한국어"] {
            assert!(store_api_key(&connection, invalid).is_err());
            assert_eq!(
                read_saved_api_key(&connection).unwrap().as_deref(),
                Some("test_key-123")
            );
        }
        assert!(store_api_key(&connection, &"x".repeat(513)).is_err());
        store_api_key(&connection, "replacement_key").unwrap();
        assert_eq!(
            read_saved_api_key(&connection).unwrap().as_deref(),
            Some("replacement_key")
        );
        connection
            .execute(
                "INSERT INTO app_settings (key,value) VALUES ('other_setting','unchanged')",
                [],
            )
            .unwrap();
        remove_saved_api_key(&connection).unwrap();
        assert!(read_saved_api_key(&connection).unwrap().is_none());
        assert_eq!(
            connection
                .query_row(
                    "SELECT value FROM app_settings WHERE key='other_setting'",
                    [],
                    |row| row.get::<_, String>(0)
                )
                .unwrap(),
            "unchanged"
        );
        drop(connection);
        std::fs::remove_dir_all(directory).unwrap();
    }

    #[test]
    fn accepts_supported_links_and_rejects_unrelated_hosts() {
        for link in [
            "https://youtu.be/dQw4w9WgXcQ?t=30",
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://m.youtube.com/shorts/dQw4w9WgXcQ",
        ] {
            assert_eq!(video_id(link).as_deref(), Some("dQw4w9WgXcQ"));
        }
        assert!(video_id("https://youtube.com.example.org/watch?v=dQw4w9WgXcQ").is_none());
        assert!(video_id("https://www.youtube.com/embed/bad").is_none());
    }

    #[test]
    fn updates_youtube_history_and_keeps_known_duration() {
        let connection = Connection::open_in_memory().unwrap();
        connection
            .execute_batch(include_str!("schema.sql"))
            .unwrap();
        let id = "jNQXAC9IVRw";
        save_watch_progress(&connection, id, "Video", "Channel", 5.0, 19.0).unwrap();
        save_watch_progress(&connection, id, "Video", "Channel", 7.0, 0.0).unwrap();
        assert!(save_watch_progress(&connection, id, "", "", f64::NAN, 0.0).is_err());
        assert!(save_watch_progress(&connection, "bad", "", "", 0.0, 0.0).is_err());
        let entries = watch_history(&connection).unwrap();
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0]["youtubeId"], id);
        assert_eq!(entries[0]["seconds"], 7.0);
        assert_eq!(entries[0]["duration"], 19.0);
    }

    #[test]
    fn updates_metadata_without_touching_progress() {
        let connection = Connection::open_in_memory().unwrap();
        connection
            .execute_batch(include_str!("schema.sql"))
            .unwrap();
        let id = "jNQXAC9IVRw";
        save_watch_progress(&connection, id, "YouTube video", "", 7.0, 19.0).unwrap();
        update_metadata(&connection, id, "정말 좋은 영상", "테스트 채널").unwrap();
        let entries = watch_history(&connection).unwrap();
        assert_eq!(entries[0]["title"], "정말 좋은 영상");
        assert_eq!(entries[0]["channel"], "테스트 채널");
        assert_eq!(entries[0]["seconds"], 7.0);
        assert_eq!(entries[0]["duration"], 19.0);
    }

    #[test]
    fn parses_oembed_metadata() {
        let metadata = parse_metadata(
            br#"{"title":"One &amp; Two","author_name":"Channel","other":"ignored"}"#,
        )
        .unwrap();
        assert_eq!(metadata.title, "One & Two");
        assert_eq!(metadata.channel, "Channel");
        assert!(parse_metadata(br#"{"title":"","author_name":"Channel"}"#).is_err());
    }

    #[test]
    fn parses_and_updates_durations() {
        assert_eq!(parse_iso_duration("PT14M5S"), Some(845.0));
        assert_eq!(parse_iso_duration("PT1H2M3S"), Some(3723.0));
        assert_eq!(parse_iso_duration("P1DT1S"), Some(86_401.0));
        assert_eq!(parse_iso_duration("PT0S"), None);
        assert_eq!(parse_iso_duration("14:05"), None);

        let body = br#"{"items":[{"contentDetails":{"duration":"PT14M5S"}}]}"#;
        assert_eq!(parse_duration_response(body).unwrap(), 845.0);
        assert!(parse_duration_response(br#"{"items":[]}"#).is_err());

        let connection = Connection::open_in_memory().unwrap();
        connection
            .execute_batch(include_str!("schema.sql"))
            .unwrap();
        let id = "jNQXAC9IVRw";
        save_watch_progress(&connection, id, "Video", "Channel", 7.0, 0.0).unwrap();
        update_duration(&connection, id, 845.0).unwrap();
        assert_eq!(watch_history(&connection).unwrap()[0]["duration"], 845.0);
        assert!(update_duration(&connection, id, f64::NAN).is_err());
    }

    #[test]
    fn reads_key_from_settings_file_syntax() {
        let settings = "VITE_YOUTUBE_API_KEY=old\nexport SORI_YOUTUBE_API_KEY = \"new-key\"\n";
        assert_eq!(
            key_from_settings(settings, "SORI_YOUTUBE_API_KEY").as_deref(),
            Some("new-key")
        );
        assert_eq!(
            key_from_settings(settings, "VITE_YOUTUBE_API_KEY").as_deref(),
            Some("old")
        );
        assert_eq!(key_from_settings(settings, "OTHER_KEY"), None);
    }

    #[test]
    fn parses_titles_and_pagination() {
        let page = parse_search(br#"{"nextPageToken":"next","items":[
            {"id":{"videoId":"dQw4w9WgXcQ"},"snippet":{"title":"One &amp; Two","channelTitle":"Channel"}},
            {"id":{"videoId":"bad"},"snippet":{"title":"Bad","channelTitle":"Channel"}}
        ]}"#).unwrap();
        assert_eq!(page.videos.len(), 1);
        assert_eq!(page.videos[0].title, "One & Two");
        assert_eq!(page.next_page, "next");
    }

    #[test]
    fn parses_channel_links_handles_and_ids() {
        assert!(matches!(channel_input("@TalkToMeInKorean"), ChannelInput::Handle(_)));
        assert!(matches!(
            channel_input("https://www.youtube.com/@TalkToMeInKorean/videos"),
            ChannelInput::Handle(_)
        ));
        assert!(matches!(
            channel_input("https://www.youtube.com/channel/UC5r3WHrX4Z7peSYpDlgktGw"),
            ChannelInput::Id(_)
        ));
        assert!(matches!(channel_input("UC5r3WHrX4Z7peSYpDlgktGw"), ChannelInput::Id(_)));
        assert!(matches!(channel_input("Talk To Me In Korean"), ChannelInput::Query(_)));
    }

    #[test]
    fn parses_durations_and_detects_shorts_by_title() {
        assert_eq!(parse_duration("PT58S"), Some(58));
        assert_eq!(parse_duration("PT3M20S"), Some(200));
        assert_eq!(parse_duration("PT1H2M3S"), Some(3723));
        assert_eq!(parse_duration("PT"), None);
        assert!(short_by_title(" photographed #Shorts"));
        assert!(short_by_title("쇼츠 모음"));
        assert!(short_by_title("Funny SHORTS compilation"));
        assert!(!short_by_title("제주도 여행 브이로그"));
        assert!(live_by_title("라이브 방송"));
        assert!(live_by_title("Live from Seoul"));
        assert!(!live_by_title("서울 여행 브이로그"));
    }

    #[test]
    fn subscriptions_round_trip_in_sqlite() {
        let connection = Connection::open_in_memory().unwrap();
        connection.execute_batch(include_str!("schema.sql")).unwrap();
        add_subscription(&connection, "UC1", "Channel One", "UU1").unwrap();
        add_subscription(&connection, "UC2", "Channel Two", "UU2").unwrap();
        let entries = subscriptions(&connection).unwrap();
        assert_eq!(entries.len(), 2);
        assert!(entries.iter().any(|entry| entry.channel_id == "UC1"));
        add_subscription(&connection, "UC1", "Renamed", "UU9").unwrap();
        let entries = subscriptions(&connection).unwrap();
        assert_eq!(entries.len(), 2);
        assert!(entries.iter().any(|entry| entry.title == "Renamed"
            && entry.uploads_playlist_id == "UU9"));
        remove_subscription(&connection, "UC1").unwrap();
        let entries = subscriptions(&connection).unwrap();
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].channel_id, "UC2");
    }

    #[test]
    #[ignore = "requires a YouTube Data API key and network access"]
    fn live_search() {
        assert!(!search("한국어 대화", "").unwrap().videos.is_empty());
    }
}

use reqwest::blocking::Client;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::io::Read;
use std::sync::OnceLock;
use std::time::Duration;
use url::Url;

mod parsing;
mod settings;
mod store;
pub(crate) use parsing::*;
pub(crate) use settings::*;
pub(crate) use store::*;

static CLIENT: OnceLock<Result<Client, String>> = OnceLock::new();

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

pub(crate) fn resolve_channel(input: &str) -> Result<Subscription, String> {
    let input = input.trim();
    if input.is_empty() || input.len() > 250 {
        return Err("Enter a channel name, handle, or link.".into());
    }
    let key = api_key().ok_or("Add a YouTube API key in Settings first.")?;
    let input_kind = channel_input(input);
    let mut url = Url::parse("https://www.googleapis.com/youtube/v3/channels")
        .expect("constant channels URL");
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
        let mut url = Url::parse("https://www.googleapis.com/youtube/v3/videos")
            .expect("constant videos URL");
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
            Some(info) => {
                !info.live
                    && !info.completed_live
                    && info.seconds.is_none_or(|seconds| seconds > 180)
            }
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
    let next_page = result["nextPageToken"]
        .as_str()
        .unwrap_or_default()
        .to_owned();
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
    Ok((videos, next_page))
}

pub(crate) fn subscription_feed(
    database: &crate::db::Database,
    tokens: &Value,
) -> Result<Value, String> {
    let key = api_key().ok_or("Add a YouTube API key in Settings to discover videos.")?;
    let channels = subscriptions(&database.connect()?)?;
    if channels.is_empty() {
        return Err("Add a channel in Settings to build your feed.".into());
    }
    let loading_more = tokens
        .as_object()
        .is_some_and(|entries| !entries.is_empty());
    let key = key.as_str();

    // Channel uploads are independent; fetch them concurrently instead of
    // waiting for one network round trip per channel.
    let fetched: Vec<(String, Vec<FeedVideo>, String)> = std::thread::scope(|scope| {
        let handles: Vec<_> = channels
            .iter()
            .filter(|channel| {
                !loading_more
                    || tokens
                        .get(&channel.channel_id)
                        .and_then(Value::as_str)
                        .is_some()
            })
            .map(|channel| {
                let token = tokens
                    .get(&channel.channel_id)
                    .and_then(Value::as_str)
                    .unwrap_or_default();
                scope.spawn(move || {
                    let result = channel_uploads(channel, key, token);
                    (channel.channel_id.clone(), result)
                })
            })
            .collect();
        handles
            .into_iter()
            .filter_map(|handle| handle.join().ok())
            .filter_map(|(id, result)| result.ok().map(|(uploaded, next)| (id, uploaded, next)))
            .collect()
    });

    let mut videos = Vec::new();
    let mut next_tokens = serde_json::Map::new();
    for (id, mut uploaded, next) in fetched {
        videos.append(&mut uploaded);
        if !next.is_empty() {
            next_tokens.insert(id, json!(next));
        }
    }
    // One batched details lookup for every channel together.
    let mut videos = filter_uploads(videos, key);
    videos.sort_by(|left, right| right.published_at.cmp(&left.published_at));
    Ok(json!({"videos": videos, "nextPageTokens": Value::Object(next_tokens)}))
}

pub(crate) fn search(query: &str, page: &str) -> Result<SearchPage, String> {
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
    use rusqlite::Connection;

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
        assert_eq!(watch_entry(&connection, id).unwrap(), entries[0]);
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
        assert!(matches!(
            channel_input("@TalkToMeInKorean"),
            ChannelInput::Handle(_)
        ));
        assert!(matches!(
            channel_input("https://www.youtube.com/@TalkToMeInKorean/videos"),
            ChannelInput::Handle(_)
        ));
        assert!(matches!(
            channel_input("https://www.youtube.com/channel/UC5r3WHrX4Z7peSYpDlgktGw"),
            ChannelInput::Id(_)
        ));
        assert!(matches!(
            channel_input("UC5r3WHrX4Z7peSYpDlgktGw"),
            ChannelInput::Id(_)
        ));
        assert!(matches!(
            channel_input("Talk To Me In Korean"),
            ChannelInput::Query(_)
        ));
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
        connection
            .execute_batch(include_str!("schema.sql"))
            .unwrap();
        add_subscription(&connection, "UC1", "Channel One", "UU1").unwrap();
        add_subscription(&connection, "UC2", "Channel Two", "UU2").unwrap();
        let entries = subscriptions(&connection).unwrap();
        assert_eq!(entries.len(), 2);
        assert!(entries.iter().any(|entry| entry.channel_id == "UC1"));
        add_subscription(&connection, "UC1", "Renamed", "UU9").unwrap();
        let entries = subscriptions(&connection).unwrap();
        assert_eq!(entries.len(), 2);
        assert!(entries
            .iter()
            .any(|entry| entry.title == "Renamed" && entry.uploads_playlist_id == "UU9"));
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

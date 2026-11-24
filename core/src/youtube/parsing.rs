use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::sync::OnceLock;
use url::Url;

pub(crate) static DURATION_PATTERN: OnceLock<Regex> = OnceLock::new();

#[derive(Deserialize)]
pub(crate) struct OEmbedResponse {
    #[serde(default)]
    pub(crate) title: String,
    #[serde(default)]
    pub(crate) author_name: String,
}

pub(crate) struct Metadata {
    pub title: String,
    pub channel: String,
}

pub(crate) fn parse_metadata(body: &[u8]) -> Result<Metadata, String> {
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

#[derive(Deserialize)]
pub(crate) struct VideosResponse {
    #[serde(default)]
    pub(crate) items: Vec<VideoResource>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct VideoResource {
    #[serde(default)]
    pub(crate) content_details: Option<ContentDetails>,
}

#[derive(Deserialize)]
pub(crate) struct ContentDetails {
    #[serde(default)]
    pub(crate) duration: String,
}

pub(crate) fn parse_duration_response(body: &[u8]) -> Result<f64, String> {
    let response: VideosResponse = serde_json::from_slice(body)
        .map_err(|_| "Could not read the YouTube video details.".to_string())?;
    response
        .items
        .first()
        .and_then(|item| item.content_details.as_ref())
        .and_then(|details| parse_iso_duration(&details.duration))
        .ok_or_else(|| "YouTube did not return the video duration.".to_string())
}

pub(crate) fn parse_iso_duration(text: &str) -> Option<f64> {
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

pub(crate) fn valid_id(id: &str) -> bool {
    id.len() == 11
        && id
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
}

pub(crate) fn watch_url(id: &str) -> Option<String> {
    valid_id(id).then(|| format!("https://www.youtube.com/watch?v={id}"))
}

pub(crate) fn video_id(link: &str) -> Option<String> {
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
pub(crate) struct SearchResponse {
    #[serde(default)]
    pub(crate) items: Vec<SearchItem>,
    pub(crate) next_page_token: Option<String>,
}

#[derive(Deserialize)]
pub(crate) struct SearchItem {
    pub(crate) id: SearchId,
    pub(crate) snippet: Snippet,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct SearchId {
    pub(crate) video_id: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Snippet {
    pub(crate) title: String,
    pub(crate) channel_title: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct SearchPage {
    pub(crate) videos: Vec<SearchVideo>,
    pub(crate) next_page: String,
}

#[derive(Serialize)]
pub(crate) struct SearchVideo {
    pub(crate) id: String,
    pub(crate) title: String,
    pub(crate) channel: String,
}

pub(crate) fn decode_title(title: &str) -> String {
    // The API HTML-escapes some titles and channel names.
    scraper::Html::parse_fragment(title)
        .root_element()
        .text()
        .collect::<String>()
}

pub(crate) fn parse_search(body: &[u8]) -> Result<SearchPage, String> {
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

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct FeedVideo {
    pub(crate) id: String,
    pub(crate) title: String,
    pub(crate) channel: String,
    pub(crate) published_at: String,
}

pub(crate) enum ChannelInput {
    Id(String),
    Handle(String),
    User(String),
    Query(String),
}

pub(crate) fn channel_input(input: &str) -> ChannelInput {
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

pub(crate) fn api_error(status: u16, body: &[u8]) -> String {
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

pub(crate) fn channel_from_api(items: &[Value], fallback_id: &str) -> Result<Subscription, String> {
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

pub(crate) fn parse_duration(value: &str) -> Option<u64> {
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

pub(crate) fn short_by_title(title: &str) -> bool {
    let lower = title.to_lowercase();
    lower.contains("#shorts")
        || lower.contains("쇼츠")
        || lower.split_whitespace().any(|word| word == "shorts")
}

pub(crate) fn live_by_title(title: &str) -> bool {
    let lower = title.to_lowercase();
    lower.contains("라이브")
        || lower.contains("#live")
        || lower.split_whitespace().any(|word| word == "live")
}

pub(crate) struct VideoDetails {
    pub(crate) seconds: Option<u64>,
    pub(crate) live: bool,
    pub(crate) completed_live: bool,
}

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Subscription {
    pub(crate) channel_id: String,
    pub(crate) title: String,
    pub(crate) uploads_playlist_id: String,
}

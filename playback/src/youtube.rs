use qtbridge::{qobject, QmlObject};
use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::io::Read;
use std::sync::OnceLock;
use std::time::Duration;
use url::Url;

static CLIENT: OnceLock<Result<Client, String>> = OnceLock::new();

#[derive(Default)]
pub struct YouTube {
    request: i32,
}

#[qobject(Singleton, ConvertToCamelCase)]
impl YouTube {
    qproperty!("configured", Read = configured, Constant);

    #[qsignal]
    fn search_finished(&mut self, request: i32, result: &Value);

    fn configured(&self) -> bool {
        api_key().is_some()
    }

    #[qslot]
    fn resolve_link(&self, link: String) -> String {
        video_id(&link)
            .map(|id| format!("https://www.youtube.com/watch?v={id}"))
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
}

fn api_key() -> Option<String> {
    std::env::var("SORI_YOUTUBE_API_KEY")
        .ok()
        .map(|key| key.trim().to_owned())
        .filter(|key| !key.is_empty())
}

fn valid_id(id: &str) -> bool {
    id.len() == 11
        && id
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
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

fn search(query: &str, page: &str) -> Result<SearchPage, String> {
    let key = api_key().ok_or("Set SORI_YOUTUBE_API_KEY to search YouTube from Sori.")?;
    let query = query.trim();
    if query.is_empty() || query.chars().count() > 250 {
        return Err("Enter a search of up to 250 characters.".into());
    }

    let client = CLIENT
        .get_or_init(|| {
            Client::builder()
                .user_agent("Sori/0.1 (Korean immersion desktop app)")
                .timeout(Duration::from_secs(15))
                .redirect(reqwest::redirect::Policy::none())
                .build()
                .map_err(|error| error.to_string())
        })
        .as_ref()
        .map_err(Clone::clone)?;
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
    #[ignore = "requires a YouTube Data API key and network access"]
    fn live_search() {
        assert!(!search("한국어 대화", "").unwrap().videos.is_empty());
    }
}

use reqwest::{Client, StatusCode, Url};
use scraper::Html;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, time::Duration};
use tauri::State;

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Definition {
    pub term: String,
    pub part_of_speech: String,
    pub text: String,
    pub source_url: String,
}

pub struct Dictionary {
    client: Client,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct LanguageEntry {
    part_of_speech: String,
    definitions: Vec<Sense>,
}

#[derive(Deserialize)]
struct Sense {
    definition: String,
}

pub fn source_url(term: &str) -> String {
    let mut url = Url::parse("https://en.wiktionary.org/wiki/").expect("constant dictionary URL");
    url.path_segments_mut().unwrap().pop_if_empty().push(term);
    url.set_fragment(Some("Korean"));
    url.into()
}

impl Dictionary {
    pub fn new() -> Result<Self, reqwest::Error> {
        Ok(Self {
            client: Client::builder()
                .user_agent("Sori/0.1 (Korean immersion desktop app; dictionary lookup)")
                .timeout(Duration::from_secs(15))
                .redirect(reqwest::redirect::Policy::none())
                .build()?,
        })
    }

    async fn lookup(&self, term: &str) -> Result<Vec<Definition>, String> {
        let term = term.trim();
        if term.is_empty() || term.chars().count() > 100 || term.chars().any(char::is_control) {
            return Err("Enter a word of up to 100 characters.".into());
        }
        let mut url = Url::parse("https://en.wiktionary.org/api/rest_v1/page/definition/").unwrap();
        url.path_segments_mut().unwrap().pop_if_empty().push(term);
        let mut response = self.client.get(url).send().await.map_err(|_| {
            "Couldn't reach Wiktionary. Check your connection and try again.".to_string()
        })?;
        match response.status() {
            StatusCode::NOT_FOUND => return Ok(vec![]),
            StatusCode::TOO_MANY_REQUESTS => {
                return Err("Wiktionary is busy. Please wait before trying again.".into());
            }
            status if !status.is_success() => {
                return Err("Wiktionary is temporarily unavailable. Try again later.".into());
            }
            _ => {}
        }
        let mut body = Vec::new();
        while let Some(chunk) = response
            .chunk()
            .await
            .map_err(|_| "Dictionary response was interrupted.")?
        {
            if body.len() + chunk.len() > 2 * 1024 * 1024 {
                return Err(
                    "This dictionary entry is too large. Open it on Wiktionary instead.".into(),
                );
            }
            body.extend_from_slice(&chunk);
        }
        parse_definitions(term, &body)
    }
}

fn parse_definitions(term: &str, body: &[u8]) -> Result<Vec<Definition>, String> {
    let entries: HashMap<String, Vec<LanguageEntry>> =
        serde_json::from_slice(body).map_err(|_| {
            "Wiktionary returned an unexpected response. Try opening the full entry.".to_string()
        })?;
    let mut definitions = Vec::new();
    for entry in entries.get("ko").into_iter().flatten() {
        for sense in &entry.definitions {
            // Remote markup is converted to plain text and never executed in the webview.
            let html = Html::parse_fragment(&sense.definition);
            let text = html.root_element().text().collect::<String>();
            let text = text.split_whitespace().collect::<Vec<_>>().join(" ");
            if !text.is_empty() {
                definitions.push(Definition {
                    term: term.into(),
                    part_of_speech: entry.part_of_speech.clone(),
                    text,
                    source_url: source_url(term),
                });
            }
        }
    }
    Ok(definitions)
}

#[tauri::command]
pub async fn lookup_dictionary(
    dictionary: State<'_, Dictionary>,
    term: String,
) -> Result<Vec<Definition>, String> {
    dictionary.lookup(&term).await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_only_korean_definitions_as_plain_text() {
        let body = br#"{"en":[{"partOfSpeech":"Noun","definitions":[{"definition":"English"}]}],"ko":[{"partOfSpeech":"Noun","definitions":[{"definition":"<a href='/wiki/mind'>mind</a> &amp; <b>heart</b>"}]}]}"#;
        let result = parse_definitions("마음", body).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].text, "mind & heart");
        assert_eq!(result[0].part_of_speech, "Noun");
        assert!(result[0].source_url.ends_with("#Korean"));
        assert!(parse_definitions("missing", b"{}").unwrap().is_empty());
        assert!(parse_definitions("bad", b"invalid").is_err());
    }

    #[test]
    fn encodes_terms_as_one_url_segment() {
        let url = source_url("a/b?#");
        assert!(url.contains("a%2Fb%3F%23"));
        assert!(url.starts_with("https://en.wiktionary.org/wiki/a"));
    }

    #[test]
    #[ignore = "requires access to the live Wiktionary API"]
    fn live_korean_lookup() {
        tauri::async_runtime::block_on(async {
            let dictionary = Dictionary::new().unwrap();
            for term in ["마음", "가다", "학교", "-은", "좋다"] {
                let definitions = dictionary.lookup(term).await.unwrap();
                assert!(
                    !definitions.is_empty(),
                    "missing Korean definitions for {term}"
                );
                assert!(definitions.iter().all(|item| !item.text.contains("<a ")));
            }
            assert!(
                dictionary
                    .lookup("sori-no-such-word-123456789")
                    .await
                    .unwrap()
                    .is_empty()
            );
        });
    }
}

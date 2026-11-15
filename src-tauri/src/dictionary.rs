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
    #[serde(default)]
    pub hanja: Option<String>,
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
        let mut definitions = parse_definitions(term, &body)?;
        if !definitions.is_empty()
            && let Ok(wikitext) = self.wikitext(term).await
        {
            attach_hanja(&mut definitions, &body, &wikitext);
        }
        Ok(definitions)
    }

    async fn wikitext(&self, term: &str) -> Result<String, String> {
        let mut url = Url::parse("https://en.wiktionary.org/w/api.php").unwrap();
        url.query_pairs_mut().extend_pairs([
            ("action", "parse"),
            ("page", term),
            ("prop", "wikitext"),
            ("format", "json"),
            ("formatversion", "2"),
            ("redirects", "1"),
        ]);
        let mut response = self
            .client
            .get(url)
            .timeout(Duration::from_secs(5))
            .send()
            .await
            .map_err(|error| error.to_string())?
            .error_for_status()
            .map_err(|error| error.to_string())?;
        let mut body = Vec::new();
        while let Some(chunk) = response.chunk().await.map_err(|error| error.to_string())? {
            if body.len() + chunk.len() > 2 * 1024 * 1024 {
                return Err("Dictionary page too large.".into());
            }
            body.extend_from_slice(&chunk);
        }
        let value: serde_json::Value =
            serde_json::from_slice(&body).map_err(|error| error.to_string())?;
        value
            .pointer("/parse/wikitext")
            .and_then(|text| text.as_str())
            .map(str::to_owned)
            .ok_or_else(|| "Missing dictionary page.".into())
    }
}

// Restrict extraction to Korean headword lines and explicitly annotated derivations.
// Characters in quotations, historical spellings, and related words are unrelated.
fn hanja_entries(wikitext: &str) -> Vec<(String, Option<String>)> {
    let mut korean = false;
    let mut inherited = None;
    let mut entries = Vec::new();
    for line in wikitext.lines().map(str::trim) {
        if line.starts_with("==") && !line.starts_with("===") {
            korean = line.trim_matches('=').trim() == "Korean";
        }
        if !korean {
            continue;
        }
        if line.starts_with('=') && line.trim_matches('=').trim().starts_with("Etymology") {
            inherited = None;
        }
        if !line.starts_with("{{") {
            continue;
        }
        let Some(end) = line.find("}}") else {
            continue;
        };
        let fields: Vec<_> = line[2..end].split('|').map(str::trim).collect();
        let name = fields[0];
        if matches!(name, "af" | "affix") && fields.get(1) == Some(&"ko") && fields.len() >= 4 {
            // Resolve only the explicitly annotated base + a recognized Korean suffix.
            let base = fields[2];
            if let Some((_, spelling)) = base.split_once('(')
                && let Some(spelling) = spelling.strip_suffix(')')
            {
                let suffix = fields[3].trim_start_matches('-');
                if matches!(suffix, "하다" | "되다" | "적") {
                    inherited = clean_hanja(spelling).map(|hanja| format!("{hanja}{suffix}"));
                }
            }
        }
        if matches!(name, "ko-etym-sino" | "ko-etym-Sino") && fields.len() >= 2 {
            inherited = clean_hanja(fields[1]);
        }
        let pos = match name {
            "ko-noun" => "Noun",
            "ko-proper noun" => "Proper noun",
            "ko-verb" => "Verb",
            "ko-adj" => "Adjective",
            "ko-adv" => "Adverb",
            _ => continue,
        };
        let explicit = fields.iter().find_map(|field| {
            let (key, value) = field.split_once('=')?;
            matches!(key.trim(), "hanja" | "occasional hanja")
                .then(|| clean_hanja(value))
                .flatten()
        });
        entries.push((pos.into(), explicit.or_else(|| inherited.clone())));
    }
    entries
}

fn clean_hanja(value: &str) -> Option<String> {
    let value = value.replace("[[", "").replace("]]", "");
    let value = value.trim();
    let is_han = |ch: char| matches!(ch as u32, 0x3400..=0x4dbf | 0x4e00..=0x9fff | 0xf900..=0xfaff | 0x20000..=0x323af);
    if value.chars().any(is_han)
        && value.chars().all(|ch| {
            is_han(ch) || matches!(ch, '/' | ' ' | '·' | '、') || ('가'..='힣').contains(&ch)
        })
    {
        Some(value.to_owned())
    } else {
        None
    }
}

fn attach_hanja(definitions: &mut [Definition], body: &[u8], wikitext: &str) {
    let Ok(entries) = serde_json::from_slice::<HashMap<String, Vec<LanguageEntry>>>(body) else {
        return;
    };
    let Some(korean) = entries.get("ko") else {
        return;
    };
    let headwords = hanja_entries(wikitext);
    // Preserve homonym boundaries. Omit enrichment if the two endpoints disagree.
    if headwords.len() != korean.len()
        || headwords
            .iter()
            .zip(korean)
            .any(|((pos, _), entry)| pos != &entry.part_of_speech)
    {
        return;
    }
    let mut index = 0;
    for ((_, hanja), entry) in headwords.iter().zip(korean) {
        for sense in &entry.definitions {
            if Html::parse_fragment(&sense.definition)
                .root_element()
                .text()
                .any(|text| !text.trim().is_empty())
            {
                if let Some(definition) = definitions.get_mut(index) {
                    definition.hanja = hanja.clone();
                }
                index += 1;
            }
        }
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
                    hanja: None,
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
    fn extracts_hanja_from_headwords_and_derived_verbs_only() {
        let text = "==Chinese==\n{{ko-noun|hanja=錯誤}}\n==Korean==\n===Etymology===\n{{ko-etym-native|心音}}\n===Noun===\n{{ko-noun}}\n# {{ux|ko|學校}}\n===Etymology 2===\n{{af|ko|충전(充電)|-하다|t2=to do}}\n====Verb====\n{{ko-verb}}\n===Etymology 3===\n{{af|ko|충전(充塡)|-하다}}\n====Verb====\n{{ko-verb}}\n==Japanese==\n{{ko-noun|hanja=無關}}";
        assert_eq!(
            hanja_entries(text),
            vec![
                ("Noun".into(), None),
                ("Verb".into(), Some("充電하다".into())),
                ("Verb".into(), Some("充塡하다".into())),
            ]
        );
        assert_eq!(
            hanja_entries("==Korean==\n{{ko-noun|hanja=[[學校]]}}"),
            vec![("Noun".into(), Some("學校".into()))]
        );
        assert_eq!(clean_hanja("{{unknown|學校}}"), None);
        assert_eq!(
            hanja_entries(
                "==Korean==\n===Etymology 1===\n{{ko-etym-sino|學界}}\n====Noun====\n{{ko-noun}}\n===Etymology 2===\n{{ko-etym-sino|學契}}\n====Noun====\n{{ko-noun}}"
            ),
            vec![
                ("Noun".into(), Some("學界".into())),
                ("Noun".into(), Some("學契".into()))
            ]
        );
    }

    #[test]
    fn assigns_hanja_to_each_homonym_and_accepts_legacy_snapshots() {
        let body = br#"{"ko":[{"partOfSpeech":"Verb","definitions":[{"definition":"charge"}]},{"partOfSpeech":"Verb","definitions":[{"definition":"fill"}]}]}"#;
        let mut definitions = parse_definitions("충전하다", body).unwrap();
        let wiki = "==Korean==\n===Etymology 1===\n{{af|ko|충전(充電)|-하다}}\n{{ko-verb}}\n===Etymology 2===\n{{af|ko|충전(充塡)|-하다}}\n{{ko-verb}}";
        attach_hanja(&mut definitions, body, wiki);
        assert_eq!(definitions[0].hanja.as_deref(), Some("充電하다"));
        assert_eq!(definitions[1].hanja.as_deref(), Some("充塡하다"));
        let legacy = r#"{"term":"마음","partOfSpeech":"Noun","text":"heart","sourceUrl":"https://en.wiktionary.org/wiki/마음"}"#;
        assert_eq!(
            serde_json::from_str::<Definition>(legacy).unwrap().hanja,
            None
        );
        let mut unmatched = parse_definitions("충전하다", body).unwrap();
        attach_hanja(&mut unmatched, body, "==Korean==\n{{ko-verb}}");
        assert!(unmatched.iter().all(|item| item.hanja.is_none()));
    }

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
                if term == "학교" {
                    assert_eq!(definitions[0].hanja.as_deref(), Some("學校"));
                }
                if term == "마음" {
                    assert!(definitions.iter().all(|item| item.hanja.is_none()));
                }
            }
            let homonyms = dictionary.lookup("충전하다").await.unwrap();
            assert_eq!(homonyms[0].hanja.as_deref(), Some("充電하다"));
            assert_eq!(homonyms[1].hanja.as_deref(), Some("充塡하다"));
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

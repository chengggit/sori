use crate::dictionary::{clean_hanja, Definition};
use reqwest::blocking::Client;
use rusqlite::{Connection, OptionalExtension};
use std::io::Read;
use std::sync::OnceLock;
use std::time::Duration;

static CLIENT: OnceLock<Result<Client, String>> = OnceLock::new();

pub fn read_settings(db: &Connection) -> Result<(Option<String>, String), String> {
    let key = db
        .query_row(
            "SELECT value FROM app_settings WHERE key='krdict_api_key'",
            [],
            |row| row.get(0),
        )
        .optional()
        .map_err(|e| e.to_string())?;
    let provider: Option<String> = db
        .query_row(
            "SELECT value FROM app_settings WHERE key='analysis_dictionary'",
            [],
            |row| row.get(0),
        )
        .optional()
        .map_err(|e| e.to_string())?;
    let provider = if provider.as_deref() == Some("krdict") && key.is_some() {
        "krdict"
    } else {
        "wiktionary"
    };
    Ok((key, provider.into()))
}

pub fn save_key(db: &Connection, input: &str) -> Result<String, String> {
    let key = input.trim();
    if key.len() != 32 || !key.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err("KRDict keys must contain 32 hexadecimal characters.".into());
    }
    #[cfg(unix)]
    if let Some(path) = db
        .path()
        .filter(|path| !path.is_empty() && *path != ":memory:")
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))
            .map_err(|_| "Could not protect the local API key settings.")?;
    }
    let key = key.to_owned();
    db.execute("INSERT INTO app_settings(key,value) VALUES('krdict_api_key',?1) ON CONFLICT(key) DO UPDATE SET value=excluded.value", [&key])
        .map_err(|e| e.to_string())?;
    Ok(key)
}

pub fn select(db: &Connection, provider: &str) -> Result<(), String> {
    if !matches!(provider, "wiktionary" | "krdict") {
        return Err("Choose Wiktionary or KRDict.".into());
    }
    if provider == "krdict" && read_settings(db)?.0.is_none() {
        return Err("Save a KRDict API key first.".into());
    }
    db.execute("INSERT INTO app_settings(key,value) VALUES('analysis_dictionary',?1) ON CONFLICT(key) DO UPDATE SET value=excluded.value", [provider])
        .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn remove_key(db: &mut Connection) -> Result<(), String> {
    let transaction = db.transaction().map_err(|e| e.to_string())?;
    transaction
        .execute("DELETE FROM app_settings WHERE key='krdict_api_key'", [])
        .map_err(|e| e.to_string())?;
    transaction.execute("UPDATE app_settings SET value='wiktionary' WHERE key='analysis_dictionary' AND value='krdict'", []).map_err(|e| e.to_string())?;
    transaction.commit().map_err(|e| e.to_string())
}

/// Only accept canonical entry links emitted by this provider.
pub fn is_source_url(url: &str) -> bool {
    url.strip_prefix("https://krdict.korean.go.kr/eng/dicSearch/SearchView?ParaWordNo=")
        .is_some_and(|code| !code.is_empty() && code.bytes().all(|byte| byte.is_ascii_digit()))
}

pub fn lookup(term: &str, key: &str) -> Result<Vec<Definition>, String> {
    let term = term.trim();
    if term.is_empty() || term.chars().count() > 100 || term.chars().any(char::is_control) {
        return Err("Enter a word of up to 100 characters.".into());
    }
    let client = CLIENT
        .get_or_init(|| {
            Client::builder()
                .timeout(Duration::from_secs(15))
                .redirect(reqwest::redirect::Policy::none())
                .user_agent("Sori/0.1 (Korean dictionary lookup)")
                .build()
                .map_err(|_| "Could not initialize KRDict networking.".into())
        })
        .as_ref()
        .map_err(Clone::clone)?;
    let mut url = url::Url::parse("https://krdict.korean.go.kr/api/search").unwrap();
    url.query_pairs_mut().extend_pairs([
        ("key", key),
        ("q", term),
        ("part", "word"),
        ("advanced", "y"),
        ("method", "exact"),
        ("translated", "y"),
        ("trans_lang", "1"),
        ("num", "100"),
    ]);
    let response = client
        .get(url)
        .send()
        .map_err(|_| "Could not reach KRDict. Check your connection and retry.")?;
    if !response.status().is_success() {
        return Err("KRDict is temporarily unavailable. Try again later.".into());
    }
    let mut bytes = Vec::new();
    response
        .take(1024 * 1024 + 1)
        .read_to_end(&mut bytes)
        .map_err(|_| "Could not read the KRDict response.")?;
    if bytes.len() > 1024 * 1024 {
        return Err("The KRDict response exceeded the size limit.".into());
    }
    parse(
        term,
        std::str::from_utf8(&bytes).map_err(|_| "KRDict returned invalid text.")?,
    )
}

fn child_text(node: roxmltree::Node<'_, '_>, name: &str) -> String {
    node.children()
        .find(|child| child.has_tag_name(name))
        .map(|child| {
            child
                .descendants()
                .filter(|node| node.is_text())
                .filter_map(|node| node.text())
                .collect::<String>()
                .trim()
                .to_owned()
        })
        .unwrap_or_default()
}

fn normalized(word: &str) -> String {
    word.replace(['^', '-'], "")
}

fn parse(term: &str, xml: &str) -> Result<Vec<Definition>, String> {
    let document =
        roxmltree::Document::parse(xml).map_err(|_| "KRDict returned an invalid response.")?;
    let root = document.root_element();
    if root.has_tag_name("error") {
        return Err(match child_text(root, "error_code").as_str() {
            "020" => "KRDict rejected this API key. Replace it in Settings.",
            "021" => "The KRDict API key is temporarily disabled.",
            "010" => "The KRDict daily request limit has been reached.",
            _ => "KRDict could not complete this lookup. Try again later.",
        }
        .into());
    }
    if !root.has_tag_name("channel") {
        return Err("KRDict returned an invalid response.".into());
    }
    let mut definitions = Vec::new();
    for item in root.children().filter(|child| child.has_tag_name("item")) {
        let word = child_text(item, "word");
        if normalized(&word) != normalized(term) {
            continue;
        }
        let code = child_text(item, "target_code");
        if code.is_empty() || !code.bytes().all(|byte| byte.is_ascii_digit()) {
            continue;
        }
        let source_url =
            format!("https://krdict.korean.go.kr/eng/dicSearch/SearchView?ParaWordNo={code}");
        let hanja = clean_hanja(&child_text(item, "origin"));
        let part_of_speech = child_text(item, "pos");
        for sense in item.children().filter(|child| child.has_tag_name("sense")) {
            let korean = child_text(sense, "definition");
            let translation = sense
                .children()
                .filter(|child| child.has_tag_name("translation"))
                .find(|child| {
                    matches!(
                        child_text(*child, "trans_lang").as_str(),
                        "" | "영어" | "English" | "en" | "1"
                    )
                });
            let english = translation
                .map(|node| {
                    let word = child_text(node, "trans_word");
                    let meaning = child_text(node, "trans_dfn");
                    [word, meaning]
                        .into_iter()
                        .filter(|text| !text.is_empty())
                        .collect::<Vec<_>>()
                        .join(" — ")
                })
                .unwrap_or_default();
            let text = if english.is_empty() { korean } else { english };
            if text.is_empty() {
                continue;
            }
            let definition = Definition {
                term: term.into(),
                part_of_speech: part_of_speech.clone(),
                text,
                source_url: source_url.clone(),
                hanja: hanja.clone(),
                custom: false,
                note: None,
            };
            if !definitions.contains(&definition) {
                definitions.push(definition);
            }
        }
    }
    Ok(definitions)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn parses_exact_entries_english_cdata_hanja_and_korean_fallback() {
        let xml = r#"<channel><total>2</total><item><target_code>1234</target_code><word>학교</word><origin>學校</origin><pos>명사</pos>
        <sense><definition>공부하는 곳.</definition><translation><trans_lang>영어</trans_lang><trans_word>school</trans_word><trans_dfn><![CDATA[A place for learning & teaching.]]></trans_dfn></translation></sense>
        <sense><definition>한국어 뜻풀이.</definition><translation><trans_lang>일본어</trans_lang><trans_word>学校</trans_word></translation></sense>
        </item><item><target_code>5678</target_code><word>대학교</word><pos>명사</pos><sense><definition>다른 단어.</definition></sense></item></channel>"#;
        let definitions = parse("학교", xml).unwrap();
        assert_eq!(definitions.len(), 2);
        assert_eq!(definitions[0].term, "학교");
        assert_eq!(definitions[0].hanja.as_deref(), Some("學校"));
        assert_eq!(definitions[0].part_of_speech, "명사");
        assert_eq!(
            definitions[0].text,
            "school — A place for learning & teaching."
        );
        assert_eq!(definitions[1].text, "한국어 뜻풀이.");
        assert_eq!(
            definitions[0].source_url,
            "https://krdict.korean.go.kr/eng/dicSearch/SearchView?ParaWordNo=1234"
        );
        assert!(!definitions[0].custom);
        assert!(parse("모르는말", xml).unwrap().is_empty());
        assert!(parse("말", "<channel><total>0</total></channel>")
            .unwrap()
            .is_empty());
    }
    #[test]
    fn rejects_xml_errors_and_does_not_echo_server_messages() {
        for (code, message) in [
            ("020", "Replace it in Settings"),
            ("021", "disabled"),
            ("010", "limit"),
        ] {
            let xml = format!(
                "<error><error_code>{code}</error_code><message>do not echo keys</message></error>"
            );
            let error = parse("학교", &xml).unwrap_err();
            assert!(error.contains(message));
            assert!(!error.contains("echo keys"));
        }
        assert!(parse("학교", "<channel>").is_err());
        assert!(parse("학교", "<html>Oops</html>").is_err());
        assert!(parse(
            "학교",
            "<!DOCTYPE channel [<!ENTITY example 'external'>]><channel>&example;</channel>"
        )
        .is_err());
    }
    #[test]
    fn persists_provider_and_key_and_removal_reverts_to_wiktionary() {
        let mut db = Connection::open_in_memory().unwrap();
        db.execute_batch(include_str!("schema.sql")).unwrap();
        assert_eq!(read_settings(&db).unwrap(), (None, "wiktionary".into()));
        assert!(select(&db, "krdict").is_err());
        for invalid in [
            "",
            "1234",
            "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz",
            "0000000000000000000000000000000?",
        ] {
            assert!(save_key(&db, invalid).is_err());
        }
        let key = "0123456789ABCDEF0123456789ABCDEF";
        assert_eq!(save_key(&db, &format!(" {} ", key)).unwrap(), key);
        select(&db, "krdict").unwrap();
        assert_eq!(
            read_settings(&db).unwrap(),
            (Some(key.into()), "krdict".into())
        );
        assert!(select(&db, "invalid").is_err());
        db.execute(
            "INSERT INTO app_settings(key,value) VALUES('youtube_api_key','youtube-test')",
            [],
        )
        .unwrap();
        remove_key(&mut db).unwrap();
        assert_eq!(read_settings(&db).unwrap(), (None, "wiktionary".into()));
        assert_eq!(
            db.query_row(
                "SELECT value FROM app_settings WHERE key='youtube_api_key'",
                [],
                |row| row.get::<_, String>(0)
            )
            .unwrap(),
            "youtube-test"
        );
    }
}

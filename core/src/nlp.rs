use kiwi_rs::{BuilderConfig, Kiwi, KiwiConfig};
use serde::Serialize;
use std::{
    cell::OnceCell,
    path::{Path, PathBuf},
    sync::mpsc::{self, SyncSender},
};

const MAX_TEXT_BYTES: usize = 16 * 1024;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct KoreanToken {
    pub form: String,
    pub tag: String,
    pub surface: String,
    /// Offsets into the original text in UTF-16 code units, matching JS string.slice().
    pub start: usize,
    pub end: usize,
    pub word_index: usize,
    pub sentence_index: usize,
}

struct Request {
    text: String,
    reply: mpsc::Sender<Result<Vec<KoreanToken>, String>>,
}

/// Kiwi stays on its owning thread because its Rust handle is not Send or Sync.
#[derive(Clone)]
pub struct KoreanAnalyzer {
    requests: SyncSender<Request>,
}

impl KoreanAnalyzer {
    pub fn start(resources: PathBuf) -> Result<Self, String> {
        let (requests, receiver) = mpsc::sync_channel::<Request>(8);
        std::thread::Builder::new()
            .name("sori-kiwi".into())
            .spawn(move || {
                // Load the model once, on the first analysis, without blocking app startup.
                let analyzer = OnceCell::new();
                for request in receiver {
                    let result = analyzer
                        .get_or_init(|| load(&resources))
                        .as_ref()
                        .map_err(Clone::clone)
                        .and_then(|kiwi| tokenize(kiwi, &request.text));
                    let _ = request.reply.send(result);
                }
            })
            .map_err(|error| error.to_string())?;
        Ok(Self { requests })
    }

    pub fn analyze(&self, text: String) -> Result<Vec<KoreanToken>, String> {
        validate(&text)?;
        if text.trim().is_empty() {
            return Ok(Vec::new());
        }
        let (reply, response) = mpsc::channel();
        self.requests
            .try_send(Request { text, reply })
            .map_err(|error| match error {
                mpsc::TrySendError::Full(_) => {
                    "Korean analysis is busy. Try again shortly.".to_string()
                }
                mpsc::TrySendError::Disconnected(_) => {
                    "Korean analysis worker is unavailable.".to_string()
                }
            })?;
        response
            .recv()
            .map_err(|_| "Korean analysis worker stopped.".to_string())?
    }
}

fn validate(text: &str) -> Result<(), String> {
    if text.len() > MAX_TEXT_BYTES {
        return Err("Analyze a text passage no larger than 16 KiB at a time.".into());
    }
    if text.contains('\0') {
        return Err("Text for Korean analysis cannot contain null characters.".into());
    }
    Ok(())
}

fn load(resources: &Path) -> Result<Kiwi, String> {
    let library = resources.join("lib").join(format!(
        "{}kiwi{}",
        std::env::consts::DLL_PREFIX,
        std::env::consts::DLL_SUFFIX
    ));
    let models = resources.join("models/cong/base");
    if !library.is_file() || !models.join("sj.morph").is_file() {
        return Err(
            "Kiwi resources are missing. Run cmake -P scripts/setup-kiwi.cmake and restart Sori.".into(),
        );
    }
    #[cfg(test)]
    eprintln!("Kiwi: initializing library {library:?} and model {models:?}");
    let builder = BuilderConfig::default()
        .with_model_path(models)
        .with_num_threads(1);
    let config = KiwiConfig::default()
        .with_library_path(library)
        .with_builder(builder);
    let kiwi = Kiwi::from_config(config)
        .map_err(|error| format!("Could not load bundled Kiwi resources: {error}"))?;
    #[cfg(test)]
    eprintln!("Kiwi: initialization completed");
    if !kiwi.supports_utf16_api() {
        return Err("The bundled Kiwi library does not support the required UTF-16 APIs.".into());
    }
    Ok(kiwi)
}

fn tokenize(kiwi: &Kiwi, text: &str) -> Result<Vec<KoreanToken>, String> {
    let utf16: Vec<u16> = text.encode_utf16().collect();
    #[cfg(test)]
    eprintln!("Kiwi: analyzing {} UTF-16 units", utf16.len());
    let tokens = kiwi
        .tokenize_utf16(&utf16)
        .map_err(|error| error.to_string())?;
    #[cfg(test)]
    eprintln!("Kiwi: native analysis returned {} tokens", tokens.len());
    tokens
        .into_iter()
        .map(|token| {
            let start = token.position;
            let end = start
                .checked_add(token.length)
                .ok_or("Invalid Kiwi token offset.")?;
            let span = utf16.get(start..end).ok_or("Invalid Kiwi token offset.")?;
            let surface =
                String::from_utf16(span).map_err(|_| "Invalid Kiwi token Unicode boundary.")?;
            Ok(KoreanToken {
                form: token.form,
                tag: token.tag,
                surface,
                start,
                end,
                word_index: token.word_position,
                sentence_index: token.sent_position,
            })
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_input_before_loading_resources() {
        let analyzer = KoreanAnalyzer::start(PathBuf::from("missing-kiwi-test-resources")).unwrap();
        assert!(analyzer.analyze(" \n\t".into()).unwrap().is_empty());
        assert!(analyzer
            .analyze("a".repeat(MAX_TEXT_BYTES + 1))
            .unwrap_err()
            .contains("16 KiB"));
        assert!(analyzer
            .analyze("안녕\0하세요".into())
            .unwrap_err()
            .contains("null"));
        assert!(analyzer
            .analyze("한국어".into())
            .unwrap_err()
            .contains("setup-kiwi.cmake"));
    }

    #[test]
    #[ignore = "requires native Kiwi resources from cmake -P scripts/setup-kiwi.cmake"]
    fn analyzes_korean_offline_with_utf16_offsets() {
        let resources = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../resources/kiwi");
        let analyzer = KoreanAnalyzer::start(resources).unwrap();
        let example = analyzer.analyze("마음만큼은".into()).unwrap();
        let forms: Vec<_> = example.iter().map(|token| token.form.as_str()).collect();
        assert_eq!(forms, ["마음", "만큼", "은"]);
        let tags: Vec<_> = example.iter().map(|token| token.tag.as_str()).collect();
        assert_eq!(tags, ["NNG", "JKB", "JX"]);
        for text in [
            "학교에 갔어요.",
            "😀 학교에 갔어요.\n한국어를 공부해요.",
            "Hello, 학교!",
            "학교에 갔어요.",
        ] {
            let tokens = analyzer.analyze(text.into()).unwrap();
            assert!(!tokens.is_empty());
            assert!(
                tokens
                    .iter()
                    .any(|token| token.form == "학교" || token.form == "한국어"),
                "{text}: {tokens:?}"
            );
            let utf16: Vec<u16> = text.encode_utf16().collect();
            for token in &tokens {
                assert_eq!(
                    token.surface,
                    String::from_utf16(&utf16[token.start..token.end]).unwrap()
                );
                assert!(!token.tag.is_empty());
            }
            if text.starts_with('😀') {
                assert_eq!(
                    tokens
                        .iter()
                        .find(|token| token.form == "학교")
                        .unwrap()
                        .start,
                    3
                );
            }
            if text.contains("갔어요") {
                assert!(tokens
                    .iter()
                    .any(|token| token.form == "가" && token.tag.starts_with("VV")));
            }
        }
    }
}

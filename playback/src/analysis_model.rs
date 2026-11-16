use crate::{dictionary::Dictionary, nlp::KoreanAnalyzer, reader};
use qtbridge::{qobject, QmlObject};
use serde_json::{json, Value};
use std::sync::OnceLock;

static DICTIONARY: OnceLock<Result<Dictionary, String>> = OnceLock::new();

#[derive(Default)]
pub struct Analysis {
    analyzer: Option<KoreanAnalyzer>,
    initialization_error: String,
    request: i32,
    dictionary_request: i32,
}

#[qobject(Singleton, ConvertToCamelCase)]
impl Analysis {
    #[qsignal]
    fn finished(&mut self, request: i32, result: &Value);

    #[qsignal]
    fn dictionary_finished(&mut self, request: i32, result: &Value);

    #[qslot]
    fn initialize(&mut self, resources: String) {
        if self.analyzer.is_none() {
            match KoreanAnalyzer::start(resources.into()) {
                Ok(analyzer) => self.analyzer = Some(analyzer),
                Err(error) => self.initialization_error = error,
            }
        }
    }

    #[qslot]
    fn analyze(&mut self, text: String, start: i32, end: i32) -> i32 {
        self.request = self.request.wrapping_add(1).max(1);
        let request = self.request;
        let analyzer = self.analyzer.clone();
        let error = self.initialization_error.clone();
        let handle = self.get_thread_handle();
        // The analyzer owns a bounded queue and loads the model on its own thread.
        std::thread::spawn(move || {
            let result = analyzer
                .ok_or(error)
                .and_then(|analyzer| {
                    reader::analyze(&analyzer, &text, start as usize, end as usize)
                })
                .map(|analysis| json!(analysis))
                .unwrap_or_else(|error| json!({ "error": error }));
            let _ = handle.invoke_mut(move |model| model.finished(request, &result));
        });
        request
    }

    #[qslot]
    fn lookup_dictionary(&mut self, term: String) -> i32 {
        self.dictionary_request = self.dictionary_request.wrapping_add(1).max(1);
        let request = self.dictionary_request;
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let result = DICTIONARY
                .get_or_init(|| Dictionary::new().map_err(|error| error.to_string()))
                .as_ref()
                .map_err(Clone::clone)
                .and_then(|dictionary| dictionary.lookup(&term))
                .map(|definitions| json!({ "definitions": definitions }))
                .unwrap_or_else(|error| json!({ "error": error }));
            let _ = handle.invoke_mut(move |model| model.dictionary_finished(request, &result));
        });
        request
    }
}

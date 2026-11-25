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
    passage_request: i32,
    settings_database: Option<crate::db::Database>,
    krdict_key: Option<String>,
    dictionary_provider: String,
    dictionary_settings_error: String,
}

#[qobject(Singleton, ConvertToCamelCase)]
impl Analysis {
    qproperty!(
        "defaultDictionary",
        Read = default_dictionary,
        Notify = dictionary_settings_changed
    );
    qproperty!(
        "krdictConfigured",
        Read = krdict_configured,
        Notify = dictionary_settings_changed
    );
    qproperty!(
        "krdictKey",
        Read = saved_krdict_key,
        Notify = dictionary_settings_changed
    );
    qproperty!(
        "dictionarySettingsError",
        Member = dictionary_settings_error,
        Notify = dictionary_settings_changed
    );

    #[qsignal]
    fn dictionary_settings_changed(&mut self);

    fn default_dictionary(&self) -> String {
        if self.dictionary_provider == "krdict" {
            "krdict"
        } else {
            "wiktionary"
        }
        .into()
    }

    fn krdict_configured(&self) -> bool {
        self.krdict_key.is_some()
    }

    fn saved_krdict_key(&self) -> String {
        self.krdict_key.clone().unwrap_or_default()
    }

    fn settings_connection(&self) -> Result<rusqlite::Connection, String> {
        self.settings_database
            .as_ref()
            .ok_or("Dictionary settings are unavailable.")?
            .connect()
    }

    #[qslot]
    fn initialize_dictionary(&mut self, directory: String) -> Value {
        let result = crate::db::Database::initialize(directory.into()).and_then(|database| {
            let (key, provider) = crate::krdict::read_settings(&database.connect()?)?;
            self.settings_database = Some(database);
            self.krdict_key = key;
            self.dictionary_provider = provider;
            Ok(())
        });
        self.dictionary_settings_error = result.as_ref().err().cloned().unwrap_or_default();
        self.dictionary_settings_changed();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn save_krdict_key(&mut self, key: String) -> Value {
        match self
            .settings_connection()
            .and_then(|db| crate::krdict::save_key(&db, &key))
        {
            Ok(key) => {
                self.krdict_key = Some(key);
                self.dictionary_settings_changed();
                crate::bridge::reply(Ok(()))
            }
            Err(error) => crate::bridge::reply::<()>(Err(error)),
        }
    }

    #[qslot]
    fn remove_krdict_key(&mut self) -> Value {
        match self
            .settings_connection()
            .and_then(|mut db| crate::krdict::remove_key(&mut db))
        {
            Ok(()) => {
                self.krdict_key = None;
                self.dictionary_provider = "wiktionary".into();
                self.dictionary_settings_changed();
                crate::bridge::reply(Ok(()))
            }
            Err(error) => crate::bridge::reply::<()>(Err(error)),
        }
    }

    #[qslot]
    fn set_default_dictionary(&mut self, provider: String) -> Value {
        match self
            .settings_connection()
            .and_then(|db| crate::krdict::select(&db, &provider))
        {
            Ok(()) => {
                self.dictionary_provider = provider;
                self.dictionary_settings_changed();
                crate::bridge::reply(Ok(()))
            }
            Err(error) => crate::bridge::reply::<()>(Err(error)),
        }
    }

    #[qsignal]
    fn finished(&mut self, request: i32, result: &Value);

    #[qsignal]
    fn dictionary_finished(&mut self, request: i32, result: &Value);

    #[qslot]
    fn initialize(&mut self, resources: String) -> Value {
        if self.analyzer.is_none() {
            match KoreanAnalyzer::start(resources.into()) {
                Ok(analyzer) => self.analyzer = Some(analyzer),
                Err(error) => self.initialization_error = error,
            }
        }
        crate::bridge::reply(
            self.analyzer
                .as_ref()
                .map(|_| ())
                .ok_or_else(|| self.initialization_error.clone()),
        )
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
                .map(|analysis| json!(analysis));
            let result = crate::bridge::reply(result);
            handle.invoke_mut(move |model| model.finished(request, &result));
        });
        request
    }

    #[qsignal]
    fn passage_finished(&mut self, request: i32, result: &Value);

    #[qslot]
    fn tokenize_passage(&mut self, text: String) -> i32 {
        self.passage_request = self.passage_request.wrapping_add(1).max(1);
        let request = self.passage_request;
        let analyzer = self.analyzer.clone();
        let error = self.initialization_error.clone();
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let result = analyzer
                .ok_or(error)
                .and_then(|analyzer| reader::word_ranges(&analyzer, text))
                .map(|ranges| json!(ranges));
            let result = crate::bridge::reply(result);
            handle.invoke_mut(move |model| model.passage_finished(request, &result));
        });
        request
    }

    #[qslot]
    fn dictionary_lookup_url(&self, template: String, encoded_word: String) -> Value {
        let url = template.trim().replace("{word}", &encoded_word);
        let result = url::Url::parse(&url)
            .ok()
            .filter(|url| {
                url.scheme() == "https"
                    && url.has_host()
                    && url.username().is_empty()
                    && url.password().is_none()
            })
            .map(String::from)
            .ok_or_else(|| "Enter an HTTPS address without a username or password.".to_string());
        crate::bridge::reply(result)
    }

    #[qslot]
    fn lookup_dictionary(&mut self, term: String) -> i32 {
        self.dictionary_request = self.dictionary_request.wrapping_add(1).max(1);
        let request = self.dictionary_request;
        let handle = self.get_thread_handle();
        let provider = self.default_dictionary();
        let key = self.krdict_key.clone();
        std::thread::spawn(move || {
            let wiktionary = || {
                DICTIONARY
                    .get_or_init(|| Dictionary::new().map_err(|error| error.to_string()))
                    .as_ref()
                    .map_err(Clone::clone)
                    .and_then(|dictionary| dictionary.lookup(&term))
            };
            let lookup = if provider == "krdict" {
                crate::dictionary::fallback_if_empty(
                    key.ok_or_else(|| "Save a KRDict API key in Settings.".to_string())
                        .and_then(|key| crate::krdict::lookup(&term, &key)),
                    wiktionary,
                )
            } else {
                wiktionary()
            };
            let result = lookup.map(|definitions| json!({ "definitions": definitions }));
            let result = crate::bridge::reply(result);
            handle.invoke_mut(move |model| model.dictionary_finished(request, &result));
        });
        request
    }
}

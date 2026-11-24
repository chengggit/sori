use crate::youtube::*;
use qtbridge::{qobject, QmlObject};
use rusqlite::Connection;
use serde_json::{json, Value};
use std::path::PathBuf;

#[derive(Default)]
pub struct YouTube {
    request: i32,
    database: Option<crate::db::Database>,
    settings_error: String,
    subscriptions: Vec<Value>,
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
        Member = subscriptions,
        Notify = subscriptions_changed
    );

    #[qsignal]
    fn configuration_changed(&mut self);

    #[qsignal]
    fn subscriptions_changed(&mut self);

    #[qsignal]
    fn subscription_feed_finished(&mut self, request: i32, result: &Value);

    #[qslot]
    fn initialize(&mut self, directory: String) -> Value {
        let result =
            crate::db::Database::initialize(PathBuf::from(directory)).and_then(|database| {
                let key = read_saved_api_key(&database.connect()?)?;
                self.database = Some(database);
                set_saved_api_key(key);
                self.reload_subscriptions()
            });
        self.settings_error = result.as_ref().err().cloned().unwrap_or_default();
        self.configuration_changed();
        self.subscriptions_changed();
        crate::bridge::reply(result)
    }

    fn saved_key(&self) -> bool {
        has_saved_api_key()
    }

    #[qslot]
    fn save_api_key(&mut self, key: String) -> Value {
        let result = self
            .database
            .as_ref()
            .ok_or_else(|| "Settings are not available.".to_string())
            .and_then(|database| {
                let key = store_api_key(&database.connect()?, &key)?;
                set_saved_api_key(Some(key));
                Ok(())
            });
        if result.is_ok() {
            self.configuration_changed();
        }
        crate::bridge::reply(result)
    }

    #[qslot]
    fn remove_api_key(&mut self) -> Value {
        let result = self
            .database
            .as_ref()
            .ok_or_else(|| "Settings are not available.".to_string())
            .and_then(|database| {
                remove_saved_api_key(&database.connect()?)?;
                set_saved_api_key(None);
                Ok(())
            });
        if result.is_ok() {
            self.configuration_changed();
        }
        crate::bridge::reply(result)
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
            let result = crate::youtube_transcript::fetch(&id, &language);
            let result = crate::bridge::reply(result);
            handle.invoke_mut(move |model| model.transcript_finished(request, &result));
        });
        request
    }

    fn configured(&self) -> bool {
        has_api_key()
    }

    #[qslot]
    fn resolve_link(&self, link: String) -> Value {
        crate::bridge::reply(
            video_id(&link)
                .and_then(|id| watch_url(&id))
                .ok_or_else(|| "Enter a valid YouTube video link.".to_string()),
        )
    }

    #[qslot]
    fn search(&mut self, query: String, page: String) -> i32 {
        self.request = self.request.wrapping_add(1).max(1);
        let request = self.request;
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let result = search(&query, &page).map(|result| json!(result));
            let result = crate::bridge::reply(result);
            handle.invoke_mut(move |model| model.search_finished(request, &result));
        });
        request
    }

    fn connection(&self) -> Result<Connection, String> {
        self.database
            .as_ref()
            .ok_or_else(|| "Settings are not available.".to_string())?
            .connect()
    }

    fn reload_subscriptions(&mut self) -> Result<(), String> {
        let entries = subscriptions(&self.connection()?)?;
        self.subscriptions = entries.into_iter().map(|entry| json!(entry)).collect();
        self.subscriptions_changed();
        Ok(())
    }

    #[qsignal]
    fn channel_resolved(&mut self, request: i32, result: &Value);

    #[qslot]
    fn resolve_channel(&mut self, input: String) -> i32 {
        self.request = self.request.wrapping_add(1).max(1);
        let request = self.request;
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let result = resolve_channel(&input).map(|channel| json!(channel));
            let result = crate::bridge::reply(result);
            handle.invoke_mut(move |model| model.channel_resolved(request, &result));
        });
        request
    }

    #[qslot]
    fn add_subscription(&mut self, id: String, title: String, playlist: String) -> Value {
        let result = self
            .connection()
            .and_then(|connection| add_subscription(&connection, &id, &title, &playlist))
            .and_then(|()| self.reload_subscriptions());
        crate::bridge::reply(result)
    }

    #[qslot]
    fn remove_subscription(&mut self, id: String) -> Value {
        let result = self
            .connection()
            .and_then(|connection| remove_subscription(&connection, &id))
            .and_then(|()| self.reload_subscriptions());
        crate::bridge::reply(result)
    }

    fn request_feed(&mut self, tokens: Value) -> i32 {
        self.request = self.request.wrapping_add(1).max(1);
        let request = self.request;
        let database = self.database.clone();
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let result = database
                .ok_or_else(|| "Settings are not available.".to_string())
                .and_then(|database| subscription_feed(&database, &tokens));
            let result = crate::bridge::reply(result);
            handle.invoke_mut(move |model| model.subscription_feed_finished(request, &result));
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

use crate::{
    library_jobs::{self, LibraryJobs},
    library_service::LibraryService,
    youtube,
};
use qtbridge::{qobject, QmlObject};
use serde_json::Value;
use std::time::{Duration, Instant};

const THUMBNAIL_RETRY_DELAY: Duration = Duration::from_secs(60);
const YOUTUBE_RETRY_DELAY: Duration = Duration::from_secs(60);

fn youtube_metadata_missing(entry: &Value) -> bool {
    let title = entry["title"].as_str().unwrap_or_default().trim();
    let channel = entry["channel"].as_str().unwrap_or_default().trim();
    title.is_empty() || title == "YouTube video" || channel.is_empty()
}

#[derive(Default)]
pub struct Library {
    service: LibraryService,
    jobs: LibraryJobs,
}

#[qobject(Singleton, ConvertToCamelCase)]
impl Library {
    qproperty!("documents", Read = documents, Notify = library_changed);
    qproperty!("videos", Read = videos, Notify = videos_changed);
    qproperty!(
        "recentVideos",
        Read = recent_videos,
        Notify = videos_changed
    );
    qproperty!("error", Read = error, Notify = library_changed);
    qproperty!("vocabulary", Read = vocabulary, Notify = vocabulary_changed);

    #[qsignal]
    fn library_changed(&mut self);

    #[qsignal]
    fn videos_changed(&mut self);

    qproperty!(
        "youtubeHistory",
        Read = youtube_history,
        Notify = youtube_history_changed
    );

    #[qsignal]
    fn youtube_history_changed(&mut self);

    #[qsignal]
    fn youtube_metadata_changed(&mut self, id: &String, title: &String, channel: &String);

    #[qsignal]
    fn vocabulary_changed(&mut self);

    fn documents(&self) -> Vec<Value> {
        self.service.documents.clone()
    }
    fn videos(&self) -> Vec<Value> {
        self.service.videos.clone()
    }
    fn vocabulary(&self) -> Vec<Value> {
        self.service.vocabulary.clone()
    }
    fn youtube_history(&self) -> Vec<Value> {
        self.service.youtube_history.clone()
    }
    fn error(&self) -> String {
        self.service.error.clone()
    }
    fn recent_videos(&self) -> Vec<Value> {
        self.service
            .videos
            .iter()
            .filter(|video| {
                !video["watchedAt"].is_null() || video["seconds"].as_f64().unwrap_or_default() > 0.0
            })
            .cloned()
            .collect()
    }
    #[qslot]
    fn initialize(&mut self, directory: String) -> Value {
        let result = self.service.initialize(directory);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn import_document(&mut self, path: String) -> Value {
        let result = self.service.import_document(path);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn add_document(&mut self, title: String, content: String) -> Value {
        let result = self.service.add_document(title, content);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn update_document(&mut self, id: i64, title: String, content: String) -> Value {
        let result = self.service.update_document(id, title, content);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn remove_document(&mut self, id: i64) -> Value {
        let result = self.service.remove_document(id);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn read_document(&mut self, id: i64) -> Value {
        let result = self.service.read_document(id);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn save_reading_progress(&mut self, id: i64, position: f64) -> Value {
        let result = self.service.save_reading_progress(id, position);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn import_video(&mut self, path: String) -> Value {
        let result = self.service.import_video(path);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn read_video(&mut self, id: i64) -> Value {
        let result = self.service.read_video(id);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn remove_video(&mut self, id: i64) -> Value {
        let result = self.service.remove_video(id);
        if result.is_ok() {
            self.jobs.last_thumbnail_attempt.remove(&id);
        }
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn save_video_progress(&mut self, id: i64, seconds: f64, duration: f64) -> Value {
        let result = self.service.save_video_progress(id, seconds, duration);
        if result.is_ok() {
            self.ensure_video_thumbnail(id);
        }
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn save_youtube_progress(
        &mut self,
        id: String,
        title: String,
        channel: String,
        seconds: f64,
        duration: f64,
    ) -> Value {
        let result = self
            .service
            .save_youtube_progress(id, title, channel, seconds, duration);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn read_youtube_transcript(&mut self, id: String) -> Value {
        let result = self.service.read_youtube_transcript(id);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn cache_youtube_transcript(&mut self, id: String, data: Value) -> Value {
        let result = self.service.cache_youtube_transcript(id, data);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn attach_youtube_transcript(&mut self, id: String, path: String) -> Value {
        let result = self.service.attach_youtube_transcript(id, path);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn save_youtube_transcript_position(&mut self, id: String, position: f64) -> Value {
        let result = self.service.save_youtube_transcript_position(id, position);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn remove_youtube_text_transcript(&mut self, id: String) -> Value {
        let result = self.service.remove_youtube_text_transcript(id);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn find_youtube_word(&mut self, id: String, word: String, context: String) -> Value {
        let result = self.service.find_youtube_word(id, word, context);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn save_youtube_word(&mut self, id: String, title: String, input: Value) -> Value {
        let result = self.service.save_youtube_word(id, title, input);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn read_video_transcript(&mut self, id: i64) -> Value {
        let result = self.service.read_video_transcript(id);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn save_video_transcript(&mut self, id: i64, path: String) -> Value {
        let result = self.service.save_video_transcript(id, path);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn save_transcript_position(&mut self, id: i64, position: f64) -> Value {
        let result = self.service.save_transcript_position(id, position);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn remove_video_transcript(&mut self, id: i64) -> Value {
        let result = self.service.remove_video_transcript(id);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn save_video_subtitles(&mut self, id: i64, path: String) -> Value {
        let result = self.service.save_video_subtitles(id, path);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn save_word(&mut self, kind: String, id: i64, input: Value) -> Value {
        let result = self.service.save_word(kind, id, input);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn find_word(&mut self, kind: String, id: i64, word: String, context: String) -> Value {
        let result = self.service.find_word(kind, id, word, context);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn edit_word(&mut self, id: i64, input: Value) -> Value {
        let result = self.service.edit_word(id, input);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qslot]
    fn remove_word(&mut self, id: i64) -> Value {
        let result = self.service.remove_word(id);
        self.publish_changes();
        crate::bridge::reply(result)
    }

    #[qsignal]
    fn background_finished(&mut self, job: &String, key: &String, response: &Value);

    #[qslot]
    fn ensure_youtube_metadata(&mut self, id: String) -> Value {
        let id = id.trim().to_owned();
        if youtube::watch_url(&id).is_none() {
            return crate::bridge::reply::<bool>(Err("Invalid YouTube video ID.".into()));
        }
        if self.jobs.pending_metadata.contains(&id)
            || self
                .jobs
                .last_metadata_attempt
                .get(&id)
                .is_some_and(|time| time.elapsed() < YOUTUBE_RETRY_DELAY)
            || self
                .service
                .youtube_history
                .iter()
                .any(|entry| entry["youtubeId"] == id && !youtube_metadata_missing(entry))
        {
            return crate::bridge::reply(Ok(false));
        }
        let Some(database) = self.service.database.clone() else {
            return crate::bridge::reply::<bool>(Err("Library unavailable.".into()));
        };
        self.jobs.pending_metadata.insert(id.clone());
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let result = library_jobs::youtube_metadata(&database, &id);
            handle.invoke_mut(move |model| {
                model.jobs.pending_metadata.remove(&id);
                model
                    .jobs
                    .last_metadata_attempt
                    .insert(id.clone(), Instant::now());
                match result {
                    Ok(metadata) => {
                        let refresh = model.service.refresh_youtube_history();
                        model.youtube_metadata_changed(&id, &metadata.title, &metadata.channel);
                        model.finish_job("youtubeMetadata", &id, refresh);
                    }
                    Err(error) => model.finish_job("youtubeMetadata", &id, Err(error)),
                }
            });
        });
        crate::bridge::reply(Ok(true))
    }

    #[qslot]
    fn ensure_youtube_duration(&mut self, id: String) -> Value {
        let id = id.trim().to_owned();
        if youtube::watch_url(&id).is_none() {
            return crate::bridge::reply::<bool>(Err("Invalid YouTube video ID.".into()));
        }
        if !youtube::has_api_key()
            || self.jobs.pending_durations.contains(&id)
            || self
                .jobs
                .last_duration_attempt
                .get(&id)
                .is_some_and(|time| time.elapsed() < YOUTUBE_RETRY_DELAY)
        {
            return crate::bridge::reply(Ok(false));
        }
        let Some(entry) = self
            .service
            .youtube_history
            .iter()
            .find(|entry| entry["youtubeId"] == id)
        else {
            return crate::bridge::reply(Ok(false));
        };
        let seconds = entry["seconds"].as_f64().unwrap_or_default();
        let duration = entry["duration"].as_f64().unwrap_or_default();
        if duration > 0.0 && duration >= seconds {
            return crate::bridge::reply(Ok(false));
        }
        let Some(database) = self.service.database.clone() else {
            return crate::bridge::reply::<bool>(Err("Library unavailable.".into()));
        };
        self.jobs.pending_durations.insert(id.clone());
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let result = library_jobs::youtube_duration(&database, &id);
            handle.invoke_mut(move |model| {
                model.jobs.pending_durations.remove(&id);
                model
                    .jobs
                    .last_duration_attempt
                    .insert(id.clone(), Instant::now());
                let result = result.and_then(|()| model.service.refresh_youtube_history());
                model.finish_job("youtubeDuration", &id, result);
            });
        });
        crate::bridge::reply(Ok(true))
    }

    #[qslot]
    fn ensure_video_thumbnail(&mut self, id: i64) -> Value {
        if self.jobs.pending_thumbnails.contains(&id)
            || self
                .jobs
                .last_thumbnail_attempt
                .get(&id)
                .is_some_and(|time| time.elapsed() < THUMBNAIL_RETRY_DELAY)
        {
            return crate::bridge::reply(Ok(false));
        }
        let Some(database) = self.service.database.clone() else {
            return crate::bridge::reply::<bool>(Err("Library unavailable.".into()));
        };
        self.jobs.pending_thumbnails.insert(id);
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let result = library_jobs::video_thumbnail(&database, id);
            handle.invoke_mut(move |model| {
                model.jobs.pending_thumbnails.remove(&id);
                if model
                    .service
                    .videos
                    .iter()
                    .any(|entry| entry["id"].as_i64() == Some(id))
                {
                    model.jobs.last_thumbnail_attempt.insert(id, Instant::now());
                }
                let result = result.and_then(|changed| {
                    if changed {
                        model.service.refresh_videos()
                    } else {
                        Ok(())
                    }
                });
                model.finish_job("videoThumbnail", &id.to_string(), result);
            });
        });
        crate::bridge::reply(Ok(true))
    }

    fn finish_job(&mut self, job: &str, key: &str, result: Result<(), String>) {
        if let Err(error) = &result {
            self.service.error = error.clone();
            self.service.changes.library = true;
        }
        self.publish_changes();
        self.background_finished(
            &job.to_string(),
            &key.to_string(),
            &crate::bridge::reply(result),
        );
    }

    fn publish_changes(&mut self) {
        let changes = std::mem::take(&mut self.service.changes);
        if changes.library {
            self.library_changed();
        }
        if changes.videos {
            self.videos_changed();
        }
        if changes.history {
            self.youtube_history_changed();
        }
        if changes.vocabulary {
            self.vocabulary_changed();
        }
    }
}

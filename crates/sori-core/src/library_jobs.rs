use std::{
    collections::{HashMap, HashSet},
    time::Instant,
};

#[derive(Default)]
pub struct LibraryJobs {
    pub pending_thumbnails: HashSet<i64>,
    pub pending_metadata: HashSet<String>,
    pub pending_durations: HashSet<String>,
    pub last_thumbnail_attempt: HashMap<i64, Instant>,
    pub last_metadata_attempt: HashMap<String, Instant>,
    pub last_duration_attempt: HashMap<String, Instant>,
}

pub fn youtube_metadata(
    database: &crate::db::Database,
    id: &str,
) -> Result<crate::youtube::Metadata, String> {
    let metadata = crate::youtube::fetch_metadata(id)?;
    crate::youtube::update_metadata(&database.connect()?, id, &metadata.title, &metadata.channel)?;
    Ok(metadata)
}

pub fn youtube_duration(database: &crate::db::Database, id: &str) -> Result<(), String> {
    let duration = crate::youtube::fetch_duration(id)?;
    crate::youtube::update_duration(&database.connect()?, id, duration)
}

pub fn video_thumbnail(database: &crate::db::Database, id: i64) -> Result<bool, String> {
    use crate::video_library;
    use std::path::Path;
    let metadata = video_library::metadata(&database.connect()?, id)?;
    let has_thumbnail = metadata
        .thumbnail
        .as_deref()
        .map(Path::new)
        .is_some_and(video_library::has_thumbnail);
    if metadata.duration > 0.0 && has_thumbnail {
        return Ok(false);
    }
    let duration = if metadata.duration <= 0.0 {
        video_library::probe_duration(&metadata.path)?
    } else {
        metadata.duration
    };
    let output = video_library::thumbnail_path(&database.thumbnail_directory(), id);
    let thumbnail = if has_thumbnail {
        None
    } else {
        video_library::prepare_thumbnail(&metadata.path, &output, duration)?;
        Some(output.as_path())
    };
    let result = video_library::update_metadata(&database.connect()?, id, duration, thumbnail);
    if matches!(result, Ok(false) | Err(_)) && thumbnail.is_some() {
        let _ = std::fs::remove_file(output);
    }
    result
}

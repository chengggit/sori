use super::parsing::{valid_id, Subscription};
use rusqlite::{params, Connection};
use serde_json::{json, Value};

pub(crate) fn update_metadata(
    connection: &Connection,
    id: &str,
    title: &str,
    channel: &str,
) -> Result<(), String> {
    if !valid_id(id) {
        return Err("Invalid YouTube video ID.".into());
    }
    connection
        .execute(
            "UPDATE youtube_watch_history SET title = ?2, channel = ?3 WHERE video_id = ?1",
            params![id, title.trim(), channel.trim()],
        )
        .map_err(|error| error.to_string())?;
    Ok(())
}

pub(crate) fn update_duration(
    connection: &Connection,
    id: &str,
    duration: f64,
) -> Result<(), String> {
    if !valid_id(id) {
        return Err("Invalid YouTube video ID.".into());
    }
    if !duration.is_finite() || duration <= 0.0 {
        return Err("Invalid YouTube video duration.".into());
    }
    connection
        .execute(
            "UPDATE youtube_watch_history SET duration = ?2
             WHERE video_id = ?1 AND seconds <= ?2",
            params![id, duration],
        )
        .map_err(|error| error.to_string())?;
    Ok(())
}

pub(crate) fn watch_history(connection: &Connection) -> Result<Vec<Value>, String> {
    let mut statement = connection
        .prepare(
            "SELECT video_id, title, channel, seconds, duration, watched_at
                  FROM youtube_watch_history ORDER BY watched_at DESC, rowid DESC",
        )
        .map_err(|error| error.to_string())?;
    let entries = statement
        .query_map([], watch_entry_row)
        .map_err(|error| error.to_string())?;
    entries
        .collect::<Result<_, _>>()
        .map_err(|error| error.to_string())
}

pub(crate) fn watch_entry_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<Value> {
    let id: String = row.get(0)?;
    Ok(json!({
        "youtubeId": id,
        "title": row.get::<_, String>(1)?,
        "channel": row.get::<_, String>(2)?,
        "seconds": row.get::<_, f64>(3)?,
        "duration": row.get::<_, f64>(4)?,
        "watchedAt": row.get::<_, i64>(5)?,
        "thumbnailUrl": format!("https://i.ytimg.com/vi/{id}/mqdefault.jpg"),
    }))
}

pub(crate) fn watch_entry(connection: &Connection, id: &str) -> Result<Value, String> {
    connection
        .query_row(
            "SELECT video_id, title, channel, seconds, duration, watched_at
         FROM youtube_watch_history WHERE video_id = ?1",
            [id],
            watch_entry_row,
        )
        .map_err(|error| error.to_string())
}

pub(crate) fn save_watch_progress(
    connection: &Connection,
    id: &str,
    title: &str,
    channel: &str,
    seconds: f64,
    duration: f64,
) -> Result<(), String> {
    if !valid_id(id) || !seconds.is_finite() || seconds < 0.0 {
        return Err("Invalid YouTube playback position.".into());
    }
    let duration = if duration.is_finite() {
        duration.max(0.0)
    } else {
        0.0
    };
    connection.execute(
        "INSERT INTO youtube_watch_history (video_id, title, channel, seconds, duration, watched_at)
         VALUES (?1, ?2, ?3, ?4, ?5, unixepoch())
         ON CONFLICT(video_id) DO UPDATE SET title = excluded.title, channel = excluded.channel,
             seconds = excluded.seconds, watched_at = excluded.watched_at,
             duration = CASE WHEN excluded.duration > 0 THEN excluded.duration ELSE duration END",
        params![id, title, channel, seconds, duration],
    ).map_err(|error| error.to_string())?;
    Ok(())
}

pub(crate) fn subscriptions(connection: &Connection) -> Result<Vec<Subscription>, String> {
    let mut statement = connection
        .prepare(
            "SELECT channel_id, title, uploads_playlist_id FROM youtube_subscriptions
         ORDER BY added_at DESC",
        )
        .map_err(|error| error.to_string())?;
    let entries = statement
        .query_map([], |row| {
            Ok(Subscription {
                channel_id: row.get(0)?,
                title: row.get(1)?,
                uploads_playlist_id: row.get(2)?,
            })
        })
        .map_err(|error| error.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|error| error.to_string());
    entries
}

pub(crate) fn add_subscription(
    connection: &Connection,
    id: &str,
    title: &str,
    playlist: &str,
) -> Result<(), String> {
    if id.trim().is_empty() || title.trim().is_empty() || playlist.trim().is_empty() {
        return Err("Could not resolve that channel.".into());
    }
    connection
        .execute(
            "INSERT INTO youtube_subscriptions (channel_id, title, uploads_playlist_id)
         VALUES (?1, ?2, ?3) ON CONFLICT(channel_id) DO UPDATE SET
         title = excluded.title, uploads_playlist_id = excluded.uploads_playlist_id",
            params![id.trim(), title.trim(), playlist.trim()],
        )
        .map_err(|error| error.to_string())?;
    Ok(())
}

pub(crate) fn remove_subscription(connection: &Connection, id: &str) -> Result<(), String> {
    connection
        .execute(
            "DELETE FROM youtube_subscriptions WHERE channel_id = ?1",
            [id],
        )
        .map_err(|error| error.to_string())?;
    Ok(())
}

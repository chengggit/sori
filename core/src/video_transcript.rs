use rusqlite::{params, Connection, OptionalExtension};
use serde_json::{json, Value};
use std::io::Read;
use std::path::Path;

pub fn read(connection: &Connection, id: i64) -> Result<Value, String> {
    connection
        .query_row(
            "SELECT title, content, position FROM video_transcripts WHERE video_id = ?1",
            [id],
            |row| {
                Ok(
                    json!({"title": row.get::<_, String>(0)?, "content": row.get::<_, String>(1)?,
            "position": row.get::<_, f64>(2)?}),
                )
            },
        )
        .optional()
        .map(|row| row.unwrap_or_else(|| json!({})))
        .map_err(|error| error.to_string())
}

pub fn read_text(path: &Path) -> Result<(String, String), String> {
    if !path
        .extension()
        .is_some_and(|extension| extension.eq_ignore_ascii_case("txt"))
    {
        return Err("Choose a UTF-8 TXT transcript.".into());
    }
    let mut bytes = Vec::new();
    std::fs::File::open(path)
        .map_err(|error| error.to_string())?
        .take(crate::documents::MAX_TEXT_BYTES as u64 + 1)
        .read_to_end(&mut bytes)
        .map_err(|error| error.to_string())?;
    if bytes.len() > crate::documents::MAX_TEXT_BYTES {
        return Err("The transcript exceeds 2 MiB.".into());
    }
    let text = String::from_utf8(bytes).map_err(|_| "Choose a UTF-8 TXT transcript.")?;
    let text = text
        .trim_start_matches('\u{feff}')
        .replace("\r\n", "\n")
        .replace('\r', "\n");
    if text.trim().is_empty() || text.contains('\0') {
        return Err("Choose a transcript containing readable text.".into());
    }
    let title = path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .into_owned();
    Ok((title, text))
}

pub fn attach(connection: &Connection, id: i64, path: &Path) -> Result<Value, String> {
    let (title, text) = read_text(path)?;
    connection.execute(
        "INSERT INTO video_transcripts (video_id, title, content) VALUES (?1, ?2, ?3)
         ON CONFLICT(video_id) DO UPDATE SET title = excluded.title, content = excluded.content, position = 0",
        params![id, title, text],
    ).map_err(|error| error.to_string())?;
    read(connection, id)
}

pub fn save_position(connection: &Connection, id: i64, position: f64) -> Result<(), String> {
    if !position.is_finite() || !(0.0..=1.0).contains(&position) {
        return Err("Invalid transcript position.".into());
    }
    connection
        .execute(
            "UPDATE video_transcripts SET position = ?2 WHERE video_id = ?1",
            params![id, position],
        )
        .map_err(|error| error.to_string())?;
    Ok(())
}

pub fn remove(connection: &Connection, id: i64) -> Result<(), String> {
    connection
        .execute("DELETE FROM video_transcripts WHERE video_id = ?1", [id])
        .map_err(|error| error.to_string())?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn imports_persists_replaces_and_removes_transcripts() {
        let directory =
            std::env::temp_dir().join(format!("sori-transcript-{}", std::process::id()));
        std::fs::create_dir_all(&directory).unwrap();
        let path = directory.join("podcast.txt");
        let database_path = directory.join("library.sqlite3");
        let connection = Connection::open(&database_path).unwrap();
        connection
            .pragma_update(None, "foreign_keys", true)
            .unwrap();
        connection
            .execute_batch(include_str!("schema.sql"))
            .unwrap();
        connection
            .execute(
                "INSERT INTO videos (id, path, title) VALUES (1, '/podcast.mp4', 'Podcast')",
                [],
            )
            .unwrap();
        std::fs::write(&path, "\u{feff}안녕하세요.\r\n한국어 공부").unwrap();
        let saved = attach(&connection, 1, &path).unwrap();
        assert_eq!(saved["content"], "안녕하세요.\n한국어 공부");
        assert_eq!(saved["title"], "podcast.txt");
        save_position(&connection, 1, 0.4).unwrap();
        assert!(save_position(&connection, 1, f64::NAN).is_err());
        assert!(save_position(&connection, 1, 1.1).is_err());
        drop(connection);
        let connection = Connection::open(&database_path).unwrap();
        connection
            .pragma_update(None, "foreign_keys", true)
            .unwrap();
        assert_eq!(read(&connection, 1).unwrap()["position"], 0.4);
        assert_eq!(
            read(&connection, 1).unwrap()["content"],
            "안녕하세요.\n한국어 공부"
        );
        for invalid in [b"  \n".as_slice(), &[0xff], b"bad\0text"] {
            std::fs::write(&path, invalid).unwrap();
            assert!(attach(&connection, 1, &path).is_err());
            assert_eq!(read(&connection, 1).unwrap()["position"], 0.4);
        }
        std::fs::write(&path, vec![b'a'; crate::documents::MAX_TEXT_BYTES + 1]).unwrap();
        assert!(attach(&connection, 1, &path).is_err());
        std::fs::write(&path, "새로운 내용").unwrap();
        assert_eq!(attach(&connection, 1, &path).unwrap()["position"], 0.0);
        assert!(attach(&connection, 999, &path).is_err());
        remove(&connection, 1).unwrap();
        assert!(read(&connection, 1).unwrap().get("content").is_none());
        attach(&connection, 1, &path).unwrap();
        connection
            .execute("DELETE FROM videos WHERE id = 1", [])
            .unwrap();
        assert!(read(&connection, 1).unwrap().get("content").is_none());
        drop(connection);
        std::fs::remove_dir_all(directory).unwrap();
    }
}

use rusqlite::{params, Connection, OptionalExtension};
use serde_json::{json, Value};
use std::path::Path;
use std::process::Command;
use std::time::Duration;

pub fn validate_id(id: &str) -> Result<(), String> {
    if id.len() == 11
        && id
            .bytes()
            .all(|c| c.is_ascii_alphanumeric() || c == b'_' || c == b'-')
    {
        Ok(())
    } else {
        Err("Invalid YouTube video ID.".into())
    }
}

pub fn validate(data: Value) -> Result<Value, String> {
    if let Some(error) = data["error"].as_str() {
        return Err(error.to_owned());
    }
    let cues = data["cues"]
        .as_array()
        .ok_or("Invalid transcript response.")?;
    if cues.is_empty() || cues.len() > 50000 {
        return Err("No readable transcript was returned.".into());
    }
    let mut previous = 0.0;
    for cue in cues {
        let start = cue["start"].as_f64().ok_or("Invalid transcript timing.")?;
        let end = cue["end"].as_f64().ok_or("Invalid transcript timing.")?;
        if !start.is_finite()
            || !end.is_finite()
            || start < previous
            || end <= start
            || cue["text"]
                .as_str()
                .is_none_or(|text| text.trim().is_empty())
        {
            return Err("Invalid transcript cue.".into());
        }
        previous = start;
    }
    if !matches!(data["language"].as_str(), Some("ko" | "en")) {
        return Err("Unsupported transcript language.".into());
    }
    Ok(data)
}

pub fn fetch(id: &str, language: &str) -> Result<Value, String> {
    validate_id(id)?;
    if !matches!(language, "ko" | "en") {
        return Err("Choose Korean or English.".into());
    }
    let development_python = Path::new(env!("CARGO_MANIFEST_DIR")).join(if cfg!(windows) {
        "../.venv-youtube/Scripts/python.exe"
    } else {
        "../.venv-youtube/bin/python"
    });
    let python = std::env::var_os("SORI_PYTHON").unwrap_or_else(|| {
        if development_python.is_file() {
            development_python.into_os_string()
        } else {
            if cfg!(windows) {
                "python".into()
            } else {
                "python3".into()
            }
        }
    });
    let app_directory = std::env::current_exe()
        .ok()
        .and_then(|path| path.parent().map(Path::to_path_buf));
    let bundled = app_directory
        .map(|directory| {
            directory
                .join("helpers/sori-youtube-transcript")
                .join(if cfg!(windows) {
                    "sori-youtube-transcript.exe"
                } else {
                    "sori-youtube-transcript"
                })
        })
        .filter(|path| path.is_file());
    let mut command = if let Some(helper) = &bundled {
        let mut command = Command::new(helper);
        command.args([id, language]);
        command
    } else {
        let mut command = Command::new(python);
        command.args([
            "-c",
            include_str!(concat!(
                env!("CARGO_MANIFEST_DIR"),
                "/../../scripts/youtube_transcript.py"
            )),
            id,
            language,
        ]);
        command
    };
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        command.creation_flags(0x08000000); // CREATE_NO_WINDOW
    }
    let bytes = crate::process::output(&mut command, "YouTube transcript helper", 2 * 1024 * 1024,
        Duration::from_secs(40))
        .map_err(|error| format!("{error} See README.md for transcript helper setup."))?;
    validate(serde_json::from_slice(&bytes).map_err(|_| "Invalid transcript helper output.")?)
}

pub fn read(connection: &Connection, id: &str) -> Result<Value, String> {
    validate_id(id)?;
    connection.query_row("SELECT timed_json, language, title, content, position FROM youtube_transcripts WHERE video_id=?1", [id], |row| {
        let cues: Option<String> = row.get(0)?;
        Ok(json!({"cues": cues.and_then(|data| serde_json::from_str::<Value>(&data).ok()).unwrap_or(json!([])),
            "language": row.get::<_, Option<String>>(1)?, "title": row.get::<_, Option<String>>(2)?,
            "content": row.get::<_, Option<String>>(3)?, "position": row.get::<_, f64>(4)?}))
    }).optional().map(|data| data.unwrap_or(json!({}))).map_err(|e| e.to_string())
}

pub fn cache(connection: &Connection, id: &str, data: Value) -> Result<(), String> {
    validate_id(id)?;
    let data = validate(data)?;
    let cues = serde_json::to_string(&data["cues"]).map_err(|e| e.to_string())?;
    if cues.len() > 2 * 1024 * 1024 {
        return Err("The transcript exceeds 2 MiB.".into());
    }
    connection.execute("INSERT INTO youtube_transcripts(video_id,timed_json,language) VALUES(?1,?2,?3)
        ON CONFLICT(video_id) DO UPDATE SET timed_json=excluded.timed_json, language=excluded.language",
        params![id, cues, data["language"].as_str()]).map_err(|e| e.to_string())?;
    Ok(())
}

pub fn attach(connection: &Connection, id: &str, path: &Path) -> Result<Value, String> {
    validate_id(id)?;
    let (title, text) = crate::video_transcript::read_text(path)?;
    connection.execute("INSERT INTO youtube_transcripts(video_id,title,content) VALUES(?1,?2,?3)
        ON CONFLICT(video_id) DO UPDATE SET title=excluded.title,content=excluded.content,position=0",
        params![id,title,text]).map_err(|e| e.to_string())?;
    read(connection, id)
}

pub fn save_position(connection: &Connection, id: &str, position: f64) -> Result<(), String> {
    validate_id(id)?;
    if !position.is_finite() || !(0.0..=1.0).contains(&position) {
        return Err("Invalid transcript position.".into());
    }
    connection
        .execute(
            "UPDATE youtube_transcripts SET position=?2 WHERE video_id=?1",
            params![id, position],
        )
        .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn remove_text(connection: &Connection, id: &str) -> Result<(), String> {
    validate_id(id)?;
    connection
        .execute(
            "UPDATE youtube_transcripts SET content=NULL,title=NULL,position=0 WHERE video_id=?1",
            [id],
        )
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn validates_cues_and_caches_without_destroying_attached_text() {
        let db = Connection::open_in_memory().unwrap();
        db.execute_batch(include_str!("schema.sql")).unwrap();
        let id = "dQw4w9WgXcQ";
        let data = json!({"language":"ko", "cues":[{"start":1.0,"end":3.0,"text":"한국어"}]});
        cache(&db, id, data.clone()).unwrap();
        assert_eq!(read(&db, id).unwrap()["cues"], data["cues"]);
        db.execute(
            "UPDATE youtube_transcripts SET title='text.txt',content='공부' WHERE video_id=?1",
            [id],
        )
        .unwrap();
        save_position(&db, id, 0.5).unwrap();
        cache(&db, id, data.clone()).unwrap();
        assert_eq!(read(&db, id).unwrap()["content"], "공부");
        assert_eq!(read(&db, id).unwrap()["position"], 0.5);
        remove_text(&db, id).unwrap();
        assert!(read(&db, id).unwrap()["content"].is_null());
        assert_eq!(read(&db, id).unwrap()["cues"], data["cues"]);
        assert!(cache(&db, "not-an-id", data).is_err());
        assert!(save_position(&db, id, f64::NAN).is_err());
        for invalid in [
            json!({"error":"Unavailable"}),
            json!({"language":"ko", "cues":[]}),
            json!({"language":"ko", "cues":[{"start":-1,"end":3,"text":"x"}]}),
            json!({"language":"ko", "cues":[{"start":1,"end":1,"text":"x"}]}),
            json!({"language":"ko", "cues":[{"start":1,"end":3,"text":" "}]}),
            json!({"language":"ko", "cues":[{"start":2,"end":4,"text":"a"},{"start":1,"end":3,"text":"b"}]}),
        ] {
            assert!(validate(invalid).is_err());
        }
    }
}

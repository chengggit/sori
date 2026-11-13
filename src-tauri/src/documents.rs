use rusqlite::{Connection, OptionalExtension, params};
use serde::Serialize;

const MAX_TEXT_BYTES: usize = 2 * 1024 * 1024;

#[derive(Serialize)]
pub struct LibraryItem {
    pub id: i64,
    pub title: String,
}

pub fn list(database: &Connection) -> Result<Vec<LibraryItem>, String> {
    let mut statement = database
        .prepare("SELECT id, title FROM documents ORDER BY id DESC")
        .map_err(|error| error.to_string())?;
    statement
        .query_map([], |row| {
            Ok(LibraryItem {
                id: row.get(0)?,
                title: row.get(1)?,
            })
        })
        .map_err(|error| error.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|error| error.to_string())
}

pub fn import(database: &Connection, filename: &str, bytes: &[u8]) -> Result<(), String> {
    let (title, extension) = filename.rsplit_once('.').ok_or("Choose a .txt file.")?;
    if title.trim().is_empty() || !extension.eq_ignore_ascii_case("txt") {
        return Err("Choose a .txt file.".into());
    }
    if bytes.len() > MAX_TEXT_BYTES {
        return Err("Choose a text file no larger than 2 MiB.".into());
    }

    let content = std::str::from_utf8(bytes).map_err(|_| "Choose a UTF-8 text file.")?;
    let content = content.strip_prefix('\u{feff}').unwrap_or(content);
    if content.trim().is_empty() {
        return Err("This text file is empty.".into());
    }

    database
        .execute(
            "INSERT INTO documents (title, content)
         SELECT ?1, ?2 WHERE NOT EXISTS (
             SELECT 1 FROM documents WHERE title = ?1 AND content = ?2
         )",
            params![title, content],
        )
        .map_err(|error| error.to_string())?;
    Ok(())
}

pub fn read(database: &Connection, id: i64) -> Result<String, String> {
    database
        .query_row("SELECT content FROM documents WHERE id = ?1", [id], |row| {
            row.get(0)
        })
        .optional()
        .map_err(|error| error.to_string())?
        .ok_or_else(|| "Document not found.".into())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn database() -> Connection {
        let database = Connection::open_in_memory().unwrap();
        database.execute_batch(include_str!("schema.sql")).unwrap();
        database
    }

    #[test]
    fn imports_korean_text_and_lists_newest_first() {
        let database = database();
        import(
            &database,
            "첫 번째.TXT",
            "\u{feff}안녕하세요\n한국어 공부".as_bytes(),
        )
        .unwrap();
        import(&database, "두 번째.txt", "다음 이야기".as_bytes()).unwrap();
        let items = list(&database).unwrap();
        assert_eq!(items.len(), 2);
        assert_eq!(items[0].title, "두 번째");
        assert_eq!(items[1].title, "첫 번째");
        assert_eq!(
            read(&database, items[1].id).unwrap(),
            "안녕하세요\n한국어 공부"
        );
    }

    #[test]
    fn duplicate_imports_preserve_id_but_different_content_is_kept() {
        let database = database();
        import(&database, "책.txt", "첫 문장".as_bytes()).unwrap();
        let id = list(&database).unwrap()[0].id;
        import(&database, "책.txt", "\u{feff}첫 문장".as_bytes()).unwrap();
        assert_eq!(list(&database).unwrap().len(), 1);
        assert_eq!(list(&database).unwrap()[0].id, id);
        import(&database, "책.txt", "다른 문장".as_bytes()).unwrap();
        assert_eq!(list(&database).unwrap().len(), 2);
    }

    #[test]
    fn rejects_invalid_imports_without_writing() {
        let database = database();
        for (filename, bytes, expected) in [
            ("book.pdf", b"text".as_slice(), "Choose a .txt file."),
            ("book", b"text".as_slice(), "Choose a .txt file."),
            (" .txt", b"text".as_slice(), "Choose a .txt file."),
            ("book.txt", &[0xff], "Choose a UTF-8 text file."),
            (
                "book.txt",
                "\u{feff} \n\t".as_bytes(),
                "This text file is empty.",
            ),
        ] {
            assert_eq!(import(&database, filename, bytes).unwrap_err(), expected);
        }
        assert!(import(&database, "book.txt", &vec![b'a'; MAX_TEXT_BYTES + 1]).is_err());
        assert!(list(&database).unwrap().is_empty());
    }

    #[test]
    fn accepts_size_limit_and_reports_missing_documents() {
        let database = database();
        import(&database, "book.txt", &vec![b'a'; MAX_TEXT_BYTES]).unwrap();
        assert_eq!(
            read(&database, list(&database).unwrap()[0].id)
                .unwrap()
                .len(),
            MAX_TEXT_BYTES
        );
        assert_eq!(read(&database, -1).unwrap_err(), "Document not found.");
    }
}

use rusqlite::{params, Connection, OptionalExtension};
use serde::Serialize;

pub const MAX_TEXT_BYTES: usize = 2 * 1024 * 1024;

#[derive(Serialize)]
pub struct LibraryItem {
    pub id: i64,
    pub title: String,
    pub pdf: bool,
}

pub fn list(database: &Connection) -> Result<Vec<LibraryItem>, String> {
    let mut statement = database
        .prepare(
            "SELECT id, title, pdf_path IS NOT NULL AND pdf_path <> '' \
             FROM documents ORDER BY id DESC",
        )
        .map_err(|error| error.to_string())?;
    let rows = statement
        .query_map([], |row| {
            Ok(LibraryItem {
                id: row.get(0)?,
                title: row.get(1)?,
                pdf: row.get(2)?,
            })
        })
        .map_err(|error| error.to_string())?;
    rows.collect::<Result<Vec<_>, _>>()
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

    insert(database, title, content).map(|_| ())
}

pub fn import_pdf(database: &Connection, filename: &str, content: &str) -> Result<i64, String> {
    let (title, extension) = filename
        .rsplit_once('.')
        .ok_or("Choose a .txt or .pdf file.")?;
    let title = title.trim();
    if title.is_empty() || !extension.eq_ignore_ascii_case("pdf") {
        return Err("Choose a .txt or .pdf file.".into());
    }
    if content.len() > MAX_TEXT_BYTES {
        return Err("This PDF contains too much text.".into());
    }
    insert(database, title, content)
}

fn insert(database: &Connection, title: &str, content: &str) -> Result<i64, String> {
    database
        .execute(
            "INSERT INTO documents (title, content)
         SELECT ?1, ?2 WHERE NOT EXISTS (
             SELECT 1 FROM documents WHERE title = ?1 AND content = ?2
         )",
            params![title, content],
        )
        .map_err(|error| error.to_string())?;
    database
        .query_row(
            "SELECT id FROM documents WHERE title = ?1 AND content = ?2 ORDER BY id LIMIT 1",
            params![title, content],
            |row| row.get(0),
        )
        .map_err(|error| error.to_string())
}

pub fn read_pdf_path(database: &Connection, id: i64) -> Result<Option<String>, String> {
    database
        .query_row("SELECT pdf_path FROM documents WHERE id = ?1", [id], |row| {
            row.get(0)
        })
        .optional()
        .map_err(|error| error.to_string())
        .map(|path| path.flatten())
}

pub fn set_pdf_path(database: &Connection, id: i64, path: Option<&str>) -> Result<(), String> {
    let changed = database
        .execute(
            "UPDATE documents SET pdf_path = ?2 WHERE id = ?1",
            params![id, path],
        )
        .map_err(|error| error.to_string())?;
    if changed == 0 {
        return Err("Document not found.".into());
    }
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

pub fn update(database: &Connection, id: i64, title: &str, content: &str) -> Result<(), String> {
    if title.trim().is_empty() {
        return Err("Enter a title.".into());
    }
    if content.trim().is_empty() {
        return Err("Enter some text.".into());
    }
    if content.len() > MAX_TEXT_BYTES {
        return Err("Text must be no larger than 2 MiB.".into());
    }
    let transaction = database
        .unchecked_transaction()
        .map_err(|error| error.to_string())?;
    let original = read(&transaction, id)?;
    transaction
        .execute(
            "UPDATE documents SET title = ?2, content = ?3 WHERE id = ?1",
            params![id, title.trim(), content],
        )
        .map_err(|error| error.to_string())?;
    if original != content {
        transaction
            .execute("DELETE FROM reading_progress WHERE document_id = ?1", [id])
            .map_err(|error| error.to_string())?;
    }
    transaction.commit().map_err(|error| error.to_string())
}

pub fn remove(database: &Connection, id: i64) -> Result<(), String> {
    database
        .execute("DELETE FROM documents WHERE id = ?1", [id])
        .map_err(|error| error.to_string())?;
    Ok(())
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
    fn edits_reset_progress_only_when_content_changes() {
        let database = database();
        database.pragma_update(None, "foreign_keys", true).unwrap();
        import(&database, "책.txt", "한국어".as_bytes()).unwrap();
        let id = list(&database).unwrap()[0].id;
        crate::progress::save(&database, id, 0.5).unwrap();
        update(&database, id, "새 제목", "한국어").unwrap();
        assert_eq!(crate::progress::read(&database, id).unwrap(), 0.5);
        assert!(update(&database, id, "", "다른 내용").is_err());
        assert_eq!(read(&database, id).unwrap(), "한국어");
        update(&database, id, "새 제목", "새로운 내용").unwrap();
        assert_eq!(read(&database, id).unwrap(), "새로운 내용");
        assert_eq!(list(&database).unwrap()[0].title, "새 제목");
        assert_eq!(crate::progress::read(&database, id).unwrap(), 0.0);
        remove(&database, id).unwrap();
        assert!(list(&database).unwrap().is_empty());
        assert!(update(&database, id, "제목", "내용").is_err());
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
    fn imports_pdf_text_and_validates_pdf_input() {
        let database = database();
        let id = import_pdf(&database, "책.pdf", "첫 문단\n\n둘째 문단").unwrap();
        assert_eq!(list(&database).unwrap()[0].id, id);
        assert_eq!(list(&database).unwrap()[0].title, "책");
        assert!(!list(&database).unwrap()[0].pdf);
        assert_eq!(read(&database, id).unwrap(), "첫 문단\n\n둘째 문단");
        assert_eq!(
            import_pdf(&database, "책.pdf", "첫 문단\n\n둘째 문단").unwrap(),
            id
        );

        set_pdf_path(&database, id, Some("/tmp/책.pdf")).unwrap();
        assert_eq!(
            read_pdf_path(&database, id).unwrap().as_deref(),
            Some("/tmp/책.pdf")
        );
        assert!(list(&database).unwrap()[0].pdf);
        set_pdf_path(&database, id, None).unwrap();
        assert_eq!(read_pdf_path(&database, id).unwrap(), None);
        assert!(!list(&database).unwrap()[0].pdf);

        let scanned = import_pdf(&database, "스캔.pdf", "").unwrap();
        assert_eq!(read(&database, scanned).unwrap(), "");
        assert_eq!(list(&database).unwrap().len(), 2);

        assert_eq!(
            import_pdf(&database, "책.txt", "본문").unwrap_err(),
            "Choose a .txt or .pdf file."
        );
        let oversized = "a".repeat(MAX_TEXT_BYTES + 1);
        assert_eq!(
            import_pdf(&database, "큰책.pdf", &oversized).unwrap_err(),
            "This PDF contains too much text."
        );
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

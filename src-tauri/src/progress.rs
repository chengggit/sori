use rusqlite::{Connection, OptionalExtension, params};

pub fn read(database: &Connection, id: i64) -> Result<f64, String> {
    database
        .query_row(
            "SELECT COALESCE(p.position, 0.0) FROM documents d
             LEFT JOIN reading_progress p ON p.document_id = d.id WHERE d.id = ?1",
            [id],
            |row| row.get(0),
        )
        .optional()
        .map_err(|error| error.to_string())?
        .ok_or_else(|| "Document not found.".into())
}

pub fn save(database: &Connection, id: i64, position: f64) -> Result<(), String> {
    if !position.is_finite() || !(0.0..=1.0).contains(&position) {
        return Err("Reading position must be between 0 and 1.".into());
    }
    let changed = database
        .execute(
            "INSERT INTO reading_progress (document_id, position)
             SELECT id, ?2 FROM documents WHERE id = ?1
             ON CONFLICT (document_id) DO UPDATE
             SET position = excluded.position, updated_at = unixepoch()",
            params![id, position],
        )
        .map_err(|error| error.to_string())?;
    if changed == 0 {
        return Err("Document not found.".into());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn database() -> Connection {
        let database = Connection::open_in_memory().unwrap();
        database.pragma_update(None, "foreign_keys", true).unwrap();
        database.execute_batch(include_str!("schema.sql")).unwrap();
        database
            .execute("INSERT INTO documents VALUES (1, '책', '안녕하세요')", [])
            .unwrap();
        database
            .execute("INSERT INTO documents VALUES (2, '다른 책', '한국어')", [])
            .unwrap();
        database
    }

    #[test]
    fn starts_at_zero_and_updates_each_document_independently() {
        let database = database();
        assert_eq!(read(&database, 1).unwrap(), 0.0);
        for position in [0.4, 1.0, 0.2, 0.0] {
            save(&database, 1, position).unwrap();
            assert_eq!(read(&database, 1).unwrap(), position);
            assert_eq!(read(&database, 2).unwrap(), 0.0);
        }
        let count: i64 = database
            .query_row("SELECT count(*) FROM reading_progress", [], |row| {
                row.get(0)
            })
            .unwrap();
        assert_eq!(count, 1);
    }

    #[test]
    fn invalid_positions_and_missing_documents_do_not_modify_progress() {
        let database = database();
        save(&database, 1, 0.5).unwrap();
        for position in [-0.1, 1.1, f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
            assert!(save(&database, 1, position).is_err());
        }
        assert_eq!(read(&database, 1).unwrap(), 0.5);
        assert_eq!(read(&database, 999).unwrap_err(), "Document not found.");
        assert_eq!(
            save(&database, 999, 0.5).unwrap_err(),
            "Document not found."
        );
    }

    #[test]
    fn deleting_source_removes_progress() {
        let database = database();
        save(&database, 1, 0.5).unwrap();
        database
            .execute("DELETE FROM documents WHERE id = 1", [])
            .unwrap();
        assert_eq!(read(&database, 1).unwrap_err(), "Document not found.");
        let count: i64 = database
            .query_row("SELECT count(*) FROM reading_progress", [], |row| {
                row.get(0)
            })
            .unwrap();
        assert_eq!(count, 0);
    }
}

use crate::{db::Database, documents};
use std::{io::Read, path::Path};

pub fn import_file(database: &Database, path: &Path) -> Result<(), String> {
    let filename = path
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or("Choose a .txt or .pdf file.")?;
    let extension = filename
        .rsplit_once('.')
        .map(|(_, extension)| extension)
        .unwrap_or_default();
    let connection = database.connect()?;
    if extension.eq_ignore_ascii_case("pdf") {
        let metadata =
            std::fs::metadata(path).map_err(|error| format!("Could not read this PDF: {error}"))?;
        if metadata.len() > documents::MAX_PDF_BYTES {
            return Err("Choose a PDF no larger than 50 MiB.".into());
        }
        if !metadata.is_file() {
            return Err("Choose a readable PDF file.".into());
        }
        let directory = database.pdf_directory();
        std::fs::create_dir_all(&directory)
            .map_err(|error| format!("Could not save this PDF: {error}"))?;
        let transaction = rusqlite::Transaction::new_unchecked(
            &connection,
            rusqlite::TransactionBehavior::Immediate,
        )
        .map_err(|error| error.to_string())?;
        let id = documents::import_pdf(&transaction, filename)?;
        let target = directory.join(format!("{id}.pdf"));
        let copied = path != target.as_path();
        let save = || -> Result<(), String> {
            if copied {
                std::fs::copy(path, &target)
                    .map_err(|error| format!("Could not save this PDF: {error}"))?;
            }
            documents::set_pdf_path(&transaction, id, Some(&target.to_string_lossy()))?;
            transaction.commit().map_err(|error| error.to_string())
        };
        if let Err(error) = save() {
            if copied {
                let _ = std::fs::remove_file(&target);
            }
            return Err(error);
        }
        Ok(())
    } else if extension.eq_ignore_ascii_case("txt") {
        let file = std::fs::File::open(path).map_err(|error| error.to_string())?;
        let mut bytes = Vec::new();
        file.take(documents::MAX_TEXT_BYTES as u64 + 1)
            .read_to_end(&mut bytes)
            .map_err(|error| error.to_string())?;
        documents::import(&connection, filename, &bytes)
    } else {
        Err("Choose a .txt or .pdf file.".into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn failed_pdf_import_rolls_back_row_and_copied_file() {
        let directory = std::env::temp_dir().join(format!(
            "sori-import-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let database = Database::initialize(directory.clone()).unwrap();
        let source = directory.join("source.pdf");
        std::fs::write(&source, b"%PDF-1.4").unwrap();
        std::fs::write(database.pdf_directory(), b"blocked").unwrap();
        assert!(import_file(&database, &source).is_err());
        assert!(documents::list(&database.connect().unwrap())
            .unwrap()
            .is_empty());
        std::fs::remove_file(database.pdf_directory()).unwrap();
        let connection = database.connect().unwrap();
        connection.execute_batch("CREATE TRIGGER reject_pdf BEFORE UPDATE ON documents BEGIN SELECT RAISE(ABORT,'test failure'); END;").unwrap();
        assert!(import_file(&database, &source).is_err());
        assert!(documents::list(&connection).unwrap().is_empty());
        assert_eq!(
            std::fs::read_dir(database.pdf_directory()).unwrap().count(),
            0
        );
        connection
            .execute_batch("DROP TRIGGER reject_pdf;")
            .unwrap();
        import_file(&database, &source).unwrap();
        let items = documents::list(&connection).unwrap();
        assert_eq!(items.len(), 1);
        let target = documents::read_pdf_path(&connection, items[0].id)
            .unwrap()
            .unwrap();
        assert_eq!(std::fs::read(target).unwrap(), b"%PDF-1.4");
        drop(connection);
        std::fs::remove_dir_all(directory).unwrap();
    }
}

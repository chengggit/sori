use rusqlite::{Connection, OptionalExtension};
use std::{path::PathBuf, sync::RwLock};

pub(crate) static SAVED_API_KEY: RwLock<Option<String>> = RwLock::new(None);

pub(crate) fn has_saved_api_key() -> bool {
    SAVED_API_KEY
        .read()
        .unwrap_or_else(|poison| poison.into_inner())
        .is_some()
}

pub(crate) fn set_saved_api_key(key: Option<String>) {
    *SAVED_API_KEY
        .write()
        .unwrap_or_else(|poison| poison.into_inner()) = key;
}

pub(crate) fn has_api_key() -> bool {
    api_key().is_some()
}

pub(crate) fn api_key() -> Option<String> {
    SAVED_API_KEY
        .read()
        .unwrap_or_else(|poison| poison.into_inner())
        .clone()
        .or_else(|| {
            std::env::var("SORI_YOUTUBE_API_KEY")
                .ok()
                .map(|key| key.trim().to_owned())
                .filter(|key| !key.is_empty())
                .or_else(|| {
                    let path = env_file()?;
                    let settings = std::fs::read_to_string(path).ok()?;
                    key_from_settings(&settings, "SORI_YOUTUBE_API_KEY")
                        .or_else(|| key_from_settings(&settings, "VITE_YOUTUBE_API_KEY"))
                })
        })
}

pub(crate) fn read_saved_api_key(connection: &Connection) -> Result<Option<String>, String> {
    connection
        .query_row(
            "SELECT value FROM app_settings WHERE key = 'youtube_api_key'",
            [],
            |row| row.get(0),
        )
        .optional()
        .map_err(|error| error.to_string())
}

pub(crate) fn store_api_key(connection: &Connection, input: &str) -> Result<String, String> {
    let key = input.trim();
    if key.is_empty()
        || key.len() > 512
        || !key
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'-'))
    {
        return Err("Enter an API key without spaces or punctuation.".into());
    }
    #[cfg(unix)]
    if let Some(path) = connection
        .path()
        .filter(|path| !path.is_empty() && *path != ":memory:")
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))
            .map_err(|_| "Could not protect the local API key settings.".to_string())?;
    }
    connection
        .execute(
            "INSERT INTO app_settings (key, value) VALUES ('youtube_api_key', ?1)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            [key],
        )
        .map_err(|error| error.to_string())?;
    Ok(key.to_owned())
}

pub(crate) fn remove_saved_api_key(connection: &Connection) -> Result<(), String> {
    connection
        .execute("DELETE FROM app_settings WHERE key = 'youtube_api_key'", [])
        .map_err(|error| error.to_string())?;
    Ok(())
}

/// Resolve `.env.local` independently of the directory Sori was launched from.
pub(crate) fn env_file() -> Option<PathBuf> {
    if let Some(path) = std::env::var_os("SORI_ENV_FILE") {
        let path = PathBuf::from(path);
        if path.is_file() {
            return Some(path);
        }
    }
    let mut candidates = Vec::new();
    if let Ok(directory) = std::env::current_dir() {
        candidates.extend(
            directory
                .ancestors()
                .take(6)
                .map(|ancestor| ancestor.join(".env.local")),
        );
    }
    if let Ok(executable) = std::env::current_exe() {
        candidates.extend(
            executable
                .ancestors()
                .skip(1)
                .take(6)
                .map(|ancestor| ancestor.join(".env.local")),
        );
    }
    candidates.into_iter().find(|path| path.is_file())
}

pub(crate) fn key_from_settings(settings: &str, name: &str) -> Option<String> {
    settings.lines().rev().find_map(|line| {
        let line = line.trim();
        let (key, value) = line
            .strip_prefix("export ")
            .unwrap_or(line)
            .split_once('=')?;
        if key.trim() != name {
            return None;
        }
        let value = value.trim();
        let value = value
            .strip_prefix('"')
            .and_then(|value| value.strip_suffix('"'))
            .or_else(|| {
                value
                    .strip_prefix('\'')
                    .and_then(|value| value.strip_suffix('\''))
            })
            .unwrap_or(value);
        (!value.is_empty()).then(|| value.to_owned())
    })
}

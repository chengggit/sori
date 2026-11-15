use std::{
    collections::VecDeque,
    fs::File,
    io::{Read, Seek, SeekFrom},
    path::{Path, PathBuf},
    sync::{Arc, Mutex},
};
use tiny_http::{Header, Method, Request, Response, Server, StatusCode};

const MAX_REGISTERED_FILES: usize = 16;

type RegisteredFiles = Arc<Mutex<VecDeque<(String, PathBuf)>>>;

#[derive(Default)]
pub struct VideoServerState(Mutex<Option<VideoServer>>);

impl VideoServerState {
    pub fn url(&self, path: &Path) -> Result<String, String> {
        let mut state = self.0.lock().map_err(|error| error.to_string())?;
        if state.is_none() {
            *state = Some(VideoServer::start()?);
        }
        state.as_ref().unwrap().register(path)
    }
}

struct VideoServer {
    address: String,
    files: RegisteredFiles,
}

impl VideoServer {
    fn start() -> Result<Self, String> {
        let server = Arc::new(Server::http("127.0.0.1:0").map_err(|error| error.to_string())?);
        let address = server.server_addr().to_string();
        let files: RegisteredFiles = Arc::new(Mutex::new(VecDeque::new()));
        for _ in 0..4 {
            let server = Arc::clone(&server);
            let files = Arc::clone(&files);
            std::thread::spawn(move || {
                while let Ok(request) = server.recv() {
                    serve(request, &files);
                }
            });
        }
        Ok(Self { address, files })
    }

    fn register(&self, path: &Path) -> Result<String, String> {
        let path = path.canonicalize().map_err(|error| error.to_string())?;
        if !path.is_file() {
            return Err("The video file is unavailable.".into());
        }
        let mut files = self.files.lock().map_err(|error| error.to_string())?;
        if let Some(index) = files.iter().position(|(_, source)| *source == path) {
            let entry = files.remove(index).unwrap();
            let url = format!("http://{}/{}", self.address, entry.0);
            files.push_back(entry);
            return Ok(url);
        }
        let mut bytes = [0; 24];
        getrandom::fill(&mut bytes).map_err(|error| error.to_string())?;
        let token = bytes
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect::<String>();
        let url = format!("http://{}/{token}", self.address);
        if files.len() == MAX_REGISTERED_FILES {
            files.pop_front();
        }
        files.push_back((token, path));
        Ok(url)
    }
}

fn mime_type(path: &Path) -> &'static str {
    match path
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or("")
        .to_ascii_lowercase()
        .as_str()
    {
        "mkv" => "video/x-matroska",
        "webm" => "video/webm",
        "mov" => "video/quicktime",
        "avi" => "video/x-msvideo",
        "mp4" | "m4v" => "video/mp4",
        _ => "application/octet-stream",
    }
}

fn byte_range(value: &str, length: u64) -> Option<(u64, u64)> {
    let (start, end) = value.strip_prefix("bytes=")?.split_once('-')?;
    if start.is_empty() {
        let suffix: u64 = end.parse().ok()?;
        return (suffix > 0 && length > 0).then(|| (length.saturating_sub(suffix), length - 1));
    }
    let start: u64 = start.parse().ok()?;
    if start >= length {
        return None;
    }
    let end = if end.is_empty() {
        length - 1
    } else {
        end.parse::<u64>().ok()?.min(length - 1)
    };
    (end >= start).then_some((start, end))
}

fn header(name: &str, value: &str) -> Header {
    Header::from_bytes(name, value).expect("valid HTTP header")
}

fn serve(request: Request, files: &RegisteredFiles) {
    if !matches!(request.method(), Method::Get | Method::Head) {
        let _ = request.respond(Response::empty(405).with_header(header("Allow", "GET, HEAD")));
        return;
    }
    let source = files.lock().ok().and_then(|files| {
        let token = request.url().strip_prefix('/')?;
        files
            .iter()
            .find(|(key, _)| key == token)
            .map(|(_, path)| path.clone())
    });
    let Some(path) = source else {
        let _ = request.respond(Response::empty(404));
        return;
    };
    if path.canonicalize().ok().as_deref() != Some(path.as_path()) {
        let _ = request.respond(Response::empty(404));
        return;
    }
    let Ok(mut file) = File::open(&path) else {
        let _ = request.respond(Response::empty(404));
        return;
    };
    let Ok(metadata) = file.metadata() else {
        let _ = request.respond(Response::empty(404));
        return;
    };
    if !metadata.is_file() {
        let _ = request.respond(Response::empty(404));
        return;
    }
    let length = metadata.len();
    let range = request
        .headers()
        .iter()
        .find(|header| header.field.equiv("Range"));
    let mut headers = vec![
        header("Content-Type", mime_type(&path)),
        header("Accept-Ranges", "bytes"),
        header("Cache-Control", "no-store"),
    ];
    let (status, start, count) = if let Some(range) = range {
        let Some((start, end)) = byte_range(range.value.as_str(), length) else {
            let _ = request.respond(
                Response::empty(416)
                    .with_header(header("Content-Range", &format!("bytes */{length}"))),
            );
            return;
        };
        headers.push(header(
            "Content-Range",
            &format!("bytes {start}-{end}/{length}"),
        ));
        (206, start, end - start + 1)
    } else {
        (200, 0, length)
    };
    let Ok(count) = usize::try_from(count) else {
        let _ = request.respond(Response::empty(500));
        return;
    };
    if file.seek(SeekFrom::Start(start)).is_err() {
        let _ = request.respond(Response::empty(500));
        return;
    }
    let response = Response::new(
        StatusCode(status),
        headers,
        file.take(count as u64),
        Some(count),
        None,
    )
    // Keep Content-Length available for WebKit's media seeking on large files.
    .with_chunked_threshold(usize::MAX);
    let _ = request.respond(response);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn serves_original_mkv_bytes_and_supports_seeking() {
        let path = std::env::temp_dir().join(format!("sori-http-test-{}.mkv", std::process::id()));
        std::fs::write(&path, b"original bytes").unwrap();
        let server = VideoServer::start().unwrap();
        let url = server.register(&path).unwrap();
        assert!(url.starts_with("http://127.0.0.1:"));

        tauri::async_runtime::block_on(async {
            let client = reqwest::Client::new();
            let info = client.head(&url).send().await.unwrap();
            assert_eq!(info.status(), 200);
            assert_eq!(info.headers()["Content-Type"], "video/x-matroska");
            assert_eq!(info.headers()["Content-Length"], "14");
            assert_eq!(info.headers()["Accept-Ranges"], "bytes");

            let part = client
                .get(&url)
                .header("Range", "bytes=9-")
                .send()
                .await
                .unwrap();
            assert_eq!(part.status(), 206);
            assert_eq!(part.headers()["Content-Range"], "bytes 9-13/14");
            assert_eq!(part.bytes().await.unwrap().as_ref(), b"bytes");

            let invalid = client
                .get(&url)
                .header("Range", "bytes=99-")
                .send()
                .await
                .unwrap();
            assert_eq!(invalid.status(), 416);
            let unknown = client
                .get(format!("http://{}/unknown", server.address))
                .send()
                .await
                .unwrap();
            assert_eq!(unknown.status(), 404);
        });
        std::fs::remove_file(path).unwrap();
    }
}

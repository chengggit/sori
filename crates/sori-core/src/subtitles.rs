//! Subtitle subprocess helpers. Full SRT/VTT parsing lives in TypeScript at
//! `src/lib/video/subtitles.ts`, so it is not duplicated here.

pub(super) fn command_output(
    program: &str,
    args: impl IntoIterator<Item = impl AsRef<std::ffi::OsStr>>,
    limit: usize,
) -> Result<Vec<u8>, String> {
    let tool = match program {
        "ffmpeg" => std::env::var_os("SORI_FFMPEG_PATH"),
        "ffprobe" => std::env::var_os("SORI_FFPROBE_PATH"),
        _ => None,
    }.unwrap_or_else(|| program.into());
    crate::process::output(
        std::process::Command::new(tool).args(args), program, limit,
        std::time::Duration::from_secs(30),
    )
}

/// Minimal check before storing a sidecar; real parsing happens in the UI.
pub(super) fn has_cues(text: &str) -> bool {
    let normalized = text
        .trim_start_matches('\u{feff}')
        .replace("\r\n", "\n")
        .replace('\r', "\n");
    normalized.lines().any(|line| line.contains("-->"))
}

#[cfg(test)]
mod tests {
    use super::has_cues;

    #[test]
    fn detects_a_timing_line() {
        assert!(has_cues("\u{feff}1\n00:00:01,000 --> 00:00:02,000\nHello"));
        assert!(!has_cues("WEBVTT\n\nNo timings here"));
    }
}

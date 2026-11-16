use regex::Regex;
use std::sync::LazyLock;

pub(super) struct Cue {
    pub(super) start: f64,
    pub(super) end: f64,
    pub(super) text: String,
}

static BLOCKS: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\n[ \t]*\n+").unwrap());
static TIMING: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^\s*(\S+)\s+-->\s+(\S+)").unwrap());
static TIMESTAMP: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^(?:(\d{2,}):)?([0-5]\d):([0-5]\d)[.,](\d{3})$").unwrap());
static BREAK: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(?i)<br\s*/?>").unwrap());
static TAGS: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"<[^>\n]*>").unwrap());

fn seconds(value: &str) -> Option<f64> {
    let fields = TIMESTAMP.captures(value)?;
    let hours = fields
        .get(1)
        .map_or("0", |hours| hours.as_str())
        .parse::<f64>()
        .ok()?;
    let minutes = fields[2].parse::<f64>().ok()?;
    let seconds = fields[3].parse::<f64>().ok()?;
    let milliseconds = fields[4].parse::<f64>().ok()?;
    let total = hours * 3600.0 + minutes * 60.0 + seconds + milliseconds / 1000.0;
    total.is_finite().then_some(total)
}

fn cue(block: &str) -> Option<Cue> {
    let mut lines = block.trim().splitn(2, '\n');
    let mut timing = lines.next()?;
    if !timing.contains("-->") {
        lines = lines.next()?.splitn(2, '\n');
        timing = lines.next()?;
    }
    let times = TIMING.captures(timing)?;
    let (start, end) = (seconds(&times[1])?, seconds(&times[2])?);
    let body = BREAK.replace_all(lines.next()?, "\n");
    let text = TAGS
        .replace_all(&body, "")
        .replace("&nbsp;", " ")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&amp;", "&");
    let text = text.trim();
    (end > start && !text.is_empty()).then(|| Cue {
        start,
        end,
        text: text.to_owned(),
    })
}

pub(super) fn parse(input: &str) -> Vec<Cue> {
    let normalized = input.replace("\r\n", "\n").replace('\r', "\n");
    let mut cues: Vec<_> = BLOCKS.split(&normalized).filter_map(cue).collect();
    cues.sort_by(|a, b| a.start.total_cmp(&b.start));
    cues
}

#[cfg(test)]
mod tests {
    use super::parse;

    #[test]
    fn parses_and_sorts_mixed_cues() {
        let input = "WEBVTT\r\n\r\n2\r\n00:04,000 --> 00:05,000\r\nSecond\r\n\r\n00:01.500 --> 00:02.000 align:start\r\n<b>한국어</b><br>&amp; English\r\n\r\n00:03.000 --> 00:02.000\r\nIgnore";
        let cues = parse(input);
        assert_eq!(cues.len(), 2);
        assert_eq!(cues[0].start, 1.5);
        assert_eq!(cues[0].text, "한국어\n& English");
        assert_eq!(cues[1].text, "Second");
    }
}

pub(super) fn command_output(
    program: &str,
    args: impl IntoIterator<Item = impl AsRef<std::ffi::OsStr>>,
    limit: usize,
) -> Result<Vec<u8>, String> {
    use std::io::Read;
    use std::process::{Command, Stdio};

    let mut child = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .stdout(Stdio::piped())
        .spawn()
        .map_err(|error| format!("Could not start {program}: {error}"))?;
    let mut output = Vec::new();
    let read = child
        .stdout
        .take()
        .unwrap()
        .take(limit as u64 + 1)
        .read_to_end(&mut output);
    if read.is_err() || output.len() > limit {
        let _ = child.kill();
    }
    let status = child
        .wait()
        .map_err(|error| format!("Could not wait for {program}: {error}"))?;
    read.map_err(|error| format!("Could not read output from {program}: {error}"))?;
    if output.len() > limit {
        return Err(format!("{program} output exceeds the size limit"));
    }
    if !status.success() {
        return Err(format!("{program} could not process the media"));
    }
    Ok(output)
}

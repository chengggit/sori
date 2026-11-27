use std::{
    io::Read,
    process::{Command, Stdio},
    sync::mpsc,
    time::{Duration, Instant},
};

/// Capture bounded output under a single deadline covering both pipe reads and exit.
/// Always reap the direct child, including on timeout and output overflow.
pub fn output(
    command: &mut Command,
    label: &str,
    limit: usize,
    timeout: Duration,
) -> Result<Vec<u8>, String> {
    let started = Instant::now();
    let mut child = command
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .stdout(Stdio::piped())
        .spawn()
        .map_err(|error| format!("Could not start {label}: {error}"))?;
    let stdout = child.stdout.take().expect("piped stdout");
    let (sender, receiver) = mpsc::channel();
    std::thread::spawn(move || {
        let mut bytes = Vec::new();
        let result = stdout
            .take(limit as u64 + 1)
            .read_to_end(&mut bytes)
            .map(|_| bytes);
        let _ = sender.send(result);
    });
    let collect = || -> Result<Vec<u8>, String> {
        let bytes = receiver
            .recv_timeout(timeout.saturating_sub(started.elapsed()))
            .map_err(|_| format!("{label} timed out."))?
            .map_err(|error| format!("Could not read output from {label}: {error}"))?;
        if bytes.len() > limit {
            return Err(format!("{label} output exceeds the size limit"));
        }
        Ok(bytes)
    };
    let result = collect().and_then(|bytes| loop {
        match child.try_wait() {
            Ok(Some(status)) if status.success() => break Ok(bytes),
            Ok(Some(_)) => break Err(format!("{label} could not process the media")),
            Err(error) => break Err(format!("Could not wait for {label}: {error}")),
            Ok(None) if started.elapsed() >= timeout => break Err(format!("{label} timed out.")),
            Ok(None) => std::thread::sleep(Duration::from_millis(10)),
        }
    });
    if result.is_err() {
        let _ = child.kill();
        let _ = child.wait();
    }
    result
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    fn run(script: &str, limit: usize, timeout: Duration) -> Result<Vec<u8>, String> {
        output(
            Command::new("sh").args(["-c", script]),
            "test process",
            limit,
            timeout,
        )
    }
    #[test]
    fn captures_output_and_rejects_failure_and_overflow() {
        let timeout = Duration::from_secs(2);
        assert_eq!(run("printf hello", 5, timeout).unwrap(), b"hello");
        assert!(run("exit 1", 5, timeout)
            .unwrap_err()
            .contains("could not process"));
        assert!(run("printf too-long", 5, timeout)
            .unwrap_err()
            .contains("size limit"));
    }
    #[test]
    fn bounds_wait_for_silent_process_and_closed_stdout() {
        for script in ["exec sleep 5", "exec 1>&-; exec sleep 5"] {
            let start = Instant::now();
            assert!(run(script, 64, Duration::from_millis(50))
                .unwrap_err()
                .contains("timed out"));
            assert!(start.elapsed() < Duration::from_secs(2));
        }
    }
}

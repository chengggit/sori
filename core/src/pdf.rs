use std::collections::HashMap;
use std::io::ErrorKind;
use std::path::Path;
use std::process::Command;

pub const MAX_PDF_BYTES: u64 = 50 * 1024 * 1024;

pub fn extract(path: &Path) -> Result<String, String> {
    let metadata = std::fs::metadata(path)
        .map_err(|error| format!("Could not read this PDF: {error}"))?;
    if metadata.len() > MAX_PDF_BYTES {
        return Err("Choose a PDF no larger than 50 MiB.".into());
    }

    let program = std::env::var_os("SORI_PDFTOTEXT").unwrap_or_else(|| "pdftotext".into());
    let output = Command::new(program)
        .arg("-enc")
        .arg("UTF-8")
        .arg("-eol")
        .arg("unix")
        .arg(path)
        .arg("-")
        .output()
        .map_err(|error| {
            if error.kind() == ErrorKind::NotFound {
                "Install poppler-utils to import PDFs.".to_string()
            } else {
                format!("Could not read this PDF: {error}")
            }
        })?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let message = stderr.lines().next().unwrap_or_default().trim();
        return Err(if message.is_empty() {
            "Could not read this PDF.".into()
        } else {
            format!("Could not read this PDF: {message}")
        });
    }

    let raw = String::from_utf8_lossy(&output.stdout);
    Ok(reflow(&raw))
}

pub fn reflow(raw: &str) -> String {
    let raw = raw.replace("\r\n", "\n").replace('\r', "\n");
    let mut pages: Vec<Vec<String>> = raw
        .split('\u{0c}')
        .map(|page| page.lines().map(clean_line).collect())
        .collect();
    remove_running_lines(&mut pages);

    let mut paragraphs_out = Vec::new();
    for lines in &pages {
        paragraphs_out.extend(paragraphs(lines));
    }
    paragraphs_out.join("\n\n")
}

fn clean_line(line: &str) -> String {
    let line = line.replace('\u{00a0}', " ").replace(['\u{200b}', '\u{feff}'], "");
    line.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn remove_running_lines(pages: &mut [Vec<String>]) {
    let page_count = pages.len();
    if page_count < 3 {
        return;
    }

    let mut counts = HashMap::new();
    if page_count >= 5 {
        for lines in pages.iter() {
            for index in edge_indices(lines) {
                *counts.entry(normalize_running(&lines[index])).or_insert(0) += 1;
            }
        }
    }

    for (page_index, lines) in pages.iter_mut().enumerate() {
        for index in edge_indices(lines) {
            let line = &lines[index];
            if is_page_number(line) {
                lines[index].clear();
                continue;
            }
            if page_count >= 5 && page_index > 0 {
                let count = counts
                    .get(&normalize_running(line))
                    .copied()
                    .unwrap_or_default();
                if count >= 3 && count * 5 >= page_count * 3 {
                    lines[index].clear();
                }
            }
        }
    }
}

fn edge_indices(lines: &[String]) -> Vec<usize> {
    let non_empty: Vec<usize> = lines
        .iter()
        .enumerate()
        .filter(|(_, line)| !line.is_empty())
        .map(|(index, _)| index)
        .collect();
    if non_empty.len() <= 4 {
        return non_empty;
    }
    let mut edges = Vec::with_capacity(4);
    edges.extend_from_slice(&non_empty[..2]);
    edges.extend_from_slice(&non_empty[non_empty.len() - 2..]);
    edges.sort_unstable();
    edges.dedup();
    edges
}

fn normalize_running(line: &str) -> String {
    line.chars()
        .map(|c| if c.is_ascii_digit() { '#' } else { c })
        .collect()
}

fn is_page_number(line: &str) -> bool {
    let trimmed = line.trim().trim_matches(|c: char| {
        c.is_whitespace() || matches!(c, '-' | '–' | '—' | '.' | '·' | '|' | '/')
    });
    !trimmed.is_empty()
        && trimmed.len() <= 8
        && trimmed.chars().any(|c| c.is_ascii_digit())
        && trimmed.chars().all(|c| {
            c.is_ascii_digit() || matches!(c, ' ' | '/' | '|' | '-' | '–' | '—' | '.')
        })
}

fn paragraphs(lines: &[String]) -> Vec<String> {
    let mut result = Vec::new();
    let mut current = String::new();
    for line in lines {
        if line.is_empty() {
            push_paragraph(&mut result, &mut current);
            continue;
        }
        if current.is_empty() {
            current.push_str(line);
        } else {
            append_wrapped(&mut current, line);
        }
    }
    push_paragraph(&mut result, &mut current);
    result
}

fn append_wrapped(current: &mut String, line: &str) {
    let join_without_space = if current.ends_with('\u{00ad}') {
        current.pop();
        true
    } else if current.ends_with('-') && line.starts_with(|c: char| c.is_ascii_lowercase()) {
        current.pop();
        true
    } else {
        ends_with_opening(current) || starts_with_closing(line)
    };
    if !join_without_space {
        current.push(' ');
    }
    current.push_str(line);
}

fn ends_with_opening(text: &str) -> bool {
    text.chars()
        .next_back()
        .is_some_and(|c| matches!(c, '(' | '[' | '{' | '“' | '‘' | '«' | '〈' | '《' | '「' | '『'))
}

fn starts_with_closing(text: &str) -> bool {
    text.chars().next().is_some_and(|c| {
        matches!(
            c,
            ',' | '.' | ';' | ':' | '!' | '?' | ')' | ']' | '}' | '”' | '’' | '»' | '〉' | '》'
                | '」' | '』'
        )
    })
}

fn push_paragraph(result: &mut Vec<String>, current: &mut String) {
    let trimmed = current.trim();
    if !trimmed.is_empty() {
        result.push(trimmed.to_owned());
    }
    current.clear();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn joins_wrapped_lines_and_keeps_paragraph_breaks() {
        assert_eq!(
            reflow("한국어 공부를\n시작합니다.\n\n새 문단입니다.\n"),
            "한국어 공부를 시작합니다.\n\n새 문단입니다."
        );
    }

    #[test]
    fn removes_page_numbers_and_repeated_running_headers() {
        let raw: String = (1..=6)
            .map(|page| format!("표준 교재 {page}\n본문 {page}입니다.\n한 줄 더.\n- {page} -\n\u{0c}"))
            .collect();
        let text = reflow(&raw);
        assert!(text.contains("표준 교재 1"));
        assert!(!text.contains("표준 교재 2"));
        assert!(!text.contains("- 2 -"));
        assert!(text.contains("본문 1입니다."));
    }

    #[test]
    fn joins_hyphenated_latin_words_and_drops_control_characters() {
        assert_eq!(reflow("exam-\nple\n"), "example");
        assert_eq!(reflow("\u{feff}  한국어\u{00a0}공부  \n"), "한국어 공부");
    }

    #[test]
    fn keeps_short_documents_and_empty_input_intact() {
        assert_eq!(reflow("2024\n본문입니다."), "2024 본문입니다.");
        assert_eq!(
            reflow("제목\n본문\n\u{0c}제목\n본문\n\u{0c}")
                .matches("제목")
                .count(),
            2
        );
        assert_eq!(reflow(" \n\u{0c}\n"), "");
    }
}

use crate::nlp::{KoreanAnalyzer, KoreanToken};
use serde::Serialize;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WordAnalysis {
    pub word: String,
    pub context: String,
    pub morphemes: Vec<KoreanToken>,
}

fn passage(text: &str, start: usize, end: usize) -> Result<(Vec<u16>, usize), String> {
    let text: Vec<u16> = text.encode_utf16().collect();
    if start >= end || end > text.len() || end - start > 2048 {
        return Err("Select a word or short phrase to analyze.".into());
    }
    String::from_utf16(&text[start..end]).map_err(|_| "Select complete Unicode characters.")?;
    let mut left = start.saturating_sub(1024);
    let mut right = (end + 1024).min(text.len());
    // Keep the bounded passage inside a paragraph where possible.
    if let Some(index) = text[left..start]
        .iter()
        .rposition(|unit| matches!(unit, 10 | 13))
    {
        left += index + 1;
    }
    if let Some(index) = text[end..right]
        .iter()
        .position(|unit| matches!(unit, 10 | 13))
    {
        right = end + index;
    }
    if left < start && (0xdc00..=0xdfff).contains(&text[left]) {
        left += 1;
    }
    if right < text.len() && (0xdc00..=0xdfff).contains(&text[right]) {
        right -= 1;
    }
    Ok((text[left..right].to_vec(), left))
}

pub fn analyze(
    analyzer: &KoreanAnalyzer,
    text: &str,
    start: usize,
    end: usize,
) -> Result<WordAnalysis, String> {
    let (passage, offset) = passage(text, start, end)?;
    let word = String::from_utf16(&passage[start - offset..end - offset])
        .map_err(|error| error.to_string())?;
    if word.trim().is_empty() {
        return Err("Select a word to analyze.".into());
    }
    let tokens =
        analyzer.analyze(String::from_utf16(&passage).map_err(|error| error.to_string())?)?;
    let selected: Vec<_> = tokens
        .iter()
        .filter(|token| token.start < end - offset && token.end > start - offset)
        .collect();
    let first = selected
        .first()
        .ok_or("No morphemes found for this selection.")?
        .sentence_index;
    let last = selected.last().unwrap().sentence_index;
    let sentence: Vec<_> = tokens
        .iter()
        .filter(|token| token.sentence_index >= first && token.sentence_index <= last)
        .collect();
    let context_start = sentence
        .iter()
        .map(|token| token.start)
        .min()
        .unwrap()
        .min(start - offset);
    let context_end = sentence
        .iter()
        .map(|token| token.end)
        .max()
        .unwrap()
        .max(end - offset);
    let context = String::from_utf16(&passage[context_start..context_end])
        .map_err(|error| error.to_string())?;
    let morphemes = tokens
        .into_iter()
        .filter(|token| token.start < end - offset && token.end > start - offset)
        .map(|mut token| {
            token.start += offset;
            token.end += offset;
            token
        })
        .collect();
    Ok(WordAnalysis {
        word,
        context,
        morphemes,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn bounds_passages_without_splitting_unicode_or_crossing_paragraphs() {
        let (part, offset) = passage("앞 문단\n😀 학교에 갔어요.\n다음 문단", 8, 10).unwrap();
        assert_eq!(offset, 5);
        assert_eq!(String::from_utf16(&part).unwrap(), "😀 학교에 갔어요.");
        assert!(passage("😀 학교", 1, 2).is_err());
        assert!(passage("학교", 0, 99).is_err());
        assert!(passage("학교", 1, 1).is_err());
        let text = "😀한국어".repeat(10000);
        let (part, _) = passage(&text, 5003, 5005).unwrap();
        assert!(String::from_utf16(&part).unwrap().len() <= 16 * 1024);
    }

    #[test]
    #[ignore = "requires native Kiwi resources from npm run setup:kiwi"]
    fn analyzes_selection_with_original_sentence_and_contracted_morphemes() {
        let analyzer = KoreanAnalyzer::start(
            std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("resources/kiwi"),
        )
        .unwrap();
        let result = analyze(&analyzer, "😀 학교에 갔어요. 다음 문장입니다.", 7, 10).unwrap();
        assert_eq!(result.word, "갔어요");
        assert_eq!(result.context, "😀 학교에 갔어요.");
        assert!(result.morphemes.iter().any(|token| token.form == "가"));
        assert!(result.morphemes.len() > 1);
    }
}

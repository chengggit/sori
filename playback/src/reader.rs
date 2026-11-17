use crate::nlp::{KoreanAnalyzer, KoreanToken};
use serde::Serialize;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WordAnalysis {
    pub word: String,
    pub context: String,
    pub morphemes: Vec<KoreanToken>,
    pub normalized_form: String,
    pub lookup_terms: Vec<String>,
    pub parts: Vec<WordPart>,
}

#[derive(Serialize)]
pub struct WordRange {
    start: usize,
    end: usize,
}

pub fn word_ranges(analyzer: &KoreanAnalyzer, text: String) -> Result<Vec<WordRange>, String> {
    let tokens = analyzer.analyze(text)?;
    let mut ranges = Vec::new();
    for group in
        tokens.chunk_by(|a, b| a.sentence_index == b.sentence_index && a.word_index == b.word_index)
    {
        let mut words = group
            .iter()
            .filter(|token| token.surface.chars().any(char::is_alphanumeric));
        if let Some(first) = words.next() {
            let range = words.fold(
                WordRange {
                    start: first.start,
                    end: first.end,
                },
                |range, token| WordRange {
                    start: range.start.min(token.start),
                    end: range.end.max(token.end),
                },
            );
            ranges.push(range);
        }
    }
    Ok(ranges)
}

#[derive(Debug, Serialize)]
pub struct WordPart {
    pub term: String,
    pub label: &'static str,
    pub explanation: Option<&'static str>,
}

fn grammar_explanation(tag: &str, form: &str) -> Option<&'static str> {
    Some(match (tag, form) {
        ("EP", "었" | "았" | "였") => "Past tense / completed state",
        ("EP", "겠") => "Intention, prediction, or supposition",
        ("EP", "시" | "으시") => "Honorific marker for the subject",
        ("EF", "다" | "ㄴ다" | "는다") => "Plain-style statement ending",
        ("EF", "어요" | "아요" | "여요") => "Polite conversational ending",
        ("EF", "습니다" | "ㅂ니다") => "Formal polite statement ending",
        ("JKS", "이" | "가") => "Subject marker",
        ("JKO", "을" | "를") => "Object marker",
        ("JKG", "의") => "Possession or relation marker",
        ("JX", "은" | "는") => "Topic or contrast marker",
        ("JX", "도") => "Also / too",
        ("JX", "만") => "Only",
        ("ETN", "기") => "Turns the action into a noun",
        ("ETN", "음" | "ㅁ") => "Turns the action or state into a noun",
        ("XSV", "하") => "Forms a verb meaning to do the preceding action",
        ("XSV", "되") => "Forms a verb meaning to become or be acted on",
        ("XSA", "하") => "Forms an adjective from the preceding noun or root",
        _ => return None,
    })
}

fn word_breakdown(tokens: &[KoreanToken]) -> Vec<WordPart> {
    let mut parts = Vec::<WordPart>::new();
    for token in tokens {
        let tag = token.tag.split('-').next().unwrap_or_default();
        if matches!(tag, "XSV" | "XSA") && token.form == "하" {
            if let Some(previous) = parts
                .last_mut()
                .filter(|part| matches!(part.label, "Noun" | "Proper noun" | "Root"))
            {
                previous.term.push_str("하다");
                previous.label = if tag == "XSV" { "Verb" } else { "Adjective" };
                continue;
            }
        }

        let label = match tag {
            "NNG" => "Noun",
            "NNP" => "Proper noun",
            "NNB" => "Dependent noun",
            "NP" => "Pronoun",
            "NR" => "Numeral",
            "VV" => "Verb",
            "VA" => "Adjective",
            "VX" => "Auxiliary",
            "VCP" | "VCN" => "Copula",
            "MM" => "Determiner",
            "MAG" | "MAJ" => "Adverb",
            "IC" => "Interjection",
            "XR" => "Root",
            "XPN" => "Prefix",
            "XSN" => "Noun suffix",
            "XSV" => "Verb suffix",
            "XSA" => "Adjective suffix",
            "SL" => "Foreign word",
            "SH" => "Hanja",
            "SN" => "Number",
            tag if tag.starts_with('J') => "Particle",
            tag if tag.starts_with('E') => "Ending",
            tag if tag.starts_with('S') => continue,
            _ => "Morpheme",
        };
        let term = if tag.starts_with(['J', 'E']) || matches!(tag, "XSN" | "XSV" | "XSA") {
            format!("-{}", token.form)
        } else if matches!(tag, "VV" | "VA" | "VX" | "VCP" | "VCN") {
            format!("{}다", token.form)
        } else {
            token.form.clone()
        };
        parts.push(WordPart {
            term,
            label,
            explanation: grammar_explanation(tag, &token.form),
        });
    }
    parts
}

fn lookup_terms(word: &str, normalized: &str, tokens: &[KoreanToken]) -> Vec<String> {
    let base: String = tokens
        .iter()
        .take_while(|token| !token.tag.starts_with(['J', 'E']))
        .position(|token| token.tag.starts_with("XSV") && token.form == "되")
        .map(|position| {
            tokens[..position]
                .iter()
                .map(|token| token.form.as_str())
                .collect()
        })
        .unwrap_or_default();
    let mut candidates = Vec::new();
    for term in [word.trim(), normalized, &base] {
        if !term.is_empty()
            && term.chars().count() <= 100
            && !candidates.iter().any(|candidate| candidate == term)
        {
            candidates.push(term.to_owned());
        }
    }
    candidates
}

fn dictionary_form(tokens: &[KoreanToken]) -> String {
    let mut form = String::new();
    let mut last_tag = "";
    for token in tokens {
        let tag = token.tag.split('-').next().unwrap_or_default();
        if tag.starts_with(['J', 'E', 'S']) && tag != "SL" && tag != "SH" {
            break;
        }
        form.push_str(&token.form);
        last_tag = tag;
    }
    if matches!(last_tag, "VV" | "VA" | "VX" | "VCP" | "VCN" | "XSV" | "XSA") {
        form.push('다');
    }
    form
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
    let morphemes: Vec<_> = tokens
        .into_iter()
        .filter(|token| token.start < end - offset && token.end > start - offset)
        .map(|mut token| {
            token.start += offset;
            token.end += offset;
            token
        })
        .collect();
    let normalized_form = dictionary_form(&morphemes);
    Ok(WordAnalysis {
        lookup_terms: lookup_terms(&word, &normalized_form, &morphemes),
        parts: word_breakdown(&morphemes),
        word,
        context,
        normalized_form,
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
    #[ignore = "requires native Kiwi resources from node scripts/setup-kiwi.mjs"]
    fn analyzes_selection_with_original_sentence_and_contracted_morphemes() {
        let analyzer = KoreanAnalyzer::start(
            std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../resources/kiwi"),
        )
        .unwrap();
        let result = analyze(&analyzer, "😀 학교에 갔어요. 다음 문장입니다.", 7, 10).unwrap();
        assert_eq!(result.word, "갔어요");
        assert_eq!(result.context, "😀 학교에 갔어요.");
        assert_eq!(result.normalized_form, "가다");
        assert!(result.morphemes.iter().any(|token| token.form == "가"));
        assert!(result.morphemes.len() > 1);
    }
}

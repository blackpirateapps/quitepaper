use crate::model::{clean_title, display_title};
use pulldown_cmark::{Event, Parser, Tag, TagEnd};
use regex::Regex;
use std::{collections::BTreeSet, sync::LazyLock};

#[derive(Default, Debug)]
pub struct Frontmatter<'a> {
    pub body: &'a str,
    pub title: Option<String>,
    pub tags: Vec<String>,
    pub journal_date: Option<String>,
    pub end: usize,
}

pub fn frontmatter(content: &str) -> Frontmatter<'_> {
    let mut parsed = Frontmatter {
        body: content,
        ..Default::default()
    };
    let trimmed = content.trim_start();
    let mut lines = trimmed.split_inclusive('\n');
    if !lines.next().is_some_and(|l| l.trim_end() == "---") {
        return parsed;
    }
    let mut offset =
        content.len() - trimmed.len() + trimmed.find('\n').map_or(trimmed.len(), |i| i + 1);
    let mut journal = false;
    let mut date = None;
    let mut list = false;
    for line in lines {
        offset += line.len();
        if matches!(line.trim_end(), "---" | "...") {
            parsed.end = offset;
            parsed.body = &content[offset..];
            if journal {
                parsed.journal_date = date;
            }
            return parsed;
        }
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if list && line.starts_with("- ") {
            parsed.tags.push(clean_title(&line[2..]));
            continue;
        }
        if let Some((key, value)) = line.split_once(':') {
            let key = key.trim().to_lowercase();
            let value = clean_title(value);
            list = false;
            match key.as_str() {
                "title" if !value.is_empty() => parsed.title = Some(value),
                "journal" => {
                    journal = matches!(value.to_lowercase().as_str(), "true" | "yes" | "1")
                }
                "date" => date = Some(value),
                "tags" | "tag" => {
                    list = value.is_empty();
                    if value.starts_with('[') && value.ends_with(']') {
                        parsed
                            .tags
                            .extend(value[1..value.len() - 1].split(',').map(clean_title));
                    } else if !value.is_empty() {
                        parsed.tags.push(value);
                    }
                }
                _ => {}
            }
        }
    }
    Frontmatter {
        body: content,
        ..Default::default()
    }
}

pub fn title(content: &str, fallback: Option<&str>) -> String {
    let fm = frontmatter(content);
    if let Some(title) = fm.title {
        return title;
    }
    if !fm.body.trim_start().starts_with('#') {
        if let Some(value) = fallback.filter(|s| !s.trim().is_empty()) {
            return clean_title(value);
        }
    }
    display_title("", content)
}

pub fn normalized_tag(tag: &str) -> String {
    tag.trim().trim_start_matches('#').trim().to_lowercase()
}

pub fn valid_tag(tag: &str) -> bool {
    static SEGMENT: LazyLock<Regex> =
        LazyLock::new(|| Regex::new(r"^[\p{L}\p{M}\p{N}_-]+$").unwrap());
    static NUMERIC: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^\p{N}+$").unwrap());
    tag.split('/').enumerate().all(|(i, part)| {
        !part.is_empty()
            && !part.starts_with(['-', '_'])
            && !part.ends_with(['-', '_'])
            && SEGMENT.is_match(part)
            && (i != 0 || !NUMERIC.is_match(part))
    })
}

pub fn tags(title: &str, content: &str, explicit: &[String]) -> Vec<String> {
    static HASHTAG: LazyLock<Regex> =
        LazyLock::new(|| Regex::new(r###"(?:^|[\s(\[{<"'`])#([\p{L}\p{M}\p{N}_\-/]+)"###).unwrap());
    let fm = frontmatter(content);
    let text = format!("{title}\n{}", fm.body);
    let mut masked = text.as_bytes().to_vec();
    let mut code = false;
    for (event, range) in Parser::new(&text).into_offset_iter() {
        match event {
            Event::Start(Tag::CodeBlock(_)) => code = true,
            Event::End(TagEnd::CodeBlock) => {
                code = false;
                masked[range].fill(b' ');
            }
            Event::Code(_) => masked[range].fill(b' '),
            _ if code => masked[range].fill(b' '),
            _ => {}
        }
    }
    let masked = String::from_utf8(masked).expect("masked entire UTF-8 ranges");
    let mut result = BTreeSet::new();
    for tag in explicit.iter().chain(&fm.tags) {
        let tag = normalized_tag(tag);
        if valid_tag(&tag) {
            result.insert(tag);
        }
    }
    for capture in HASHTAG.captures_iter(&masked) {
        let value = capture.get(1).unwrap();
        if masked[value.end()..]
            .chars()
            .next()
            .is_some_and(|c| !c.is_whitespace() && !")],.!?>\"'`:".contains(c))
        {
            continue;
        }
        let tag = normalized_tag(value.as_str());
        if valid_tag(&tag) {
            result.insert(tag);
        }
    }
    result.into_iter().collect()
}

pub fn plain_text(content: &str) -> String {
    let mut text = String::new();
    for event in Parser::new(frontmatter(content).body) {
        match event {
            Event::Text(value) | Event::Code(value) => text.push_str(&value),
            Event::SoftBreak | Event::HardBreak | Event::End(_) => text.push(' '),
            _ => {}
        }
    }
    text
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn frontmatter_tags_code_and_unicode() {
        let source = "---\r\ntitle: 'Journal'\r\njournal: true\r\ndate: 2026-11-25\r\ntags:\r\n - work/2026\r\n---\r\n#বাংলা #2026 #a//b #a_ `#no`\n```\n#hidden\n```\n#yes";
        assert_eq!(title(source, None), "Journal");
        assert_eq!(
            frontmatter(source).journal_date.as_deref(),
            Some("2026-11-25")
        );
        assert_eq!(
            tags("Title", source, &["#EXPLICIT".into()]),
            ["explicit", "work/2026", "yes", "বাংলা"]
        );
        assert_eq!(title("body", Some("Fallback")), "Fallback");
    }
}

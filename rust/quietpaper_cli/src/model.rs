use anyhow::{anyhow, Result};
use jiff::{tz::TimeZone, Timestamp};
use serde::Serialize;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Note {
    pub id: String,
    pub short_id: String,
    pub title: String,
    pub content: String,
    pub created_at: String,
    pub updated_at: String,
    pub is_pinned: bool,
    pub is_archived: bool,
    pub is_trashed: bool,
    pub tags: Vec<String>,
    pub journal_date: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Tag {
    pub id: String,
    pub name: String,
    pub note_count: i64,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub is_pinned: bool,
}

pub fn timestamp(seconds: i64) -> Result<String> {
    let date = Timestamp::from_second(seconds)
        .map_err(|_| anyhow!("Invalid note timestamp: {seconds}"))?;
    // Dart's CLI emits local DateTime.toIso8601String(), without an offset.
    Ok(date
        .to_zoned(TimeZone::system())
        .strftime("%Y-%m-%dT%H:%M:%S.000")
        .to_string())
}

pub fn clean_title(raw: &str) -> String {
    let mut title = raw.trim();
    if title
        .get(..6)
        .is_some_and(|s| s.eq_ignore_ascii_case("title:"))
    {
        title = title[6..].trim();
    }
    if title.len() >= 2
        && ((title.starts_with('"') && title.ends_with('"'))
            || (title.starts_with('\'') && title.ends_with('\'')))
    {
        title = title[1..title.len() - 1].trim();
    }
    title.to_owned()
}

pub fn display_title(stored: &str, content: &str) -> String {
    let title = clean_title(stored);
    if !title.is_empty() {
        return title;
    }
    let mut body = content;
    let trimmed = content.trim_start();
    let mut lines = trimmed.split_inclusive('\n');
    if lines.next().is_some_and(|line| line.trim_end() == "---") {
        let mut offset = trimmed.find('\n').map_or(trimmed.len(), |i| i + 1);
        let mut frontmatter_title = None;
        for line in lines {
            offset += line.len();
            if matches!(line.trim_end(), "---" | "...") {
                body = &trimmed[offset..];
                if let Some(title) = frontmatter_title {
                    return title;
                }
                break;
            }
            if let Some((key, value)) = line.split_once(':') {
                if key.trim().eq_ignore_ascii_case("title") {
                    let title = clean_title(value);
                    if !title.is_empty() {
                        frontmatter_title = Some(title);
                    }
                }
            }
        }
    }
    for line in body.lines().map(str::trim).filter(|line| !line.is_empty()) {
        let title = if line.starts_with('#') {
            clean_title(line.trim_start_matches('#'))
        } else if line.chars().count() > 80 {
            format!("{}...", line.chars().take(77).collect::<String>())
        } else {
            clean_title(line)
        };
        if !title.is_empty() {
            return title;
        }
    }
    "Untitled".to_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn titles_preserve_unicode_and_skip_frontmatter() {
        assert_eq!(display_title("title: 'বাংলা'", "body"), "বাংলা");
        assert_eq!(
            display_title("", "---\r\ntitle: \"Journal\"\r\n---\r\nBody"),
            "Journal"
        );
        assert_eq!(
            display_title("", "---\ntags: [work]\n...\n# Heading"),
            "Heading"
        );
        assert_eq!(display_title("", "---\ntitle: ignored\n"), "---");
        assert_eq!(
            display_title("", &"界".repeat(81)),
            format!("{}...", "界".repeat(77))
        );
        assert_eq!(display_title("", "\n#\n"), "Untitled");
    }
}

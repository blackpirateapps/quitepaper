use crate::{database::Database, markdown, model::display_title, rich, writes};
use anyhow::{bail, ensure, Context, Result};
use jiff::civil::Date;
use pulldown_cmark::{Event, Options, Parser};
use regex::Regex;
use sha2::{Digest, Sha256};
use std::{ops::Range, sync::LazyLock};

#[derive(Clone)]
pub struct Task {
    pub note_id: String,
    pub note_title: String,
    pub text: String,
    pub heading: Option<String>,
    pub completed: bool,
    pub due: Option<Date>,
    pub ordinal: usize,
    id: Option<String>,
    version: [u8; 32],
}

#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Group {
    Overdue,
    Today,
    Upcoming,
    Undated,
}

impl Group {
    pub fn label(self) -> &'static str {
        match self {
            Self::Overdue => "Overdue",
            Self::Today => "Today",
            Self::Upcoming => "Upcoming",
            Self::Undated => "No due date",
        }
    }
}

impl Task {
    pub fn id(&self) -> Option<&str> {
        self.id.as_deref()
    }

    pub fn group(&self, today: Date) -> Group {
        match self.due {
            Some(due) if due < today => Group::Overdue,
            Some(due) if due == today => Group::Today,
            Some(_) => Group::Upcoming,
            None => Group::Undated,
        }
    }
}

struct Metadata {
    id: String,
    due: Option<Date>,
}

impl Metadata {
    fn new(id: &str, due: Option<&str>) -> Option<Self> {
        static ID: LazyLock<Regex> = LazyLock::new(|| {
            Regex::new(
                r"(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
            )
            .unwrap()
        });
        if !ID.is_match(id) {
            return None;
        }
        let due = match due {
            Some(value) => Some(calendar_date(value)?),
            None => None,
        };
        Some(Self {
            id: id.to_ascii_lowercase(),
            due,
        })
    }
}

fn calendar_date(value: &str) -> Option<Date> {
    let date: Date = value.parse().ok()?;
    (date.year() >= 1 && date.to_string() == value).then_some(date)
}

#[derive(serde::Deserialize)]
#[serde(deny_unknown_fields)]
struct RichMetadata {
    v: f64,
    id: String,
    due: Option<String>,
}

enum Marker {
    Markdown(usize),
    Rich(Range<usize>, bool),
}

impl Marker {
    fn write(&self, content: &mut String, completed: bool) {
        match self {
            Self::Markdown(offset) => {
                content.replace_range(*offset..*offset + 1, if completed { "x" } else { " " })
            }
            Self::Rich(range, missing) => {
                let replacement = match (missing, completed) {
                    (true, true) => "\"isChecked\":true,",
                    (true, false) => "\"isChecked\":false,",
                    (false, true) => "true",
                    (false, false) => "false",
                };
                content.replace_range(range.clone(), replacement);
            }
        }
    }
}

struct Occurrence {
    marker: Marker,
    text: String,
    heading: Option<String>,
    completed: bool,
    metadata: Option<Metadata>,
}

fn occurrences(content: &str) -> Result<Vec<Occurrence>> {
    if !rich::is_document(content) {
        return Ok(markdown_occurrences(content));
    }

    let mut heading = None;
    let mut items = Vec::new();
    let blocks = rich::blocks(content)
        .map_err(|_| anyhow::anyhow!("The rich source note could not be read"))?;
    for block in blocks {
        match block.kind().as_str() {
            "heading" => heading = Some(block.text()),
            "checklist_item" => {
                let metadata = block.field::<RichMetadata>("task").and_then(|meta| {
                    (meta.v == 1.0)
                        .then(|| Metadata::new(&meta.id, meta.due.as_deref()))
                        .flatten()
                });
                let (range, missing) = block.completion_range(content);
                items.push(Occurrence {
                    marker: Marker::Rich(range, missing),
                    text: block.text(),
                    heading: heading.clone(),
                    completed: block.completed(),
                    metadata,
                });
            }
            _ => {}
        }
    }
    Ok(items)
}

fn markdown_metadata(text: &str) -> (&str, Option<Metadata>) {
    static COMMENT: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(
            r" <!-- qp-task:v1 id=([0-9a-fA-F-]+)(?: due=([0-9]{4}-[0-9]{2}-[0-9]{2}))? -->$",
        )
        .unwrap()
    });
    static TICKS: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"`+").unwrap());
    let Some(parts) = COMMENT.captures(text) else {
        return (text, None);
    };
    let prefix = &text[..parts.get(0).unwrap().start()];
    if prefix.contains("<!--") || prefix.ends_with('\\') {
        return (text, None);
    }
    let mut open = None;
    for run in TICKS.find_iter(prefix) {
        if prefix[..run.start()].ends_with('\\') {
            continue;
        }
        match open {
            None => open = Some(run.len()),
            Some(width) if width == run.len() => open = None,
            _ => {}
        }
    }
    if open.is_some() {
        return (text, None);
    }
    match Metadata::new(&parts[1], parts.get(2).map(|part| part.as_str())) {
        Some(meta) => (prefix, Some(meta)),
        None => (text, None),
    }
}

// Match the desktop's structural checklist scan, keeping UTF-8 byte offsets for
// editing. CommonMark alone would miss some of the checklist forms the app accepts.
fn markdown_occurrences(content: &str) -> Vec<Occurrence> {
    static CHECK: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(r"^([ \t]*(?:>[ \t]*)*(?:[-*+]|[0-9]+[.)])[ \t]+\[)([ xX])\](?:[ \t]+(.*))?$")
            .unwrap()
    });
    static QUOTE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^[ \t]*(?:>[ \t]*)+").unwrap());
    static FENCE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^(`{3,}|~{3,})(.*)$").unwrap());
    static HTML: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(r"(?i)^<(pre|script|style|textarea|div|table|section|details|summary|p|article|aside|blockquote|ul|ol|li|dl|dt|dd|figure|header|footer|main|nav|form|h[1-6])(?:[ >])").unwrap()
    });
    static LIST: LazyLock<Regex> =
        LazyLock::new(|| Regex::new(r"^(?:[-*+]|[0-9]+[.)])\s+").unwrap());
    static HEADING: LazyLock<Regex> =
        LazyLock::new(|| Regex::new(r"^#{1,6}\s+(.+?)(?:\s+#+)?$").unwrap());

    let mut items: Vec<Occurrence> = Vec::new();
    let mut fence: Option<(u8, usize)> = None;
    let mut html: Option<String> = None;
    let mut indent_of_list = None;
    let mut heading = None;
    let fm = markdown::frontmatter(content);
    let mut offset = fm.end;
    for physical in fm.body.split_inclusive('\n') {
        let start = offset;
        offset += physical.len();
        let line = physical
            .strip_suffix('\n')
            .map_or(physical, |line| line.strip_suffix('\r').unwrap_or(line));
        let structural = QUOTE.find(line).map_or(line, |quote| &line[quote.end()..]);
        let trimmed = structural.trim_start();

        let delimiter = FENCE.captures(trimmed);
        if let Some((ch, width)) = fence {
            if delimiter.is_some_and(|p| {
                p[1].as_bytes()[0] == ch && p[1].len() >= width && p[2].trim().is_empty()
            }) {
                fence = None;
            }
            continue;
        }
        if let Some(p) = delimiter {
            fence = Some((p[1].as_bytes()[0], p[1].len()));
            continue;
        }
        if let Some(end) = &html {
            if (end.is_empty() && trimmed.is_empty())
                || (!end.is_empty() && trimmed.to_ascii_lowercase().contains(end))
            {
                html = None;
            }
            continue;
        }
        if trimmed.starts_with("<!--") {
            if !trimmed.contains("-->") {
                html = Some("-->".into());
            }
            continue;
        }
        if let Some(tag) = HTML.captures(trimmed) {
            let tag = tag[1].to_ascii_lowercase();
            if matches!(tag.as_str(), "pre" | "script" | "style" | "textarea") {
                let end = format!("</{tag}>");
                if !trimmed.to_ascii_lowercase().contains(&end) {
                    html = Some(end);
                }
            } else {
                html = Some(String::new());
            }
            continue;
        }

        let indent = structural[..structural.len() - trimmed.len()]
            .chars()
            .count();
        if let Some(parts) = CHECK
            .captures(line)
            .filter(|_| indent < 4 || indent_of_list.is_some())
        {
            let prefix = parts.get(1).unwrap();
            let text = line[prefix.end() + 2..].trim_start();
            let (text, metadata) = markdown_metadata(text);
            indent_of_list = Some(indent);
            items.push(Occurrence {
                marker: Marker::Markdown(start + prefix.end()),
                text: text.into(),
                heading: heading.clone(),
                completed: &parts[2] != " ",
                metadata,
            });
        } else if !trimmed.is_empty() {
            if let Some(item) = items
                .last_mut()
                .filter(|_| indent_of_list.is_some_and(|previous| indent > previous))
            {
                item.text.push('\n');
                item.text.push_str(trimmed);
            }
            if indent == 0 {
                indent_of_list = LIST.is_match(trimmed).then_some(0);
                if let Some(h) = HEADING.captures(trimmed) {
                    heading = Some(h[1].to_owned());
                }
            }
        }
    }
    for item in &mut items {
        let mut label = String::new();
        for event in Parser::new_ext(&item.text, Options::ENABLE_STRIKETHROUGH) {
            match event {
                Event::Text(text) | Event::Code(text) => label.push_str(&text),
                Event::SoftBreak | Event::HardBreak => label.push(' '),
                _ => {}
            }
        }
        item.text = label;
    }
    items
}

pub fn list(db: &Database) -> Result<Vec<Task>> {
    // The desktop's projection can be absent on older notebooks, or dirty after
    // a CLI save. Read canonical sources directly so either notebook works.
    let mut query = db.0.prepare(
        "SELECT id,title,content FROM notes WHERE is_archived=0 AND is_trashed=0
            AND deleted_at IS NULL AND instr(content,'[')>0 ORDER BY lower(title),id",
    )?;
    let mut rows = query.query([])?;
    let mut result = Vec::new();
    while let Some(row) = rows.next()? {
        let content: String = row.get(2)?;
        if writes::is_protected(&content) {
            continue;
        }
        let Ok(items) = occurrences(&content) else {
            continue;
        };
        if items.is_empty() {
            continue;
        }
        let note_id: String = row.get(0)?;
        let title: String = row.get(1)?;
        let note_title = display_title(&title, &content);
        let version = Sha256::digest(content.as_bytes()).into();
        result.extend(items.into_iter().enumerate().map(|(ordinal, item)| Task {
            note_id: note_id.clone(),
            note_title: note_title.clone(),
            text: item.text,
            heading: item.heading,
            completed: item.completed,
            due: item.metadata.as_ref().and_then(|metadata| metadata.due),
            ordinal,
            id: item.metadata.map(|metadata| metadata.id),
            version,
        }));
    }
    Ok(result)
}

pub fn toggle(db: &Database, task: &Task) -> Result<Task> {
    db.transaction(|| {
        let note = db
            .note_by_id(&task.note_id)?
            .context("The source note is no longer available")?;
        let deleted = !db.row("notes", &note.id)?["deleted_at"].is_null();
        ensure!(
            !note.is_trashed
                && !note.is_archived
                && !deleted
                && !writes::is_protected(&note.content),
            "The source note is no longer available in Tasks"
        );

        let items = occurrences(&note.content)?;
        let (ordinal, item) = if let Some(id) = &task.id {
            let mut matches = items.iter().enumerate().filter(|(_, item)| {
                item.metadata
                    .as_ref()
                    .is_some_and(|metadata| &metadata.id == id)
            });
            let found = matches
                .next()
                .context("The task changed. Refresh Tasks and try again.")?;
            ensure!(
                matches.next().is_none(),
                "This task ID is duplicated in its source note"
            );
            found
        } else {
            ensure!(
                task.version == <[u8; 32]>::from(Sha256::digest(note.content.as_bytes())),
                "The source note changed. Refresh Tasks and try again."
            );
            (
                task.ordinal,
                items
                    .get(task.ordinal)
                    .context("The task is no longer available")?,
            )
        };
        if task.completed != item.completed {
            bail!("The task's completion changed. Refresh Tasks and try again.");
        }

        let completed = !item.completed;
        let mut content = note.content.clone();
        item.marker.write(&mut content, completed);
        db.save_task_completion(&note, &content)?;
        Ok(Task {
            completed,
            ordinal,
            version: Sha256::digest(content.as_bytes()).into(),
            ..task.clone()
        })
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::params;

    fn fixture(content: &str) -> (tempfile::TempDir, Database) {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("notebook.sqlite");
        Database::initialize(&path).unwrap();
        let db = Database::open_writable(&path).unwrap();
        db.0.execute(
            "INSERT INTO notes (id,title,content,created_at,updated_at,server_revision)
             VALUES ('source','Source',?1,1,1,7)",
            [content],
        )
        .unwrap();
        (dir, db)
    }

    const ID: &str = "03fe77cf-8000-4d05-ba80-d365fd69b17c";

    #[test]
    fn markdown_writes_only_the_selected_marker_and_queues_the_canonical_note() {
        let source = format!(
            "---\r\n- [ ] yaml\r\n---\r\n# Work\r\n> 1) [ ] **বাংলা** <!-- qp-task:v1 id={ID} due=2026-11-26 -->\r\n>    details\r\n\r\n~~~md\r\n- [ ] fenced\r\n~~~\r\n<!--\r\n- [ ] hidden\r\n-->\r\n\r\nDone\r\n    - [ ] indented code\r\n"
        );
        let (_dir, db) = fixture(&source);
        db.0.execute_batch(
            "INSERT INTO tags (id,name,created_at,updated_at) VALUES ('t','work/sub',1,1);
             INSERT INTO note_tags (note_id,tag_id,is_pinned) VALUES ('source','t',1);
             DELETE FROM task_dirty;
             INSERT INTO task_index (note_id,ordinal,version,text,note_title,completed,search_text)
               VALUES ('source',0,'old','বাংলা','Source',0,'বাংলা');",
        )
        .unwrap();
        let items = list(&db).unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].text, "বাংলা");
        assert_eq!(items[0].heading.as_deref(), Some("Work"));
        assert_eq!(items[0].due, "2026-11-26".parse().ok());
        let undo = toggle(&db, &items[0]).unwrap();
        let note = db.note_by_id("source").unwrap().unwrap();
        assert_eq!(note.content, source.replace("1) [ ]", "1) [x]"));
        assert_eq!(note.tags, ["work/sub"]);
        assert_eq!(db.row("notes", "source").unwrap()["server_revision"], 7);
        for table in [
            "note_versions",
            "sync_queue",
            "task_dirty",
            "note_search_prefix",
        ] {
            let count: i32 =
                db.0.query_row(
                    &format!("SELECT count(*) FROM {table} WHERE note_id='source'"),
                    [],
                    |row| row.get(0),
                )
                .unwrap();
            assert_eq!(count, 1, "{table}");
        }
        toggle(&db, &undo).unwrap();
        assert_eq!(db.note_by_id("source").unwrap().unwrap().content, source);
    }

    #[test]
    fn rich_writes_preserve_unknown_fields_and_do_not_require_the_desktop_index() {
        let content = r#" {
  "$schema": "quietpaper:rich_document:v1",
  "private": 123456789012345678901234567890,
  "blocks": [
    {"type":"heading","spans":[{"text":"Heading"}]},
    {"type":"checklist_item","spans":[{"text":"One","custom":true}],"isChecked": null},
    {"type":"checklist_item","spans":[{"text":"Two"}],"opaque":["unknown"]},
    {"type":"code_block","code":"- [ ] literal"}
  ]
}"#;
        let (_dir, db) = fixture(content);
        db.0.execute_batch(
            "DROP TRIGGER task_note_insert; DROP TRIGGER task_note_update;
            DROP TRIGGER task_note_delete; DROP TABLE task_index; DROP TABLE task_dirty;",
        )
        .unwrap();
        let items = list(&db).unwrap();
        assert_eq!(items.len(), 2);
        assert_eq!(items[1].heading.as_deref(), Some("Heading"));
        toggle(&db, &items[0]).unwrap();
        let first = content.replace("\"isChecked\": null", "\"isChecked\": true");
        assert_eq!(db.note_by_id("source").unwrap().unwrap().content, first);
        toggle(&db, &list(&db).unwrap()[1]).unwrap();
        assert_eq!(
            db.note_by_id("source").unwrap().unwrap().content,
            first.replace(
                "{\"type\":\"checklist_item\",\"spans\":[{\"text\":\"Two\"}]",
                "{\"isChecked\":true,\"type\":\"checklist_item\",\"spans\":[{\"text\":\"Two\"}]"
            )
        );
        let body: String =
            db.0.query_row("SELECT body_text FROM note_search_prefix", [], |row| {
                row.get(0)
            })
            .unwrap();
        assert_eq!(body, "Heading\nOne\nTwo\n- [ ] literal");
    }

    #[test]
    fn durable_task_resolves_across_edits_and_rejects_duplicates_or_changed_completion() {
        let task = format!("- [ ] Do it <!-- qp-task:v1 id={ID} -->");
        let (_dir, db) = fixture(&format!("- [ ] Legacy\n{task}"));
        let items = list(&db).unwrap();
        let external = format!("# Heading\n{text}\n{task}", text = "- [ ] New legacy task");
        let replace = |content: &str| {
            db.0.execute(
                "UPDATE notes SET content=? WHERE id='source'",
                params![content],
            )
            .unwrap()
        };
        replace(&external);
        assert!(toggle(&db, &items[0]).is_err());
        let receipt = toggle(&db, &items[1]).unwrap();
        let updated = db.note_by_id("source").unwrap().unwrap().content;
        assert!(updated.contains("- [x] Do it"));
        assert!(toggle(&db, &items[1]).is_err());
        replace(&format!("{updated}\n{task}"));
        assert!(toggle(&db, &receipt).is_err());
        assert_eq!(
            db.note_by_id("source").unwrap().unwrap().content,
            format!("{updated}\n{task}")
        );
    }
}

//! Offline native messaging. Only framed JSON reaches stdout; no acquisition,
//! asset loading, credential access, or automatic network sync occurs here.
use crate::{database::Database, markdown, writes::Save};
use anyhow::{bail, ensure, Context, Result};
use html5ever::{parse_document, tendril::TendrilSink};
use markup5ever_rcdom::{Handle, NodeData, RcDom};
use serde_json::{json, Value};
use std::{
    io::{Read, Write},
    path::Path,
};
use url::Url;
use uuid::Uuid;

const MAX_MESSAGE: usize = 8 * 1024 * 1024;

pub fn serve(path: &Path, input: &mut impl Read, output: &mut impl Write) -> Result<()> {
    loop {
        let mut header = [0; 4];
        if input.read(&mut header[..1])? == 0 {
            return Ok(());
        }
        let frame = (|| -> Result<Vec<u8>> {
            input
                .read_exact(&mut header[1..])
                .context("Truncated message header")?;
            let length = u32::from_ne_bytes(header) as usize;
            ensure!(
                (1..=MAX_MESSAGE).contains(&length),
                "Capture exceeds the 8 MiB limit"
            );
            let mut bytes = vec![0; length];
            input.read_exact(&mut bytes).context("Truncated message")?;
            Ok(bytes)
        })();
        let bytes = match frame {
            Ok(bytes) => bytes,
            Err(error) => {
                reply(output, &json!({"ok":false,"error":error.to_string()}))?;
                return Err(error);
            }
        };
        let result = serde_json::from_slice(&bytes)
            .map_err(anyhow::Error::from)
            .and_then(|request| handle(path, request));
        let response = result.unwrap_or_else(|error| json!({"ok":false,"error":error.to_string()}));
        reply(output, &response)?;
    }
}

fn reply(output: &mut impl Write, value: &Value) -> Result<()> {
    let bytes = serde_json::to_vec(value)?;
    output.write_all(&(bytes.len() as u32).to_ne_bytes())?;
    output.write_all(&bytes)?;
    output.flush()?;
    Ok(())
}

fn field<'a>(request: &'a Value, key: &str, limit: usize, required: bool) -> Result<&'a str> {
    let value = match request.get(key) {
        None | Some(Value::Null) if !required => "",
        Some(Value::String(value)) => value.trim(),
        _ => bail!("Invalid {key}"),
    };
    ensure!(
        value.len() <= limit && (!required || !value.is_empty()),
        "Invalid {key}"
    );
    Ok(value)
}

fn handle(path: &Path, request: Value) -> Result<Value> {
    ensure!(
        request.is_object() && request["version"] == 1,
        "Unsupported browser clip protocol"
    );
    if request["action"] == "ping" {
        return Ok(json!({"ok":true,"version":1}));
    }
    ensure!(request["action"] == "clip", "Unsupported browser action");
    let source = field(&request, "url", 16384, true)?;
    let base = Url::parse(source).context("Invalid webpage URL")?;
    ensure!(
        matches!(base.scheme(), "http" | "https")
            && base.host_str().is_some()
            && base.username().is_empty()
            && base.password().is_none(),
        "Only HTTP and HTTPS pages can be clipped"
    );
    let title = field(&request, "title", 4096, true)?;
    let html = field(&request, "html", MAX_MESSAGE, true)?;
    let author = field(&request, "author", 4096, false)?;
    let description = field(&request, "description", 4096, false)?;
    let published = field(&request, "publishedAt", 4096, false)?;
    let mut tags = Vec::new();
    if let Some(value) = request.get("tags") {
        let values = value.as_array().context("Invalid tags")?;
        ensure!(values.len() <= 50, "Invalid tags");
        for value in values {
            let raw = value.as_str().context("Invalid tags")?;
            let tag = markdown::normalized_tag(raw);
            ensure!(
                raw.len() <= 100 && !raw.chars().any(char::is_control) && markdown::valid_tag(&tag),
                "Invalid tags"
            );
            if !tags.contains(&tag) {
                tags.push(tag);
            }
        }
    }
    let domain = base.host_str().unwrap().trim_start_matches("www.");
    let domain: String = domain
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '_' || c == '-' {
                c
            } else {
                '-'
            }
        })
        .collect();
    tags.extend([
        "clipped".to_owned(),
        format!("web/{}", domain.trim_matches(['-', '_'])),
    ]);
    let body = convert(html, &base)?;
    ensure!(
        !body.trim().is_empty(),
        "This page has no readable content to save"
    );
    // JSON quoted strings are valid YAML scalars and cannot inject properties.
    let mut content = format!("---\ntitle: {}\nsource: {}\n", json!(title), json!(source));
    if !author.is_empty() {
        content.push_str(&format!("author: {}\n", json!(author)));
    }
    let timestamp = published
        .parse::<jiff::Timestamp>()
        .unwrap_or_else(|_| jiff::Timestamp::now());
    let date = timestamp
        .to_zoned(jiff::tz::TimeZone::UTC)
        .date()
        .to_string();
    content.push_str(&format!("created: {}\n", json!(date)));
    if !description.is_empty() {
        content.push_str(&format!("description: {}\n", json!(description)));
    }
    content.push_str("tags:\n");
    for tag in &tags {
        content.push_str(&format!("  - {}\n", json!(tag)));
    }
    content.push_str(&format!("---\n\n{}\n", body.trim()));
    // Validate the complete request before opening or creating a notebook.
    if !path.exists() {
        Database::initialize(path)?;
    }
    let db = Database::open_writable(path)?;
    let id = Uuid::new_v4().to_string();
    let note = db.transaction(|| {
        db.save_inner(&Save {
            id: &id,
            title,
            content: &content,
            tags: &tags,
            pinned: false,
            expected: None,
        })
    })?;
    Ok(json!({"ok":true,"id":note.id,"title":note.title,"savedLocally":true}))
}

fn tag(node: &Handle) -> &str {
    match &node.data {
        NodeData::Element { name, .. } => name.local.as_ref(),
        _ => "",
    }
}

fn attr(node: &Handle, key: &str) -> Option<String> {
    match &node.data {
        NodeData::Element { attrs, .. } => attrs
            .borrow()
            .iter()
            .find(|a| a.name.ns.is_empty() && a.name.local.as_ref() == key)
            .map(|a| a.value.to_string()),
        _ => None,
    }
}

fn blocked(node: &Handle) -> bool {
    matches!(
        tag(node),
        "head"
            | "script"
            | "style"
            | "noscript"
            | "iframe"
            | "object"
            | "embed"
            | "form"
            | "input"
            | "textarea"
            | "select"
            | "button"
            | "svg"
            | "canvas"
            | "template"
            | "link"
            | "meta"
            | "base"
    )
}

fn safe_url(node: &Handle, key: &str, base: &Url) -> Option<String> {
    let raw = attr(node, key)?;
    if raw.trim().is_empty() {
        return None;
    }
    let url = base.join(raw.trim()).ok()?;
    if (matches!(url.scheme(), "http" | "https")
        && url.host_str().is_some()
        && url.username().is_empty()
        && url.password().is_none())
        || (key == "href" && url.scheme() == "mailto")
    {
        Some(url.to_string().replace('(', "%28").replace(')', "%29"))
    } else {
        None
    }
}

fn escape(text: &str) -> String {
    let mut output = String::new();
    for c in text.chars() {
        if "\\`*_[]<>#".contains(c) {
            output.push('\\');
        }
        output.push(c);
    }
    output
}

fn raw_text(node: &Handle) -> String {
    if blocked(node) {
        return String::new();
    }
    if let NodeData::Text { contents } = &node.data {
        return contents.borrow().to_string();
    }
    node.children.borrow().iter().map(raw_text).collect()
}

fn children(node: &Handle, base: &Url) -> String {
    node.children
        .borrow()
        .iter()
        .map(|child| render(child, base))
        .collect()
}

fn render(node: &Handle, base: &Url) -> String {
    if blocked(node) {
        return String::new();
    }
    if let NodeData::Text { contents } = &node.data {
        let text = contents.borrow();
        let mut output = String::new();
        let mut whitespace = false;
        for c in text.chars() {
            if c.is_whitespace() {
                if !whitespace {
                    output.push(' ');
                }
            } else {
                output.push_str(&escape(&c.to_string()));
            }
            whitespace = c.is_whitespace();
        }
        return output;
    }
    let name = tag(node);
    match name {
        "pre" | "code" => {
            let raw = raw_text(node);
            let longest = raw.split(|c| c != '`').map(str::len).max().unwrap_or(0);
            if name == "code" {
                let fence = "`".repeat(longest + 1);
                return format!("{fence}{raw}{fence}");
            }
            let code = node
                .children
                .borrow()
                .iter()
                .find(|n| tag(n) == "code")
                .cloned();
            let class = code
                .as_ref()
                .and_then(|n| attr(n, "class"))
                .or_else(|| attr(node, "class"))
                .unwrap_or_default();
            let language = class
                .split_whitespace()
                .find_map(|s| s.strip_prefix("language-"))
                .unwrap_or("");
            let language: String = language
                .chars()
                .filter(|c| c.is_ascii_alphanumeric() || "_-".contains(*c))
                .collect();
            let fence = "`".repeat((longest + 1).max(3));
            return format!("\n\n{fence}{language}\n{}\n{fence}\n\n", raw.trim_end());
        }
        "img" => {
            return safe_url(node, "src", base)
                .map(|url| {
                    format!(
                        "![{}]({url})",
                        escape(&attr(node, "alt").unwrap_or_default())
                    )
                })
                .unwrap_or_default()
        }
        "br" => return "  \n".into(),
        "hr" => return "\n\n---\n\n".into(),
        "table" => return table(node, base),
        "ul" | "ol" => {
            let mut output = String::from("\n\n");
            let mut index = 0;
            for child in node.children.borrow().iter().filter(|n| tag(n) == "li") {
                index += 1;
                let prefix = if name == "ol" {
                    format!("{index}. ")
                } else {
                    "- ".into()
                };
                let text = children(child, base);
                let indent = " ".repeat(prefix.len());
                output.push_str(&prefix);
                output.push_str(&text.trim().replace('\n', &format!("\n{indent}")));
                output.push('\n');
            }
            output.push('\n');
            return output;
        }
        _ => {}
    }
    let text = children(node, base);
    match name {
        "p" | "div" | "section" | "article" | "main" | "figure" | "figcaption" => {
            format!("\n\n{}\n\n", text.trim())
        }
        "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => format!(
            "\n\n{} {}\n\n",
            "#".repeat(name.as_bytes()[1] as usize - b'0' as usize),
            text.trim()
        ),
        "b" | "strong" => format!("**{}**", text.trim()),
        "i" | "em" => format!("*{}*", text.trim()),
        "mark" => format!("=={}==", text.trim()),
        "s" | "strike" | "del" => format!("~~{}~~", text.trim()),
        "blockquote" => format!("\n\n> {}\n\n", text.trim().replace('\n', "\n> ")),
        "a" => safe_url(node, "href", base)
            .map(|url| format!("[{}]({url})", text.trim()))
            .unwrap_or(text),
        _ => text,
    }
}

fn table(node: &Handle, base: &Url) -> String {
    fn rows(node: &Handle, base: &Url, output: &mut Vec<Vec<String>>) {
        if blocked(node) {
            return;
        }
        if tag(node) == "tr" {
            output.push(
                node.children
                    .borrow()
                    .iter()
                    .filter(|n| matches!(tag(n), "td" | "th"))
                    .map(|n| {
                        children(n, base)
                            .split_whitespace()
                            .collect::<Vec<_>>()
                            .join(" ")
                            .replace('|', "\\|")
                    })
                    .collect(),
            );
        } else {
            for child in node.children.borrow().iter() {
                rows(child, base, output);
            }
        }
    }
    let mut cells = Vec::new();
    rows(node, base, &mut cells);
    let columns = cells.iter().map(Vec::len).max().unwrap_or(0);
    if columns == 0 {
        return String::new();
    }
    let mut output = String::from("\n\n");
    for (index, row) in cells.iter().enumerate() {
        output.push_str("| ");
        for column in 0..columns {
            output.push_str(row.get(column).map(String::as_str).unwrap_or(""));
            output.push_str(" | ");
        }
        output.push('\n');
        if index == 0 {
            output.push('|');
            for _ in 0..columns {
                output.push_str(" --- |");
            }
            output.push('\n');
        }
    }
    output.push('\n');
    output
}

fn convert(html: &str, base: &Url) -> Result<String> {
    let dom = parse_document(RcDom::default(), Default::default()).one(html);
    let mut pending = vec![(dom.document.clone(), 0)];
    let mut count = 0;
    while let Some((node, depth)) = pending.pop() {
        count += 1;
        ensure!(
            count <= 60000 && depth <= 256,
            "This page is too large or deeply nested; clip a selection instead"
        );
        if !blocked(&node) {
            pending.extend(
                node.children
                    .borrow()
                    .iter()
                    .map(|n| (n.clone(), depth + 1)),
            );
        }
    }
    Ok(render(&dom.document, base).trim().to_owned())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    fn request() -> Value {
        json!({"version":1,"action":"clip","url":"https://members.example.com/articles/private",
            "title":"Members-only article","author":"A Writer","publishedAt":"2026-11-17T10:00:00Z",
            "tags":["research"],"html":"<article><p>Unique authenticated article text.</p><p><a href='../related'>Related story</a></p><pre><code class='language-dart'>print(42);</code></pre><table><tr><th>Name</th></tr><tr><td>Quiet Paper</td></tr></table></article>"})
    }

    fn frame(value: &Value) -> Vec<u8> {
        let mut output = Vec::new();
        reply(&mut output, value).unwrap();
        output
    }

    fn responses(mut bytes: &[u8]) -> Vec<Value> {
        let mut output = Vec::new();
        while !bytes.is_empty() {
            let length = u32::from_ne_bytes(bytes[..4].try_into().unwrap()) as usize;
            output.push(serde_json::from_slice(&bytes[4..4 + length]).unwrap());
            bytes = &bytes[4 + length..];
        }
        output
    }

    #[test]
    fn capture_saves_search_history_tags_and_queue_atomically() {
        let root = tempfile::tempdir().unwrap();
        let path = root.path().join("notebook.sqlite");
        let response = handle(&path, request()).unwrap();
        assert_eq!(response["ok"], true);
        let db = Database::open(&path).unwrap();
        let note = db.find(response["id"].as_str().unwrap()).unwrap();
        for text in [
            "Unique authenticated article text.",
            "[Related story](https://members.example.com/related)",
            "```dart\nprint(42);\n```",
            "| Quiet Paper |",
            "created: \"2026-11-17\"",
        ] {
            assert!(
                note.content.contains(text),
                "Missing {text}: {}",
                note.content
            );
        }
        assert_eq!(
            note.tags,
            ["clipped", "research", "web/members-example-com"]
        );
        for table in [
            "sync_queue",
            "note_versions",
            "note_search_prefix",
            "note_search_trigram",
        ] {
            assert_eq!(
                db.0.query_row(
                    &format!("SELECT COUNT(*) FROM {table} WHERE note_id=?"),
                    [&note.id],
                    |r| r.get::<_, i64>(0)
                )
                .unwrap(),
                1
            );
        }
    }

    #[test]
    fn active_content_and_non_web_urls_never_reach_markdown() {
        let html = "<script>SECRET_SCRIPT</script><form>SECRET_FORM<input value='password'></form><p onclick='evil()'>Keep this <a href='javascript:evil()'>link</a>.</p><img src='file:///etc/private.png'><img src='https://cdn.example.com/photo.png' alt='Photo'><a href='qp://document/fake'>vault</a><a href='mailto:hello@example.com'>Email</a>";
        let body = convert(html, &Url::parse("https://example.com").unwrap()).unwrap();
        assert!(body.contains("Keep this link."));
        assert!(body.contains("![Photo](https://cdn.example.com/photo.png)"));
        assert!(body.contains("[Email](mailto:hello@example.com)"));
        for text in [
            "SECRET_",
            "javascript:",
            "file:",
            "qp:",
            "password",
            "evil()",
        ] {
            assert!(!body.contains(text), "Leaked {text}");
        }
    }

    #[test]
    fn yaml_metadata_and_code_fences_cannot_inject_properties_or_break_out() {
        let root = tempfile::tempdir().unwrap();
        let path = root.path().join("notebook.sqlite");
        let mut capture = request();
        capture["title"] = json!("Title \"quote\" \\ path\njournal: true");
        capture["author"] = json!("Author\"\ntags: [injected]");
        capture["html"] = json!("<pre><code class='language-js'>```\n# literal</code></pre>");
        let response = handle(&path, capture.clone()).unwrap();
        let db = Database::open(&path).unwrap();
        let note = db.find(response["id"].as_str().unwrap()).unwrap();
        assert!(note
            .content
            .contains(&format!("title: {}", capture["title"])));
        assert!(note.content.contains("````js\n```\n# literal\n````"));
        assert!(db.row("notes", &note.id).unwrap()["journal_date"].is_null());
        assert!(!note.tags.contains(&"injected".to_owned()));
    }

    #[test]
    fn invalid_requests_and_ping_do_not_create_notebooks() {
        let root = tempfile::tempdir().unwrap();
        let path = root.path().join("notebook.sqlite");
        assert_eq!(
            handle(&path, json!({"version":1,"action":"ping"})).unwrap()["ok"],
            true
        );
        let mut invalid = vec![Value::Null, json!({"version":2,"action":"clip"})];
        for (key, value) in [
            ("action", json!("exec")),
            ("url", json!("file:///etc/passwd")),
            ("url", json!("https://user:secret@example.com")),
            ("html", json!("<script>Nothing readable</script>")),
            ("title", json!(42)),
            ("tags", json!(["bad\ntag"])),
            ("tags", json!(["invalid tag"])),
            ("tags", json!([42])),
            ("html", json!(" ")),
        ] {
            let mut capture = request();
            capture[key] = value;
            invalid.push(capture);
        }
        for value in invalid {
            assert!(handle(&path, value).is_err());
        }
        assert!(!path.exists());
    }

    #[test]
    fn fragmented_multiple_frames_and_malformed_json_keep_transport_usable() {
        struct Fragmented(Cursor<Vec<u8>>);
        impl Read for Fragmented {
            fn read(&mut self, bytes: &mut [u8]) -> std::io::Result<usize> {
                let length = bytes.len().min(1);
                self.0.read(&mut bytes[..length])
            }
        }
        let root = tempfile::tempdir().unwrap();
        let path = root.path().join("notebook.sqlite");
        let mut input = 1u32.to_ne_bytes().to_vec();
        input.push(b'{');
        input.extend(frame(&json!({"version":1,"action":"ping"})));
        let mut capture = request();
        capture["title"] = json!("বাংলা · café ☕");
        input.extend(frame(&capture));
        let mut output = Vec::new();
        serve(&path, &mut Fragmented(Cursor::new(input)), &mut output).unwrap();
        let values = responses(&output);
        assert_eq!(values.len(), 3);
        assert_eq!(values[0]["ok"], false);
        assert_eq!(values[1]["ok"], true);
        assert_eq!(values[2]["title"], "বাংলা · café ☕");
    }

    #[test]
    fn truncated_and_oversized_frames_report_errors_without_partial_saves() {
        let root = tempfile::tempdir().unwrap();
        let path = root.path().join("notebook.sqlite");
        for input in [
            vec![1, 0],
            vec![5, 0, 0, 0, b'{'],
            ((MAX_MESSAGE + 1) as u32).to_ne_bytes().to_vec(),
            0u32.to_ne_bytes().to_vec(),
        ] {
            let mut output = Vec::new();
            assert!(serve(&path, &mut Cursor::new(input), &mut output).is_err());
            assert_eq!(responses(&output)[0]["ok"], false);
        }
        assert!(!path.exists());
    }
}

use crate::{markdown, model::Note, rich, writes};
use pulldown_cmark::{Event, Options, Parser, Tag, TagEnd};
use ratatui::{
    style::{Modifier, Style},
    text::{Line, Span},
};

pub fn single_line(value: &str) -> String {
    value
        .chars()
        .map(|ch| if ch.is_control() { ' ' } else { ch })
        .collect()
}

pub fn title(note: &Note) -> &str {
    if writes::is_protected(&note.content)
        && note
            .title
            .starts_with("<!-- quiet-paper-encrypted-note-v1:")
    {
        "Protected note"
    } else {
        &note.title
    }
}

pub fn note(note: &Note, accent: Style) -> Vec<Line<'static>> {
    let title = single_line(title(note));
    let mut lines = vec![Line::styled(
        title.clone(),
        accent.add_modifier(Modifier::BOLD),
    )];
    let date = note
        .journal_date
        .as_deref()
        .or_else(|| note.updated_at.get(..10));
    let tags = note
        .tags
        .iter()
        .map(|tag| format!("#{}", single_line(tag)))
        .collect::<Vec<_>>()
        .join(" ");
    let details = [date.map(single_line).unwrap_or_default(), tags]
        .into_iter()
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>()
        .join("  ");
    if !details.is_empty() {
        lines.push(Line::styled(
            details,
            Style::new().add_modifier(Modifier::DIM),
        ));
    }
    lines.push(Line::default());

    let mut body = if writes::is_protected(&note.content) {
        vec![Line::raw(
            "Password-protected note. Unlock it in the desktop app.",
        )]
    } else if rich::is_document(&note.content) {
        rich_document(&note.content, &title, accent)
    } else {
        markdown_document(markdown::frontmatter(&note.content).body, &title, accent)
    };
    if body.is_empty() {
        body.push(Line::raw("This note is empty."));
    }
    lines.extend(body);
    lines
}

fn rich_document(content: &str, title: &str, accent: Style) -> Vec<Line<'static>> {
    let Ok(blocks) = rich::blocks(content) else {
        return vec![Line::raw("This rich document could not be displayed.")];
    };
    let mut lines = Vec::new();
    for (index, block) in blocks.into_iter().enumerate() {
        let kind = block.kind();
        let text = block.text();
        if index == 0 && kind == "heading" && single_line(&text) == title {
            continue;
        }
        let (prefix, style) = match kind.as_str() {
            "heading" => ("", accent.add_modifier(Modifier::BOLD)),
            "checklist_item" if block.completed() => ("[x] ", Style::new()),
            "checklist_item" => ("[ ] ", Style::new()),
            "bulleted_list_item" => ("• ", Style::new()),
            "ordered_list_item" => ("• ", Style::new()),
            "quote" => ("│ ", Style::new().add_modifier(Modifier::ITALIC)),
            "code_block" => ("    ", Style::new()),
            "horizontal_rule" => ("────────", Style::new().add_modifier(Modifier::DIM)),
            "image" => ("Image  ", Style::new().add_modifier(Modifier::DIM)),
            "attachment" => ("Attachment  ", Style::new().add_modifier(Modifier::DIM)),
            _ => ("", Style::new()),
        };
        for (index, line) in text.split('\n').enumerate() {
            let prefix = if index == 0 { prefix } else { "" };
            lines.push(Line::styled(
                format!("{prefix}{}", single_line(line)),
                style,
            ));
        }
    }
    lines
}

#[derive(Default)]
struct Markdown {
    lines: Vec<Line<'static>>,
    current: Vec<Span<'static>>,
    lists: Vec<Option<u64>>,
    style: Style,
    quote_depth: usize,
    code: bool,
}

impl Markdown {
    fn span(&mut self, text: &str, style: Style) {
        if self.current.is_empty() && self.quote_depth != 0 {
            self.current.push(Span::styled(
                "│ ".repeat(self.quote_depth),
                Style::new().add_modifier(Modifier::DIM),
            ));
        }
        self.current.push(Span::styled(single_line(text), style));
    }

    fn line(&mut self) {
        self.lines
            .push(Line::from(std::mem::take(&mut self.current)));
    }

    fn finish(&mut self, blank: bool) {
        if !self.current.is_empty() {
            self.line();
        }
        if blank && self.lines.last().is_some_and(|line| !line.spans.is_empty()) {
            self.line();
        }
    }

    fn text(&mut self, text: &str, style: Style) {
        for (index, line) in text.split('\n').enumerate() {
            if index != 0 {
                self.line();
            }
            if !line.is_empty() {
                if self.code && self.current.is_empty() {
                    self.span("    ", style);
                }
                self.span(line, style);
            }
        }
    }

    fn event(&mut self, event: Event<'_>, accent: Style) {
        match event {
            Event::Start(Tag::Heading { .. }) => self.style = accent.add_modifier(Modifier::BOLD),
            Event::End(TagEnd::Heading(_)) => {
                self.finish(true);
                self.style = Style::new();
            }
            Event::Start(Tag::List(start)) => self.lists.push(start),
            Event::End(TagEnd::List(_)) => {
                self.lists.pop();
                self.finish(self.lists.is_empty());
            }
            Event::Start(Tag::Item) => {
                self.finish(false);
                let indent = "  ".repeat(self.lists.len().saturating_sub(1));
                let marker = match self.lists.last_mut() {
                    Some(Some(number)) => {
                        let marker = format!("{number}. ");
                        *number = number.saturating_add(1);
                        marker
                    }
                    _ => "• ".into(),
                };
                self.span(&format!("{indent}{marker}"), self.style);
            }
            Event::End(TagEnd::Item) => self.finish(false),
            Event::TaskListMarker(checked) => {
                if let Some(marker) = self.current.last_mut() {
                    if let Some(indent) = marker.content.strip_suffix("• ") {
                        marker.content = indent.to_owned().into();
                    }
                }
                self.span(if checked { "[x] " } else { "[ ] " }, self.style)
            }
            Event::Start(Tag::BlockQuote(_)) => self.quote_depth += 1,
            Event::End(TagEnd::BlockQuote(_)) => self.quote_depth -= 1,
            Event::Start(Tag::CodeBlock(_)) => self.code = true,
            Event::End(TagEnd::CodeBlock) => {
                self.code = false;
                self.finish(true);
            }
            Event::Start(Tag::Strong) => self.style = self.style.add_modifier(Modifier::BOLD),
            Event::End(TagEnd::Strong) => self.style = self.style.remove_modifier(Modifier::BOLD),
            Event::Start(Tag::Emphasis) => self.style = self.style.add_modifier(Modifier::ITALIC),
            Event::End(TagEnd::Emphasis) => {
                self.style = self.style.remove_modifier(Modifier::ITALIC)
            }
            Event::Start(Tag::Strikethrough) => {
                self.style = self.style.add_modifier(Modifier::CROSSED_OUT)
            }
            Event::End(TagEnd::Strikethrough) => {
                self.style = self.style.remove_modifier(Modifier::CROSSED_OUT)
            }
            Event::Start(Tag::Link { .. }) => {
                self.style = self.style.add_modifier(Modifier::UNDERLINED)
            }
            Event::End(TagEnd::Link) => {
                self.style = self.style.remove_modifier(Modifier::UNDERLINED)
            }
            Event::Start(Tag::Image { .. }) => self.span("[Image: ", self.style),
            Event::End(TagEnd::Image) => self.span("]", self.style),
            Event::End(TagEnd::TableCell) => self.span("  ", self.style),
            Event::End(TagEnd::TableRow | TagEnd::TableHead) => self.finish(false),
            Event::End(TagEnd::Paragraph) => self.finish(self.lists.is_empty()),
            Event::Text(text) => self.text(&text, self.style),
            Event::Code(text) => self.span(&text, self.style.patch(accent)),
            Event::SoftBreak => self.span(" ", self.style),
            Event::HardBreak => self.line(),
            Event::Rule => {
                self.span("────────", Style::new().add_modifier(Modifier::DIM));
                self.finish(true);
            }
            _ => {}
        }
    }
}

fn markdown_document(source: &str, title: &str, accent: Style) -> Vec<Line<'static>> {
    let mut body = Markdown::default();
    let options =
        Options::ENABLE_TASKLISTS | Options::ENABLE_STRIKETHROUGH | Options::ENABLE_TABLES;
    let mut events = Parser::new_ext(source, options).peekable();
    if matches!(events.peek(), Some(Event::Start(Tag::Heading { .. }))) {
        for event in events.by_ref() {
            let end = matches!(event, Event::End(TagEnd::Heading(_)));
            body.event(event, accent);
            if end {
                break;
            }
        }
        if body.lines.first().is_some_and(|line| {
            line.spans
                .iter()
                .map(|span| span.content.as_ref())
                .collect::<String>()
                == title
        }) {
            body.lines.clear();
        }
    }
    for event in events {
        body.event(event, accent);
    }
    body.finish(false);
    while body.lines.last().is_some_and(|line| line.spans.is_empty()) {
        body.lines.pop();
    }
    body.lines
}

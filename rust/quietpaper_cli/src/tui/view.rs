use super::{
    preview::{single_line, title as note_title},
    App, Item, Pane, Section,
};
use ratatui::{
    layout::{Constraint, Layout, Rect},
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, List, ListItem, Padding, Paragraph, Wrap},
    Frame,
};

const DIM: Style = Style::new().add_modifier(Modifier::DIM);
const BOLD: Style = Style::new().add_modifier(Modifier::BOLD);

pub fn render(frame: &mut Frame, app: &mut App) {
    let area = frame.area();
    if area.width < 25 || area.height < 8 {
        frame.render_widget(
            Paragraph::new("Enlarge terminal · q Quit").wrap(Wrap { trim: true }),
            area,
        );
        return;
    }

    let footer_height = if app.search_before.is_some()
        || !app.status.is_empty()
        || (!app.filter.is_empty() && area.width < 96)
    {
        2
    } else {
        1
    };
    let [header, body, footer] = Layout::vertical([
        Constraint::Length(2),
        Constraint::Min(1),
        Constraint::Length(footer_height),
    ])
    .areas(area);

    let mut header_spans = vec![Span::styled("Quiet Paper", app.accent.patch(BOLD))];
    if app.reader.is_some() {
        header_spans.push(Span::styled("  /  Reader", DIM));
    }
    if app.reader.is_none() && (area.width < 96 || app.section == Section::Tasks) {
        header_spans.push(Span::styled(format!("  /  {}", app.section.label()), DIM));
    }
    frame.render_widget(
        Paragraph::new(Line::from(header_spans))
            .block(Block::default().padding(Padding::horizontal(1))),
        header,
    );

    if app.reader.is_some() {
        let width = body.width.min(90);
        let centered = Rect::new(
            body.x + (body.width - width) / 2,
            body.y,
            width,
            body.height,
        );
        render_preview(frame, app, centered);
    } else if area.width >= 96 {
        let [sidebar, list, preview] = Layout::horizontal([
            Constraint::Length(18),
            Constraint::Percentage(31),
            Constraint::Min(40),
        ])
        .areas(body);
        render_sidebar(frame, app, sidebar);
        render_list(frame, app, list);
        render_preview(frame, app, preview);
    } else {
        match app.pane {
            Pane::Sidebar => render_sidebar(frame, app, body),
            Pane::List => render_list(frame, app, body),
            Pane::Preview => render_preview(frame, app, body),
        }
    }

    render_footer(frame, app, footer);
    if app.help {
        render_help(frame, app, body);
    }
}

fn pane(app: &App, title: String, focus: Pane) -> Block<'static> {
    let active = focus == app.pane;
    let border_style = if active { app.accent } else { DIM };
    let title_style = if active { app.accent.patch(BOLD) } else { DIM };
    Block::default()
        .borders(Borders::TOP)
        .border_style(border_style)
        .title(Line::styled(format!(" {title} "), title_style))
        .padding(Padding::horizontal(1))
}

fn render_sidebar(frame: &mut Frame, app: &mut App, area: Rect) {
    let active = app.pane == Pane::Sidebar;
    let rows = Section::ALL.map(|section| {
        let current = app.section == section;
        let marker = if current { "› " } else { "  " };
        let style = if current {
            app.accent.patch(BOLD)
        } else {
            Style::new()
        };
        ListItem::new(Line::styled(format!("{marker}{}", section.label()), style))
    });
    let block = pane(app, "Notebook".into(), Pane::Sidebar);
    let highlight = if active {
        Style::new().add_modifier(Modifier::REVERSED)
    } else {
        Style::new()
    };
    frame.render_stateful_widget(
        List::new(rows).block(block).highlight_style(highlight),
        area,
        &mut app.sidebar,
    );
}

fn render_list(frame: &mut Frame, app: &mut App, area: Rect) {
    let title = if app.section == Section::Tasks {
        if app.completed {
            "Completed".into()
        } else {
            "Open tasks".into()
        }
    } else if let Some(tag) = &app.tag {
        format!("#{}", single_line(tag))
    } else {
        app.section.label().into()
    };
    let block = pane(app, title, Pane::List);
    if app.visible.is_empty() {
        let message = if !app.filter.is_empty() {
            "No matches"
        } else if app.absent {
            "No notebook yet. Press n to create a note."
        } else if app.section == Section::Tasks && app.completed {
            "No completed tasks"
        } else if app.section == Section::Tasks {
            "No open tasks"
        } else if app.section == Section::Tags && app.tag.is_none() {
            "No tags"
        } else {
            "No notes here"
        };
        frame.render_widget(
            Paragraph::new(message)
                .style(DIM)
                .wrap(Wrap { trim: true })
                .block(block),
            area,
        );
        return;
    }

    let mut previous_group = None;
    let items = app.visible.iter().enumerate().map(|(row, &index)| {
        let mut lines = Vec::new();
        let item = &app.items[index];
        if let Item::Task(task) = item {
            let group = task.group(app.today);
            if !app.completed && previous_group != Some(group) {
                lines.push(Line::styled(group.label(), app.accent.patch(BOLD)));
                previous_group = Some(group);
            }
        }
        let selected = app.list.selected() == Some(row);
        let active = app.pane == Pane::List;
        let marker = if selected { "› " } else { "  " };
        let row_style = if selected && active {
            Style::new().add_modifier(Modifier::REVERSED)
        } else {
            Style::new()
        };
        let mut spans = vec![Span::raw(marker)];
        match item {
            Item::Today(note) => {
                spans.push(Span::styled("Today", BOLD));
                let date = app.today.to_string();
                spans.push(Span::styled(format!("  {date}"), DIM));
                if note.as_ref().is_some_and(|note| note.is_trashed) {
                    spans.push(Span::styled("  In Trash", DIM));
                }
            }
            Item::Note(note) => {
                if app.section == Section::Journal {
                    if let Some(date) = &note.journal_date {
                        spans.push(Span::styled(format!("{}  ", single_line(date)), DIM));
                    }
                } else if note.is_pinned {
                    spans.push(Span::styled("* ", app.accent));
                }
                spans.push(Span::raw(single_line(note_title(note))));
            }
            Item::Tag(tag) => {
                let mut path = tag.rsplitn(2, '/');
                let leaf = path.next().unwrap_or_default();
                if let Some(parent) = path.next() {
                    spans.push(Span::styled(format!("#{}/", single_line(parent)), DIM));
                    spans.push(Span::raw(single_line(leaf)));
                } else {
                    spans.push(Span::raw(format!("#{}", single_line(leaf))));
                }
            }
            Item::Task(task) => {
                let checkbox = if task.completed { "[x] " } else { "[ ] " };
                spans.push(Span::styled(checkbox, app.accent));
                spans.push(Span::raw(single_line(&task.text)));
                if let Some(date) = task.due {
                    spans.push(Span::styled(format!("  {date}"), DIM));
                }
            }
        }
        lines.push(Line::from(spans).style(row_style));
        ListItem::new(lines)
    });
    frame.render_stateful_widget(List::new(items).block(block), area, &mut app.list);
}

fn render_preview(frame: &mut Frame, app: &mut App, area: Rect) {
    let title = if app.reader.is_some() {
        "Note"
    } else {
        "Preview"
    };
    let block = pane(app, title.into(), Pane::Preview).padding(Padding::horizontal(2));
    let inner = block.inner(area);
    let paragraph = Paragraph::new(app.preview.clone()).wrap(Wrap { trim: false });
    let max = paragraph
        .line_count(inner.width)
        .saturating_sub(usize::from(inner.height));
    app.scroll_max = u16::try_from(max).unwrap_or(u16::MAX);
    app.scroll = app.scroll.min(app.scroll_max);
    frame.render_widget(paragraph.block(block).scroll((app.scroll, 0)), area);
}

fn render_footer(frame: &mut Frame, app: &App, area: Rect) {
    let search = app.search_before.is_some();
    let mut rows = Vec::new();
    if search {
        let query = single_line(&app.filter);
        rows.push(Line::from(vec![
            Span::styled(" / ", app.accent.patch(BOLD)),
            Span::raw(query),
            Span::styled("▏", app.accent),
        ]));
    } else if !app.status.is_empty() {
        rows.push(Line::styled(
            format!(" {}", single_line(&app.status)),
            app.accent,
        ));
    } else if !app.filter.is_empty() && area.width < 96 {
        rows.push(Line::styled(
            format!(" Filter: {}", single_line(&app.filter)),
            app.accent,
        ));
    }

    let controls = if search {
        " Enter Apply   Esc Cancel"
    } else if app.reader.is_some() {
        " Esc Back   ↑↓ Scroll   e Edit   ? Help   q Quit"
    } else if app.pane == Pane::Sidebar {
        " ↑↓ Choose   Enter Open section   Tab Pane   ? Help"
    } else if app.pane == Pane::Preview {
        " ↑↓ Scroll   Esc Back   Tab Pane   ? Help"
    } else if app.section == Section::Tasks {
        if area.width < 72 {
            " Space Toggle   t Switch tab   ? Help"
        } else {
            " Space Toggle   Enter Source   t Open/Completed   u Undo   / Search   ? Help"
        }
    } else if matches!(app.selected(), Some(Item::Today(_))) {
        " Enter Write today   / Search   Tab Pane   ? Help"
    } else if matches!(app.selected(), Some(Item::Tag(_))) {
        " Enter Browse tag   / Search   Tab Pane   ? Help"
    } else if area.width < 75 {
        " Tab Pane   / Search   ? Help"
    } else {
        " Enter Read   e Edit   n New   / Search   Tab Pane   ? Help   q Quit"
    };

    let mut controls = Line::styled(controls, DIM);
    if !search && !app.filter.is_empty() && area.width >= 96 {
        controls.spans.push(Span::styled(
            format!("     Filter: {}", single_line(&app.filter)),
            app.accent,
        ));
    }
    rows.push(controls);
    frame.render_widget(Paragraph::new(rows), area);
}

fn render_help(frame: &mut Frame, app: &App, area: Rect) {
    let width = area.width.saturating_sub(2).min(52);
    let height = area.height.min(13);
    let panel = Rect::new(
        area.x + (area.width - width) / 2,
        area.y + (area.height - height) / 2,
        width,
        height,
    );
    let block = Block::bordered()
        .title(Line::styled(" Shortcuts ", app.accent.patch(BOLD)))
        .padding(Padding::horizontal(1));
    let rows = [
        "Tab / Shift+Tab  Switch panes",
        "↑↓ / j k         Move or scroll",
        "Enter            Open selected item",
        "/                Search this section",
        "n / e            New note / Edit",
        "Space / u        Toggle task / Undo",
        "t                Open / Completed tasks",
        "r                Refresh notebook",
        "Esc              Back / Close help",
        "q                Quit",
    ];
    frame.render_widget(Clear, panel);
    frame.render_widget(
        Paragraph::new(rows.map(Line::raw).to_vec()).block(block),
        panel,
    );
}

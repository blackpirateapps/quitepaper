mod preview;
mod view;

use crate::{
    database::Database,
    editor,
    model::Note,
    rich,
    tasks::{self, Task},
    writes::{self, Save},
    ListOptions,
};
use anyhow::{ensure, Context, Result};
use jiff::civil::Date;
use ratatui::{
    crossterm::{
        cursor::Show,
        event::{
            self, DisableBracketedPaste, EnableBracketedPaste, Event, KeyCode, KeyEvent,
            KeyEventKind, KeyModifiers,
        },
        execute,
        terminal::{self, EnterAlternateScreen},
    },
    style::{Color, Style},
    text::Line,
    widgets::ListState,
    DefaultTerminal,
};
use std::{io, path::PathBuf, time::Duration};
use uuid::Uuid;

#[derive(Clone, Copy, PartialEq, Eq)]
enum Section {
    Notes,
    Pinned,
    Archive,
    Trash,
    Tags,
    Journal,
    Tasks,
}

impl Section {
    const ALL: [Self; 7] = [
        Self::Notes,
        Self::Pinned,
        Self::Archive,
        Self::Trash,
        Self::Tags,
        Self::Journal,
        Self::Tasks,
    ];

    fn label(self) -> &'static str {
        match self {
            Self::Notes => "Notes",
            Self::Pinned => "Pinned",
            Self::Archive => "Archive",
            Self::Trash => "Trash",
            Self::Tags => "Tags",
            Self::Journal => "Journal",
            Self::Tasks => "Tasks",
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Pane {
    Sidebar,
    List,
    Preview,
}

impl Pane {
    fn next(self, backwards: bool) -> Self {
        use Pane::*;
        match (self, backwards) {
            (Sidebar, false) | (Preview, true) => List,
            (List, false) | (Sidebar, true) => Preview,
            (Preview, false) | (List, true) => Sidebar,
        }
    }
}

enum Item {
    Note(Note),
    Today(Option<Note>),
    Tag(String),
    Task(Task),
}

#[derive(PartialEq)]
enum Identity<'a> {
    Note(&'a str),
    Today,
    Tag(&'a str),
    Task(&'a str, &'a str),
    LegacyTask(&'a str, usize),
}

impl Item {
    fn note(&self) -> Option<&Note> {
        match self {
            Self::Note(note) | Self::Today(Some(note)) => Some(note),
            _ => None,
        }
    }

    fn identity(&self) -> Identity<'_> {
        match self {
            Self::Note(note) => Identity::Note(&note.id),
            Self::Today(_) => Identity::Today,
            Self::Tag(tag) => Identity::Tag(tag),
            Self::Task(task) => match task.id() {
                Some(id) => Identity::Task(&task.note_id, id),
                None => Identity::LegacyTask(&task.note_id, task.ordinal),
            },
        }
    }

    fn matches(&self, query: &str, today: Date) -> bool {
        let contains = |value: &str| value.to_lowercase().contains(query);
        match self {
            Self::Today(None) => contains("today") || contains(&today.to_string()),
            Self::Tag(tag) => contains(&format!("#{tag}")),
            Self::Task(task) => {
                contains(&task.text)
                    || contains(&task.note_title)
                    || task.heading.as_deref().is_some_and(contains)
                    || task.due.is_some_and(|date| contains(&date.to_string()))
            }
            Self::Today(Some(note)) | Self::Note(note) => {
                if (matches!(self, Self::Today(_)) && contains("today"))
                    || contains(preview::title(note))
                    || note.tags.iter().any(|tag| contains(&format!("#{tag}")))
                    || note.journal_date.as_deref().is_some_and(contains)
                {
                    return true;
                }
                if writes::is_protected(&note.content) {
                    return false;
                }
                if rich::is_document(&note.content) {
                    contains(&rich::plain_text(&note.content))
                } else {
                    contains(markdown_body(note))
                }
            }
        }
    }
}

fn markdown_body(note: &Note) -> &str {
    crate::markdown::frontmatter(&note.content).body
}

struct App {
    path: PathBuf,
    section: Section,
    sidebar: ListState,
    pane: Pane,
    items: Vec<Item>,
    visible: Vec<usize>,
    list: ListState,
    preview: Vec<Line<'static>>,
    scroll: u16,
    scroll_max: u16,
    reader: Option<Note>,
    tag: Option<String>,
    completed: bool,
    undo: Option<Task>,
    today: Date,
    filter: String,
    search_before: Option<String>,
    status: String,
    absent: bool,
    help: bool,
    accent: Style,
}

impl App {
    fn new(path: PathBuf, no_color: bool) -> Result<Self> {
        let mut app = Self {
            path,
            section: Section::Notes,
            sidebar: ListState::default().with_selected(Some(0)),
            pane: Pane::List,
            items: Vec::new(),
            visible: Vec::new(),
            list: ListState::default(),
            preview: Vec::new(),
            scroll: 0,
            scroll_max: 0,
            reader: None,
            tag: None,
            completed: false,
            undo: None,
            today: local_date(),
            filter: String::new(),
            search_before: None,
            status: String::new(),
            absent: false,
            help: false,
            accent: if no_color {
                Style::new()
            } else {
                Style::new().fg(Color::Cyan)
            },
        };
        app.reload()?;
        Ok(app)
    }

    fn selected(&self) -> Option<&Item> {
        self.items.get(*self.visible.get(self.list.selected()?)?)
    }

    fn reload(&mut self) -> Result<()> {
        let absent = !self.path.try_exists()?;
        let (items, reader) = if absent {
            (self.empty_items(), None)
        } else {
            let db = Database::open(&self.path)?;
            let reader = match &self.reader {
                Some(note) => db.note_by_id(&note.id)?,
                None => None,
            };
            (self.load(&db)?, reader)
        };
        let preferred = self.selected().and_then(|old| {
            items
                .iter()
                .position(|item| item.identity() == old.identity())
        });
        self.reader = reader;
        self.absent = absent;
        self.items = items;
        self.apply_filter(preferred, self.list.selected().unwrap_or(0));
        Ok(())
    }

    fn empty_items(&self) -> Vec<Item> {
        if self.section == Section::Journal {
            vec![Item::Today(None)]
        } else {
            Vec::new()
        }
    }

    fn load(&self, db: &Database) -> Result<Vec<Item>> {
        match self.section {
            Section::Journal => {
                let today = self.today.to_string();
                let mut entries = db.journal_entries(&today)?;
                let entry = entries
                    .iter()
                    .position(|note| note.journal_date.as_deref() == Some(&today))
                    .map(|index| entries.remove(index));
                Ok(std::iter::once(Item::Today(entry))
                    .chain(entries.into_iter().map(Item::Note))
                    .collect())
            }
            Section::Tasks => {
                let mut items = tasks::list(db)?;
                items.sort_by_key(|task| (task.group(self.today), task.due));
                Ok(items.into_iter().map(Item::Task).collect())
            }
            Section::Tags if self.tag.is_none() => {
                let mut paths = std::collections::BTreeSet::new();
                for tag in db.tags()? {
                    paths.extend(
                        tag.name
                            .match_indices('/')
                            .map(|(byte, _)| tag.name[..byte].to_owned()),
                    );
                    paths.insert(tag.name);
                }
                Ok(paths.into_iter().map(Item::Tag).collect())
            }
            section => Ok(db
                .list(&ListOptions {
                    pinned: section == Section::Pinned,
                    archived: section == Section::Archive,
                    trash: section == Section::Trash,
                    tag: self.tag.clone(),
                    ..Default::default()
                })?
                .into_iter()
                .map(Item::Note)
                .collect()),
        }
    }

    fn apply_filter(&mut self, preferred: Option<usize>, fallback: usize) {
        let query = self.filter.trim().to_lowercase();
        self.visible = self
            .items
            .iter()
            .enumerate()
            .filter_map(|(index, item)| {
                if matches!(item, Item::Task(task) if task.completed != self.completed) {
                    None
                } else {
                    (query.is_empty() || item.matches(&query, self.today)).then_some(index)
                }
            })
            .collect();

        let selected = self
            .visible
            .iter()
            .position(|&index| Some(index) == preferred)
            .or_else(|| (!self.visible.is_empty()).then(|| fallback.min(self.visible.len() - 1)));
        self.list.select(selected);
        self.update_preview();
    }

    fn edit_filter(&mut self) {
        let selected = self
            .list
            .selected()
            .and_then(|index| self.visible.get(index))
            .copied();
        self.apply_filter(selected, 0);
    }

    fn update_preview(&mut self) {
        self.scroll = 0;
        self.scroll_max = 0;
        self.preview = if let Some(note) = self
            .reader
            .as_ref()
            .or_else(|| self.selected().and_then(Item::note))
        {
            preview::note(note, self.accent)
        } else {
            match self.selected() {
                Some(Item::Today(None)) => vec![
                    Line::raw("No entry for today yet."),
                    Line::raw("Press Enter to open your editor."),
                ],
                Some(Item::Tag(tag)) => vec![
                    Line::raw(format!("#{}", preview::single_line(tag))),
                    Line::raw("Press Enter to browse notes in this tag and its subtags."),
                ],
                Some(Item::Task(task)) => {
                    let state = if task.completed { "Completed" } else { "Open" };
                    let due = task
                        .due
                        .map_or("No due date".into(), |date| format!("Due {date}"));
                    let mut lines = vec![
                        Line::styled(preview::single_line(&task.text), self.accent),
                        Line::raw(format!("{state}  ·  {due}")),
                        Line::default(),
                        Line::raw(format!("From {}", preview::single_line(&task.note_title))),
                    ];
                    if let Some(heading) = &task.heading {
                        lines.push(Line::raw(preview::single_line(heading)));
                    }
                    lines
                }
                _ => Vec::new(),
            }
        };
    }

    fn move_selection(&mut self, amount: isize) {
        match self.pane {
            Pane::Sidebar => {
                let next = self
                    .sidebar
                    .selected()
                    .unwrap_or(0)
                    .saturating_add_signed(amount);
                self.sidebar.select(Some(next.min(Section::ALL.len() - 1)));
            }
            Pane::List if !self.visible.is_empty() => {
                let next = self
                    .list
                    .selected()
                    .unwrap_or(0)
                    .saturating_add_signed(amount);
                self.list.select(Some(next.min(self.visible.len() - 1)));
                self.update_preview();
            }
            Pane::Preview => {
                let next = i32::from(self.scroll).saturating_add(amount as i32);
                self.scroll = next.clamp(0, i32::from(self.scroll_max)) as u16;
            }
            _ => {}
        }
    }

    fn choose_section(&mut self, section: Section) -> Result<()> {
        let previous = self.section;
        let previous_tag = self.tag.take();
        self.section = section;
        let previous_filter = std::mem::take(&mut self.filter);
        if let Err(error) = self.reload() {
            self.section = previous;
            self.tag = previous_tag;
            self.filter = previous_filter;
            return Err(error);
        }
        self.apply_filter(None, 0);
        self.pane = Pane::List;
        self.status.clear();
        Ok(())
    }

    fn set_tag(&mut self, tag: Option<String>) -> Result<()> {
        let previous = std::mem::replace(&mut self.tag, tag);
        let previous_filter = std::mem::take(&mut self.filter);
        if let Err(error) = self.reload() {
            self.tag = previous;
            self.filter = previous_filter;
            return Err(error);
        }
        let preferred = previous.as_ref().and_then(|tag| {
            self.items
                .iter()
                .position(|item| item.identity() == Identity::Tag(tag))
        });
        self.apply_filter(preferred, 0);
        self.pane = Pane::List;
        Ok(())
    }

    fn open_note(&mut self, id: &str) -> Result<()> {
        let note = Database::open(&self.path)?
            .note_by_id(id)?
            .context("The note is no longer available")?;
        self.reader = Some(note);
        self.pane = Pane::Preview;
        self.update_preview();
        Ok(())
    }

    fn writable(&self) -> Result<Database> {
        if !self.path.try_exists()? {
            Database::initialize(&self.path)?;
        }
        Database::open_writable(&self.path)
    }

    fn edit(&mut self, target: Edit) -> Result<()> {
        let edited = (|| {
            let db = match target {
                Edit::New | Edit::Today => self.writable()?,
                Edit::Note(_) => Database::open_writable(&self.path)?,
            };
            match &target {
                Edit::New => editor::create_note(&db, &self.path, editor::NewOptions::default()),
                Edit::Today => {
                    let note = journal_today(&db, local_date())?;
                    ensure!(
                        !note.is_trashed,
                        "Today's entry is in Trash. Restore it with qp delete --restore {}",
                        note.id
                    );
                    editor::edit_note(&db, &self.path, &note.id, editor::EditOptions::default())
                }
                Edit::Note(id) => {
                    let note = db
                        .note_by_id(id)?
                        .context("The note is no longer available")?;
                    ensure!(!note.is_trashed, "Restore this note before editing.");
                    editor::edit_note(&db, &self.path, id, editor::EditOptions::default())
                }
            }
        })();
        let refreshed = self.reload();
        self.status = if edited?.is_some() {
            "Saved locally".into()
        } else {
            "Editor closed without changes".into()
        };
        refreshed
    }

    fn edit_target(&self) -> Option<Edit> {
        if let Some(note) = &self.reader {
            return Some(Edit::Note(note.id.clone()));
        }
        match self.selected()? {
            Item::Today(_) => Some(Edit::Today),
            Item::Note(note) => Some(Edit::Note(note.id.clone())),
            Item::Task(task) => Some(Edit::Note(task.note_id.clone())),
            Item::Tag(_) => None,
        }
    }

    fn activate(&mut self) -> Result<Action> {
        if self.reader.is_some() {
            return Ok(Action::Continue);
        }
        if self.pane == Pane::Sidebar {
            let section = Section::ALL[self.sidebar.selected().unwrap_or(0)];
            self.choose_section(section)?;
            return Ok(Action::Continue);
        }

        match self.selected() {
            Some(Item::Today(_)) => return Ok(Action::Edit(Edit::Today)),
            Some(Item::Tag(tag)) => self.set_tag(Some(tag.clone()))?,
            Some(Item::Note(note)) => self.open_note(&note.id.clone())?,
            Some(Item::Task(task)) => self.open_note(&task.note_id.clone())?,
            None => {}
        }
        Ok(Action::Continue)
    }

    fn toggle_task(&mut self, undo: bool) -> Result<()> {
        let task = if undo {
            self.undo.as_ref()
        } else if let Some(Item::Task(task)) = self.selected() {
            Some(task)
        } else {
            None
        };
        let Some(task) = task else { return Ok(()) };
        let db = Database::open_writable(&self.path)?;
        let result = tasks::toggle(&db, task);
        let refresh = self.reload();
        let updated = result?;
        self.status = if undo {
            self.undo = None;
            "Task change undone".into()
        } else {
            let message = if updated.completed {
                "Task completed · u Undo"
            } else {
                "Task reopened · u Undo"
            };
            self.undo = Some(updated);
            message.into()
        };
        refresh
    }

    fn escape(&mut self) -> Result<()> {
        if self.reader.take().is_some() || self.pane == Pane::Preview {
            self.pane = Pane::List;
            self.update_preview();
        } else if !self.filter.is_empty() {
            self.filter.clear();
            self.edit_filter();
        } else if self.tag.is_some() {
            self.set_tag(None)?;
        } else {
            self.pane = Pane::Sidebar;
        }
        Ok(())
    }

    fn key(&mut self, key: KeyEvent) -> Result<Action> {
        let press = key.kind == KeyEventKind::Press;
        if key.code == KeyCode::Char('c') && key.modifiers.contains(KeyModifiers::CONTROL) {
            return Ok(Action::Quit);
        }
        if self.help {
            if press && matches!(key.code, KeyCode::Esc | KeyCode::Char('?')) {
                self.help = false;
            }
            return Ok(if press && key.code == KeyCode::Char('q') {
                Action::Quit
            } else {
                Action::Continue
            });
        }
        if self.search_before.is_some() {
            match key.code {
                KeyCode::Esc => {
                    self.filter = self.search_before.take().unwrap();
                    self.edit_filter();
                }
                KeyCode::Enter => {
                    self.search_before = None;
                }
                KeyCode::Backspace => {
                    self.filter.pop();
                    self.edit_filter();
                }
                KeyCode::Char('u') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                    self.filter.clear();
                    self.edit_filter();
                }
                KeyCode::Char(c)
                    if !key
                        .modifiers
                        .intersects(KeyModifiers::CONTROL | KeyModifiers::ALT) =>
                {
                    if !c.is_control() {
                        self.filter.push(c);
                        self.edit_filter();
                    }
                }
                KeyCode::Up => self.move_selection(-1),
                KeyCode::Down => self.move_selection(1),
                _ => {}
            }
            return Ok(Action::Continue);
        }
        if key
            .modifiers
            .intersects(KeyModifiers::CONTROL | KeyModifiers::ALT)
        {
            return Ok(Action::Continue);
        }
        match key.code {
            KeyCode::Up | KeyCode::Char('k') => self.move_selection(-1),
            KeyCode::Down | KeyCode::Char('j') => self.move_selection(1),
            KeyCode::PageUp => self.move_selection(-8),
            KeyCode::PageDown => self.move_selection(8),
            KeyCode::Home => self.move_selection(-(u16::MAX as isize)),
            KeyCode::End => self.move_selection(u16::MAX as isize),
            _ if !press => {}
            KeyCode::Esc => self.escape()?,
            KeyCode::Char('q') => return Ok(Action::Quit),
            KeyCode::Char('?') => self.help = true,
            KeyCode::Tab | KeyCode::BackTab | KeyCode::Left | KeyCode::Right
                if self.reader.is_none() =>
            {
                self.pane = self
                    .pane
                    .next(matches!(key.code, KeyCode::BackTab | KeyCode::Left));
            }
            KeyCode::Enter => return self.activate(),
            KeyCode::Char('/') if self.reader.is_none() => {
                self.search_before = Some(self.filter.clone());
                self.pane = Pane::List;
            }
            KeyCode::Char('e') if self.pane != Pane::Sidebar => {
                if let Some(target) = self.edit_target() {
                    return Ok(Action::Edit(target));
                }
            }
            KeyCode::Char('n') => return Ok(Action::Edit(Edit::New)),
            KeyCode::Char('r') => {
                self.reload()?;
                self.status = "Notebook refreshed".into();
            }
            KeyCode::Char('t') if self.section == Section::Tasks && self.reader.is_none() => {
                self.completed = !self.completed;
                self.pane = Pane::List;
                self.apply_filter(None, 0);
            }
            KeyCode::Char(' ') if self.section == Section::Tasks && self.pane == Pane::List => {
                self.toggle_task(false)?;
            }
            KeyCode::Char('u') if self.section == Section::Tasks => self.toggle_task(true)?,
            _ => {}
        }
        Ok(Action::Continue)
    }
}

enum Edit {
    New,
    Today,
    Note(String),
}

enum Action {
    Continue,
    Quit,
    Edit(Edit),
}

fn local_date() -> Date {
    jiff::Zoned::now().date()
}

fn journal_today(db: &Database, date: Date) -> Result<Note> {
    db.transaction(|| {
        let date_string = date.to_string();
        match db.journal_entry(&date_string)? {
            Some(note) => Ok(note),
            None => db.save_inner(&Save {
                id: &Uuid::new_v4().to_string(),
                title: &date.strftime("%B %-d, %Y").to_string(),
                content: &format!("---\njournal: true\ndate: {date_string}\n---\n"),
                tags: &[],
                pinned: false,
                expected: None,
            }),
        }
    })
}

pub fn run(path: PathBuf, no_color: bool) -> Result<()> {
    let mut app = App::new(path, no_color)?;
    let result = (|| {
        let mut terminal = ratatui::try_init()?;
        execute!(terminal.backend_mut(), EnableBracketedPaste)?;
        event_loop(&mut terminal, &mut app)
    })();
    let restore = leave_terminal();
    result.and(restore)
}

fn leave_terminal() -> Result<()> {
    let controls = execute!(io::stdout(), DisableBracketedPaste, Show);
    let mode = ratatui::try_restore();
    controls?;
    mode?;
    Ok(())
}

fn enter_terminal(terminal: &mut DefaultTerminal) -> Result<()> {
    terminal::enable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        EnterAlternateScreen,
        EnableBracketedPaste
    )?;
    terminal.clear()?;
    Ok(())
}

fn event_loop(terminal: &mut DefaultTerminal, app: &mut App) -> Result<()> {
    let mut redraw = true;
    loop {
        if redraw {
            terminal.draw(|frame| view::render(frame, app))?;
        }
        let has_event = event::poll(Duration::from_secs(1))?;
        redraw = has_event;
        let today = local_date();
        if today != app.today {
            app.today = today;
            if matches!(app.section, Section::Journal | Section::Tasks) {
                if let Err(error) = app.reload() {
                    app.status = format!("{error:#}");
                }
                redraw = true;
            }
        }
        if !has_event {
            continue;
        }
        match event::read()? {
            Event::Key(key) if key.kind != KeyEventKind::Release => {
                match app.key(key) {
                    Ok(Action::Quit) => return Ok(()),
                    Ok(Action::Continue) => {}
                    Ok(Action::Edit(target)) => {
                        // The child inherits the user's original screen and terminal settings.
                        leave_terminal()?;
                        let edited = app.edit(target);
                        enter_terminal(terminal)?;
                        if let Err(error) = edited {
                            app.status = format!("{error:#}");
                        }
                    }
                    Err(error) => {
                        app.status = format!("{error:#}");
                    }
                }
            }
            Event::Paste(text) if app.search_before.is_some() => {
                app.filter.push_str(&preview::single_line(&text));
                app.edit_filter();
            }
            _ => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ratatui::{backend::TestBackend, Terminal};
    use rusqlite::params;

    fn press(app: &mut App, code: KeyCode) -> Action {
        app.key(KeyEvent::new(code, KeyModifiers::NONE)).unwrap()
    }

    fn screen(app: &mut App, width: u16, height: u16) -> String {
        let mut terminal = Terminal::new(TestBackend::new(width, height)).unwrap();
        terminal.draw(|frame| view::render(frame, app)).unwrap();
        terminal
            .backend()
            .buffer()
            .content()
            .iter()
            .map(|cell| cell.symbol())
            .collect()
    }

    #[test]
    fn sidebar_search_and_reader_work_in_wide_and_narrow_terminals() {
        let folder = tempfile::tempdir().unwrap();
        let path = folder.path().join("notebook.sqlite");
        Database::initialize(&path).unwrap();
        let db = Database::open_writable(&path).unwrap();
        db.transaction(|| {
            db.save_inner(&Save {
                id: "one",
                title: "Travel plan",
                content: "# Travel plan\n\nA **বাংলা** place to visit.",
                tags: &["trips/train".into()],
                pinned: false,
                expected: None,
            })
        })
        .unwrap();

        let mut app = App::new(path, true).unwrap();
        let initial = screen(&mut app, 110, 22);
        for value in [
            "Notebook",
            "Journal",
            "Tasks",
            "Travel plan",
            "place to visit.",
        ] {
            assert!(initial.contains(value), "{value}");
        }
        assert_eq!(initial.matches("Travel plan").count(), 2);
        assert!(!screen(&mut app, 50, 14).contains("Notebook"));
        press(&mut app, KeyCode::Left);
        assert!(screen(&mut app, 50, 14).contains("Notebook"));
        app.move_selection(4);
        press(&mut app, KeyCode::Enter);
        assert!(screen(&mut app, 50, 14).contains("#trips/train"));
        press(&mut app, KeyCode::Enter);
        press(&mut app, KeyCode::Char('/'));
        for ch in "বাংলা".chars() {
            press(&mut app, KeyCode::Char(ch));
        }
        press(&mut app, KeyCode::Enter);
        assert_eq!(app.visible.len(), 1);
        press(&mut app, KeyCode::Enter);
        assert!(screen(&mut app, 50, 14).contains("place to visit."));
        assert!(
            matches!(press(&mut app, KeyCode::Char('e')), Action::Edit(Edit::Note(id)) if id == "one")
        );
        press(&mut app, KeyCode::Esc);
        assert!(app.reader.is_none());
        assert!(matches!(app.selected(), Some(Item::Note(note)) if note.id == "one"));
    }

    #[test]
    fn journal_today_reuses_the_canonical_entry_and_tasks_toggle_in_the_workspace() {
        let folder = tempfile::tempdir().unwrap();
        let path = folder.path().join("notebook.sqlite");
        let mut app = App::new(path.clone(), false).unwrap();
        let today = app.today;
        app.choose_section(Section::Journal).unwrap();
        assert!(!path.exists());
        assert!(matches!(
            press(&mut app, KeyCode::Enter),
            Action::Edit(Edit::Today)
        ));

        let db = app.writable().unwrap();
        let earlier = journal_today(&db, today.yesterday().unwrap()).unwrap();
        let today_note = journal_today(&db, today).unwrap();
        assert_eq!(journal_today(&db, today).unwrap().id, today_note.id);
        assert_eq!(
            today_note.journal_date.as_deref(),
            Some(today.to_string().as_str())
        );
        app.reload().unwrap();
        assert!(
            matches!(app.selected(), Some(Item::Today(Some(note))) if note.id == today_note.id)
        );
        app.move_selection(1);
        assert!(matches!(app.selected(), Some(Item::Note(note)) if note.id == earlier.id));

        db.0.execute(
            "UPDATE notes SET content=content || ? WHERE id=?",
            params!["\n- [ ] Buy paper\n", today_note.id],
        )
        .unwrap();
        app.choose_section(Section::Tasks).unwrap();
        assert!(screen(&mut app, 105, 18).contains("No due date"));
        press(&mut app, KeyCode::Char(' '));
        assert!(app.visible.is_empty());
        press(&mut app, KeyCode::Char('t'));
        assert!(screen(&mut app, 50, 16).contains("[x] Buy paper"));
        press(&mut app, KeyCode::Enter);
        assert!(app
            .reader
            .as_ref()
            .unwrap()
            .content
            .contains("- [x] Buy paper"));
        press(&mut app, KeyCode::Esc);
        press(&mut app, KeyCode::Char('u'));
        assert!(app.visible.is_empty());
        assert!(db
            .note_by_id(&today_note.id)
            .unwrap()
            .unwrap()
            .content
            .contains("- [ ] Buy paper"));
    }
}

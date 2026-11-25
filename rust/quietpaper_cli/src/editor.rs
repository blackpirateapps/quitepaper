use crate::{
    database::Database,
    markdown,
    model::Note,
    writes::{self, Save},
    ListOptions,
};
use anyhow::{bail, Context, Result};
use clap::Args;
use std::{
    env, fs,
    io::{self, IsTerminal, Read, Write},
    path::Path,
    process::Command,
};
use tempfile::Builder;
use uuid::Uuid;

#[derive(Args)]
pub struct NewOptions {
    #[arg(num_args=0..)]
    pub name: Vec<String>,
    #[arg(short, long)]
    pub title: Option<String>,
    #[arg(short = 'T', long = "tag", value_delimiter = ',')]
    pub tags: Vec<String>,
    #[arg(short, long)]
    pub editor: Option<String>,
    #[arg(short, long)]
    pub pinned: bool,
}

#[derive(Args)]
pub struct EditOptions {
    #[arg(num_args=0..)]
    pub note: Vec<String>,
    #[arg(short, long)]
    pub editor: Option<String>,
    #[arg(short, long, conflicts_with = "no_pinned")]
    pub pinned: bool,
    #[arg(long)]
    pub no_pinned: bool,
}

pub fn resolve(db: &Database, query: &[String], trash: bool) -> Result<Option<Note>> {
    if !query.is_empty() {
        let query = query.join(" ");
        if !io::stdin().is_terminal() {
            return db.find(&query).map(Some);
        }
        return pick(db.candidates(&query)?);
    }
    if !io::stdin().is_terminal() {
        bail!("Specify a note ID or title when running non-interactively.");
    }
    pick(db.list(&ListOptions {
        trash,
        limit: Some(50),
        ..Default::default()
    })?)
}

fn pick(mut notes: Vec<Note>) -> Result<Option<Note>> {
    if notes.is_empty() {
        eprintln!("No matching notes.");
        return Ok(None);
    }
    if notes.len() == 1 {
        return Ok(notes.pop());
    }
    for (index, note) in notes.iter().enumerate() {
        eprintln!(
            "{:2}) [{}] {}",
            index + 1,
            note.short_id,
            note.title.replace(['\n', '\r', '\t'], " ")
        );
    }
    eprint!("Select a note (1-{}) or q to cancel: ", notes.len());
    io::stderr().flush()?;
    let mut line = String::new();
    io::stdin().read_line(&mut line)?;
    let line = line.trim();
    if line.is_empty() || line.eq_ignore_ascii_case("q") {
        return Ok(None);
    }
    let index: usize = line.parse().context("Invalid note number")?;
    if index == 0 || index > notes.len() {
        bail!("Invalid note number");
    }
    Ok(Some(notes.remove(index - 1)))
}

fn editor_command(explicit: Option<&str>) -> String {
    explicit
        .filter(|s| !s.trim().is_empty())
        .map(str::to_owned)
        .or_else(|| {
            ["QP_EDITOR", "VISUAL", "EDITOR"]
                .iter()
                .find_map(|k| env::var(k).ok().filter(|v| !v.trim().is_empty()))
        })
        .unwrap_or_else(|| {
            ["nvim", "vim", "nano", "vi"]
                .iter()
                .find(|name| {
                    env::split_paths(&env::var_os("PATH").unwrap_or_default())
                        .any(|p| p.join(name).is_file())
                })
                .unwrap_or(&"nano")
                .to_string()
        })
}

fn initial_text(title: Option<&str>, content: Option<&str>) -> String {
    if let Some(content) = content.filter(|s| !s.is_empty()) {
        let fm = markdown::frontmatter(content);
        if fm.end > 0 && fm.title.is_none() {
            if let Some(title) = title {
                let position = content.find('\n').unwrap_or(0) + 1;
                let newline = if content.contains("\r\n") {
                    "\r\n"
                } else {
                    "\n"
                };
                return format!(
                    "{}title: {}{newline}{}",
                    &content[..position],
                    serde_json::to_string(title).unwrap(),
                    &content[position..]
                );
            }
        }
        if !content.trim_start().starts_with(['#', '-']) {
            if let Some(title) = title {
                return format!("# {title}\n\n{content}");
            }
        }
        return content.to_owned();
    }
    format!(
        "# {}\n\nStart writing note content...\n",
        title.unwrap_or("Note Title")
    )
}

fn edit_text(
    database: &Path,
    title: Option<&str>,
    content: Option<&str>,
    editor: Option<&str>,
) -> Result<Option<String>> {
    let mut file = Builder::new()
        .prefix("qp-editor-")
        .suffix(".md")
        .tempfile()?;
    let initial = initial_text(title, content);
    file.write_all(initial.as_bytes())?;
    file.as_file().sync_all()?;
    let parts =
        shell_words::split(&editor_command(editor)).context("Invalid editor command quoting")?;
    let executable = parts.first().context("Editor command is empty")?;
    let status = Command::new(executable)
        .args(&parts[1..])
        .arg(file.path())
        .status();
    let text = fs::read_to_string(file.path()).context("Editor draft could not be read")?;
    if status.as_ref().map_or(true, |s| !s.success()) {
        let path = writes::preserve_draft(database, &text)?;
        bail!("Editor failed; draft preserved at {}", path.display());
    }
    if text == initial || text.trim().is_empty() {
        return Ok(None);
    }
    Ok(Some(text))
}

pub fn create(db: &Database, path: &Path, options: NewOptions) -> Result<()> {
    let fallback = options
        .title
        .or_else(|| (!options.name.is_empty()).then(|| options.name.join(" ")));
    let content = if io::stdin().is_terminal() {
        let Some(text) = edit_text(path, fallback.as_deref(), None, options.editor.as_deref())?
        else {
            println!("Note creation cancelled (empty or unchanged).");
            return Ok(());
        };
        text
    } else {
        let mut text = String::new();
        io::stdin()
            .take(64 * 1024 * 1024 + 1)
            .read_to_string(&mut text)?;
        if text.len() > 64 * 1024 * 1024 {
            bail!("Markdown input exceeds 64 MiB");
        }
        if text.trim().is_empty() {
            bail!("Stdin was empty. Note not created.");
        }
        text
    };
    let title = markdown::title(&content, fallback.as_deref());
    let id = Uuid::new_v4().to_string();
    let result = writes::pending_guard(&content).and_then(|_| {
        db.save(&Save {
            id: &id,
            title: &title,
            content: &content,
            tags: &options.tags,
            pinned: options.pinned,
            expected: None,
        })
    });
    let note = result.map_err(|error| recover(path, &content, error))?;
    println!("Created note: {} ({})", note.title, note.short_id);
    eprintln!("Saved locally; desktop sync can upload pending changes.");
    Ok(())
}

pub fn edit(db: &Database, path: &Path, options: EditOptions) -> Result<()> {
    let Some(note) = resolve(db, &options.note, false)? else {
        return Ok(());
    };
    let snapshot = db.snapshot(&note.id)?;
    writes::guard_editor(&note.content)?;
    writes::pending_guard(&note.content)?;
    let text = edit_text(
        path,
        Some(&note.title),
        Some(&note.content),
        options.editor.as_deref(),
    )?;
    let pinned = if options.pinned {
        true
    } else if options.no_pinned {
        false
    } else {
        note.is_pinned
    };
    if text.is_none() && pinned == note.is_pinned {
        println!("No changes made.");
        return Ok(());
    }
    let content = text.as_deref().unwrap_or(&note.content);
    let title = markdown::title(content, Some(&note.title));
    let result = writes::pending_guard(content).and_then(|_| {
        db.save(&Save {
            id: &note.id,
            title: &title,
            content,
            tags: &[],
            pinned,
            expected: Some(&snapshot),
        })
    });
    let note = result.map_err(|error| recover(path, content, error))?;
    println!("Saved note: {} [{}]", note.title, note.short_id);
    eprintln!("Saved locally; desktop sync can upload pending changes.");
    Ok(())
}

pub fn recover(database: &Path, content: &str, error: anyhow::Error) -> anyhow::Error {
    match writes::preserve_draft(database, content) {
        Ok(path) => error.context(format!("Draft preserved at {}", path.display())),
        Err(recovery) => error.context(format!("Draft recovery failed: {recovery}")),
    }
}

mod attachments;
mod credentials;
mod crypto;
mod database;
mod editor;
mod image_paths;
mod markdown;
mod model;
mod process;
mod sync;
mod writes;

use std::{
    io::{self, Write},
    path::PathBuf,
    process::ExitCode,
};

use anyhow::Result;
use clap::{error::ErrorKind, Args, Parser, Subcommand};

#[derive(Parser)]
#[command(name = "qp", version, about = "Quiet Paper CLI — Offline-first notes in your terminal",
    long_version = concat!(env!("CARGO_PKG_VERSION"), " (Rust)"),
    after_help = "Upload sync retries local notes and images; remote pull/merge remains in the desktop app.",
    disable_version_flag = true, propagate_version = true, arg_required_else_help = true)]
struct Cli {
    /// Print the current CLI version
    #[arg(short = 'v', long, global = true, action = clap::ArgAction::Version)]
    version: Option<bool>,
    /// Disable ANSI colors (output currently uses plain text)
    #[arg(long, global = true)]
    no_color: bool,
    /// Path to an existing quiet_paper.sqlite database
    #[arg(long, global = true)]
    db: Option<PathBuf>,
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// List notes with optional filters, search or JSON export
    #[command(alias = "ls")]
    List(ListOptions),
    /// Display a note by full ID, ID prefix (8+ characters), or title substring
    #[command(aliases = ["cat", "view", "s"])]
    Show {
        #[arg(num_args = 0..)]
        note: Vec<String>,
        #[arg(long)]
        raw: bool,
        #[arg(short, long)]
        info: bool,
        #[arg(long)]
        json: bool,
    },
    /// List tags and active note counts
    #[command(alias = "t")]
    Tags {
        #[arg(long)]
        json: bool,
    },
    /// Create a note with an external editor or piped Markdown
    #[command(aliases=["create","add","n"])]
    New(editor::NewOptions),
    /// Edit a note using an external editor
    #[command(aliases=["e","modify"])]
    Edit(editor::EditOptions),
    /// Trash, restore, or permanently delete a note
    #[command(aliases=["rm","del"])]
    Delete {
        #[arg(num_args=0..)]
        note: Vec<String>,
        #[arg(short = 'f', long, conflicts_with = "restore")]
        permanent: bool,
        #[arg(short = 'r', long)]
        restore: bool,
    },
    /// Append image files or a clipboard screenshot to a note
    Attach {
        note: String,
        paths: Vec<PathBuf>,
        #[command(flatten)]
        options: attachments::ImportOptions,
    },
    /// List attached images, or open one with temporary plaintext cleanup
    Attachments {
        note: String,
        #[arg(value_parser=["open"],requires="image")]
        action: Option<String>,
        #[arg(requires = "action")]
        image: Option<String>,
        #[arg(long)]
        json: bool,
    },
    /// Retry encrypted note/image uploads (conflicts require the desktop app)
    Sync {
        #[arg(num_args=0..)]
        note: Vec<String>,
    },
}

#[derive(Args, Default)]
pub struct ListOptions {
    #[arg(short, long)]
    tag: Option<String>,
    #[arg(short, long, aliases = ["query", "q"])]
    search: Option<String>,
    #[arg(short, long)]
    pinned: bool,
    #[arg(short, long)]
    archived: bool,
    #[arg(long)]
    trash: bool,
    /// Maximum number of notes (positive integer)
    #[arg(short = 'n', long, value_parser = clap::value_parser!(u32).range(1..))]
    limit: Option<u32>,
    #[arg(long, conflicts_with = "plain")]
    json: bool,
    /// Tab-separated ID, title, tags and update timestamp
    #[arg(long)]
    plain: bool,
}

fn run(cli: Cli) -> Result<()> {
    let path = match cli.db {
        Some(path) => path,
        None => database::default_path()?,
    };
    if matches!(&cli.command, Command::New(_)) && !path.exists() {
        database::Database::initialize(&path)?;
    }
    let path = std::fs::canonicalize(&path).unwrap_or(path);
    if matches!(
        &cli.command,
        Command::New(_)
            | Command::Edit(_)
            | Command::Delete { .. }
            | Command::Attach { .. }
            | Command::Sync { .. }
    ) {
        let db = database::Database::open_writable(&path)?;
        match cli.command {
            Command::New(options) => editor::create(&db, &path, options)?,
            Command::Edit(options) => editor::edit(&db, &path, options)?,
            Command::Delete {
                note,
                restore,
                permanent,
            } => {
                if let Some(note) = editor::resolve(&db, &note, restore)? {
                    db.delete(&note, restore, permanent)?;
                    println!(
                        "{} note: {} [{}]",
                        if permanent {
                            "Permanently deleted"
                        } else if restore {
                            "Restored"
                        } else {
                            "Moved to trash"
                        },
                        note.title,
                        note.short_id
                    );
                    sync::after_save(&db, &path, &note.id);
                }
            }
            Command::Attach {
                note,
                paths,
                mut options,
            } => {
                options.files.extend(paths);
                if options.files.is_empty() && !options.clipboard {
                    anyhow::bail!("Specify image files or --clipboard");
                }
                if let Some(note) = editor::resolve(&db, &[note], false)? {
                    writes::guard_editor(&note.content)?;
                    let snapshot = db.snapshot(&note.id)?;
                    let saved = attachments::save(
                        &db,
                        &path,
                        &writes::Save {
                            id: &note.id,
                            title: &note.title,
                            content: &note.content,
                            tags: &note.tags,
                            pinned: note.is_pinned,
                            expected: Some(&snapshot),
                        },
                        &options,
                    )
                    .map_err(|e| editor::recover(&path, &note.content, e))?;
                    println!("Saved images to {} [{}]", saved.title, saved.short_id);
                    sync::after_save(&db, &path, &saved.id);
                }
            }
            Command::Sync { note } => sync::run(&db, &path, &note)?,
            _ => unreachable!(),
        }
        return Ok(());
    }
    let db = database::Database::open(&path)?;
    let mut out = io::BufWriter::new(io::stdout().lock());
    match cli.command {
        Command::List(options) => {
            let notes = db.list(&options)?;
            if options.json {
                serde_json::to_writer_pretty(&mut out, &notes)?;
                writeln!(out)?;
            } else if options.plain {
                for note in notes {
                    writeln!(
                        out,
                        "{}\t{}\t{}\t{}",
                        note.short_id,
                        single_line(&note.title),
                        note.tags.join(","),
                        note.updated_at
                    )?;
                }
            } else if notes.is_empty() {
                writeln!(out, "No notes found.")?;
            } else {
                writeln!(out, "  ID        TITLE                                     TAGS                    UPDATED")?;
                for note in &notes {
                    writeln!(
                        out,
                        "{} {:8}  {:40}  {:22}  {}",
                        if note.is_pinned { "*" } else { " " },
                        note.short_id,
                        truncate(&single_line(&note.title), 40),
                        truncate(
                            &note
                                .tags
                                .iter()
                                .map(|t| format!("#{t}"))
                                .collect::<Vec<_>>()
                                .join(" "),
                            22
                        ),
                        note.updated_at
                    )?;
                }
                writeln!(out, "\n{} notes displayed.", notes.len())?;
            }
        }
        Command::Show {
            note,
            raw,
            info,
            json,
        } => {
            let Some(note) = editor::resolve(&db, &note, false)? else {
                return Ok(());
            };
            if json {
                serde_json::to_writer_pretty(&mut out, &note)?;
                writeln!(out)?;
            } else if info {
                writeln!(out, "=== Note Metadata ===\nID:        {} (Short: {})\nTitle:     {}\nPinned:    {}\nArchived:  {}\nTrashed:   {}\nCreated:   {}\nUpdated:   {}", note.id, note.short_id, note.title, yes_no(note.is_pinned), yes_no(note.is_archived), yes_no(note.is_trashed), note.created_at, note.updated_at)?;
                if !note.tags.is_empty() {
                    writeln!(out, "Tags:      #{}", note.tags.join(" #"))?;
                }
                if let Some(date) = note.journal_date {
                    writeln!(out, "Journal:   {date}")?;
                }
                writeln!(
                    out,
                    "Length:    {} characters, {} words",
                    note.content.encode_utf16().count(),
                    note.content.split_whitespace().count()
                )?;
            } else {
                let trimmed = note.content.trim();
                if !raw && !trimmed.starts_with('#') && !trimmed.starts_with("---") {
                    writeln!(out, "# {}\n", note.title)?;
                }
                write!(out, "{}", note.content)?;
                if !note.content.ends_with('\n') {
                    writeln!(out)?;
                }
            }
        }
        Command::Tags { json } => {
            let tags = db.tags()?;
            if json {
                serde_json::to_writer_pretty(&mut out, &tags)?;
                writeln!(out)?;
            } else if tags.is_empty() {
                writeln!(out, "No tags found in vault.")?;
            } else {
                writeln!(out, "TAG                               NOTES")?;
                for tag in &tags {
                    writeln!(
                        out,
                        "{} #{:30} {:5}",
                        if tag.is_pinned { "*" } else { " " },
                        single_line(&tag.name),
                        tag.note_count
                    )?;
                }
                writeln!(out, "\n{} tags total.", tags.len())?;
            }
        }
        Command::Attachments {
            note,
            action: _,
            image,
            json,
        } => {
            let Some(note) = editor::resolve(&db, &[note], false)? else {
                return Ok(());
            };
            if let Some(image) = image {
                attachments::open(&db, &path, &note, &image)?;
            } else {
                let rows = attachments::list(&db, &note)?;
                if json {
                    serde_json::to_writer_pretty(&mut out, &rows)?;
                    writeln!(out)?;
                } else if rows.is_empty() {
                    writeln!(out, "No attached images.")?;
                } else {
                    for row in rows {
                        writeln!(
                            out,
                            "{}  {}  {} bytes  {}",
                            row["id"].as_str().unwrap_or_default(),
                            row["file_name"].as_str().unwrap_or_default(),
                            row["byte_size"],
                            row["upload_state"].as_str().unwrap_or_default()
                        )?;
                    }
                }
            }
        }
        _ => unreachable!(),
    }
    out.flush()?;
    Ok(())
}

fn single_line(value: &str) -> String {
    value.replace(['\n', '\r', '\t'], " ")
}
fn truncate(value: &str, width: usize) -> String {
    if value.chars().count() <= width {
        value.to_owned()
    } else {
        format!("{}…", value.chars().take(width - 1).collect::<String>())
    }
}
fn yes_no(value: bool) -> &'static str {
    if value {
        "Yes"
    } else {
        "No"
    }
}

fn main() -> ExitCode {
    let cli = match Cli::try_parse() {
        Ok(cli) => cli,
        Err(error) => {
            let help = matches!(
                error.kind(),
                ErrorKind::DisplayHelp
                    | ErrorKind::DisplayVersion
                    | ErrorKind::DisplayHelpOnMissingArgumentOrSubcommand
            );
            if help {
                print!("{error}");
            } else {
                eprint!("{error}");
            }
            return ExitCode::from(if help { 0 } else { 64 });
        }
    };
    match run(cli) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            if error
                .downcast_ref::<io::Error>()
                .is_some_and(|e| e.kind() == io::ErrorKind::BrokenPipe)
            {
                return ExitCode::SUCCESS;
            }
            eprintln!("Error: {error:#}");
            ExitCode::FAILURE
        }
    }
}

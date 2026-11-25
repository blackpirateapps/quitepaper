use std::{
    env,
    path::{Path, PathBuf},
    time::Duration,
};

use anyhow::{bail, Context, Result};
use rusqlite::{params, params_from_iter, Connection, OpenFlags, Row};

use crate::{
    model::{display_title, timestamp, Note, Tag},
    ListOptions,
};

const NOTE_COLUMNS: &str = "n.id, n.title, n.content, n.created_at, n.updated_at,
    n.is_pinned, n.is_archived, n.is_trashed, n.journal_date";

pub fn default_path() -> Result<PathBuf> {
    resolve_path(
        env::var_os("QP_DB").map(PathBuf::from),
        env::var_os("XDG_DATA_HOME").map(PathBuf::from),
        env::var_os("HOME").map(PathBuf::from),
    )
}

pub fn resolve_path(
    qp_db: Option<PathBuf>,
    xdg: Option<PathBuf>,
    home: Option<PathBuf>,
) -> Result<PathBuf> {
    if let Some(path) = qp_db.filter(|p| !p.as_os_str().to_string_lossy().trim().is_empty()) {
        return Ok(path.to_string_lossy().trim().into());
    }
    let data = xdg
        .filter(|p| !p.as_os_str().to_string_lossy().trim().is_empty())
        .or_else(|| home.map(|p| p.join(".local/share")))
        .context("Cannot locate notebook: set --db, QP_DB, XDG_DATA_HOME or HOME")?;
    let canonical = data.join("com.blackpiratex.quietpaper/quiet_paper.sqlite");
    let legacy = data.join("quitepaper/quiet_paper.sqlite");
    Ok(if canonical.is_file() || !legacy.is_file() {
        canonical
    } else {
        legacy
    })
}

pub struct Database(pub(crate) Connection);

impl Database {
    pub fn open(path: &Path) -> Result<Self> {
        Self::open_mode(path, false)
    }

    pub fn open_writable(path: &Path) -> Result<Self> {
        Self::open_mode(path, true)
    }

    fn open_mode(path: &Path, writable: bool) -> Result<Self> {
        let mode = if writable {
            OpenFlags::SQLITE_OPEN_READ_WRITE
        } else {
            OpenFlags::SQLITE_OPEN_READ_ONLY
        };
        let db = Connection::open_with_flags(path, mode | OpenFlags::SQLITE_OPEN_NO_MUTEX)
            .with_context(|| format!("Cannot open notebook at {}. Initialize it in the desktop app or select an existing database with --db", path.display()))?;
        db.busy_timeout(Duration::from_secs(5))?;
        // One consistent snapshot for notes and their tags, including a live WAL.
        // No table creation, schema migration, title repair, or journal-mode write.
        db.execute_batch("PRAGMA foreign_keys = ON;")?;
        if !writable {
            db.execute_batch("PRAGMA query_only = ON; BEGIN DEFERRED;")?;
        }
        db.prepare(&format!("SELECT {NOTE_COLUMNS} FROM notes n LIMIT 0"))
            .context("Unsupported notebook schema: expected the desktop notes table")?;
        db.prepare("SELECT t.id, t.name, t.color, t.icon, t.is_pinned, t.is_deleted, nt.note_id, nt.tag_id FROM tags t LEFT JOIN note_tags nt ON nt.tag_id = t.id LIMIT 0")
            .context("Unsupported notebook schema: expected desktop tags and note_tags tables")?;
        Ok(Self(db))
    }

    fn note(&self, row: &Row<'_>) -> Result<Note> {
        let id: String = row.get(0)?;
        let stored_title: String = row.get(1)?;
        let content: String = row.get(2)?;
        let tags = self.0.prepare("SELECT t.name FROM tags t JOIN note_tags nt ON nt.tag_id = t.id WHERE nt.note_id = ? AND t.is_deleted = 0 ORDER BY t.name")?
            .query_map([&id], |r| r.get(0))?.collect::<rusqlite::Result<Vec<String>>>()?;
        Ok(Note {
            short_id: id.chars().take(8).collect(),
            title: display_title(&stored_title, &content),
            id,
            content,
            created_at: timestamp(row.get(3)?)?,
            updated_at: timestamp(row.get(4)?)?,
            is_pinned: row.get(5)?,
            is_archived: row.get(6)?,
            is_trashed: row.get(7)?,
            journal_date: row.get(8)?,
            tags,
        })
    }

    fn query(&self, sql: &str, values: &[String]) -> Result<Vec<Note>> {
        let mut statement = self.0.prepare(sql)?;
        let mut rows = statement.query(params_from_iter(values))?;
        let mut notes = Vec::new();
        while let Some(row) = rows.next()? {
            notes.push(self.note(row)?);
        }
        Ok(notes)
    }

    pub fn list(&self, options: &ListOptions) -> Result<Vec<Note>> {
        let mut conditions = vec![if options.trash {
            "n.is_trashed = 1"
        } else if options.archived {
            "n.is_archived = 1 AND n.is_trashed = 0"
        } else {
            "n.is_archived = 0 AND n.is_trashed = 0"
        }];
        let mut values = Vec::new();
        if options.pinned {
            conditions.push("n.is_pinned = 1");
        }
        if let Some(tag) = options.tag.as_deref().filter(|s| !s.trim().is_empty()) {
            let tag = tag.trim().trim_start_matches('#').trim().to_lowercase();
            conditions.push("EXISTS (SELECT 1 FROM note_tags nt JOIN tags t ON t.id = nt.tag_id WHERE nt.note_id = n.id AND t.is_deleted = 0 AND (t.name = ? OR t.name LIKE ? ESCAPE '\\'))");
            values.push(tag.clone());
            values.push(format!("{}/%", escape_like(&tag)));
        }
        if let Some(search) = options.search.as_deref().filter(|s| !s.trim().is_empty()) {
            conditions.push("(n.title LIKE ? ESCAPE '\\' OR n.content LIKE ? ESCAPE '\\')");
            let pattern = format!("%{}%", escape_like(search.trim()));
            values.extend([pattern.clone(), pattern]);
        }
        let limit = options
            .limit
            .map_or(String::new(), |n| format!(" LIMIT {n}"));
        self.query(&format!("SELECT {NOTE_COLUMNS} FROM notes n WHERE {} ORDER BY n.is_pinned DESC, n.updated_at DESC, n.id{limit}", conditions.join(" AND ")), &values)
    }

    pub fn find(&self, query: &str) -> Result<Note> {
        unique(self.candidates(query)?, query)
    }

    pub fn candidates(&self, query: &str) -> Result<Vec<Note>> {
        let query = query.trim();
        let exact = self.query(
            &format!("SELECT {NOTE_COLUMNS} FROM notes n WHERE lower(n.id) = lower(?)"),
            &[query.to_owned()],
        )?;
        if !exact.is_empty() {
            return Ok(exact);
        }
        if query.len() >= 8 && query.chars().all(|c| c.is_ascii_hexdigit() || c == '-') {
            let prefix = self.query(&format!("SELECT {NOTE_COLUMNS} FROM notes n WHERE lower(substr(n.id, 1, length(?))) = lower(?) ORDER BY n.id"), &[query.to_owned(), query.to_owned()])?;
            if !prefix.is_empty() {
                return Ok(prefix);
            }
        }
        let candidates = self.query(&format!("SELECT {NOTE_COLUMNS} FROM notes n WHERE n.is_archived = 0 AND n.is_trashed = 0 AND n.title LIKE ? ESCAPE '\\' ORDER BY n.updated_at DESC, n.id"), &[format!("%{}%", escape_like(query))])?;
        Ok(candidates)
    }

    pub fn tags(&self) -> Result<Vec<Tag>> {
        // Count the matched active notes, not note_tags links to archived/trash rows.
        let mut statement = self.0.prepare("SELECT t.id, t.name, COUNT(n.id), t.color, t.icon, t.is_pinned FROM tags t LEFT JOIN note_tags nt ON nt.tag_id = t.id LEFT JOIN notes n ON n.id = nt.note_id AND n.is_trashed = 0 AND n.is_archived = 0 WHERE t.is_deleted = 0 GROUP BY t.id ORDER BY t.is_pinned DESC, t.name")?;
        let tags = statement
            .query_map(params![], |row| {
                Ok(Tag {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    note_count: row.get(2)?,
                    color: row.get(3)?,
                    icon: row.get(4)?,
                    is_pinned: row.get(5)?,
                })
            })?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        Ok(tags)
    }
}

fn escape_like(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('%', "\\%")
        .replace('_', "\\_")
}

fn unique(mut notes: Vec<Note>, query: &str) -> Result<Note> {
    match notes.len() {
        0 => bail!("No note found matching {query:?}"),
        1 => Ok(notes.remove(0)),
        _ => bail!(
            "Multiple notes match {query:?}; use a full ID: {}",
            notes
                .iter()
                .map(|n| n.id.as_str())
                .collect::<Vec<_>>()
                .join(", ")
        ),
    }
}

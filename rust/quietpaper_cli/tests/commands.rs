use std::{
    fs,
    path::Path,
    process::{Command, Output},
};

use rusqlite::{params, Connection};
use serde_json::{json, Value};
use tempfile::{tempdir, TempDir};

fn qp(path: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_qp"))
        .arg("--db")
        .arg(path)
        .args(args)
        .env("TZ", "UTC")
        .output()
        .unwrap()
}

fn decoded(output: Output) -> Value {
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    serde_json::from_slice(&output.stdout).unwrap()
}

fn fixture() -> (TempDir, Connection) {
    let dir = tempdir().unwrap();
    let db = Connection::open(dir.path().join("notes.sqlite")).unwrap();
    db.execute_batch("PRAGMA journal_mode = WAL; PRAGMA user_version = 25;
        CREATE TABLE notes (id TEXT PRIMARY KEY, title TEXT, content TEXT, created_at INTEGER, updated_at INTEGER,
            is_pinned INTEGER DEFAULT 0, is_archived INTEGER DEFAULT 0, is_trashed INTEGER DEFAULT 0, journal_date TEXT);
        CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT, color TEXT, icon TEXT, is_pinned INTEGER DEFAULT 0, is_deleted INTEGER DEFAULT 0);
        CREATE TABLE note_tags (note_id TEXT, tag_id TEXT);
        INSERT INTO tags (id, name, is_pinned) VALUES ('work', 'work/cli', 1), ('under', 'work_item/cli', 0), ('wild', 'workXitem/cli', 0), ('gone', 'deleted', 0), ('empty', 'empty', 0);
        UPDATE tags SET is_deleted = 1 WHERE id = 'gone';").unwrap();
    for (id, title, content, updated, pin, archive, trash) in [
        (
            "aaaaaaaa-1111",
            "title: 'বাংলা'",
            "# Body\n100% done",
            10,
            1,
            0,
            0,
        ),
        ("bbbbbbbb-2222", "Recent", "needle body", 30, 0, 0, 0),
        ("cccccccc-3333", "Archived", "archive", 40, 0, 1, 0),
        ("dddddddd-4444", "Trashed", "trash", 50, 0, 0, 1),
    ] {
        db.execute("INSERT INTO notes (id, title, content, created_at, updated_at, is_pinned, is_archived, is_trashed) VALUES (?, ?, ?, 0, ?, ?, ?, ?)", params![id, title, content, updated, pin, archive, trash]).unwrap();
        db.execute("INSERT INTO note_tags VALUES (?, 'work')", [id])
            .unwrap();
    }
    db.execute_batch("INSERT INTO note_tags VALUES ('aaaaaaaa-1111', 'under'), ('bbbbbbbb-2222', 'wild'), ('bbbbbbbb-2222', 'gone');").unwrap();
    (dir, db)
}

#[test]
fn help_version_and_usage_do_not_open_database() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("missing/notes.sqlite");
    for args in [
        vec!["--help"],
        vec!["-v"],
        vec!["--version"],
        vec!["list", "--help"],
        vec!["show", "--help"],
        vec!["new", "--help"],
        vec!["edit", "--help"],
        vec!["delete", "--help"],
        vec!["attach", "--help"],
        vec!["attachments", "--help"],
    ] {
        assert!(qp(&path, &args).status.success(), "{args:?}");
    }
    assert!(Command::new(env!("CARGO_BIN_EXE_qp"))
        .output()
        .unwrap()
        .status
        .success());
    for args in [
        vec!["unknown-command"],
        vec!["list", "--limit", "-1"],
        vec!["list", "--limit", "0"],
        vec!["list", "--limit", "oops"],
        vec!["list", "--json", "--plain"],
        vec!["list", "--wat"],
    ] {
        assert_eq!(qp(&path, &args).status.code(), Some(64), "{args:?}");
    }
    assert!(!path.parent().unwrap().exists());
}

#[test]
fn missing_or_incompatible_database_has_actionable_error() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("notes.sqlite");
    let output = qp(&path, &["list"]);
    assert_eq!(output.status.code(), Some(1));
    assert!(String::from_utf8_lossy(&output.stderr).contains("Initialize it in the desktop app"));
    assert!(!path.exists());
    Connection::open(&path).unwrap();
    let output = qp(&path, &["tags"]);
    assert_eq!(output.status.code(), Some(1));
    assert!(String::from_utf8_lossy(&output.stderr).contains("Unsupported notebook schema"));
}

#[test]
fn list_json_matches_dart_field_contract_and_epoch_seconds() {
    let (dir, _db) = fixture();
    let notes = decoded(qp(&dir.path().join("notes.sqlite"), &["ls", "--json"]));
    assert_eq!(notes.as_array().unwrap().len(), 2);
    assert_eq!(
        notes[0],
        json!({
            "id": "aaaaaaaa-1111", "shortId": "aaaaaaaa", "title": "বাংলা",
            "content": "# Body\n100% done", "createdAt": "1970-01-01T00:00:00.000",
            "updatedAt": "1970-01-01T00:00:10.000", "isPinned": true,
            "isArchived": false, "isTrashed": false, "tags": ["work/cli", "work_item/cli"], "journalDate": null,
        })
    );
    assert_eq!(notes[1]["tags"], json!(["work/cli", "workXitem/cli"]));
}

#[test]
fn list_filters_search_subtrees_and_limits() {
    let (dir, _db) = fixture();
    let path = dir.path().join("notes.sqlite");
    for (args, expected) in [
        (vec!["list", "--archived"], vec!["Archived"]),
        (vec!["list", "--trash", "--archived"], vec!["Trashed"]),
        (vec!["list", "--pinned"], vec!["বাংলা"]),
        (vec!["list", "--search", "needle"], vec!["Recent"]),
        (vec!["list", "--query", "100%"], vec!["বাংলা"]),
        (vec!["list", "--q", "%' OR 1=1 --"], vec![]),
        (vec!["list", "--tag", "#WORK"], vec!["বাংলা", "Recent"]),
        (vec!["list", "--tag", "work_item"], vec!["বাংলা"]),
        (vec!["list", "--tag", "deleted"], vec![]),
        (vec!["list", "--limit", "1"], vec!["বাংলা"]),
    ] {
        let mut args = args;
        args.push("--json");
        let result = decoded(qp(&path, &args));
        let titles = result
            .as_array()
            .unwrap()
            .iter()
            .map(|n| n["title"].as_str().unwrap())
            .collect::<Vec<_>>();
        assert_eq!(titles, expected, "{args:?}");
    }
}

#[test]
fn show_supports_aliases_raw_metadata_and_full_ids_in_trash() {
    let (dir, _db) = fixture();
    let path = dir.path().join("notes.sqlite");
    for alias in ["show", "cat", "view", "s"] {
        assert_eq!(
            qp(&path, &[alias, "AAAAAAAA", "--raw"]).stdout,
            b"# Body\n100% done\n"
        );
    }
    assert_eq!(
        decoded(qp(&path, &["show", "recent", "--json"]))["id"],
        "bbbbbbbb-2222"
    );
    assert_eq!(
        decoded(qp(&path, &["show", "dddddddd-4444", "--json"]))["isTrashed"],
        true
    );
    let info = qp(&path, &["show", "Recent", "--info"]);
    assert!(info.status.success());
    assert!(String::from_utf8_lossy(&info.stdout).contains("Length:    11 characters, 2 words"));
    assert_eq!(qp(&path, &["show", "needle"]).status.code(), Some(1));
}

#[test]
fn ambiguous_prefix_or_title_requires_explicit_id() {
    let (dir, db) = fixture();
    db.execute_batch("INSERT INTO notes (id, title, content, created_at, updated_at) VALUES ('aaaaaaaa-9999', 'Recent duplicate', 'other', 0, 0)").unwrap();
    let path = dir.path().join("notes.sqlite");
    for query in ["aaaaaaaa", "Recent"] {
        let output = qp(&path, &["show", query]);
        assert_eq!(output.status.code(), Some(1));
        assert!(String::from_utf8_lossy(&output.stderr).contains("Multiple notes match"));
        assert!(output.stdout.is_empty());
    }
    assert_eq!(
        decoded(qp(&path, &["show", "aaaaaaaa-9999", "--json"]))["title"],
        "Recent duplicate"
    );
}

#[test]
fn tags_count_only_active_notes_and_keep_empty_tags() {
    let (dir, _db) = fixture();
    let tags = decoded(qp(&dir.path().join("notes.sqlite"), &["t", "--json"]));
    assert_eq!(
        tags[0],
        json!({"id": "work", "name": "work/cli", "noteCount": 2, "color": null, "icon": null, "isPinned": true})
    );
    assert_eq!(tags.as_array().unwrap().len(), 4);
    assert_eq!(tags[1]["name"], "empty");
    assert_eq!(tags[1]["noteCount"], 0);
}

#[test]
fn reads_live_wal_without_writing_notebook_or_observing_uncommitted_edits() {
    let (dir, db) = fixture();
    let path = dir.path().join("notes.sqlite");
    db.execute_batch("PRAGMA wal_checkpoint(TRUNCATE)").unwrap();
    let before = fs::read(&path).unwrap();
    db.execute_batch(
        "BEGIN IMMEDIATE; UPDATE notes SET title = 'Uncommitted' WHERE id = 'bbbbbbbb-2222'",
    )
    .unwrap();
    assert_eq!(
        decoded(qp(&path, &["show", "bbbbbbbb", "--json"]))["title"],
        "Recent"
    );
    db.execute_batch(
        "ROLLBACK; UPDATE notes SET title = 'Committed WAL' WHERE id = 'bbbbbbbb-2222'",
    )
    .unwrap();
    assert_eq!(
        decoded(qp(&path, &["show", "bbbbbbbb", "--json"]))["title"],
        "Committed WAL"
    );
    for args in [
        vec!["list", "--json"],
        vec!["show", "aaaaaaaa", "--raw"],
        vec!["tags", "--json"],
    ] {
        assert!(qp(&path, &args).status.success());
    }
    assert_eq!(fs::read(&path).unwrap(), before);
    assert_eq!(
        db.query_row("PRAGMA user_version", [], |row| row.get::<_, i64>(0))
            .unwrap(),
        25
    );
    assert_eq!(
        db.query_row(
            "SELECT title FROM notes WHERE id = 'aaaaaaaa-1111'",
            [],
            |row| row.get::<_, String>(0)
        )
        .unwrap(),
        "title: 'বাংলা'"
    );
}

#[test]
fn database_discovery_prefers_explicit_then_env_then_canonical_then_legacy() {
    let (dir, db) = fixture();
    db.execute_batch("PRAGMA wal_checkpoint(TRUNCATE)").unwrap();
    let source = dir.path().join("notes.sqlite");
    let xdg = dir.path().join("data");
    let canonical = xdg.join("com.blackpiratex.quietpaper/quiet_paper.sqlite");
    let legacy = xdg.join("quitepaper/quiet_paper.sqlite");
    fs::create_dir_all(legacy.parent().unwrap()).unwrap();
    fs::copy(&source, &legacy).unwrap();
    let invoke = |qp_db: &Path, explicit: bool| {
        let mut command = Command::new(env!("CARGO_BIN_EXE_qp"));
        command
            .env("HOME", dir.path())
            .env("XDG_DATA_HOME", &xdg)
            .env("QP_DB", qp_db);
        if explicit {
            command.arg("--db").arg(&source);
        }
        command.args(["list", "--json"]).output().unwrap()
    };
    decoded(invoke(Path::new(""), false)); // legacy exists
    fs::create_dir_all(canonical.parent().unwrap()).unwrap();
    fs::copy(&source, &canonical).unwrap();
    fs::write(&legacy, b"invalid legacy db").unwrap();
    decoded(invoke(Path::new(""), false)); // canonical wins
    fs::write(&canonical, b"invalid canonical db").unwrap();
    decoded(invoke(&source, false)); // QP_DB wins
    decoded(invoke(Path::new("/does-not-exist"), true)); // explicit wins
}

#[test]
fn home_fallback_and_empty_json_outputs() {
    let dir = tempdir().unwrap();
    let path = dir
        .path()
        .join(".local/share/com.blackpiratex.quietpaper/quiet_paper.sqlite");
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    let (source_dir, db) = fixture();
    db.execute_batch("DELETE FROM note_tags; DELETE FROM notes; DELETE FROM tags; PRAGMA wal_checkpoint(TRUNCATE)").unwrap();
    fs::copy(source_dir.path().join("notes.sqlite"), &path).unwrap();
    for command in ["list", "tags"] {
        let output = Command::new(env!("CARGO_BIN_EXE_qp"))
            .env_remove("QP_DB")
            .env_remove("XDG_DATA_HOME")
            .env("HOME", dir.path())
            .args([command, "--json"])
            .output()
            .unwrap();
        assert_eq!(decoded(output), json!([]));
    }
}

#[test]
fn plain_output_is_tsv_and_global_options_work_after_subcommand() {
    let (dir, db) = fixture();
    db.execute_batch("UPDATE notes SET title = 'Multi' || char(10) || 'line' || char(9) || 'title' WHERE id = 'bbbbbbbb-2222'").unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_qp"))
        .args(["list", "--plain", "--no-color", "--db"])
        .arg(dir.path().join("notes.sqlite"))
        .output()
        .unwrap();
    assert!(output.status.success());
    let text = String::from_utf8(output.stdout).unwrap();
    assert_eq!(text.lines().count(), 2);
    assert!(text.lines().all(|line| line.split('\t').count() == 4));
    assert!(!text.contains('\u{1b}'));
}

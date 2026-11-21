use quietpaper_watched_import::api::engine::*;
use std::{
    fs,
    process::Command,
    thread,
    time::{Duration, Instant},
};

fn candidate(handle: u32) -> Candidate {
    let start = Instant::now();
    loop {
        for event in drain_events(handle).unwrap() {
            if let Some(c) = event.candidate {
                return c;
            }
        }
        assert!(
            start.elapsed() < Duration::from_secs(20),
            "candidate deadline"
        );
        thread::sleep(Duration::from_millis(100));
    }
}
#[test]
fn restart_child() {
    let Ok(root) = std::env::var("QP_TEST_ROOT") else {
        return;
    };
    let root_info = inspect_root(root.clone(), vec![]).unwrap();
    let h = initialize_watched_import_engine(
        "folder".into(),
        root,
        root_info.identity,
        false,
        std::env::var("QP_TEST_POLL").is_ok(),
    )
    .unwrap();
    set_vault_ready(h, true).unwrap();
    let c = candidate(h);
    let bytes = read_candidate_snapshot(h, c.job_id.clone()).unwrap();
    assert_eq!(bytes, b"restart fixture");
    println!("HASH={}", c.sha256);
    // Simulate process death AFTER event/snapshot delivery but BEFORE ACK.
    // Authoritative Drift receipt, not native delivery, decides whether to import.
    if std::env::var("QP_TEST_CRASH").is_ok() {
        std::process::exit(73);
    }
    submit_import_outcome(h, c.job_id, Outcome::Complete).unwrap();
    pause_watch(h).unwrap();
    resume_watch(h).unwrap();
    shutdown_watch(h).unwrap();
    shutdown_watch(h).unwrap();
    assert!(drain_events(h).is_err());
}
#[test]
fn subprocess_redelivery_after_lost_ack_and_poll_fallback() {
    let root = tempfile::tempdir().unwrap();
    fs::write(root.path().join("message.txt"), b"restart fixture").unwrap();
    let run = |crash: bool, poll: bool| {
        let mut cmd = Command::new(std::env::current_exe().unwrap());
        cmd.args(["--exact", "restart_child", "--nocapture"])
            .env("QP_TEST_ROOT", root.path());
        if crash {
            cmd.env("QP_TEST_CRASH", "1");
        }
        if poll {
            cmd.env("QP_TEST_POLL", "1");
        }
        cmd.output().unwrap()
    };
    let first = run(true, false);
    assert_eq!(first.status.code(), Some(73));
    fs::rename(
        root.path().join("message.txt"),
        root.path().join("renamed.txt"),
    )
    .unwrap();
    let second = run(false, true);
    assert!(
        second.status.success(),
        "{}",
        String::from_utf8_lossy(&second.stderr)
    );
    let hash = |b: Vec<u8>| {
        String::from_utf8(b)
            .unwrap()
            .lines()
            .find(|l| l.starts_with("HASH="))
            .unwrap()
            .to_owned()
    };
    assert_eq!(hash(first.stdout), hash(second.stdout));
    assert_eq!(
        fs::read(root.path().join("renamed.txt")).unwrap(),
        b"restart fixture"
    );
}
#[test]
fn lock_bursts_nested_rename_and_snapshot_mutation() {
    let root = tempfile::tempdir().unwrap();
    fs::create_dir(root.path().join("nested")).unwrap();
    fs::write(root.path().join("nested/a.eml.crdownload"), b"incomplete").unwrap();
    let info = inspect_root(root.path().to_str().unwrap().into(), vec![]).unwrap();
    let h = initialize_watched_import_engine(
        "folder".into(),
        info.canonical_path,
        info.identity,
        true,
        false,
    )
    .unwrap();
    thread::sleep(Duration::from_millis(700));
    assert!(drain_events(h)
        .unwrap()
        .iter()
        .all(|e| e.candidate.is_none()));
    for i in 0..1000 {
        fs::write(root.path().join(format!("ignored-{i}.part")), b"partial").unwrap();
    }
    fs::rename(
        root.path().join("nested/a.eml.crdownload"),
        root.path().join("nested/a.eml"),
    )
    .unwrap();
    set_vault_ready(h, true).unwrap();
    let c = candidate(h);
    assert_eq!(c.display_name, "a.eml");
    assert!(c.initial_inventory);
    fs::write(root.path().join("nested/a.eml"), b"different version").unwrap();
    assert!(read_candidate_snapshot(h, c.job_id.clone()).is_err());
    assert!(read_related_image_snapshot(h, c.job_id.clone(), "/etc/passwd".into()).is_err());
    assert!(read_related_image_snapshot(h, c.job_id.clone(), "../../escape.png".into()).is_err());
    fs::write(
        root.path().join("pixel.png"),
        include_bytes!("../../../test/watched_import/fixtures/pixel.png"),
    )
    .unwrap();
    assert_eq!(
        read_related_image_snapshot(h, c.job_id.clone(), "../pixel.png".into()).unwrap(),
        include_bytes!("../../../test/watched_import/fixtures/pixel.png")
    );
    submit_import_outcome(h, c.job_id, Outcome::Retry).unwrap();
    shutdown_watch(h).unwrap();
    assert!(drain_events(h).is_err());
}

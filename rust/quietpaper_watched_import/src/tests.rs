use super::*;
use std::{
    fs,
    os::unix::{
        ffi::OsStringExt,
        fs::{symlink, MetadataExt},
    },
    path::Path,
    sync::atomic::AtomicBool,
    time::{Duration, Instant},
};

#[test]
fn supported_formats_and_temp_rules() {
    for name in [
        "file.eml",
        "folder/file.PDF",
        "é.md",
        "a.markdown",
        "a.txt",
        "a.png",
        "a.jpg",
        "a.jpeg",
        "a.webp",
    ] {
        assert!(rules::limit(Path::new(name)).is_some(), "{name}");
    }
    for name in [
        ".secret.eml",
        "dir/.x/a.eml",
        "a.part",
        "a.eml.crdownload",
        "x.exe",
        "x.sh",
        "a.tmp",
        "a.svg",
        "a.zip",
    ] {
        assert!(rules::limit(Path::new(name)).is_none(), "{name}");
    }
}
#[test]
fn stable_requires_three_checks_and_quiet_period() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("a.txt");
    fs::write(&path, b"a").unwrap();
    let id = scan::Identity::of(&fs::metadata(&path).unwrap());
    let now = Instant::now();
    let mut s = stability::Stability::new(id.clone(), now);
    assert!(!s.observe(id.clone(), now + Duration::from_secs(1)));
    assert!(!s.observe(id.clone(), now + Duration::from_secs(2)));
    assert!(s.observe(id, now + Duration::from_secs(3)));
    fs::write(&path, b"changed").unwrap();
    assert!(!s.observe(
        scan::Identity::of(&fs::metadata(path).unwrap()),
        now + Duration::from_secs(4)
    ));
}
#[test]
fn nofollow_rejects_files_directories_and_fifo() {
    let root = tempfile::tempdir().unwrap();
    let outside = tempfile::tempdir().unwrap();
    fs::write(outside.path().join("private.txt"), b"secret").unwrap();
    symlink(outside.path(), root.path().join("escape")).unwrap();
    symlink(
        outside.path().join("private.txt"),
        root.path().join("link.txt"),
    )
    .unwrap();
    let m = fs::metadata(root.path()).unwrap();
    let id = (m.dev(), m.ino());
    for name in [
        "escape/private.txt",
        "link.txt",
        "../private.txt",
        "/etc/passwd",
    ] {
        assert!(scan::safe_open(root.path(), &id, Path::new(name)).is_err());
    }
    assert!(std::process::Command::new("mkfifo")
        .arg(root.path().join("pipe.txt"))
        .status()
        .unwrap()
        .success());
    let start = Instant::now();
    assert!(scan::safe_open(root.path(), &id, Path::new("pipe.txt")).is_err());
    assert!(start.elapsed() < Duration::from_secs(1));
}
#[test]
fn streamed_hash_limits_cancel_and_source_immutability() {
    let root = tempfile::tempdir().unwrap();
    let path = root.path().join("sample.eml");
    let bytes = vec![b'x'; 1024 * 1024];
    fs::write(&path, &bytes).unwrap();
    let m = fs::metadata(root.path()).unwrap();
    let id = (m.dev(), m.ino());
    let cancel = AtomicBool::new(false);
    let (identity, digest, snapshot) = hashing::read_verified(
        root.path(),
        &id,
        Path::new("sample.eml"),
        50 * 1024 * 1024,
        &cancel,
        true,
    )
    .unwrap();
    assert_eq!(identity.size, bytes.len() as u64);
    assert_eq!(digest.len(), 64);
    assert_eq!(snapshot, bytes);
    assert_eq!(fs::read(path).unwrap(), bytes);
    assert!(
        hashing::read_verified(root.path(), &id, Path::new("sample.eml"), 2, &cancel, false)
            .is_err()
    );
    cancel.store(true, std::sync::atomic::Ordering::Relaxed);
    assert!(hashing::read_verified(
        root.path(),
        &id,
        Path::new("sample.eml"),
        50 * 1024 * 1024,
        &cancel,
        false
    )
    .is_err());
}
#[test]
fn scan_non_utf8_nested_ten_thousand_bounded_descriptors() {
    let root = tempfile::tempdir().unwrap();
    fs::create_dir(root.path().join("nested")).unwrap();
    for i in 0..10_000 {
        fs::write(root.path().join("nested").join(format!("{i}.txt")), b"x").unwrap();
    }
    let name = std::ffi::OsString::from_vec(vec![0xff, b'.', b't', b'x', b't']);
    fs::write(root.path().join(name), b"bytes").unwrap();
    symlink(root.path(), root.path().join("loop")).unwrap();
    let start = Instant::now();
    let fds = fs::read_dir("/proc/self/fd").unwrap().count();
    let mut scan = scan::Scan::new(root.path(), fs::metadata(root.path()).unwrap().dev()).unwrap();
    let mut count = 0;
    while !scan.finished {
        if scan.next().is_some() {
            count += 1;
        }
    }
    assert_eq!(count, 10_001);
    assert!(!scan.incomplete);
    assert!(fs::read_dir("/proc/self/fd").unwrap().count() <= fds + 4);
    eprintln!(
        "10,001-file actual discovery: {:?}; fd delta <=4",
        start.elapsed()
    );
}
#[test]
fn diagnostics_do_not_contain_private_context() {
    assert_eq!(
        diagnostics::EngineError::SourceChanged.to_string(),
        "source_changed"
    );
    assert!(!rules::permitted_root(
        Path::new("/home/user"),
        &["/home/user/.local/share/quietpaper".into()]
    ));
    assert!(!rules::permitted_root(Path::new("/proc/self"), &[]));
}

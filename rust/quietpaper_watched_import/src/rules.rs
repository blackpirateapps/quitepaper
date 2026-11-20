use std::path::Path;

pub fn limit(path: &Path) -> Option<u64> {
    if path
        .components()
        .any(|c| c.as_os_str().as_encoded_bytes().starts_with(b"."))
    {
        return None;
    }
    let extension = path.extension()?.to_str()?.to_ascii_lowercase();
    match extension.as_str() {
        "eml" => Some(50 * 1024 * 1024),
        "md" | "markdown" | "txt" => Some(10 * 1024 * 1024),
        "pdf" | "png" | "jpg" | "jpeg" | "webp" => Some(10_000_000),
        _ => None,
    }
}

pub fn permitted_root(path: &Path, forbidden: &[String]) -> bool {
    (!path.starts_with("/run") || portal_root(path))
        && path.parent().is_some()
        && !["/proc", "/sys", "/dev", "/etc", "/usr", "/boot", "/var"]
            .iter()
            .any(|p| path.starts_with(p))
        && !forbidden
            .iter()
            .any(|p| path.starts_with(p) || Path::new(p).starts_with(path))
}

/// Content signatures are checked before accepting renamed binary files.
pub fn valid_header(path: &Path, bytes: &[u8]) -> bool {
    match path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase()
        .as_str()
    {
        "pdf" => bytes.starts_with(b"%PDF-"),
        "png" => bytes.starts_with(b"\x89PNG\r\n\x1a\n"),
        "jpg" | "jpeg" => bytes.starts_with(&[0xff, 0xd8, 0xff]),
        "webp" => bytes.starts_with(b"RIFF") && bytes.get(8..12) == Some(b"WEBP"),
        _ => true,
    }
}

/// Only the XDG document-portal subtree is eligible under /run. Portal directory
/// grants survive sessions; inode changes still require re-enrollment.
pub fn portal_root(path: &Path) -> bool {
    let parts: Vec<_> = path.components().collect();
    parts.len() >= 7
        && parts[1].as_os_str() == "run"
        && parts[2].as_os_str() == "user"
        && parts[3]
            .as_os_str()
            .to_str()
            .is_some_and(|s| s.chars().all(|c| c.is_ascii_digit()))
        && parts[4].as_os_str() == "doc"
}

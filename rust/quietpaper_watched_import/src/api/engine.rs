use crate::{
    diagnostics::EngineError,
    hashing::read_verified,
    rules,
    worker::{Engine, Shared},
};
use serde::{Deserialize, Serialize};
use std::{
    os::unix::{ffi::OsStringExt, fs::MetadataExt},
    path::PathBuf,
    sync::{atomic::Ordering, Arc, Mutex, OnceLock},
};

static ENGINE: OnceLock<Mutex<Option<Engine>>> = OnceLock::new();
static HANDLE: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(1);
fn slot() -> &'static Mutex<Option<Engine>> {
    ENGINE.get_or_init(|| Mutex::new(None))
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RootInfo {
    pub canonical_path: String,
    pub identity: String,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Candidate {
    pub job_id: String,
    pub folder_id: String,
    pub relative_path: Vec<u8>,
    pub display_name: String,
    pub size: u32,
    pub revision: String,
    pub sha256: String,
    pub format: String,
    pub generation: u32,
    pub initial_inventory: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum EventKind {
    Discovered,
    StableCandidate,
    RootUnavailable,
    WatchDegraded,
    ScanProgress,
    ScanComplete,
    Paused,
    Error,
    Stopped,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EngineEvent {
    pub kind: EventKind,
    pub candidate: Option<Candidate>,
    pub code: Option<String>,
    pub count: u32,
    pub generation: u32,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum Outcome {
    Complete,
    Retry,
    NeedsAttention,
}

/// Validate user input, without creating directories or modifying the source.
pub fn inspect_root(
    root_path: String,
    forbidden_paths: Vec<String>,
) -> std::result::Result<RootInfo, String> {
    let path = PathBuf::from(root_path);
    let original = path.symlink_metadata().map_err(|_| "root_unavailable")?;
    if !original.is_dir() || original.file_type().is_symlink() {
        return Err("unsafe_path".into());
    }
    let canonical = path.canonicalize().map_err(|_| "root_unavailable")?;
    if !rules::permitted_root(&canonical, &forbidden_paths) {
        return Err("protected_root".into());
    }
    canonical.read_dir().map_err(|_| "permission_needed")?;
    Ok(RootInfo {
        canonical_path: canonical.to_str().ok_or("root_encoding")?.to_owned(),
        identity: format!("{}:{}", original.dev(), original.ino()),
    })
}

/// Exactly one engine per GUI process. Replacement requires explicit shutdown.
pub fn initialize_watched_import_engine(
    folder_id: String,
    root_path: String,
    expected_identity: String,
    initial_inventory: bool,
    force_poll: bool,
) -> std::result::Result<u32, String> {
    let mut guard = slot().lock().map_err(|_| "engine_lock")?;
    if guard.is_some() {
        return Err("engine_already_running".into());
    }
    let path = PathBuf::from(root_path);
    let m = path.symlink_metadata().map_err(|_| "root_unavailable")?;
    if !m.is_dir()
        || m.file_type().is_symlink()
        || format!("{}:{}", m.dev(), m.ino()) != expected_identity
    {
        return Err("root_identity_changed".into());
    }
    let handle = HANDLE.fetch_add(1, Ordering::Relaxed);
    let poll = force_poll || rules::portal_root(&path);
    *guard = Some(Engine::start(
        handle,
        folder_id,
        path,
        (m.dev(), m.ino()),
        initial_inventory,
        poll,
    ));
    Ok(handle)
}
fn shared(handle: u32) -> std::result::Result<Arc<Shared>, String> {
    let guard = slot().lock().map_err(|_| "engine_lock")?;
    guard
        .as_ref()
        .filter(|e| e.handle == handle)
        .map(|e| e.shared.clone())
        .ok_or("engine_stopped".into())
}
pub fn set_vault_ready(handle: u32, ready: bool) -> std::result::Result<(), String> {
    shared(handle)?.ready.store(ready, Ordering::Release);
    Ok(())
}
pub fn pause_watch(handle: u32) -> std::result::Result<(), String> {
    shared(handle)?.paused.store(true, Ordering::Release);
    Ok(())
}
pub fn resume_watch(handle: u32) -> std::result::Result<(), String> {
    let s = shared(handle)?;
    s.paused.store(false, Ordering::Release);
    s.dirty.store(true, Ordering::Release);
    Ok(())
}
pub fn reconcile_now(handle: u32) -> std::result::Result<(), String> {
    shared(handle)?.dirty.store(true, Ordering::Release);
    Ok(())
}

/// Bounded pull stream: one native consumer, at most ten polls/sec, no callbacks
/// into disposed Dart isolates. File bytes never appear in diagnostic events.
pub fn drain_events(handle: u32) -> std::result::Result<Vec<EngineEvent>, String> {
    let guard = slot().lock().map_err(|_| "engine_lock")?;
    let engine = guard
        .as_ref()
        .filter(|e| e.handle == handle)
        .ok_or("engine_stopped")?;
    Ok(engine.events.try_iter().take(32).collect())
}
pub fn submit_import_outcome(
    handle: u32,
    job_id: String,
    outcome: Outcome,
) -> std::result::Result<u32, String> {
    let s = shared(handle)?;
    let mut retry_after_ms = 0;
    let mut current = s.current.lock().map_err(|_| "engine_lock")?;
    if current.as_ref().is_some_and(|c| c.job_id == job_id) {
        *current = None;
        if let Ok(mut retry) = s.retry.lock() {
            if matches!(outcome, Outcome::Retry) {
                let attempt = retry.as_ref().map_or(1, |(_, n)| n + 1).min(6);
                let jitter = job_id.bytes().map(u64::from).sum::<u64>() % 500;
                retry_after_ms = ((1u64 << attempt) * 1000 + jitter) as u32;
                *retry = Some((
                    std::time::Instant::now()
                        + std::time::Duration::from_millis(u64::from(retry_after_ms)),
                    attempt,
                ));
            } else {
                *retry = None;
            }
        }
        if matches!(outcome, Outcome::Retry) {
            s.dirty.store(true, Ordering::Release);
        }
    }
    Ok(retry_after_ms)
}

/// Reopen through no-follow directory descriptors, compare BOTH metadata and
/// actual consumed bytes. This is an in-memory bounded snapshot, never a temp file.
/// The canonical importer consumes exactly these verified bytes, not a stale path.
pub fn read_candidate_snapshot(
    handle: u32,
    job_id: String,
) -> std::result::Result<Vec<u8>, String> {
    let s = shared(handle)?;
    if !s.ready.load(Ordering::Acquire) || s.paused.load(Ordering::Acquire) {
        return Err("waiting_for_unlock".into());
    }
    let candidate = s
        .current
        .lock()
        .map_err(|_| "engine_lock")?
        .clone()
        .filter(|c| c.job_id == job_id)
        .ok_or("stale_generation")?;
    let path = PathBuf::from(std::ffi::OsString::from_vec(candidate.relative_path));
    let limit = rules::limit(&path).ok_or("unsupported")?;
    let (identity, hash, bytes) =
        read_verified(&s.root, &s.identity, &path, limit, &s.cancel, true)
            .map_err(|e| e.to_string())?;
    if identity.revision() != candidate.revision
        || hash != candidate.sha256
        || identity.size != u64::from(candidate.size)
    {
        return Err(EngineError::SourceChanged.to_string());
    }
    if s.cancel.load(Ordering::Acquire) || !s.ready.load(Ordering::Acquire) {
        return Err("engine_stopped".into());
    }
    Ok(bytes)
}
pub fn shutdown_watch(handle: u32) -> std::result::Result<(), String> {
    let engine = {
        let mut guard = slot().lock().map_err(|_| "engine_lock")?;
        if guard.as_ref().is_some_and(|e| e.handle == handle) {
            guard.take()
        } else {
            None
        }
    };
    if let Some(engine) = engine {
        engine.stop();
    }
    Ok(())
}
#[flutter_rust_bridge::frb(sync)]
pub fn contract_version() -> u32 {
    1
}

/// Resolves a canonical Markdown importer's local image reference entirely in
/// native code, retaining source bytes in RAM and preserving root containment.
pub fn read_related_image_snapshot(
    handle: u32,
    job_id: String,
    target: String,
) -> std::result::Result<Vec<u8>, String> {
    let s = shared(handle)?;
    if !s.ready.load(Ordering::Acquire) || s.paused.load(Ordering::Acquire) {
        return Err("waiting_for_unlock".into());
    }
    let candidate = s
        .current
        .lock()
        .map_err(|_| "engine_lock")?
        .clone()
        .filter(|c| c.job_id == job_id)
        .ok_or("stale_generation")?;
    let source = PathBuf::from(std::ffi::OsString::from_vec(candidate.relative_path));
    let target = PathBuf::from(target);
    if target.is_absolute() || target.as_os_str().as_encoded_bytes().contains(&b':') {
        return Err("unsafe_image_path".into());
    }
    let name = target.file_name().ok_or("unsafe_image_path")?;
    let parent = source.parent().ok_or("unsafe_image_path")?;
    let mut paths = vec![parent.join(&target), target.clone()];
    for folder in [
        "attachments",
        "_resources",
        "assets",
        "images",
        "media",
        "files",
        "img",
        "photos",
    ] {
        paths.extend([
            parent.join(folder).join(&target),
            parent.join(folder).join(name),
            PathBuf::from(folder).join(&target),
            PathBuf::from(folder).join(name),
        ]);
    }
    for path in paths {
        let mut normalized = PathBuf::new();
        let mut safe = true;
        for part in path.components() {
            match part {
                std::path::Component::Normal(c) => normalized.push(c),
                std::path::Component::CurDir => {}
                std::path::Component::ParentDir => {
                    if !normalized.pop() {
                        safe = false;
                        break;
                    }
                }
                _ => {
                    safe = false;
                    break;
                }
            }
        }
        if !safe {
            continue;
        }
        if !["png", "jpg", "jpeg", "webp"].contains(
            &normalized
                .extension()
                .and_then(|s| s.to_str())
                .unwrap_or_default()
                .to_ascii_lowercase()
                .as_str(),
        ) {
            return Err("unsupported_image".into());
        }
        if let Some(limit) = rules::limit(&normalized) {
            if let Ok((_, _, bytes)) =
                read_verified(&s.root, &s.identity, &normalized, limit, &s.cancel, true)
            {
                if !s.ready.load(Ordering::Acquire) || s.cancel.load(Ordering::Acquire) {
                    return Err("waiting_for_unlock".into());
                }
                return Ok(bytes);
            }
        }
    }
    Err("missing_or_unsafe_image".into())
}

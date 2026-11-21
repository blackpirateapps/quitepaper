use crate::{
    api::engine::{Candidate, EngineEvent, EventKind},
    hashing::read_verified,
    rules,
    scan::{safe_open, Identity, Scan},
    stability::Stability,
    watch::Observation,
};
use std::{
    collections::VecDeque,
    os::unix::ffi::OsStrExt,
    path::PathBuf,
    sync::{
        atomic::{AtomicBool, Ordering},
        mpsc::{sync_channel, Receiver, SyncSender},
        Arc, Mutex,
    },
    thread::{self, JoinHandle},
    time::{Duration, Instant},
};

pub struct Shared {
    pub root: PathBuf,
    pub identity: (u64, u64),
    pub ready: AtomicBool,
    pub paused: AtomicBool,
    pub cancel: AtomicBool,
    pub dirty: Arc<AtomicBool>,
    pub current: Mutex<Option<Candidate>>,
    pub retry: Mutex<Option<(Instant, u32)>>,
}
pub struct Engine {
    pub shared: Arc<Shared>,
    pub events: Receiver<EngineEvent>,
    thread: JoinHandle<()>,
}
impl Engine {
    pub fn start(
        handle: u32,
        folder: String,
        root: PathBuf,
        identity: (u64, u64),
        initial: bool,
        poll: bool,
    ) -> Self {
        let shared = Arc::new(Shared {
            root,
            identity,
            ready: AtomicBool::new(false),
            paused: AtomicBool::new(false),
            cancel: AtomicBool::new(false),
            dirty: Arc::new(AtomicBool::new(true)),
            current: Mutex::new(None),
            retry: Mutex::new(None),
        });
        let (tx, events) = sync_channel(256);
        let s = shared.clone();
        let thread = thread::spawn(move || run(s, handle, folder, initial, poll, tx));
        Self {
            shared,
            events,
            thread,
        }
    }
    pub fn stop(self) {
        self.shared.cancel.store(true, Ordering::Release);
        let _ = self.thread.join();
    }
}
fn emit(tx: &SyncSender<EngineEvent>, s: &Shared, event: EngineEvent) -> bool {
    let mut pending = event;
    loop {
        match tx.try_send(pending) {
            Ok(()) => return true,
            Err(std::sync::mpsc::TrySendError::Disconnected(_)) => return false,
            Err(std::sync::mpsc::TrySendError::Full(e)) => pending = e,
        }
        if s.cancel.load(Ordering::Relaxed) {
            return false;
        }
        thread::sleep(Duration::from_millis(50));
    }
}
fn run(
    s: Arc<Shared>,
    generation: u32,
    folder: String,
    mut initial: bool,
    force_poll: bool,
    tx: SyncSender<EngineEvent>,
) {
    let unhealthy = Arc::new(AtomicBool::new(false));
    let mut observation =
        Observation::attach(&s.root, s.dirty.clone(), unhealthy.clone(), force_poll);
    let mut scan: Option<Scan> = None;
    let mut pending: VecDeque<(PathBuf, Stability)> = VecDeque::new();
    let mut last_scan = Instant::now() - Duration::from_secs(301);
    let mut last_event = Instant::now();
    let mut root_error = false;
    let mut count = 0u32;
    let mut rescan_requested = true;
    let mut inventory_uncertain = false;
    let mut scan_error = false;
    let status = |kind, code: Option<&str>, count| EngineEvent {
        kind,
        candidate: None,
        code: code.map(str::to_owned),
        count,
        generation,
    };
    if observation.as_ref().is_none_or(|w| w.degraded()) {
        emit(
            &tx,
            &s,
            status(EventKind::WatchDegraded, Some("polling_fallback"), 0),
        );
    }
    while !s.cancel.load(Ordering::Acquire) {
        thread::sleep(Duration::from_millis(100));
        if s.paused.load(Ordering::Acquire) || !s.ready.load(Ordering::Acquire) {
            continue;
        }
        let metadata = s.root.symlink_metadata();
        let valid = metadata.as_ref().is_ok_and(|m| {
            m.is_dir()
                && !m.file_type().is_symlink()
                && Identity::of(m).device == s.identity.0
                && Identity::of(m).inode == s.identity.1
        });
        if !valid {
            if !root_error {
                emit(
                    &tx,
                    &s,
                    status(
                        EventKind::RootUnavailable,
                        Some("root_identity_or_access"),
                        0,
                    ),
                );
                root_error = true;
            }
            scan = None;
            pending.clear();
            observation = None;
            continue;
        }
        if root_error {
            root_error = false;
            s.dirty.store(true, Ordering::Relaxed);
            observation =
                Observation::attach(&s.root, s.dirty.clone(), unhealthy.clone(), force_poll);
        }
        if unhealthy.swap(false, Ordering::Relaxed) {
            observation = Observation::attach(
                &s.root,
                s.dirty.clone(),
                Arc::new(AtomicBool::new(false)),
                true,
            );
            emit(
                &tx,
                &s,
                status(EventKind::WatchDegraded, Some("polling_fallback"), 0),
            );
            s.dirty.store(true, Ordering::Relaxed);
        }
        if s.dirty.swap(false, Ordering::Relaxed) {
            if initial && scan.is_some() {
                inventory_uncertain = true;
            }
            last_event = Instant::now();
            rescan_requested = true;
        }
        if scan.is_none()
            && pending.is_empty()
            && last_scan.elapsed() >= Duration::from_millis(500)
            && last_event.elapsed() >= Duration::from_millis(500)
            && (rescan_requested || last_scan.elapsed() >= Duration::from_secs(300))
        {
            rescan_requested = false;
            match Scan::new(&s.root, s.identity.0) {
                Ok(v) => {
                    scan = Some(v);
                    count = 0;
                    scan_error = false;
                    emit(&tx, &s, status(EventKind::ScanProgress, None, 0));
                }
                Err(_) => {
                    emit(
                        &tx,
                        &s,
                        status(EventKind::RootUnavailable, Some("permission_needed"), 0),
                    );
                    last_scan = Instant::now();
                    continue;
                }
            }
        }
        if let Some(walk) = scan.as_mut() {
            // Cooperative bounded discovery, including unsupported files: no long
            // uninterruptible full-tree traversal or unbounded candidate buffer.
            for _ in 0..64 {
                if pending.len() >= 256 {
                    break;
                }
                let Some(path) = walk.next() else {
                    break;
                };
                if let Some(limit) = rules::limit(&path) {
                    match safe_open(&s.root, &s.identity, &path).and_then(|f| {
                        f.metadata()
                            .map_err(|_| crate::diagnostics::EngineError::Io)
                    }) {
                        Ok(m) if m.len() <= limit => pending
                            .push_back((path, Stability::new(Identity::of(&m), Instant::now()))),
                        Ok(_) => {}
                        Err(_) => scan_error = true,
                    }
                }
            }
        }
        let busy = s.current.lock().map(|c| c.is_some()).unwrap_or(true);
        let retry_due = s
            .retry
            .lock()
            .map(|r| {
                r.as_ref()
                    .is_none_or(|(deadline, _)| Instant::now() >= *deadline)
            })
            .unwrap_or(false);
        if !busy && retry_due && last_event.elapsed() >= Duration::from_secs(3) {
            let n = pending.len();
            for _ in 0..n {
                let Some((path, mut stability)) = pending.pop_front() else {
                    break;
                };
                let metadata = safe_open(&s.root, &s.identity, &path).and_then(|f| {
                    f.metadata()
                        .map_err(|_| crate::diagnostics::EngineError::Io)
                });
                let Ok(m) = metadata else {
                    scan_error = true;
                    emit(
                        &tx,
                        &s,
                        status(EventKind::Error, Some("source_unreadable"), count),
                    );
                    continue;
                };
                if !stability.observe(Identity::of(&m), Instant::now()) {
                    pending.push_back((path, stability));
                    continue;
                }
                if let Some(limit) = rules::limit(&path) {
                    match read_verified(&s.root, &s.identity, &path, limit, &s.cancel, false) {
                        Ok((id, hash, _)) => {
                            let candidate = Candidate {
                                job_id: uuid::Uuid::new_v4().to_string(),
                                folder_id: folder.clone(),
                                relative_path: path.as_os_str().as_bytes().to_vec(),
                                display_name: path
                                    .file_name()
                                    .unwrap_or_default()
                                    .to_string_lossy()
                                    .chars()
                                    .filter(|c| !c.is_control())
                                    .take(200)
                                    .collect(),
                                size: id.size as u32,
                                revision: id.revision(),
                                sha256: hash,
                                format: path
                                    .extension()
                                    .unwrap_or_default()
                                    .to_string_lossy()
                                    .to_ascii_lowercase(),
                                generation,
                                initial_inventory: initial,
                            };
                            if let Ok(mut current) = s.current.lock() {
                                *current = Some(candidate.clone());
                            }
                            count = count.saturating_add(1);
                            if !emit(
                                &tx,
                                &s,
                                EngineEvent {
                                    kind: EventKind::StableCandidate,
                                    candidate: Some(candidate),
                                    code: None,
                                    count,
                                    generation,
                                },
                            ) {
                                return;
                            }
                            break;
                        }
                        Err(crate::diagnostics::EngineError::Unsupported) => {
                            emit(
                                &tx,
                                &s,
                                status(EventKind::Error, Some("unsupported_or_oversized"), count),
                            );
                        }
                        Err(_) => {
                            pending.push_back((
                                path,
                                Stability::new(Identity::of(&m), Instant::now()),
                            ));
                        }
                    }
                }
            }
        }
        // Scan iterator exhaustion can only be known after pending queue drains.
        if pending.is_empty() && !s.current.lock().map(|c| c.is_some()).unwrap_or(true) {
            if let Some(walk) = scan.as_mut() {
                if let Some(path) = walk.next() {
                    if let Some(limit) = rules::limit(&path) {
                        if let Ok(f) = safe_open(&s.root, &s.identity, &path) {
                            if let Ok(m) = f.metadata() {
                                if m.len() <= limit {
                                    pending.push_back((
                                        path,
                                        Stability::new(Identity::of(&m), Instant::now()),
                                    ));
                                }
                            }
                        }
                    }
                } else if walk.finished {
                    let incomplete = walk.incomplete || inventory_uncertain || scan_error;
                    emit(
                        &tx,
                        &s,
                        status(
                            EventKind::ScanComplete,
                            if incomplete {
                                Some("inventory_incomplete")
                            } else {
                                None
                            },
                            count,
                        ),
                    );
                    scan = None;
                    last_scan = Instant::now();
                    if !incomplete {
                        initial = false;
                    }
                }
            }
        }
    }
    drop(observation);
    tracing::debug!(code = "watch_stopped", "watcher stopped");
}

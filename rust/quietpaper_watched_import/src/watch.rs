use notify::{Config, PollWatcher, RecommendedWatcher, RecursiveMode, Watcher};
use std::{
    path::Path,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::Duration,
};

pub enum Observation {
    Native(RecommendedWatcher),
    Poll(PollWatcher),
}
impl Observation {
    pub fn attach(
        root: &Path,
        dirty: Arc<AtomicBool>,
        unhealthy: Arc<AtomicBool>,
        force_poll: bool,
    ) -> Option<Self> {
        if !force_poll {
            let flag = dirty.clone();
            let health = unhealthy.clone();
            if let Ok(mut watcher) =
                notify::recommended_watcher(move |result: notify::Result<notify::Event>| {
                    flag.store(true, Ordering::Relaxed);
                    if result.as_ref().map_or(true, |event| event.need_rescan()) {
                        health.store(true, Ordering::Relaxed);
                    }
                })
            {
                if watcher.watch(root, RecursiveMode::Recursive).is_ok() {
                    return Some(Self::Native(watcher));
                }
            }
        }
        unhealthy.store(true, Ordering::Relaxed);
        if let Ok(mut watcher) = PollWatcher::new(
            move |_: notify::Result<notify::Event>| {
                dirty.store(true, Ordering::Relaxed);
            },
            Config::default().with_poll_interval(Duration::from_secs(30)),
        ) {
            if watcher.watch(root, RecursiveMode::Recursive).is_ok() {
                return Some(Self::Poll(watcher));
            }
        }
        None
    }
    pub fn degraded(&self) -> bool {
        match self {
            Self::Native(w) => {
                let _ = w;
                false
            }
            Self::Poll(w) => {
                let _ = w;
                true
            }
        }
    }
}

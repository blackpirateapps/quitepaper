use crate::diagnostics::{EngineError, Result};
use rustix::fs::{open, openat2, Mode, OFlags, ResolveFlags};
use std::{
    fs::{File, Metadata, ReadDir},
    os::{fd::AsRawFd, unix::fs::MetadataExt},
    path::{Component, Path, PathBuf},
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Identity {
    pub device: u64,
    pub inode: u64,
    pub size: u64,
    pub seconds: i64,
    pub nanos: i64,
    pub change_seconds: i64,
    pub change_nanos: i64,
}
impl Identity {
    pub fn of(m: &Metadata) -> Self {
        Self {
            device: m.dev(),
            inode: m.ino(),
            size: m.len(),
            seconds: m.mtime(),
            nanos: m.mtime_nsec(),
            change_seconds: m.ctime(),
            change_nanos: m.ctime_nsec(),
        }
    }
    pub fn revision(&self) -> String {
        format!(
            "{}:{}:{}:{}:{}:{}:{}",
            self.device,
            self.inode,
            self.size,
            self.seconds,
            self.nanos,
            self.change_seconds,
            self.change_nanos
        )
    }
}
fn root_file(root: &Path, identity: &(u64, u64)) -> Result<File> {
    let file = File::from(
        open(
            root,
            OFlags::RDONLY | OFlags::DIRECTORY | OFlags::NOFOLLOW | OFlags::CLOEXEC,
            Mode::empty(),
        )
        .map_err(|_| EngineError::RootUnavailable)?,
    );
    let m = file.metadata().map_err(|_| EngineError::Io)?;
    if (m.dev(), m.ino()) != *identity {
        return Err(EngineError::RootUnavailable);
    }
    Ok(file)
}
/// Component-wise descriptor traversal excludes symlinks, mount escapes and
/// blocking special files at every open. No path-based follow-up file reads.
fn open_relative(
    root: &Path,
    root_identity: &(u64, u64),
    relative: &Path,
    directory: bool,
) -> Result<File> {
    let mut current = root_file(root, root_identity)?;
    if directory && relative.as_os_str().is_empty() {
        return Ok(current);
    }
    let parts: Vec<_> = relative.components().collect();
    if parts.is_empty() || parts.iter().any(|p| !matches!(p, Component::Normal(_))) {
        return Err(EngineError::UnsafePath);
    }
    for (i, part) in parts.iter().enumerate() {
        let last = i + 1 == parts.len();
        let mut flags = OFlags::RDONLY | OFlags::NOFOLLOW | OFlags::CLOEXEC | OFlags::NONBLOCK;
        if !last || directory {
            flags |= OFlags::DIRECTORY;
        }
        let next = File::from(
            openat2(
                &current,
                part.as_os_str(),
                flags,
                Mode::empty(),
                ResolveFlags::BENEATH
                    | ResolveFlags::NO_SYMLINKS
                    | ResolveFlags::NO_MAGICLINKS
                    | ResolveFlags::NO_XDEV,
            )
            .map_err(|_| EngineError::UnsafePath)?,
        );
        let m = next.metadata().map_err(|_| EngineError::Io)?;
        if m.dev() != root_identity.0 || (last && !directory && !m.is_file()) {
            return Err(EngineError::UnsafePath);
        }
        current = next;
    }
    Ok(current)
}
pub fn safe_open(root: &Path, root_identity: &(u64, u64), relative: &Path) -> Result<File> {
    open_relative(root, root_identity, relative, false)
}
struct Level {
    _descriptor: File,
    entries: ReadDir,
    relative: PathBuf,
}
fn level(root: &Path, identity: &(u64, u64), relative: PathBuf) -> Result<Level> {
    let descriptor = open_relative(root, identity, &relative, true)?;
    // Linux procfs descriptor link refers to the already approved open directory,
    // even if an adversary swaps its pathname before read_dir. Never a user link.
    let entries = std::fs::read_dir(format!("/proc/self/fd/{}", descriptor.as_raw_fd()))
        .map_err(|_| EngineError::Io)?;
    Ok(Level {
        _descriptor: descriptor,
        entries,
        relative,
    })
}
/// Lazy DFS holds at most 64 directory descriptors. It yields after at most 128
/// entries (including unsupported entries), so shutdown remains cooperative.
pub struct Scan {
    root: PathBuf,
    identity: (u64, u64),
    stack: Vec<Level>,
    pub incomplete: bool,
    pub finished: bool,
}
impl Scan {
    pub fn new(root: &Path, device: u64) -> Result<Self> {
        let m = root
            .symlink_metadata()
            .map_err(|_| EngineError::RootUnavailable)?;
        let identity = (device, m.ino());
        Ok(Self {
            root: root.to_owned(),
            identity,
            stack: vec![level(root, &identity, PathBuf::new())?],
            incomplete: false,
            finished: false,
        })
    }
    pub fn next(&mut self) -> Option<PathBuf> {
        for _ in 0..128 {
            let Some(dir) = self.stack.last_mut() else {
                self.finished = true;
                return None;
            };
            let entry = match dir.entries.next() {
                None => {
                    self.stack.pop();
                    continue;
                }
                Some(Err(_)) => {
                    self.incomplete = true;
                    continue;
                }
                Some(Ok(e)) => e,
            };
            if entry.file_name().as_encoded_bytes().starts_with(b".") {
                continue;
            }
            let relative = dir.relative.join(entry.file_name());
            let kind = match entry.file_type() {
                Ok(t) => t,
                Err(_) => {
                    self.incomplete = true;
                    continue;
                }
            };
            if kind.is_symlink() {
                continue;
            }
            if kind.is_dir() {
                if self.stack.len() >= 64 {
                    self.incomplete = true;
                    continue;
                }
                match level(&self.root, &self.identity, relative) {
                    Ok(d) => self.stack.push(d),
                    Err(_) => self.incomplete = true,
                }
            } else if kind.is_file() {
                return Some(relative);
            }
        }
        None
    }
}

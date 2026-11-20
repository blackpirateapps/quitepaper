use crate::{
    diagnostics::{EngineError, Result},
    scan::{safe_open, Identity},
};
use sha2::{Digest, Sha256};
use std::{
    io::Read,
    path::Path,
    sync::atomic::{AtomicBool, Ordering},
};

pub fn read_verified(
    root: &Path,
    root_id: &(u64, u64),
    relative: &Path,
    limit: u64,
    cancel: &AtomicBool,
    collect: bool,
) -> Result<(Identity, String, Vec<u8>)> {
    let mut file = safe_open(root, root_id, relative)?;
    let before = Identity::of(&file.metadata().map_err(|_| EngineError::Io)?);
    if before.size > limit {
        return Err(EngineError::Unsupported);
    }
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 64 * 1024];
    let mut bytes = Vec::new();
    let mut count = 0u64;
    loop {
        if cancel.load(Ordering::Relaxed) {
            return Err(EngineError::Stopped);
        }
        let n = file.read(&mut buffer).map_err(|_| EngineError::Io)?;
        if n == 0 {
            break;
        }
        if count == 0 && !crate::rules::valid_header(relative, &buffer[..n]) {
            return Err(EngineError::Unsupported);
        }
        count += n as u64;
        if count > limit {
            return Err(EngineError::Unsupported);
        }
        hasher.update(&buffer[..n]);
        if collect {
            bytes.extend_from_slice(&buffer[..n]);
        }
    }
    let after = Identity::of(&file.metadata().map_err(|_| EngineError::Io)?);
    let path_after = Identity::of(
        &safe_open(root, root_id, relative)?
            .metadata()
            .map_err(|_| EngineError::Io)?,
    );
    if before != after || after != path_after || count != before.size {
        return Err(EngineError::SourceChanged);
    }
    Ok((after, format!("{:x}", hasher.finalize()), bytes))
}

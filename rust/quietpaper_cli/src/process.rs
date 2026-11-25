use anyhow::{bail, Context, Result};
use std::{
    io::Read,
    process::{Command, Stdio},
    thread,
    time::{Duration, Instant},
};

/// Bound both output and wall time for optional desktop helper programs.
pub fn capture(program: &str, args: &[&str], limit: usize, timeout: Duration) -> Result<Vec<u8>> {
    let mut child = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .with_context(|| format!("Could not run {program}; install it for this operation"))?;
    let stdout = child.stdout.take().unwrap();
    let stderr = child.stderr.take().unwrap();
    let output = thread::spawn(move || {
        let mut bytes = Vec::new();
        stdout
            .take(limit as u64 + 1)
            .read_to_end(&mut bytes)
            .map(|_| bytes)
    });
    let errors = thread::spawn(move || {
        let _ = std::io::copy(&mut stderr.take(65536), &mut std::io::sink());
    });
    let start = Instant::now();
    let status = loop {
        if let Some(status) = child.try_wait()? {
            break Some(status);
        }
        if start.elapsed() > timeout {
            let _ = child.kill();
            let _ = child.wait();
            break None;
        }
        thread::sleep(Duration::from_millis(10));
    };
    let bytes = output
        .join()
        .map_err(|_| anyhow::anyhow!("{program} output reader failed"))??;
    let _ = errors.join();
    if status.is_none() {
        bail!("{program} timed out");
    }
    if bytes.len() > limit {
        bail!("{program} output exceeds the size limit");
    }
    if !status.unwrap().success() {
        bail!("{program} did not provide data");
    }
    Ok(bytes)
}

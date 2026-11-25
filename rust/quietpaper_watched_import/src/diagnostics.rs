use thiserror::Error;

/// Codes only: IO errors must never expose source paths or email content.
#[derive(Debug, Error)]
pub enum EngineError {
    #[error("root_unavailable")]
    RootUnavailable,
    #[error("unsafe_path")]
    UnsafePath,
    #[error("source_changed")]
    SourceChanged,
    #[error("unsupported_or_oversized")]
    Unsupported,
    #[error("engine_stopped")]
    Stopped,
    #[error("io_denied")]
    Io,
}
pub type Result<T> = std::result::Result<T, EngineError>;

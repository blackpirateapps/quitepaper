use crate::{
    credentials::Credentials,
    crypto,
    database::Database,
    image_paths,
    model::Note,
    process,
    writes::{self, Save},
};
use anyhow::{bail, Context, Result};
use clap::Args;
use image::{AnimationDecoder, ImageDecoder};
use rusqlite::params;
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::{
    collections::BTreeMap,
    fs::{self, DirBuilder, OpenOptions},
    io::{self, Cursor, IsTerminal, Read, Write},
    os::unix::fs::{DirBuilderExt, OpenOptionsExt},
    path::{Path, PathBuf},
    time::Duration,
};
use uuid::Uuid;
use zeroize::Zeroizing;

pub const MAX_BYTES: usize = 10 * 1024 * 1024;
#[derive(Args, Default)]
pub struct ImportOptions {
    /// Append an image file (repeatable)
    #[arg(long = "attach")]
    pub files: Vec<PathBuf>,
    /// Import PNG/JPEG from this machine's clipboard
    #[arg(long)]
    pub clipboard: bool,
    /// Convert supported still images to JPEG, quality 85, max 2560 pixels
    #[arg(long)]
    pub compress: bool,
    /// Directory for relative Markdown image paths
    #[arg(long)]
    pub base_dir: Option<PathBuf>,
}

pub fn mime(bytes: &[u8]) -> Option<&'static str> {
    if bytes.starts_with(b"\x89PNG\r\n\x1a\n") {
        Some("image/png")
    } else if bytes.starts_with(b"\xff\xd8\xff") {
        Some("image/jpeg")
    } else if bytes.starts_with(b"GIF87a") || bytes.starts_with(b"GIF89a") {
        Some("image/gif")
    } else if bytes.len() >= 12 && &bytes[..4] == b"RIFF" && &bytes[8..12] == b"WEBP" {
        Some("image/webp")
    } else if bytes.len() >= 16
        && &bytes[4..8] == b"ftyp"
        && matches!(&bytes[8..12], b"avif" | b"avis")
    {
        Some("image/avif")
    } else {
        None
    }
}

pub fn read_bounded(path: &Path, limit: usize) -> Result<Zeroizing<Vec<u8>>> {
    let file =
        fs::File::open(path).with_context(|| format!("Cannot open image {}", path.display()))?;
    if !file.metadata()?.is_file() {
        bail!("Image input must be a regular file");
    }
    let mut bytes = Zeroizing::new(Vec::new());
    file.take(limit as u64 + 1).read_to_end(&mut bytes)?;
    if bytes.len() > limit {
        bail!("Image exceeds {} MiB limit", limit / 1024 / 1024);
    }
    Ok(bytes)
}

fn compressed(bytes: &[u8], mime: &str) -> Result<Vec<u8>> {
    if mime == "image/gif"
        && image::codecs::gif::GifDecoder::new(Cursor::new(bytes))?
            .into_frames()
            .take(2)
            .count()
            > 1
    {
        bail!("Animated GIF cannot be compressed; attach original bytes");
    }
    if mime == "image/webp"
        && image::codecs::webp::WebPDecoder::new(Cursor::new(bytes))?.has_animation()
    {
        bail!("Animated WebP cannot be compressed; attach original bytes");
    }
    if mime == "image/png" && image::codecs::png::PngDecoder::new(Cursor::new(bytes))?.is_apng()? {
        bail!("Animated PNG cannot be compressed; attach original bytes");
    }
    let mut reader = image::ImageReader::new(Cursor::new(bytes)).with_guessed_format()?;
    let mut limits = image::Limits::default();
    limits.max_alloc = Some(128 * 1024 * 1024);
    reader.limits(limits);
    let mut decoder = reader
        .into_decoder()
        .context("Cannot decode this image for compression; attach original bytes")?;
    let orientation = decoder.orientation()?;
    let mut decoded = image::DynamicImage::from_decoder(decoder)?;
    decoded.apply_orientation(orientation);
    let scaled = if decoded.width() > 2560 || decoded.height() > 2560 {
        decoded.resize(2560, 2560, image::imageops::FilterType::Lanczos3)
    } else {
        decoded
    };
    let mut output = Vec::new();
    image::codecs::jpeg::JpegEncoder::new_with_quality(&mut output, 85)
        .encode_image(&scaled.to_rgb8())?;
    Ok(output)
}

struct Staged {
    files: Vec<PathBuf>,
    rows: Vec<Value>,
    committed: bool,
}
impl Drop for Staged {
    fn drop(&mut self) {
        if !self.committed {
            for file in &self.files {
                let _ = fs::remove_file(file);
            }
        }
    }
}

struct Importer<'a> {
    path: &'a Path,
    options: &'a ImportOptions,
    credentials: Option<Credentials>,
    staged: Staged,
    cache: BTreeMap<PathBuf, String>,
}
impl Importer<'_> {
    fn prepare(&mut self, mut bytes: Zeroizing<Vec<u8>>, mut name: String) -> Result<String> {
        let mut kind =
            mime(&bytes).context("Unsupported image; use PNG, JPEG, GIF, WebP or AVIF")?;
        if self.options.compress {
            bytes = Zeroizing::new(compressed(&bytes, kind)?);
            kind = "image/jpeg";
            name = format!(
                "{}.jpg",
                Path::new(&name)
                    .file_stem()
                    .unwrap_or_default()
                    .to_string_lossy()
            );
        }
        if bytes.len() > MAX_BYTES {
            bail!("Image exceeds 10 MiB; use --compress or resize it");
        }
        if self.credentials.is_none() {
            self.credentials = Some(Credentials::read(self.path)?);
        }
        let id = Uuid::new_v4().to_string();
        let encrypted = crypto::encrypt_attachment(
            self.credentials.as_mut().unwrap().master_key()?,
            &id,
            &bytes,
        )?;
        let root = self
            .path
            .parent()
            .unwrap_or(Path::new("."))
            .join("attachments");
        DirBuilder::new()
            .recursive(true)
            .mode(0o700)
            .create(&root)?;
        let file = root.join(format!("{id}.enc"));
        let mut output = OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&file)?;
        self.staged.files.push(file.clone());
        output.write_all(&encrypted)?;
        output.sync_all()?;
        self.staged.rows.push(serde_json::json!({"id":id,"name":name,"mime":kind,"size":bytes.len(),"sha":format!("{:x}",Sha256::digest(&bytes)),"path":file}));
        Ok(format!("qp://asset/{id}"))
    }

    fn file(&mut self, target: &str) -> Result<String> {
        let decoded = if target.starts_with("file:") {
            url::Url::parse(target)?
                .to_file_path()
                .map_err(|_| anyhow::anyhow!("Invalid local file URI"))?
        } else {
            let decoded = percent_encoding::percent_decode_str(target)
                .decode_utf8()
                .context("Invalid image path encoding")?;
            if let Some(rest) = decoded.strip_prefix("~/") {
                PathBuf::from(std::env::var_os("HOME").context("HOME unavailable for image path")?)
                    .join(rest)
            } else {
                PathBuf::from(decoded.as_ref())
            }
        };
        let base = self
            .options
            .base_dir
            .clone()
            .unwrap_or(std::env::current_dir()?);
        let path = fs::canonicalize(if decoded.is_absolute() {
            decoded
        } else {
            base.join(decoded)
        })
        .context("Image not found; use --base-dir for relative Markdown images")?;
        if let Some(uri) = self.cache.get(&path) {
            return Ok(uri.clone());
        }
        let bytes = read_bounded(
            &path,
            if self.options.compress {
                100 * 1024 * 1024
            } else {
                MAX_BYTES
            },
        )?;
        let uri = self.prepare(
            bytes,
            path.file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .into_owned(),
        )?;
        self.cache.insert(path, uri.clone());
        Ok(uri)
    }
}

pub fn save(db: &Database, path: &Path, save: &Save<'_>, options: &ImportOptions) -> Result<Note> {
    let mut importer = Importer {
        path,
        options,
        credentials: None,
        staged: Staged {
            files: Vec::new(),
            rows: Vec::new(),
            committed: false,
        },
        cache: BTreeMap::new(),
    };
    let mut content = save.content.to_owned();
    let mut replacements = Vec::new();
    for reference in image_paths::find(&content) {
        let uri = importer.file(&reference.target)?;
        replacements.push((reference.range, uri));
    }
    for (range, uri) in replacements.into_iter().rev() {
        content.replace_range(range, &uri);
    }
    for file in &options.files {
        let uri = importer.file(&file.to_string_lossy())?;
        let alt = file
            .file_stem()
            .unwrap_or_default()
            .to_string_lossy()
            .replace(['[', ']', '\\', '\r', '\n'], "");
        content = format!("{}\n\n![{alt}]({uri})\n", content.trim_end());
    }
    if options.clipboard {
        let (bytes, name) = clipboard()?;
        let uri = importer.prepare(Zeroizing::new(bytes), name.to_owned())?;
        content = format!("{}\n\n![Screenshot]({uri})\n", content.trim_end());
    }
    let updated = Save {
        content: &content,
        ..*save
    };
    let note=db.transaction(||{
        let note=db.save_inner(&updated)?;
        for row in &importer.staged.rows{
            db.0.execute("INSERT INTO attachments (id,note_id,created_at,updated_at,file_name,mime_type,byte_size,sha256,local_path,kind,is_dirty,upload_state,ocr_state,ocr_language) VALUES (?,?,?,?,?,?,?,?,?,'image',1,'upload_pending','queued','en')",params![row["id"].as_str(),save.id,writes::now(),writes::now(),row["name"].as_str(),row["mime"].as_str(),row["size"].as_i64(),row["sha"].as_str(),row["path"].as_str()])?;
        }
        Ok(note)
    })?;
    importer.staged.committed = true;
    Ok(note)
}

pub fn list(db: &Database, note: &Note) -> Result<Vec<Value>> {
    let mut ids = std::collections::BTreeSet::new();
    for part in note.content.split("qp://asset/").skip(1) {
        let id = part
            .chars()
            .take_while(|c| c.is_ascii_hexdigit() || *c == '-')
            .collect::<String>();
        if Uuid::parse_str(&id).is_ok() {
            ids.insert(id);
        }
    }
    let mut rows = Vec::new();
    for id in ids {
        let row = db.row("attachments", &id)?;
        if !row.is_null() && row["is_deleted"].as_i64() == Some(0) {
            rows.push(row);
        }
    }
    Ok(rows)
}

pub fn open(db: &Database, path: &Path, note: &Note, prefix: &str) -> Result<()> {
    if !io::stdin().is_terminal() {
        bail!("Opening images requires an interactive terminal for temporary-file cleanup");
    }
    let rows = list(db, note)?
        .into_iter()
        .filter(|r| r["id"].as_str().is_some_and(|s| s.starts_with(prefix)))
        .collect::<Vec<_>>();
    if rows.len() != 1 {
        bail!("Specify a unique attachment ID from qp attachments");
    }
    let row = &rows[0];
    let file = row["local_path"]
        .as_str()
        .context("Image is not downloaded locally; open it in the desktop app first")?;
    let mut credentials = Credentials::read(path)?;
    let encrypted = read_bounded(Path::new(file), MAX_BYTES + 48)?;
    let plaintext = crypto::decrypt_attachment(
        credentials.master_key()?,
        row["id"].as_str().unwrap(),
        &encrypted,
    )?;
    let temp = tempfile::Builder::new().prefix("qp-view-").tempdir()?;
    let name = Path::new(row["file_name"].as_str().unwrap_or("image"))
        .file_name()
        .filter(|s| !s.is_empty())
        .unwrap_or(std::ffi::OsStr::new("image"));
    let file = temp.path().join(name);
    let mut output = OpenOptions::new()
        .create_new(true)
        .write(true)
        .mode(0o600)
        .open(&file)?;
    output.write_all(&plaintext)?;
    output.sync_all()?;
    if !std::process::Command::new("xdg-open")
        .arg(&file)
        .status()?
        .success()
    {
        bail!("Could not launch an image viewer");
    }
    eprintln!("Press Enter after closing the viewer to remove its temporary image.");
    io::stdin().read_line(&mut String::new())?;
    Ok(())
}

fn clipboard() -> Result<(Vec<u8>, &'static str)> {
    let wayland = std::env::var_os("WAYLAND_DISPLAY").is_some_and(|s| !s.is_empty());
    for (mime, name) in [
        ("image/png", "clipboard.png"),
        ("image/jpeg", "clipboard.jpg"),
    ] {
        let bytes = if wayland {
            process::capture(
                "wl-paste",
                &["--no-newline", "--type", mime],
                MAX_BYTES,
                Duration::from_secs(5),
            )
        } else {
            process::capture(
                "xclip",
                &["-selection", "clipboard", "-target", mime, "-out"],
                MAX_BYTES,
                Duration::from_secs(5),
            )
        };
        if let Ok(bytes) = bytes {
            if !bytes.is_empty() {
                return Ok((bytes, name));
            }
        }
    }
    bail!("No PNG/JPEG clipboard image available; install wl-clipboard (Wayland) or xclip (X11)")
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn image_bounds_and_animation_are_enforced() {
        let mut file = tempfile::NamedTempFile::new().unwrap();
        file.write_all(b"too many bytes").unwrap();
        assert!(read_bounded(file.path(), 3).is_err());
        assert!(mime(b"not an image").is_none());
        let mut bytes = Vec::new();
        {
            let mut encoder = image::codecs::gif::GifEncoder::new(&mut bytes);
            encoder
                .encode_frames([
                    image::Frame::new(image::RgbaImage::new(2, 2)),
                    image::Frame::new(image::RgbaImage::new(2, 2)),
                ])
                .unwrap();
        }
        assert!(compressed(&bytes, "image/gif").is_err());
        let mut png = Cursor::new(Vec::new());
        image::DynamicImage::new_rgb8(3000, 20)
            .write_to(&mut png, image::ImageFormat::Png)
            .unwrap();
        let jpg = compressed(png.get_ref(), "image/png").unwrap();
        let image = image::load_from_memory(&jpg).unwrap();
        assert_eq!(image.width(), 2560);
        assert!(image.height() <= 2560);
    }
}

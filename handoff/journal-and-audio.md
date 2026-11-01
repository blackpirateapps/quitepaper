# Quiet Paper — Journal, Audio & Web Clipper Subsystem

> Part of the Quiet Paper Handoff Documentation. See [INDEX.md](INDEX.md) for the master guide.

---

## 1. Daily Journaling & Paper Calendar Archive

The journal feature provides a dedicated, date-centric space for daily reflections, habits, and timeline tracking. It lives in [`lib/features/journal/`](file:///home/dog/git/quitepaper/lib/features/journal/) and [`lib/core/journal/`](file:///home/dog/git/quitepaper/lib/core/journal/).

### Features & Philosophy
- **Daily Canonical Entries**: One primary note per calendar date, formatted as `YYYY-MM-DD`.
- **"On This Day" Timeline**: Surfaces past entries written on the same day in previous years.
- **Paper Calendar Grid**: Minimal, paper-aesthetic monthly calendar view showing writing streaks and activity density.
- **YAML Frontmatter Metadata**:
  - Automatically manages rich metadata attributes without cluttering the visible note body:
    ```yaml
    ---
    date: 2026-10-31
    mood: thoughtful
    activities: [reading, coding, walk]
    weather: crisp
    moment: morning
    location: Kyoto, Japan
    ---
    ```
  - **Location Dateline**: Optional ambient location stamp automatically resolved or manually entered.

---

## 2. Audio Journaling & On-Device Transcription

Quiet Paper includes voice memo capabilities for ambient thoughts and audio journaling ([`lib/core/audio/`](file:///home/dog/git/quitepaper/lib/core/audio/) and [`lib/core/speech/`](file:///home/dog/git/quitepaper/lib/core/speech/)).

### In-Editor Voice Memos
- **Embedded Audio Card**: Visual waveform player embedded directly within note documents.
- **Typography Integration**: Follows active app font and sizing preferences.
- **Lossless Local Storage**: Encrypted audio clips stored locally and referenced via internal URI.

### On-Device Transcription
- **Privacy-First**: Audio files are transcribed using on-device speech-to-text models without uploading raw audio to third-party cloud servers.
- **Insertable Transcripts**: Generated text can be inserted directly into the note body or preserved as searchable metadata.

---

## 3. Web Clipper & Snapshot Engine

The web clipper ([`lib/features/web_clipper/`](file:///home/dog/git/quitepaper/lib/features/web_clipper/) and [`lib/core/web_clipper/`](file:///home/dog/git/quitepaper/lib/core/web_clipper/)) allows users to save articles and web pages with maximum fidelity.

### Dual-Fidelity Snapshots
1. **Sanitized Clean Markdown**: Reader-friendly article text stripped of ads, cookie banners, and navigation menus.
2. **Authentic Web Snapshot**: Full HTML bundle preserving original fonts, layouts, and inlined CSS stylesheets for exact browser-like viewing.

### Local Encrypted Image Vault & Link Rewriting
- All remote images linked in clipped content are downloaded, compressed, and stored in the local encrypted asset vault.
- Image links are rewritten from external HTTP URLs to internal secure URIs: `qp://asset/<UUID>`.
- **Content-Aware Filtering**: Automatically ignores tiny tracking pixels, decorative spacers, and advertising banners during ingestion.
- Supports modern formats including AVIF and WebP with fallback conversion.

---

## 4. Note Export & Screenshot Sharing

- **Share as Image**: [`lib/features/export/`](file:///home/dog/git/quitepaper/lib/features/export/) enables users to export a full note or selection as a high-resolution, beautifully branded screenshot.
- Renders with the current theme colors (paper light or dark), custom typography, and subtle Quiet Paper watermark.

---

## Key References & Logs
- Audio Journaling & Voice Memos: [Latest Logs, Section 36](latest-logs.md#36-audio-journaling--in-editor-voice-memos-promptsaudiomd)
- On-Device Audio Transcription: [Latest Logs, Section 37](latest-logs.md#37-on-device-audio-journal-transcription-promptstranscriptionforaudiomd)
- Journal Frontmatter & Paper Calendar: [Latest Logs, Section 149 & 164](latest-logs.md#149-journal-frontmatter-properties-mood-activities-weather--moment-october-2026)
- Web Clipper Dual-Fidelity & Inlined Assets: [Historical Logs v1.5, Section 67–70](archive/logs-v1.5.md#67-web-clipping-feature-with-dual-fidelity-snapshots--local-encrypted-image-vault)
- Note Screenshot Sharing: [Latest Logs, Section 143](latest-logs.md#143-note-export-share-note-as-screenshot-with-branding--full-colorization-october-2026)

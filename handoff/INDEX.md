# Quiet Paper — Engineering Handoff Index

Welcome to **Quiet Paper**! This folder contains the modularized engineering handoff documentation, architectural specifications, and implementation logs for engineers and AI agents.

---

## 1. Documentation Map

| Document | Purpose & Scope | Lines / Status |
| :--- | :--- | :--- |
| **[core-architecture.md](core-architecture.md)** | Product vision, directory layout, cryptographic invariants, backend setup, dev commands & security checklist. | Sections 1–9 (Canonical) |
| **[sync-and-storage.md](sync-and-storage.md)** | Zero-knowledge E2EE, Turso cloud database, 3-way conflict merge, offline queue & Drift SQLite. | Subsystem Guide |
| **[editor-and-typography.md](editor-and-typography.md)** | SuperEditor visual AST, smart todolists with collapsible done items, native code blocks, typewriter scrolling & typography. | Subsystem Guide |
| **[ocr-and-documents.md](ocr-and-documents.md)** | Scanned documents (`qp://document/<UUID>`), Syncfusion PDF viewer, Google ML Kit, and local Ollama DeepSeek-OCR. | Subsystem Guide |
| **[journal-and-audio.md](journal-and-audio.md)** | Daily journaling, paper calendar archive, YAML frontmatter, voice memos, on-device audio transcription & web clipper. | Subsystem Guide |
| **[tags-and-search.md](tags-and-search.md)** | Nested tag hierarchy (`#parent/child`), tag sync idempotency, universal fuzzy search & category filters. | Subsystem Guide |
| **[platform-and-builds.md](platform-and-builds.md)** | Multi-platform targets (Android, Linux, iOS, Desktop), automated CI build numbers, Linux packages (DEB, RPM, AppImage, Flatpak) & onboarding. | Subsystem Guide |
| **[latest-logs.md](latest-logs.md)** | Active engineering logs, feature implementations, and bugfixes for **v1.6.0+ (October 2026 – Present)**. | Sections 165–284 (Active) |
| **[archive/logs-v1.5.md](archive/logs-v1.5.md)** | Historical engineering logs for Quiet Paper **v1.5.0 through v1.5.9**. | Sections 46–164 (Archive) |
| **[archive/logs-v1.0-v1.4.md](archive/logs-v1.0-v1.4.md)** | Historical engineering logs for Quiet Paper **v1.0.0 through v1.4.x**. | Sections 10–45 (Archive) |
| **[backup/HANDOFF.original.md](backup/HANDOFF.original.md)** | Full, bit-for-bit verbatim backup of the pre-modularization 11,433-line document. | Backup (Read-Only) |

---

## 2. Quick Architectural Reference

### Core Invariants
1. **Zero-Knowledge Cloud**: Note bodies, titles, tags, and document contents are encrypted client-side using `Argon2id` (19MB, 2 iterations, 16-byte salt) and `XChaCha20-Poly1305` before syncing. The backend is completely crypto-blind.
2. **Local-First & Resilient**: SQLite via Drift is canonical locally. The app is 100% usable offline; changes queue up in `SyncQueueTable` and sync automatically when connected.
3. **Canonical Content in Editor**: In Visual Editor mode, the in-memory SuperEditor AST is the source of truth, enabling zero-compilation autosaves and seamless typing without re-parsing markdown.
4. **Non-Destructive Attachments**: PDF documents and web snapshots are preserved in their original binary format with non-destructive encrypted storage.

### Common Development Commands
```bash
# Run unit & widget tests
flutter test

# Run static analysis
flutter analyze

# Regenerate Drift SQLite database code
dart run build_runner build --delete-conflicting-outputs

# Run backend integration tests (from backend/ directory)
npm test
```

---

## 3. Workflow for AI Agents & Engineers

When implementing new features or fixing bugs in this repository:
1. **Locate Context**: Read the relevant subsystem guide above (`editor-and-typography.md`, `sync-and-storage.md`, etc.) to understand current architectural invariants.
2. **Append Work Logs**:
   - Add new log entries to the bottom of **[`handoff/latest-logs.md`](latest-logs.md)**.
   - Follow the established format: numbered section header, problem overview, architectural design, key files touched, and test/verification status.
3. **Update Domain Guides**: If your changes introduce significant architectural shifts or new core patterns, update the corresponding domain guide (`sync-and-storage.md`, `editor-and-typography.md`, etc.).
4. **Follow `AGENTS.md`**:
   - Verify changes: `flutter analyze` and `flutter test`.
   - Update documentation as described above.
   - Commit and push to git.

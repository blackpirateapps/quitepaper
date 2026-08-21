# Quiet Paper — Cloud Sync Protocol

Quiet Paper uses an offline-first, cursor-based and revision-controlled synchronization protocol over HTTPS.

---

## 1. Sync Model & Endpoints

Base URL: `/api/v1`

### Endpoints
- `GET  /api/v1/account`: Returns authenticated user info and latest sync cursor.
- `GET  /api/v1/keys`: Fetches user's wrapped master key metadata.
- `PUT  /api/v1/keys`: Stores or rotates user's wrapped master key.
- `POST /api/v1/sync/push`: Pushes local encrypted note changes and deletions.
- `POST /api/v1/sync/pull`: Pulls remote encrypted changes after a cursor.
- `GET  /api/v1/sync/cursor`: Fetches highest global revision cursor for user.

---

## 2. Push & Pull Lifecycle

```text
Local Client                                   Vercel / Turso DB
     │                                                 │
     │── 1. Collect dirty notes & deletions ───────────│
     │   Encrypt plaintext locally                     │
     │                                                 │
     │── 2. POST /sync/push (changes, idempotencyKey) ─►
     │                                                 │── Check baseRevision conflicts
     │                                                 │── Assign new monotonic revisions
     │                                                 │── Record in sync_changes log
     │◄─ 3. Return applied revisions & conflicts ──────│
     │                                                 │
     │── 4. POST /sync/pull (cursor) ─────────────────►│
     │◄─ 5. Return changes where revision > cursor ────│
     │   Decrypt pulled notes into Drift DB            │
     │   Update local cursor = max(revision)           │
```

---

## 3. Production-Grade Conflict Handling & 3-Way Merge Protocol

Quiet Paper is **strictly crypto-blind on the backend**. The server cannot decrypt note ciphertext or merge notes. Therefore, all 3-way conflict resolution occurs client-side after decryption.

### 3.1 Revision Control & Conflict Detection
Each note carries a monotonic `revision` counter (starting at 1).
- When a client pushes an edit, it specifies `baseRevision` (the revision on which the edit was made).
- If another device pushed a change in the meantime (`baseRevision < currentServerRevision`), the backend detects a conflict and returns a structured `SYNC_CONFLICT` item containing `serverHead`:
```json
{
  "code": "SYNC_CONFLICT",
  "serverRevision": 2,
  "baseRevision": 1,
  "noteId": "UUID",
  "serverHead": {
    "revision": 2,
    "contentCiphertext": "...",
    "contentNonce": "...",
    "contentVersion": 1,
    "encryptionKeyVersion": 1,
    "isDeleted": false,
    "archived": false,
    "trashed": false,
    "pinned": false,
    "updatedAt": "..."
  }
}
```

### 3.2 Historical Revision Endpoints
Clients can query server head or historical revisions to retrieve common ancestors:
- `GET /api/v1/sync/notes/:id`: Returns the current server head ciphertext.
- `GET /api/v1/sync/notes/:id/revisions/:revision`: Returns historical encrypted snapshot from `sync_changes`.

### 3.3 Client-Side 3-Way Merge Strategy (`merge(BASE, LOCAL, REMOTE)`)
1. **Title**:
   - `BASE == LOCAL` -> `REMOTE` wins.
   - `BASE == REMOTE` -> `LOCAL` wins.
   - `LOCAL == REMOTE` -> that value.
   - Both changed differently -> flagged as Title Conflict (`manualRequired`).
2. **Tags**:
   - Normalized set-theoretic diffing relative to `BASE`.
   - Independent additions from both branches are combined (`LOCAL_ADD ∪ REMOTE_ADD`).
   - Independent removals are preserved.
3. **Markdown Content**:
   - Position-aligned line-level 3-way diff.
   - Preserves source text verbatim, line endings, code fences, blockquotes, tables, links, and `qp://asset/UUID` / `qp://document/UUID` references.
   - Checklist state changes (`- [x]` vs `- [ ]`) on distinct items merge cleanly without collisions.
   - Overlapping edits create focused `ConflictRegion` entries.
4. **Lifecycle & Delete vs Edit**:
   - If one device deleted the note while another edited its content relative to `BASE`, flagged as `deleteVsEdit` conflict with options: Keep edited note, Delete note, Keep both.
5. **Keep Both**:
   - Preserves local note and creates a new note with distinct UUID, appending `(Conflict Copy)` to the title, copying remote content, tags, and queueing for sync.
6. **Provenance Tracking**:
   - Every merge commit or resolution writes to `note_versions` with `baseRevision`, `localParentRevision`, `remoteParentRevision`, `mergeType` (`auto`, `manual`, `keepMine`, `keepTheirs`, `keepBoth`), and `resolutionSummary`.

---

## 4. Idempotency

Mobile networks can drop connections before receiving HTTP responses.
- Clients generate a unique UUID `idempotencyKey` per push request.
- The backend caches the response in `idempotency_keys` for the user.
- Repeated requests with the same key safely return the cached response without creating duplicate revisions or note entries.

---

## 5. Lifecycle Invariants (Trash & Archive)

- **Archive**: Metadata state (`archived = true`). Fully synchronizes across devices.
- **Trash**: Metadata state (`trashed = true`). Indefinite retention with **zero auto-deletion**.
- **Permanent Deletion**: Explicit user action sends a tombstone (`isDeleted = true, deletedAt = now`), cascades to `sync_changes`, and removes note records from all devices.

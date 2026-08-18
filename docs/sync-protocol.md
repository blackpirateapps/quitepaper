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

## 3. Conflict Handling

Each note carries a `revision` counter (starting at 1).
- When a client pushes an edit, it specifies `baseRevision` (the revision on which the edit was made).
- If another device pushed a change in the meantime (`baseRevision < currentServerRevision`), the backend detects a conflict and returns a structured `SYNC_CONFLICT` item.
- The client preserves the local version and schedules a resolution without silent data loss.

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

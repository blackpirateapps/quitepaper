You are implementing production-quality encrypted cloud synchronization
for Quiet Paper, a privacy-focused, Bear-inspired notes application.

The application is Flutter/Dart.

The backend must be implemented in TypeScript and deployed to Vercel.

The database is Turso/libSQL.

Authentication must use Firebase Authentication.

The Flutter client and backend live in the SAME repository.

The most important security property is:

    The backend must NEVER have access to plaintext note content
    or the user's note-encryption keys.

============================================================
1. TECHNOLOGY STACK
============================================================

CLIENT

    Flutter
    Dart

LOCAL DATABASE

    Turso/libSQL for cloud database
    Existing local Flutter database must be preserved unless changes
    are required by the sync architecture.

AUTHENTICATION

    Firebase Authentication

BACKEND

    TypeScript
    Vercel Functions / API routes
    Firebase Admin SDK
    @libsql/client

CRYPTOGRAPHY

    package:cryptography
    cryptography_flutter where appropriate

DATABASE

    Turso/libSQL

DEPLOYMENT

    Vercel

============================================================
2. CRITICAL SEPARATION OF AUTHENTICATION AND ENCRYPTION
============================================================

Firebase Authentication is ONLY responsible for application identity
and authentication.

It answers:

    "Who is this user?"

It must NOT be treated as the note encryption system.

Quiet Paper's encryption system separately answers:

    "Can this user decrypt their notes?"

These are separate security domains.

The Firebase authentication credential/token must NEVER be used directly
as a note encryption key.

The Firebase UID must NEVER be used directly as an encryption key.

The user's Firebase password, if password authentication is enabled,
must NOT automatically become the note encryption password.

Do not derive note encryption keys from:

    Firebase UID
    Firebase ID token
    Firebase refresh token
    Firebase access token
    Firebase API key

============================================================
3. FIREBASE AUTHENTICATION
============================================================

Use Firebase Authentication for account identity.

The Flutter application should use the official Firebase Flutter
integration.

Support the authentication methods already present in the application.

If no authentication currently exists, initially support:

    Email/password authentication

Design the architecture so future providers can be added:

    Google
    Apple
    Passkeys
    etc.

Do not make the encryption architecture depend on the authentication
provider.

============================================================
4. FIREBASE ID TOKENS
============================================================

After the Flutter client authenticates with Firebase, it obtains a
Firebase ID token.

Every authenticated request to the Vercel API must provide the Firebase
ID token using the standard Authorization header:

    Authorization: Bearer <firebase-id-token>

The backend must verify the token using the Firebase Admin SDK.

Do NOT simply decode the JWT and trust its contents.

The backend must verify:

    signature
    issuer
    audience
    expiration
    token validity

The authenticated Firebase UID becomes the canonical application user
identifier.

Never trust a client-supplied user ID.

For example:

    WRONG:

        POST /api/v1/users/{userId}/notes

        and trust {userId}

    CORRECT:

        Authorization: Bearer <Firebase ID token>

        backend verifies token
        backend obtains uid
        backend scopes all database operations to verified uid

============================================================
5. FIREBASE ADMIN SDK
============================================================

The Vercel backend must use the Firebase Admin SDK to verify Firebase
ID tokens.

Do not use Firebase client SDKs inside the backend.

Configure Firebase Admin securely using Vercel environment variables or
another supported secure credential mechanism.

Never commit Firebase service-account credentials to Git.

Do not expose Firebase Admin credentials to Flutter.

Create an authentication middleware/module such as:

    requireFirebaseAuth()

which:

    1. Reads Authorization header.
    2. Extracts Bearer token.
    3. Verifies token with Firebase Admin SDK.
    4. Obtains Firebase UID.
    5. Attaches authenticated user context to request.
    6. Rejects invalid/expired tokens.

All protected API endpoints must use this middleware.

============================================================
6. FIREBASE UID AND DATABASE USERS
============================================================

Use Firebase UID as the stable external identity.

The backend may maintain an internal users table:

    users
    -----
    id
    firebase_uid
    created_at
    updated_at

firebase_uid must be UNIQUE.

The database must never accept user_id from the client as the authority
for authorization.

The backend derives the user from:

    verified Firebase ID token
        ↓
    Firebase UID
        ↓
    internal user record

If a user does not yet have an internal database record, create it
server-side after successful Firebase authentication.

============================================================
7. AUTHENTICATION VS ENCRYPTION PASSWORD
============================================================

Quiet Paper has TWO logically separate credentials/concepts:

    Firebase authentication
        |
        +-- proves account identity

    Quiet Paper encryption password
        |
        +-- unlocks encrypted note keys

The UI may choose to make these passwords the same during onboarding,
but the architecture must NOT depend on that.

The encryption password must never be sent to the backend for note
encryption.

The backend should not need to know the encryption password.

============================================================
8. ENCRYPTION BOUNDARY
============================================================

Only these note fields are end-to-end encrypted:

    title
    body
    tags

These must be encrypted BEFORE leaving the device.

The backend must never receive these fields as plaintext.

The following metadata MAY remain server-readable:

    note ID
    Firebase-derived user/account ID
    created timestamp
    updated timestamp
    archived state
    trashed state
    pinned state
    folder/sidebar location
    sort/order information
    sync version
    deletion state
    encryption format version
    key version
    revision
    timestamps required for synchronization

Do not add plaintext:

    title
    body
    tags

columns to the server database.

Do not create server-side indexes over note content.

============================================================
9. ENCRYPTED CONTENT OBJECT
============================================================

Before encryption, construct:

    {
        "title": "...",
        "body": "...",
        "tags": ["...", "..."]
    }

Encrypt this entire object as one authenticated payload.

Conceptually:

    plaintext content
          |
          v
    XChaCha20-Poly1305
          |
          v
    encrypted envelope

The server stores the envelope as opaque data.

============================================================
10. CRYPTOGRAPHIC PRIMITIVES
============================================================

Do NOT implement cryptographic algorithms manually.

Use:

    package:cryptography

Recommended primitives:

    Password KDF:
        Argon2id

    Content encryption:
        XChaCha20-Poly1305

    Key derivation:
        HKDF

    Future device key exchange:
        X25519

Use cryptographically secure random generation supplied by the library.

Do not use:

    SHA256(password)

as a password key.

Do not use:

    Firebase UID

as an encryption key.

Do not use:

    Firebase ID token

as an encryption key.

Do not use:

    Firebase refresh token

as an encryption key.

============================================================
11. CRYPTO ABSTRACTION
============================================================

Do not allow the application to directly depend on package:cryptography.

Create:

    CryptoService

and:

    KeyManager

For example:

    abstract class CryptoService {
        Future<EncryptedContent> encryptContent(...);
        Future<DecryptedContent> decryptContent(...);
        Future<MasterKey> generateMasterKey();
        Future<WrappedKey> wrapMasterKey(...);
        Future<MasterKey> unwrapMasterKey(...);
    }

The exact API may differ.

The purpose is to isolate cryptographic implementation details.

Future implementations must be able to replace the underlying crypto
library without rewriting the application.

============================================================
12. KEY HIERARCHY
============================================================

Do NOT encrypt every note directly with a key derived from the user's
password.

Use a master key.

Conceptually:

    Quiet Paper Encryption Password
              |
              v
           Argon2id
              |
              v
       Password-Derived Key
              |
              v
       Wrapped Master Key
              |
              v
          MASTER KEY
              |
              v
       Note content encryption

The master key should be randomly generated.

The password protects/wraps the master key.

The master key protects note content.

============================================================
13. MASTER KEY
============================================================

The master key must be generated using cryptographically secure random
bytes.

The server may store the master key only in encrypted/wrapped form.

The server must NEVER store:

    plaintext master key

The server must never have a global master key that can decrypt all
users.

Each user's encryption hierarchy is independent.

============================================================
14. KEY WRAPPING
============================================================

Store a wrapped master key associated with the authenticated user.

Conceptually:

    encryption password
          |
          v
       Argon2id
          |
          v
    password-derived key
          |
          v
    unwrap master key

The backend stores only:

    wrapped master key
    KDF parameters
    salt
    key version
    encryption format version
    necessary metadata

The backend cannot unwrap it because it does not possess the user's
encryption password.

============================================================
15. PASSWORD CHANGES
============================================================

Changing the Quiet Paper encryption password MUST NOT re-encrypt every
note.

Correct flow:

    old encryption password
            |
            v
       derive old key
            |
            v
       unwrap master key
            |
            v
       derive new key
            |
            v
       re-wrap master key
            |
            v
       upload new wrapped key

The encrypted note content must remain unchanged.

Firebase Authentication password changes are a separate operation.

Do not confuse:

    Firebase password change

with:

    Quiet Paper encryption password change

If the application intentionally offers a combined password-change
experience, perform both operations independently and safely.

============================================================
16. PASSWORD RESET
============================================================

A Firebase password reset must NOT automatically decrypt Quiet Paper
notes.

This is critical.

For example:

    Firebase password forgotten
        ↓
    Firebase sends password reset
        ↓
    user sets new Firebase password

This does NOT automatically provide the encryption key.

The encryption system must remain independent.

If the encryption password is lost, the user must use the recovery
mechanism if one exists.

============================================================
17. RECOVERY KEY
============================================================

Design support for a recovery key.

The recovery key should be generated using cryptographically secure
randomness.

The plaintext recovery key must NOT be stored on the backend.

The recovery mechanism should allow:

    recovery key
        |
        v
    recover master key
        |
        v
    choose new encryption password
        |
        v
    re-wrap master key
        |
        v
    continue syncing

If recovery is not fully implemented in the first coding iteration,
create the correct abstractions and database schema but DO NOT create
a fake recovery mechanism.

============================================================
18. NEW DEVICE
============================================================

A user must be able to set up a completely new device without having
an existing device available.

Required flow:

    New device
        |
        v
    Firebase sign-in
        |
        v
    Firebase ID token
        |
        v
    Vercel API
        |
        v
    obtain encrypted key metadata
        |
        v
    user enters Quiet Paper encryption password
        |
        v
    Argon2id
        |
        v
    unwrap master key locally
        |
        v
    pull encrypted notes
        |
        v
    decrypt locally

The backend never sees the encryption password.

============================================================
19. LOCAL KEY STORAGE
============================================================

The master key must not be stored as plaintext in normal preferences.

Use secure platform storage.

The KeyManager should support:

    initialize()
    unlock()
    lock()
    getMasterKey()
    storeWrappedMasterKey()
    rotatePasswordWrappingKey()

If the device supports biometrics, the local UX may use biometrics to
unlock the locally protected master key.

This is a local convenience/security mechanism.

It does not replace the cloud encryption password/recovery mechanism.

Never put encryption keys in:

    SharedPreferences
    plain SQLite
    logs
    analytics
    crash reports

============================================================
20. LOCAL-FIRST SYNC
============================================================

Cloud synchronization must never block editing.

Correct:

    Editor
       |
       v
    Local DB
       |
       +----> UI updates immediately
       |
       v
    Sync Queue
       |
       v
    Encrypt
       |
       v
    Firebase-authenticated API
       |
       v
    Vercel
       |
       v
    Turso

Incorrect:

    Editor
       |
       v
    API
       |
       v
    wait for network
       |
       v
    save note

============================================================
21. LOCAL SEARCH
============================================================

Search is entirely local.

The backend must NEVER receive:

    search queries
    plaintext titles
    plaintext bodies
    plaintext tags

for search.

Search must continue working offline.

If the local database stores encrypted content at rest, maintain an
appropriate local decrypted search representation while the user is
unlocked.

Do not send a search query to the backend.

============================================================
22. BACKEND ARCHITECTURE
============================================================

Use:

    TypeScript
    Vercel Functions
    Firebase Admin SDK
    @libsql/client
    Turso/libSQL
    Zod or equivalent validation library

Recommended structure:

    backend/
        src/
            api/
            auth/
                firebase.ts
                middleware.ts
            db/
            sync/
            crypto/
                DO NOT put server-side note decryption here
            validation/
            errors/
            users/
        migrations/
        tests/

IMPORTANT:

    backend/crypto must NEVER contain functionality that decrypts
    user note content.

The backend only validates/stores encrypted payloads.

============================================================
23. BACKEND API
============================================================

Use:

    /api/v1/...

Suggested endpoints:

    GET  /api/v1/account

    GET  /api/v1/keys
    PUT  /api/v1/keys

    POST /api/v1/sync/push
    POST /api/v1/sync/pull

    GET  /api/v1/sync/cursor

    GET  /api/v1/devices
    POST /api/v1/devices
    DELETE /api/v1/devices/:id

The exact endpoint structure may be improved.

All protected endpoints require:

    Authorization: Bearer <Firebase ID token>

============================================================
24. AUTHENTICATION MIDDLEWARE
============================================================

Every protected endpoint must follow:

    HTTP request
        |
        v
    Authorization header
        |
        v
    Firebase Admin verifyIdToken()
        |
        v
    verified Firebase UID
        |
        v
    user lookup
        |
        v
    authorized operation

Never accept:

    userId

from the request body as the source of truth.

If request contains:

    {
        "userId": "..."
    }

ignore it for authorization.

Use the verified Firebase UID.

============================================================
25. FIREBASE TOKEN EXPIRATION
============================================================

The Flutter client must handle Firebase token expiration using the
official Firebase SDK.

Do not manually invent token refresh logic unless required by the
existing architecture.

The API client should obtain a valid Firebase ID token before making
protected API calls.

Do not store ID tokens permanently in ordinary preferences.

============================================================
26. DATABASE SCHEMA
============================================================

Create normalized Turso/libSQL tables.

At minimum:

    users
    encryption_keys
    devices
    notes
    sync_changes
    idempotency_keys

Possible users:

    id
    firebase_uid UNIQUE
    created_at
    updated_at

Possible encryption_keys:

    id
    user_id
    key_version
    wrapped_master_key
    kdf_algorithm
    kdf_salt
    kdf_parameters
    encryption_format_version
    created_at
    updated_at

Possible notes:

    id
    user_id
    created_at
    updated_at
    archived
    trashed
    pinned
    folder_id
    sort_order
    content_ciphertext
    content_nonce
    content_version
    encryption_key_version
    revision
    deleted_at
    created_by_device
    updated_by_device

Never store plaintext:

    title
    body
    tags

============================================================
27. DATABASE AUTHORIZATION
============================================================

Every database query involving user-owned data must scope by the
authenticated user's internal ID.

Example:

    SELECT ...
    FROM notes
    WHERE user_id = ?

The value MUST come from verified Firebase authentication.

Never use a client-provided user ID.

============================================================
28. SYNC MODEL
============================================================

Use cursor/revision based synchronization.

The client should:

    PUSH local changes
        |
        v
    receive server revisions
        |
        v
    PULL changes after cursor
        |
        v
    apply locally
        |
        v
    persist cursor

Do not download every note on every sync.

============================================================
29. IDEMPOTENCY
============================================================

Mobile networks are unreliable.

Requests may be retried.

Every sync operation should have a stable operation/request ID.

The backend must safely handle duplicate requests.

A retry must not create duplicate notes or duplicate state transitions.

Use an idempotency_keys table or equivalent.

============================================================
30. CONFLICT HANDLING
============================================================

Do not silently overwrite newer changes.

Use per-note revisions.

Example:

    Device A has revision 10.
    Device B has revision 10.

    A uploads edit.
    Server creates revision 11.

    B uploads based on revision 10.

The server must detect:

    baseRevision < currentRevision

and return a conflict.

Do not silently overwrite revision 11.

For v1, return a structured conflict response and let the client handle
it.

Do not pretend to implement CRDTs.

============================================================
31. TRASH
============================================================

Quiet Paper supports:

    active
    archived
    trashed

Moving a note to Trash is reversible.

Trash must remain indefinitely until manually deleted.

There is NO automatic trash cleanup.

Do not delete based on:

    age
    scheduled job
    sync completion
    server retention

Manual permanent deletion must be explicit.

============================================================
32. ARCHIVE
============================================================

Archive is a reversible metadata state.

It synchronizes across devices.

The server may store:

    archived = true/false

============================================================
33. NOTE IDS
============================================================

Generate note IDs client-side.

Prefer UUIDv7 or another suitable globally unique identifier.

The client must be able to create notes while offline.

============================================================
34. ENCRYPTED PAYLOAD FORMAT
============================================================

Use a versioned envelope.

Conceptually:

    {
        "version": 1,
        "algorithm": "xchacha20-poly1305",
        "keyVersion": 1,
        "nonce": "...",
        "ciphertext": "..."
    }

The exact representation must be strongly typed.

The backend validates schema but does not decrypt.

============================================================
35. ASSOCIATED DATA
============================================================

Use authenticated associated data where appropriate.

Bind the encrypted content to stable identity information such as:

    note ID
    account scope
    encryption version

The construction must be deterministic and versioned.

Do not include mutable metadata in associated data unless doing so is
intentional and documented.

============================================================
36. NONCE MANAGEMENT
============================================================

Never reuse a nonce with the same key.

Use secure random nonce generation from the cryptographic library.

Never use:

    timestamp
    note ID
    predictable counter

as a nonce.

============================================================
37. BACKEND MUST BE CRYPTO-BLIND
============================================================

The Vercel backend must not contain:

    decryptNote()
    decryptTitle()
    decryptBody()
    decryptTags()
    getMasterEncryptionKey()

The backend must not have:

    global encryption key
    master encryption key
    user encryption password

It only stores encrypted key material and encrypted content.

============================================================
38. WHAT FIREBASE CAN KNOW
============================================================

Firebase Authentication will necessarily know account identity and
authentication-related information.

That is separate from note encryption.

The system should NOT send note content to Firebase.

Do not store:

    title
    body
    tags

in Firebase user profiles.

Do not store note content in Firebase Analytics.

============================================================
39. WHAT TURSO CAN KNOW
============================================================

Turso can contain:

    Firebase-derived user ID
    note IDs
    timestamps
    archive/trash/pin state
    folder metadata
    encrypted content
    encrypted key material
    revisions
    sync information

Turso must NOT contain plaintext:

    title
    body
    tags
    encryption password
    master key

============================================================
40. VERCEL ENVIRONMENT VARIABLES
============================================================

Use environment variables for backend secrets.

At minimum:

    TURSO_DATABASE_URL
    TURSO_AUTH_TOKEN

Firebase Admin configuration must also be supplied securely.

Depending on the chosen Firebase Admin initialization method, this may
include:

    FIREBASE_PROJECT_ID
    FIREBASE_CLIENT_EMAIL
    FIREBASE_PRIVATE_KEY

or an equivalent secure credential configuration.

Never commit real values.

Create:

    .env.example

with placeholders.

============================================================
41. FIREBASE CONFIGURATION
============================================================

Flutter must use the appropriate Firebase configuration generated for
the application.

Do not commit private service-account credentials into the Flutter
application.

It is acceptable for Firebase client configuration values intended for
the client SDK to exist in the client project.

Never put Firebase Admin credentials in Flutter.

============================================================
42. API AUTHORIZATION TESTS
============================================================

Test:

    valid Firebase token -> succeeds

    expired token -> rejected

    invalid token -> rejected

    missing token -> rejected

    valid user A token attempting to access user B's notes -> rejected

    forged UID in request body -> ignored/rejected

============================================================
43. SECURITY TESTS
============================================================

Verify:

    plaintext title never reaches API

    plaintext body never reaches API

    plaintext tags never reach API

    Firebase token cannot decrypt notes

    Firebase UID cannot decrypt notes

    database dump cannot decrypt notes

    backend has no note decryption capability

    wrong encryption password cannot decrypt notes

    modified ciphertext fails authentication

    wrong key fails

============================================================
44. PASSWORD / AUTH TEST MATRIX
============================================================

Test these separately:

    Firebase password login

    Quiet Paper encryption password

    Firebase password change

    Quiet Paper encryption password change

    Firebase password reset

    Quiet Paper recovery-key recovery

The following must be true:

    Firebase password reset
        DOES NOT
    automatically decrypt notes.

The following must be true:

    Quiet Paper encryption password change
        DOES NOT
    re-encrypt all notes.

============================================================
45. NEW DEVICE TEST
============================================================

Test:

    Device A:
        Firebase login
        encryption password setup
        note creation
        sync

    Device B:
        fresh install
        Firebase login
        obtain wrapped master key
        enter encryption password
        unlock master key
        pull encrypted notes
        decrypt locally

Verify that Device B can recover the notes without Device A being
available.

============================================================
46. LOCAL SEARCH TEST
============================================================

Create:

    title = "Project Apollo"
    body = "Secret content"
    tags = ["project", "private"]

Turn off network.

Search:

    Apollo

Verify result.

Search:

    Secret

Verify result.

Search:

    private

Verify result.

Confirm no network request is made for search.

============================================================
47. PERFORMANCE
============================================================

Typing must never wait for:

    Firebase
    Vercel
    Turso
    encryption network calls

Local note writes must be immediate.

Cloud sync is asynchronous.

Batch changes.

Do not make one API call per keystroke.

Do not encrypt/upload on every character.

Use appropriate debouncing or local revision batching.

============================================================
48. SYNC STATUS
============================================================

Expose clean client states:

    localOnly
    pendingSync
    syncing
    synced
    offline
    conflict
    syncError

Do not expose cryptographic implementation details in the normal editor.

The user should not see:

    "XChaCha20 encryption in progress"

during normal editing.

============================================================
49. LOGGING
============================================================

Never log:

    Firebase tokens
    Firebase refresh tokens
    encryption passwords
    recovery keys
    master keys
    plaintext titles
    plaintext bodies
    plaintext tags

Avoid logging raw encrypted payloads unless necessary for controlled
development debugging.

Use:

    request ID
    operation ID
    note ID
    revision
    error category

for diagnostics.

============================================================
50. ANALYTICS
============================================================

Do not send note content to analytics.

Do not send:

    title
    body
    tags
    search query

to Firebase Analytics or any other analytics provider.

Sync telemetry may contain:

    sync duration
    number of changes
    error category
    retry count

but no note content.

============================================================
51. RATE LIMITING
============================================================

Design rate limiting for:

    authentication-sensitive endpoints
    sync endpoints
    key endpoints

Do not rely on process-local memory because Vercel is serverless.

If a distributed rate-limit provider is not implemented in v1, create
an abstraction and document the production requirement.

============================================================
52. REQUEST LIMITS
============================================================

Enforce:

    title length
    body size
    tag count
    tag length
    encrypted payload size
    changes per sync request

Reject oversized requests.

============================================================
53. API ERROR FORMAT
============================================================

Use consistent machine-readable errors.

Example:

    {
        "error": {
            "code": "SYNC_CONFLICT",
            "message": "The note has changed on another device."
        }
    }

Never expose stack traces or internal database errors in production.

============================================================
54. TURSO
============================================================

Use:

    @libsql/client

Use:

    TURSO_DATABASE_URL
    TURSO_AUTH_TOKEN

Use parameterized SQL.

Do not concatenate user-controlled values into SQL.

Create a centralized database module.

Create proper migrations.

============================================================
55. VERCEL
============================================================

The backend must work within Vercel's serverless execution model.

Do not depend on:

    persistent process state
    local filesystem persistence
    in-memory queues
    long-running workers

The Flutter app owns the reliable sync queue.

Vercel handles API requests.

Turso stores durable server state.

============================================================
56. SAME REPOSITORY
============================================================

Use:

    /
      app/
          Flutter application

      backend/
          TypeScript/Vercel API

      shared/
          API schemas
          protocol definitions

      docs/
          encryption.md
          sync-protocol.md
          authentication.md
          security-review.md

Do not create a second repository.

============================================================
57. DOCUMENTATION
============================================================

Create:

    docs/encryption.md

Explain:

    encryption boundary
    key hierarchy
    Argon2id
    XChaCha20-Poly1305
    password changes
    recovery
    new device
    local storage

Create:

    docs/authentication.md

Explain:

    Firebase Authentication
    ID token
    Firebase UID
    Vercel token verification
    separation from encryption password

Create:

    docs/sync-protocol.md

Explain:

    push
    pull
    cursor
    revisions
    conflicts
    retries
    idempotency
    deletes
    trash
    archive

Create:

    docs/security-review.md

Explain:

    threat model
    assumptions
    metadata leakage
    cryptographic primitives
    limitations
    areas requiring professional security review

============================================================
58. DO NOT IMPLEMENT
============================================================

Do NOT implement:

    custom cryptographic algorithms
    custom password hashing
    server-side note decryption
    server-side content search
    encrypted search on the server
    CRDTs
    blockchain
    microservices
    WebSockets
    automatic trash deletion
    attachment storage
    speculative infrastructure

unless required by the existing project.

Keep v1 simple and correct.

============================================================
59. IMPLEMENTATION ORDER
============================================================

PHASE 1

Inspect the existing repository.

Understand:

    Flutter architecture
    local database
    note model
    repository
    editor
    search
    sidebar
    archive
    trash
    existing authentication

Do not rewrite unrelated code.

PHASE 2

Integrate Firebase Authentication.

Implement:

    Flutter Firebase auth
    Firebase ID token acquisition
    Vercel Firebase Admin token verification
    authenticated user context

Add authentication tests.

PHASE 3

Create CryptoService.

Implement:

    encryption
    decryption
    key generation
    key wrapping
    key unwrapping

Add crypto tests.

PHASE 4

Create KeyManager.

Implement:

    local secure storage
    unlocking
    locking
    master key lifecycle

PHASE 5

Implement versioned encrypted content envelope.

PHASE 6

Create Vercel backend.

Configure:

    TypeScript
    Firebase Admin
    Turso
    migrations
    validation

PHASE 7

Implement:

    /api/v1/keys

PHASE 8

Implement:

    /api/v1/sync/push
    /api/v1/sync/pull
    cursor/revision system
    idempotency

PHASE 9

Implement Flutter SyncEngine.

PHASE 10

Implement:

    offline queue
    retries
    connectivity handling

PHASE 11

Implement:

    multi-device sync

PHASE 12

Implement:

    password change

PHASE 13

Implement:

    recovery key

PHASE 14

Implement:

    conflict handling

PHASE 15

Run full security/integration tests.

PHASE 16

Prepare Vercel deployment documentation.

============================================================
60. DEFINITION OF DONE
============================================================

The feature is complete when this real-world flow works:

DEVICE A

    1. User signs up through Firebase Authentication.

    2. User creates Quiet Paper encryption password.

    3. Master key is generated locally.

    4. Master key is wrapped locally.

    5. Wrapped key is uploaded to Vercel.

    6. User creates:

        Title:
            Secret Project

        Body:
            This is private.

        Tags:
            #private #project

    7. Content is encrypted locally.

    8. Only ciphertext reaches Vercel.

    9. Vercel stores ciphertext in Turso.

    10. Turso does not contain plaintext note content.

DEVICE B

    11. Fresh installation.

    12. User signs into Firebase.

    13. Backend verifies Firebase ID token.

    14. Device retrieves wrapped master key.

    15. User enters Quiet Paper encryption password.

    16. Device derives password key.

    17. Device unwraps master key locally.

    18. Device downloads encrypted notes.

    19. Device decrypts locally.

    20. Note appears correctly.

OFFLINE

    21. Disable network.

    22. Create note.

    23. Edit note.

    24. Search note.

    25. Search works without network.

    26. Re-enable network.

    27. Sync happens automatically.

PASSWORD CHANGE

    28. Change Quiet Paper encryption password.

    29. Verify master key remains the same.

    30. Verify note ciphertext does not change merely because the
        password changed.

FIREBASE PASSWORD RESET

    31. Reset Firebase password.

    32. Verify this does not automatically provide note decryption.

TRASH

    33. Move note to Trash.

    34. Sync Trash state.

    35. Verify note remains in Trash.

    36. Verify there is no automatic deletion.

    37. Manually permanently delete.

    38. Sync permanent deletion.

CONFLICT

    39. Edit note independently on Device A and Device B while offline.

    40. Reconnect both.

    41. Verify conflict detection.

    42. Verify no silent data loss.

SECURITY

    43. Inspect Turso database.

    44. Confirm plaintext title is absent.

    45. Confirm plaintext body is absent.

    46. Confirm plaintext tags are absent.

    47. Confirm Firebase tokens are not stored in Turso.

    48. Confirm encryption passwords are not stored in Turso.

    49. Confirm plaintext master keys are not stored in Turso.

============================================================
61. FINAL SECURITY REQUIREMENT
============================================================

The backend must be incapable of decrypting note content.

Firebase Authentication proves:

    WHO THE USER IS.

Quiet Paper's encryption system proves:

    WHETHER THE USER CAN DECRYPT THEIR NOTES.

These must remain separate.

Do not weaken the encryption architecture to make authentication easier.

Do not weaken authentication to make encryption easier.

The final architecture must preserve:

    Firebase Auth
          |
          v
    authenticated identity
          |
          v
       Vercel API
          |
          v
        Turso

while encryption remains:

    Quiet Paper encryption password
          |
          v
        Argon2id
          |
          v
    password-derived key
          |
          v
      master key
          |
          v
    encrypted title/body/tags
          |
          v
       Vercel/Turso

The backend must never possess the final decryption key.

============================================================
62. FINAL INSTRUCTION
============================================================

First inspect the existing codebase before making changes.

Do not rewrite unrelated functionality.

Do not implement a demo.

Implement this as a real production-oriented foundation.

When uncertain about cryptographic decisions, DO NOT invent a solution.
Document the decision and use established cryptographic constructions.

At the end:

    - run all tests
    - run static analysis
    - verify the backend builds
    - verify Flutter builds
    - verify database migrations
    - verify Firebase authentication
    - verify Vercel compatibility
    - verify encrypted sync
    - verify multi-device recovery
    - verify conflict handling
    - verify that plaintext title/body/tags never reach the backend

Then provide a concise implementation summary and list any remaining
security items requiring professional review.


============================================================
CRITICAL PRODUCT DECISION: SEPARATE PASSWORDS
============================================================

Quiet Paper MUST NOT use the Firebase Authentication password as the
Quiet Paper encryption password.

These are two completely independent credentials.

Firebase Authentication password:
    - authenticates the user's account
    - is handled by Firebase Authentication
    - may be changed/reset through Firebase
    - must never be used directly or indirectly as the note encryption key

Quiet Paper encryption password:
    - protects the user's note encryption master key
    - is known only to the user/device
    - is NEVER sent to Firebase
    - is NEVER sent to the Vercel backend
    - is NEVER stored on the server
    - is NEVER recoverable by the backend

The application MUST preserve this separation even if the user happens
to choose the same password for both.

Changing the Firebase password MUST NOT require re-encrypting notes.

Resetting the Firebase password MUST NOT provide access to encrypted
notes.

Changing the Quiet Paper encryption password MUST NOT require
re-encrypting every note. It should only re-wrap the master key.

Do not merge these two credential systems for convenience.

The encryption architecture must continue to work if Firebase
Authentication is later replaced by Google, Apple, passkeys, or another
identity provider.

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --locked -- --test-threads=1
cargo check --workspace --locked
flutter analyze
# Explicit paths only. Never invoke the complete Flutter suite from this script.
flutter test --no-pub --concurrency=1 test/watched_import test/email_import test/import test/attachments/attachment_service_test.dart test/documents/document_service_test.dart test/settings/settings_screen_test.dart

#!/usr/bin/env bash
# Focused regression gate only: never invokes the full Flutter test suite.
set -euo pipefail
flutter analyze
flutter test --no-pub --concurrency=1 \
  test/email_import \
  test/quick_capture \
  test/web_clipper \
  test/backup \
  test/database/database_migration_test.dart \
  test/database/app_database_test.dart \
  test/notes/notes_query_database_test.dart \
  test/sync/sync_engine_test.dart \
  test/sync/sync_engine_conflict_test.dart \
  test/sync/conflict_resolver_test.dart \
  test/sync/fresh_device_sync_content_retention_test.dart \
  test/attachments/attachment_service_test.dart \
  test/attachments/generic_file_attachment_test.dart \
  test/attachments/generic_attachment_export_and_backup_test.dart \
  test/editor/rich_document_parser_serializer_test.dart \
  test/editor/editor_image_upload_compression_test.dart \
  test/features/export/qpnote_package_and_validator_test.dart \
  test/search/fts5_database_search_test.dart \
  test/search/fts5_integrity_test.dart

flutter test --no-pub test/features/export/export_service_test.dart \
  --plain-name 'QPNote export through the real service includes canonical email provenance'

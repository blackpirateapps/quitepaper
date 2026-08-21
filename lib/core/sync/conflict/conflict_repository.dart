import 'dart:async';
import '../../database/app_database.dart';
import 'conflict_model.dart';

abstract class ConflictRepository {
  Future<void> saveConflict(SyncConflict conflict);
  Future<List<SyncConflict>> getPendingConflicts();
  Stream<List<SyncConflict>> watchPendingConflicts();
  Stream<int> watchPendingConflictsCount();
  Future<int> getPendingConflictsCount();
  Future<SyncConflict?> getConflict(String id);
  Future<SyncConflict?> getConflictForNote(String noteId);
  Future<void> markResolved(
    String id, {
    required int resolutionRevision,
    required ConflictResolutionType resolutionType,
  });
  Future<void> deleteConflict(String id);
  Future<void> deleteConflictsForNote(String noteId);
}

class DriftConflictRepository implements ConflictRepository {
  DriftConflictRepository({required this.database});

  final AppDatabase database;

  @override
  Future<void> saveConflict(SyncConflict conflict) async {
    await database.saveConflict(
      id: conflict.id,
      noteId: conflict.noteId,
      baseRevision: conflict.baseRevision,
      localRevision: conflict.localRevision,
      remoteRevision: conflict.remoteRevision,
      conflictType: conflict.conflictType.name,
      state: conflict.state.name,
      createdAt: conflict.createdAt,
      resolvedAt: conflict.resolvedAt,
      resolutionRevision: conflict.resolutionRevision,
      resolutionType: conflict.resolutionType?.name,
      dataJson: conflict.toDataJson(),
    );
  }

  @override
  Future<List<SyncConflict>> getPendingConflicts() async {
    final entities = await database.getPendingConflicts();
    return entities.map(SyncConflict.fromEntity).toList();
  }

  @override
  Stream<List<SyncConflict>> watchPendingConflicts() {
    return database.watchPendingConflicts().map(
          (entities) => entities.map(SyncConflict.fromEntity).toList(),
        );
  }

  @override
  Stream<int> watchPendingConflictsCount() {
    return database.watchPendingConflictsCount();
  }

  @override
  Future<int> getPendingConflictsCount() async {
    return database.getPendingConflictsCount();
  }

  @override
  Future<SyncConflict?> getConflict(String id) async {
    final entity = await database.getConflict(id);
    return entity != null ? SyncConflict.fromEntity(entity) : null;
  }

  @override
  Future<SyncConflict?> getConflictForNote(String noteId) async {
    final entity = await database.getConflictForNote(noteId);
    return entity != null ? SyncConflict.fromEntity(entity) : null;
  }

  @override
  Future<void> markResolved(
    String id, {
    required int resolutionRevision,
    required ConflictResolutionType resolutionType,
  }) async {
    await database.markConflictResolved(
      id,
      resolutionRevision: resolutionRevision,
      resolutionType: resolutionType.name,
    );
  }

  @override
  Future<void> deleteConflict(String id) async {
    await database.deleteConflict(id);
  }

  @override
  Future<void> deleteConflictsForNote(String noteId) async {
    await database.deleteConflictsForNote(noteId);
  }
}

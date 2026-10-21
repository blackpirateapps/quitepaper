import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../domain/quick_capture_payload.dart';

@immutable
class QuickCaptureState {
  const QuickCaptureState({
    required this.payload,
    required this.content,
    this.cursorPosition = 0,
    this.isSaving = false,
    this.isSaved = false,
    this.errorMessage,
    this.incomingPendingPayload,
    this.availableDrafts = const [],
  });

  final QuickCapturePayload payload;
  final String content;
  final int cursorPosition;
  final bool isSaving;
  final bool isSaved;
  final String? errorMessage;
  final QuickCapturePayload? incomingPendingPayload;
  final List<QuickCaptureDraftEntity> availableDrafts;

  bool get isEmpty => content.trim().isEmpty;
  bool get canSave => !isEmpty && !isSaving && !isSaved;

  QuickCaptureState copyWith({
    QuickCapturePayload? payload,
    String? content,
    int? cursorPosition,
    bool? isSaving,
    bool? isSaved,
    String? errorMessage,
    bool clearError = false,
    QuickCapturePayload? incomingPendingPayload,
    bool clearPendingShare = false,
    List<QuickCaptureDraftEntity>? availableDrafts,
  }) {
    return QuickCaptureState(
      payload: payload ?? this.payload,
      content: content ?? this.content,
      cursorPosition: cursorPosition ?? this.cursorPosition,
      isSaving: isSaving ?? this.isSaving,
      isSaved: isSaved ?? this.isSaved,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      incomingPendingPayload: clearPendingShare
          ? null
          : (incomingPendingPayload ?? this.incomingPendingPayload),
      availableDrafts: availableDrafts ?? this.availableDrafts,
    );
  }
}

class QuickCaptureController extends StateNotifier<QuickCaptureState> {
  QuickCaptureController({
    required AppDatabase database,
    required QuickCapturePayload initialPayload,
  })  : _db = database,
        super(
          QuickCaptureState(
            payload: initialPayload,
            content: initialPayload.initialContent,
            cursorPosition: initialPayload.cursorPosition,
          ),
        ) {
    _loadDrafts();
    if (initialPayload.initialContent.trim().isNotEmpty) {
      _persistDraft();
    }
  }

  final AppDatabase _db;
  Timer? _debounceTimer;

  Future<void> _loadDrafts() async {
    try {
      final allDrafts = await _db.getAllQuickCaptureDrafts();
      final others = allDrafts.where((d) => d.id != state.payload.id).toList();
      if (mounted) {
        state = state.copyWith(availableDrafts: others);
      }
    } catch (e) {
      debugPrint('[QuickCapture] Error loading drafts: $e');
    }
  }

  /// Updates text content from the text controller with debounced draft persistence.
  void updateContent(String newContent, {int? cursor}) {
    if (state.isSaved) return;

    final cursorLoc = cursor ?? newContent.length;
    state = state.copyWith(
      content: newContent,
      cursorPosition: cursorLoc,
      clearError: true,
    );

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _persistDraft();
    });
  }

  /// Immediately flushes the latest in-memory text to SQLite draft storage.
  Future<void> flushDraft() async {
    _debounceTimer?.cancel();
    await _persistDraft();
  }

  Future<void> _persistDraft() async {
    if (state.isSaved) return;

    try {
      if (state.content.trim().isEmpty) {
        await _db.deleteQuickCaptureDraft(state.payload.id);
      } else {
        await _db.saveQuickCaptureDraft(
          id: state.payload.id,
          targetNoteId: state.payload.targetNoteId,
          content: state.content,
          source: state.payload.origin.name,
          sourceUrl: state.payload.sourceUrl,
          titleHint: state.payload.titleHint,
          cursorPosition: state.cursorPosition,
          createdAt: state.payload.createdAt,
          updatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[QuickCapture] Draft autosave error: $e');
    }
  }

  /// Saves the current capture locally as a canonical Quiet Paper note.
  /// Returns `true` if persistence succeeded.
  Future<bool> save() async {
    if (!state.canSave) return false;

    state = state.copyWith(isSaving: true, clearError: true);
    _debounceTimer?.cancel();

    try {
      final content = state.content;
      final derived = Note.deriveTitle(content);
      final title = (derived.isNotEmpty && derived != 'Untitled')
          ? derived
          : (state.payload.titleHint ?? (derived.isNotEmpty ? derived : 'Untitled'));

      final now = DateTime.now();
      final note = Note(
        id: state.payload.targetNoteId,
        title: title,
        content: content,
        createdAt: state.payload.createdAt,
        updatedAt: now,
      );

      // Atomically commit the note and remove its draft record
      await _db.commitQuickCaptureNote(
        note: note,
        draftSessionId: state.payload.id,
      );

      state = state.copyWith(isSaving: false, isSaved: true);
      return true;
    } catch (e) {
      debugPrint('[QuickCapture] Failed to commit note: $e');
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save note locally: $e',
      );
      return false;
    }
  }

  /// Handles an additional incoming share delivered while Quick Capture is already open.
  void handleIncomingShare(QuickCapturePayload newPayload) {
    if (state.isEmpty) {
      // Current capture has no content; switch immediately
      state = state.copyWith(
        payload: newPayload,
        content: newPayload.initialContent,
        cursorPosition: newPayload.initialContent.length,
        clearPendingShare: true,
      );
      if (newPayload.initialContent.trim().isNotEmpty) {
        _persistDraft();
      }
    } else {
      // Preserve current text as draft, and offer the new share via pending banner
      _persistDraft();
      state = state.copyWith(incomingPendingPayload: newPayload);
    }
  }

  /// Explicitly switches from current text to the pending incoming share.
  Future<void> acceptIncomingPendingShare() async {
    final pending = state.incomingPendingPayload;
    if (pending == null) return;

    await flushDraft();
    state = state.copyWith(
      payload: pending,
      content: pending.initialContent,
      cursorPosition: pending.initialContent.length,
      clearPendingShare: true,
    );
    if (pending.initialContent.trim().isNotEmpty) {
      await _persistDraft();
    }
  }

  /// Dismisses the incoming pending share notification.
  void dismissIncomingPendingShare() {
    state = state.copyWith(clearPendingShare: true);
  }

  /// Resumes an unfinished draft from an earlier session.
  Future<void> resumeDraft(QuickCaptureDraftEntity draft) async {
    await flushDraft();

    final resumedPayload = QuickCapturePayload(
      id: draft.id,
      targetNoteId: draft.targetNoteId,
      origin: CaptureOrigin.values.firstWhere(
        (o) => o.name == draft.source,
        orElse: () => CaptureOrigin.widget,
      ),
      initialContent: draft.content,
      sourceUrl: draft.sourceUrl,
      titleHint: draft.titleHint,
      cursorPosition: draft.cursorPosition,
      createdAt: draft.createdAt,
    );

    state = state.copyWith(
      payload: resumedPayload,
      content: draft.content,
      cursorPosition: draft.cursorPosition,
      clearPendingShare: true,
      clearError: true,
    );
    await _loadDrafts();
  }

  /// Discards a specific unfinished draft from the database.
  Future<void> discardDraft(String draftId) async {
    try {
      await _db.deleteQuickCaptureDraft(draftId);
      await _loadDrafts();
    } catch (e) {
      debugPrint('[QuickCapture] Error discarding draft $draftId: $e');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Provider family for the Quick Capture controller keyed by session ID.
final quickCaptureControllerProvider = StateNotifierProvider.autoDispose
    .family<QuickCaptureController, QuickCaptureState, QuickCapturePayload>(
  (ref, payload) {
    final db = ref.watch(databaseProvider);
    return QuickCaptureController(database: db, initialPayload: payload);
  },
);

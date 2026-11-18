import 'dart:collection';

/// Incoming-request identity, not content, controls lifecycle deduplication.
/// A later intentional share of the same bytes has a fresh native ID.
class IncomingShareCoordinator {
  IncomingShareCoordinator({
    required this.handle,
    required this.acknowledge,
    this.onFailure,
  });
  final Future<void> Function(Map<String, dynamic> request) handle;
  final Future<void> Function(String id) acknowledge;
  final void Function()? onFailure;
  final _seen = <String>{};
  final _pending = Queue<Map<String, dynamic>>();
  bool _running = false, _disposed = false;
  Map<String, dynamic>? _current;
  void add(Map<String, dynamic> request) {
    final id = request['id'];
    if (id is! String || id.isEmpty || !_seen.add(id)) return;
    if (_seen.length > 256) _seen.remove(_seen.first);
    if (_disposed || _pending.length >= 100) {
      onFailure?.call();
      acknowledge(id);
      return;
    }
    _pending.add(request);
    _drain();
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (_pending.isNotEmpty && !_disposed) {
        final request = _pending.removeFirst();
        final id = request['id'] as String;
        _current = request;
        try {
          await handle(request);
        } catch (_) {
          onFailure?.call();
        } finally {
          await acknowledge(id);
          _current = null;
          request.clear();
        }
      }
    } finally {
      _running = false;
    }
  }

  void clear() {
    _current?.removeWhere((key, _) => key != 'id');
    _current?['invalidated'] = true;
    while (_pending.isNotEmpty) {
      final request = _pending.removeFirst();
      acknowledge(request['id'] as String);
      request.clear();
    }
  }

  void dispose() {
    _disposed = true;
    clear();
  }
}

import 'dart:async';
import 'dart:isolate';

Future<R> compute<Q, R>(FutureOr<R> Function(Q) callback, Q message) =>
    Isolate.run(() => callback(message));

bool listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

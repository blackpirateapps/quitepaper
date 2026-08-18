import 'dart:async';
import 'package:flutter/foundation.dart';

/// A simple Debouncer to execute a callback after a given delay.
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 600)});

  final Duration duration;
  Timer? _timer;

  bool get isRunning => _timer?.isActive ?? false;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void flush(VoidCallback action) {
    if (isRunning) {
      _timer?.cancel();
      action();
    }
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    cancel();
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/journal/domain/journal_date_helper.dart';

/// Injectable wall clock; calendar days remain local even across DST changes.
final journalNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final journalDayClockProvider =
    StateNotifierProvider<JournalDayClock, DateTime>((ref) {
      return JournalDayClock(ref.watch(journalNowProvider));
    });

/// Shares one current day across Today, memories and calendar highlights.
class JournalDayClock extends StateNotifier<DateTime>
    with WidgetsBindingObserver {
  JournalDayClock(this._now) : super(JournalDateHelper.toLocalDate(_now())) {
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  final DateTime Function() _now;
  Timer? _timer;

  void _refresh() {
    if (!mounted) return;
    final day = JournalDateHelper.toLocalDate(_now());
    if (day != state) state = day;
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _timer?.cancel();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.detached) {
      return;
    }
    final now = _now().toLocal();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(midnight.difference(now), _refresh);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-read wall time after sleep, timezone changes and clock adjustments.
      _refresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

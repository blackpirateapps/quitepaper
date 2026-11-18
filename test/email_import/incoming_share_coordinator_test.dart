import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/sharing/incoming_share_coordinator.dart';

void main() {
  test(
    'cold initial and warm stream duplicates have one pending session',
    () async {
      final gate = Completer<void>();
      final started = <String>[];
      final acknowledged = <String>[];
      final coordinator = IncomingShareCoordinator(
        handle: (r) async {
          started.add(r['id'] as String);
          await gate.future;
        },
        acknowledge: (id) async => acknowledged.add(id),
      );
      coordinator.add({'id': 'native-1', 'files': []});
      coordinator.add({'id': 'native-1', 'files': []});
      expect(started, ['native-1']);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(acknowledged, ['native-1']);
      coordinator.add({'id': 'native-1'});
      expect(started, ['native-1']);
      coordinator.dispose();
    },
  );
  test(
    'rapid shares run serially; intentional same content with new IDs is retained',
    () async {
      final gate = Completer<void>();
      final started = <String>[];
      final coordinator = IncomingShareCoordinator(
        handle: (r) async {
          started.add(r['id'] as String);
          if (r['id'] == 'one') await gate.future;
        },
        acknowledge: (_) async {},
      );
      coordinator.add({'id': 'one', 'text': 'same'});
      coordinator.add({'id': 'two', 'text': 'same'});
      coordinator.add({'id': 'three', 'text': 'third'});
      expect(started, ['one']);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(started, ['one', 'two', 'three']);
      coordinator.dispose();
    },
  );
  test(
    'provider or routing failure acknowledges source and continues next request',
    () async {
      final done = <String>[];
      var failures = 0;
      final coordinator = IncomingShareCoordinator(
        handle: (r) async {
          if (r['id'] == 'failed') throw StateError('private provider error');
        },
        acknowledge: (id) async => done.add(id),
        onFailure: () => failures++,
      );
      coordinator.add({'id': 'failed'});
      coordinator.add({'id': 'next'});
      await Future<void>.delayed(Duration.zero);
      expect(done, ['failed', 'next']);
      expect(failures, 1);
      coordinator.dispose();
    },
  );
  test(
    'secure clear removes queued plaintext and invalidates current request',
    () async {
      final gate = Completer<void>();
      final ack = <String>[];
      Map<String, dynamic>? active;
      final coordinator = IncomingShareCoordinator(
        handle: (r) async {
          active = r;
          await gate.future;
        },
        acknowledge: (id) async => ack.add(id),
      );
      final queued = <String, dynamic>{'id': 'queued', 'text': 'private'};
      coordinator.add({'id': 'current', 'text': 'private'});
      coordinator.add(queued);
      coordinator.clear();
      expect(active, {'id': 'current', 'invalidated': true});
      expect(queued, isEmpty);
      expect(ack, ['queued']);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(ack, ['queued', 'current']);
      coordinator.dispose();
    },
  );
  test(
    'bounded request queue rejects excess with visible failure callback',
    () async {
      final gate = Completer<void>();
      var failures = 0;
      final coordinator = IncomingShareCoordinator(
        handle: (_) async => gate.future,
        acknowledge: (_) async {},
        onFailure: () => failures++,
      );
      for (var i = 0; i < 102; i++) {
        coordinator.add({'id': 'request-$i'});
      }
      expect(failures, 1);
      coordinator.dispose();
      gate.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );
}

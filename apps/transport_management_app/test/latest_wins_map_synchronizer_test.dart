import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/features/live_operations/presentation/latest_wins_map_synchronizer.dart';

void main() {
  test(
    'serializes updates and collapses pending work to the latest state',
    () async {
      final first = Completer<void>();
      final applied = <String>[];
      final synchronizer = LatestWinsMapSynchronizer();

      synchronizer.schedule(() async {
        applied.add('first-start');
        await first.future;
        applied.add('first-end');
      });
      synchronizer.schedule(() async => applied.add('obsolete'));
      synchronizer.schedule(() async => applied.add('latest'));

      expect(synchronizer.isRunning, isTrue);
      expect(applied, ['first-start']);
      first.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(applied, ['first-start', 'first-end', 'latest']);
      expect(synchronizer.isRunning, isFalse);
    },
  );

  test(
    'a transient failure reports warning and later update recovers',
    () async {
      final failures = <Object>[];
      var recovered = 0;
      final synchronizer = LatestWinsMapSynchronizer(
        onFailure: failures.add,
        onRecovered: () => recovered++,
      );

      synchronizer.schedule(() async => throw StateError('annotation failed'));
      await Future<void>.delayed(Duration.zero);
      synchronizer.schedule(() async {});
      await Future<void>.delayed(Duration.zero);

      expect(failures, hasLength(1));
      expect(recovered, 1);
      expect(synchronizer.isRunning, isFalse);
    },
  );
}

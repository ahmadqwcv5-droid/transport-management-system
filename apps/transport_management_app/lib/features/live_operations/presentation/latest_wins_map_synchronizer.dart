import 'dart:async';

typedef MapSynchronization = Future<void> Function();

final class LatestWinsMapSynchronizer {
  LatestWinsMapSynchronizer({this.onFailure, this.onRecovered});

  final void Function(Object error)? onFailure;
  final void Function()? onRecovered;
  MapSynchronization? _pending;
  bool _running = false;

  bool get isRunning => _running;

  void schedule(MapSynchronization synchronization) {
    _pending = synchronization;
    if (!_running) unawaited(_drain());
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (_pending != null) {
        final synchronization = _pending!;
        _pending = null;
        try {
          await synchronization();
          onRecovered?.call();
        } on Object catch (error) {
          onFailure?.call(error);
        }
      }
    } finally {
      _running = false;
    }
  }
}

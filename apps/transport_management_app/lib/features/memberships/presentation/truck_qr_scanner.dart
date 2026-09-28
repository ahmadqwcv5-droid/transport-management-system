import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class TruckQrScanner {
  bool get isSupported;
  Future<String?> scan();
}

final class UnavailableTruckQrScanner implements TruckQrScanner {
  const UnavailableTruckQrScanner();
  @override
  bool get isSupported => false;
  @override
  Future<String?> scan() async => null;
}

final truckQrScannerProvider = Provider<TruckQrScanner>(
  (_) => const UnavailableTruckQrScanner(),
);

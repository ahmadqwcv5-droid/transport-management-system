import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

final qrPngEncoderProvider = Provider<QrPngEncoder>(
  (ref) => const FlutterQrPngEncoder(),
);

abstract interface class QrPngEncoder {
  Future<Uint8List> encode(String payload);
}

final class FlutterQrPngEncoder implements QrPngEncoder {
  const FlutterQrPngEncoder();

  @override
  Future<Uint8List> encode(String payload) async {
    if (payload.trim().isEmpty) {
      throw const FormatException('QR payload is empty.');
    }
    final painter = QrPainter(
      data: payload,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      gapless: true,
    );
    final data = await painter.toImageData(
      1024,
      format: ui.ImageByteFormat.png,
    );
    if (data == null || data.lengthInBytes == 0) {
      throw StateError('QR PNG encoding returned no bytes.');
    }
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (bytes.length < 8 ||
        bytes[0] != 0x89 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x4e ||
        bytes[3] != 0x47) {
      throw StateError('QR encoder returned invalid PNG bytes.');
    }
    return Uint8List.fromList(bytes);
  }
}

import 'dart:typed_data';
import 'dart:ui' as ui;

final class CircularMarkerImageProcessor {
  const CircularMarkerImageProcessor({this.size = 96});

  final int size;

  Future<Uint8List> process(Uint8List source) async {
    if (source.isEmpty || size < 16) {
      throw const FormatException('Invalid marker image input.');
    }
    final codec = await ui.instantiateImageCodec(source);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final inset = size * 0.055;
        final circle = ui.Rect.fromLTWH(
          inset,
          inset,
          size - inset * 2,
          size - inset * 2,
        );
        final radius = circle.width / 2;
        canvas.save();
        canvas.clipPath(ui.Path()..addOval(circle));
        final scale =
            circle.width /
            (image.width < image.height ? image.width : image.height);
        final sourceWidth = circle.width / scale;
        final sourceHeight = circle.height / scale;
        final sourceRect = ui.Rect.fromLTWH(
          (image.width - sourceWidth) / 2,
          (image.height - sourceHeight) / 2,
          sourceWidth,
          sourceHeight,
        );
        canvas.drawImageRect(
          image,
          sourceRect,
          circle,
          ui.Paint()..filterQuality = ui.FilterQuality.high,
        );
        canvas.restore();
        canvas.drawCircle(
          circle.center,
          radius - size * 0.018,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = size * 0.055
            ..color = const ui.Color(0xFFF8FAFC),
        );
        canvas.drawCircle(
          circle.center,
          radius - size * 0.048,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = size * 0.018
            ..color = const ui.Color(0xFF334155),
        );
        final rendered = await recorder.endRecording().toImage(size, size);
        try {
          final data = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data == null) {
            throw const FormatException('Could not encode marker.');
          }
          return data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } finally {
          rendered.dispose();
        }
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}

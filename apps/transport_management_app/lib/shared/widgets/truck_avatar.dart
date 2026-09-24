import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';

final truckThumbnailProvider = FutureProvider.autoDispose
    .family<Uint8List, ({String url, String version})>((ref, key) async {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get<List<int>>(
            key.url,
            options: Options(responseType: ResponseType.bytes),
          );
      return Uint8List.fromList(response.data!);
    });

class TruckAvatar extends ConsumerWidget {
  const TruckAvatar({
    required this.photoUrl,
    required this.photoVersion,
    this.radius = 22,
    super.key,
  });

  final String? photoUrl, photoVersion;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = photoUrl;
    final version = photoVersion;
    if (url == null || version == null) return _fallback();
    return ref
        .watch(truckThumbnailProvider((url: url, version: version)))
        .when(
          loading: () => CircleAvatar(
            radius: radius,
            child: const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => _fallback(),
          data: (bytes) =>
              CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes)),
        );
  }

  Widget _fallback() => CircleAvatar(
    radius: radius,
    child: const Icon(Icons.local_shipping_outlined),
  );
}

import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const supportedPublicLocales = <String>{'en', 'ar'};

final anonymousLocaleStoreProvider = Provider<AnonymousLocaleStore>(
  (ref) => AnonymousLocaleStore(),
);

final anonymousLocaleControllerProvider =
    AsyncNotifierProvider<AnonymousLocaleController, String>(
      AnonymousLocaleController.new,
    );

String resolveAnonymousLocale(String? saved, Iterable<Locale> platformLocales) {
  if (saved != null && supportedPublicLocales.contains(saved)) return saved;
  for (final locale in platformLocales) {
    if (supportedPublicLocales.contains(locale.languageCode)) {
      return locale.languageCode;
    }
  }
  return 'en';
}

final class AnonymousLocaleStore {
  AnonymousLocaleStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'tms_public_locale';
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String locale) => _storage.write(key: _key, value: locale);
}

class AnonymousLocaleController extends AsyncNotifier<String> {
  @override
  Future<String> build() async => resolveAnonymousLocale(
    await ref.read(anonymousLocaleStoreProvider).read(),
    PlatformDispatcher.instance.locales,
  );

  Future<void> select(String locale) async {
    if (!supportedPublicLocales.contains(locale)) return;
    state = AsyncData(locale);
    await ref.read(anonymousLocaleStoreProvider).write(locale);
  }
}

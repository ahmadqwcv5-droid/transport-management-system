import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/anonymous_locale_controller.dart';

class PublicLanguageControl extends ConsumerWidget {
  const PublicLanguageControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(anonymousLocaleControllerProvider).value ??
        Localizations.localeOf(context).languageCode;
    return Semantics(
      label: 'Language / اللغة',
      child: SegmentedButton<String>(
        key: const Key('public-language-control'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'en', label: Text('English')),
          ButtonSegment(value: 'ar', label: Text('العربية')),
        ],
        selected: {selected == 'ar' ? 'ar' : 'en'},
        onSelectionChanged: (values) => ref
            .read(anonymousLocaleControllerProvider.notifier)
            .select(values.single),
      ),
    );
  }
}

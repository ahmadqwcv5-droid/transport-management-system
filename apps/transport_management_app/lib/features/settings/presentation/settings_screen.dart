import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../auth/presentation/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale =
        ref.watch(authControllerProvider).value?.user.preferredLocale ?? 'en';
    return ListView(
      padding: const EdgeInsetsDirectional.all(24),
      children: [
        Text(
          context.l10n.settings,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(20),
            child: DropdownButtonFormField<String>(
              key: const Key('language-selector'),
              initialValue: locale,
              decoration: InputDecoration(labelText: context.l10n.language),
              items: [
                DropdownMenuItem(
                  value: 'en',
                  child: Text(context.l10n.english),
                ),
                DropdownMenuItem(value: 'ar', child: Text(context.l10n.arabic)),
              ],
              onChanged: (value) async {
                if (value == null) return;
                final ok = await ref
                    .read(authControllerProvider.notifier)
                    .updateLocale(value);
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.localeSaved)),
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

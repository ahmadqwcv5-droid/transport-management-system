import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../live_operations/presentation/live_operations_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value?.user;
    final locale = user?.preferredLocale ?? 'en';
    final nonProduction = user != null && user.environmentName != 'Production';
    return ListView(
      padding: const EdgeInsetsDirectional.all(24),
      children: [
        Text(
          context.l10n.settings,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        if (nonProduction) ...[
          MaterialBanner(
            key: const Key('non-production-indicator'),
            content: Text(
              context.l10n.nonProductionEnvironment(user.environmentName),
            ),
            leading: const Icon(Icons.science_outlined),
            actions: const [SizedBox.shrink()],
          ),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.accountIdentity,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _IdentityRow(context.l10n.signedInEmail, user?.email ?? '—'),
                _IdentityRow(
                  context.l10n.companyName,
                  user?.companyName ?? '—',
                ),
                _IdentityRow(context.l10n.role, user?.role ?? '—'),
                if (nonProduction)
                  _IdentityRow(context.l10n.environment, user.environmentName),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            key: const Key('change-password'),
            leading: const Icon(Icons.password),
            title: Text(context.l10n.changePassword),
            subtitle: Text(context.l10n.passwordMinimumLength),
            onTap: user == null ? null : () => _changePassword(context, ref),
          ),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(12),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  key: const Key('notification-sounds-setting'),
                  value: user?.notificationSoundsEnabled ?? true,
                  title: Text(context.l10n.notificationSounds),
                  subtitle: Text(context.l10n.notificationSoundsDescription),
                  secondary: Icon(
                    user?.notificationSoundsEnabled == false
                        ? Icons.volume_off_outlined
                        : Icons.volume_up_outlined,
                  ),
                  onChanged: user == null
                      ? null
                      : (enabled) => ref
                            .read(authControllerProvider.notifier)
                            .updateNotificationSounds(enabled),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    key: const Key('test-notification-sound'),
                    onPressed: user?.notificationSoundsEnabled == true
                        ? () async {
                            final result = await ref
                                .read(
                                  operationalAlertControllerProvider.notifier,
                                )
                                .testSound();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result.name == 'played'
                                        ? context.l10n.soundTestPlayed
                                        : context.l10n.enableNotificationSound,
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(context.l10n.testSound),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirmation = TextEditingController();
    String? validationError;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.changePassword),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.l10n.currentPassword,
                ),
              ),
              TextField(
                controller: next,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.l10n.newPassword,
                  helperText: context.l10n.passwordMinimumLength,
                ),
              ),
              TextField(
                controller: confirmation,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.l10n.confirmNewPassword,
                ),
              ),
              if (validationError != null)
                Text(
                  validationError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (next.text.length < 12 || next.text != confirmation.text) {
                  setDialogState(
                    () => validationError = context.l10n.passwordMinimumLength,
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      ),
    );
    if (submitted == true) {
      final ok = await ref
          .read(authControllerProvider.notifier)
          .changePassword(current.text, next.text, confirmation.text);
      if (context.mounted && ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.passwordChangedLoginAgain)),
        );
      }
    }
    current.dispose();
    next.dispose();
    confirmation.dispose();
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(width: 150, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

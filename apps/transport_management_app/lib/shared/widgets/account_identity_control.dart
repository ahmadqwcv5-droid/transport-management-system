import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_session.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../l10n/l10n_extensions.dart';

class AccountIdentityControl extends ConsumerWidget {
  const AccountIdentityControl({
    required this.user,
    required this.wide,
    super.key,
  });

  final CurrentUser user;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    key: const Key('account-identity-control'),
    tooltip: context.l10n.accountIdentity,
    onSelected: (value) {
      if (value == 'settings') context.go('/settings');
      if (value == 'logout') {
        ref.read(authControllerProvider.notifier).logout();
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(
        enabled: false,
        child: SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.operationalDisplayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('${_role(context, user.role)} · ${user.companyName}'),
              Text(user.email, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'settings',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.settings_outlined),
          title: Text(context.l10n.settings),
        ),
      ),
      PopupMenuItem(
        value: 'logout',
        child: ListTile(
          key: const Key('logout-button'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: Text(context.l10n.signOut),
        ),
      ),
    ],
    child: Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 17,
            child: Text(_initials(user.operationalDisplayName)),
          ),
          if (wide) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.operationalDisplayName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    '${_role(context, user.role)} · ${user.companyName}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    ),
  );

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
    return parts.take(2).map((x) => x.characters.first.toUpperCase()).join();
  }

  static String _role(BuildContext context, String role) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return switch (role) {
      'Owner' => arabic ? 'المالك' : 'Owner',
      'Operations' => arabic ? 'العمليات' : 'Operations',
      'Driver' => arabic ? 'السائق' : 'Driver',
      _ => role,
    };
  }
}

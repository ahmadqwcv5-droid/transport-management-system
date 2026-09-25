import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../operations/presentation/operations_controller.dart';
import '../domain/company_user.dart';
import 'company_users_controller.dart';

class CompanyUsersScreen extends ConsumerStatefulWidget {
  const CompanyUsersScreen({super.key});

  @override
  ConsumerState<CompanyUsersScreen> createState() => _CompanyUsersScreenState();
}

class _CompanyUsersScreenState extends ConsumerState<CompanyUsersScreen> {
  bool? _active;

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(companyUsersControllerProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.l10n.companyUsers,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              DropdownButton<bool?>(
                key: const Key('company-user-active-filter'),
                value: _active,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(context.l10n.allUsers),
                  ),
                  DropdownMenuItem(
                    value: true,
                    child: Text(context.l10n.activeUsers),
                  ),
                  DropdownMenuItem(
                    value: false,
                    child: Text(context.l10n.inactiveUsers),
                  ),
                ],
                onChanged: (value) => setState(() => _active = value),
              ),
              FilledButton.icon(
                key: const Key('create-driver-user'),
                onPressed: _create,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(context.l10n.createDriverAccount),
              ),
            ],
          ),
        ),
        Expanded(
          child: users.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text(context.l10n.genericError)),
            data: (items) {
              final visible = items
                  .where((item) => _active == null || item.isActive == _active)
                  .toList();
              if (visible.isEmpty) {
                return Center(child: Text(context.l10n.noCompanyUsers));
              }
              return RefreshIndicator(
                onRefresh: ref
                    .read(companyUsersControllerProvider.notifier)
                    .refresh,
                child: ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, index) => _UserTile(visible[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final result = await showDialog<_CreateUserInput>(
      context: context,
      builder: (_) => const _CreateUserDialog(),
    );
    if (result == null || !mounted) return;
    final credential = await ref
        .read(companyUsersControllerProvider.notifier)
        .create(
          email: result.email,
          displayName: result.displayName,
          driverId: result.driverId,
        );
    if (!mounted) return;
    if (credential == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
      return;
    }
    await showTemporaryCredential(context, credential);
    ref.read(operationsControllerProvider.notifier).reload();
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile(this.user);
  final CompanyUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    margin: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
    child: ListTile(
      key: Key('company-user-${user.id}'),
      leading: CircleAvatar(
        child: Icon(user.role == 'Driver' ? Icons.badge : Icons.person),
      ),
      title: Text(user.displayName),
      subtitle: Text(
        '${user.email}\n${user.driverName ?? context.l10n.noDriverLinked}',
      ),
      isThreeLine: true,
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(
            label: Text(
              user.isActive ? context.l10n.active : context.l10n.inactive,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              final controller = ref.read(
                companyUsersControllerProvider.notifier,
              );
              if (action == 'reset') {
                final credential = await controller.reset(user.id);
                if (context.mounted && credential != null) {
                  await showTemporaryCredential(context, credential);
                }
              } else if (action == 'active') {
                await controller.setActive(user.id, !user.isActive);
              } else if (action == 'unlink') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(context.l10n.unlinkDriverAccount),
                    content: Text(context.l10n.unlinkDriverAccountConfirmation),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(context.l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text(context.l10n.confirm),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                await controller.unlink(user.id);
                ref.read(operationsControllerProvider.notifier).reload();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'reset',
                child: Text(context.l10n.resetTemporaryPassword),
              ),
              PopupMenuItem(
                value: 'active',
                child: Text(
                  user.isActive
                      ? context.l10n.deactivate
                      : context.l10n.reactivate,
                ),
              ),
              if (user.driverId != null)
                PopupMenuItem(
                  value: 'unlink',
                  child: Text(context.l10n.unlinkDriverAccount),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

final class _CreateUserInput {
  const _CreateUserInput(this.email, this.displayName, this.driverId);
  final String email, displayName;
  final String? driverId;
}

class _CreateUserDialog extends ConsumerStatefulWidget {
  const _CreateUserDialog();
  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  String? _driverId;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drivers =
        ref.watch(operationsControllerProvider).value?.drivers ?? [];
    final unlinked = drivers.where((driver) => driver.userId == null).toList();
    return AlertDialog(
      title: Text(context.l10n.createDriverAccount),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('driver-user-name'),
                controller: _name,
                decoration: InputDecoration(
                  labelText: context.l10n.displayName,
                ),
                validator: (value) => value == null || value.trim().length < 2
                    ? context.l10n.required
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('driver-user-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: context.l10n.email),
                validator: (value) => value == null || !value.contains('@')
                    ? context.l10n.required
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('driver-user-link'),
                initialValue: _driverId,
                decoration: InputDecoration(labelText: context.l10n.linkDriver),
                items: unlinked
                    .map(
                      (driver) => DropdownMenuItem(
                        value: driver.id,
                        child: Text(driver.fullName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _driverId = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('save-driver-user'),
          onPressed: () {
            if (_key.currentState!.validate()) {
              Navigator.pop(
                context,
                _CreateUserInput(
                  _email.text.trim(),
                  _name.text.trim(),
                  _driverId,
                ),
              );
            }
          },
          child: Text(context.l10n.create),
        ),
      ],
    );
  }
}

Future<void> showTemporaryCredential(
  BuildContext context,
  TemporaryCredential credential,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => AlertDialog(
    title: Text(context.l10n.temporaryPassword),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.temporaryPasswordOnce),
        const SizedBox(height: 12),
        SelectableText(
          credential.password,
          key: const Key('temporary-password-value'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
    actions: [
      TextButton.icon(
        onPressed: () =>
            Clipboard.setData(ClipboardData(text: credential.password)),
        icon: const Icon(Icons.copy),
        label: Text(context.l10n.copy),
      ),
      FilledButton(
        key: const Key('temporary-password-done'),
        onPressed: () => Navigator.pop(dialogContext),
        child: Text(context.l10n.done),
      ),
    ],
  ),
);

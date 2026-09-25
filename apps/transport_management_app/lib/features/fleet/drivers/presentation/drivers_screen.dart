import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/fleet_models.dart';
import '../../../operations/presentation/operations_controller.dart';
import '../../../operations/presentation/operations_view.dart';
import '../../../../l10n/l10n_extensions.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../company_users/presentation/company_users_controller.dart';
import '../../../company_users/presentation/company_users_screen.dart';
import '../../../company_users/domain/company_user.dart';

class DriversScreen extends ConsumerWidget {
  const DriversScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => OperationsView(
    builder: (context, ref, data) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                context.l10n.drivers,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (canManageOperations(ref))
                FilledButton.icon(
                  key: const Key('add-driver'),
                  onPressed: () => _edit(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.newDriver),
                ),
            ],
          ),
        ),
        Expanded(
          child: data.drivers.isEmpty
              ? EmptyState(context.l10n.noDrivers)
              : RefreshIndicator(
                  onRefresh: ref
                      .read(operationsControllerProvider.notifier)
                      .reload,
                  child: ListView.builder(
                    itemCount: data.drivers.length,
                    itemBuilder: (_, i) => _DriverTile(data.drivers[i]),
                  ),
                ),
        ),
      ],
    ),
  );
  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    Driver? driver,
  ]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DriverForm(driver: driver),
    );
    if (data == null || !context.mounted) return;
    final ok = await ref
        .read(operationsControllerProvider.notifier)
        .mutate((repo) => repo.saveDriver(data, driver?.id));
    if (context.mounted) showResult(context, ok);
  }
}

class _DriverTile extends ConsumerWidget {
  const _DriverTile(this.driver);
  final Driver driver;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner =
        ref.watch(authControllerProvider).value?.user.role == 'Owner';
    final users = isOwner
        ? ref.watch(companyUsersControllerProvider).value ?? const []
        : const [];
    final account = users
        .where((user) => user.driverId == driver.id)
        .firstOrNull;
    return Card(
      child: ListTile(
        onTap: () => _showDriverDetails(context, ref, account),
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(driver.fullName),
        subtitle: Text(
          '${driver.licenseNumber} • ${localizedStatus(context.l10n, driver.status)}'
          '${driver.isActive ? '' : ' • ${context.l10n.inactive}'}\n'
          '${account == null
              ? context.l10n.noAppAccount
              : account.isActive
              ? context.l10n.appAccountLinked
              : context.l10n.accountInactive}',
        ),
        isThreeLine: true,
        trailing: !canManageOperations(ref)
            ? null
            : PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    return DriversScreen._edit(context, ref, driver);
                  }
                  final ok = await ref
                      .read(operationsControllerProvider.notifier)
                      .mutate(
                        (repo) => value == 'deactivate'
                            ? repo.deactivate('drivers', driver.id)
                            : repo.setFleetStatus('drivers', driver.id, value),
                      );
                  if (context.mounted) showResult(context, ok);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
                  if (driver.status != 'Available')
                    PopupMenuItem(
                      value: 'Available',
                      child: Text(context.l10n.setAvailable),
                    ),
                  if (driver.status != 'Unavailable')
                    PopupMenuItem(
                      value: 'Unavailable',
                      child: Text(context.l10n.setUnavailable),
                    ),
                  if (driver.isActive)
                    PopupMenuItem(
                      value: 'deactivate',
                      child: Text(context.l10n.deactivate),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _showDriverDetails(
    BuildContext context,
    WidgetRef ref,
    CompanyUser? account,
  ) async {
    final isOwner =
        ref.read(authControllerProvider).value?.user.role == 'Owner';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(driver.fullName),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${context.l10n.phone}: ${driver.phone ?? '—'}\n'
                '${context.l10n.license}: ${driver.licenseNumber}\n'
                '${context.l10n.licenseExpiry}: ${driver.licenseExpiryDate ?? '—'}\n'
                '${context.l10n.status}: ${localizedStatus(context.l10n, driver.status)}\n'
                '${context.l10n.active}: ${driver.isActive ? context.l10n.yes : context.l10n.no}\n'
                '${context.l10n.notes}: ${driver.notes ?? '—'}',
              ),
              const Divider(height: 28),
              Text(
                context.l10n.driverAppAccount,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                account == null
                    ? context.l10n.noAppAccount
                    : '${account.email} • ${account.isActive ? context.l10n.active : context.l10n.inactive}',
              ),
              if (isOwner) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (account == null)
                      FilledButton.icon(
                        key: const Key('create-and-link-driver-user'),
                        onPressed: () async {
                          final navigator = Navigator.of(dialogContext);
                          final values = await _accountInput(dialogContext);
                          if (values == null) return;
                          final credential = await ref
                              .read(companyUsersControllerProvider.notifier)
                              .create(
                                email: values.$1,
                                displayName: values.$2,
                                driverId: driver.id,
                              );
                          if (credential != null && navigator.mounted) {
                            if (navigator.canPop()) navigator.pop();
                            await showTemporaryCredential(
                              navigator.context,
                              credential,
                            );
                            ref
                                .read(operationsControllerProvider.notifier)
                                .reload();
                          }
                        },
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(context.l10n.createAndLinkAccount),
                      ),
                    if (account == null)
                      OutlinedButton.icon(
                        key: const Key('link-existing-driver-user'),
                        onPressed: () async {
                          final users =
                              ref.read(companyUsersControllerProvider).value ??
                              const <CompanyUser>[];
                          final available = users
                              .where(
                                (user) =>
                                    user.role == 'Driver' &&
                                    user.isActive &&
                                    user.driverId == null,
                              )
                              .toList();
                          final userId = await showDialog<String>(
                            context: dialogContext,
                            builder: (selectContext) => SimpleDialog(
                              title: Text(context.l10n.linkExistingAccount),
                              children: available.isEmpty
                                  ? [
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Text(
                                          context.l10n.noUnlinkedDriverAccounts,
                                        ),
                                      ),
                                    ]
                                  : available
                                        .map(
                                          (user) => SimpleDialogOption(
                                            onPressed: () => Navigator.pop(
                                              selectContext,
                                              user.id,
                                            ),
                                            child: Text(
                                              '${user.displayName}\n${user.email}',
                                            ),
                                          ),
                                        )
                                        .toList(),
                            ),
                          );
                          if (userId == null) return;
                          await ref
                              .read(companyUsersControllerProvider.notifier)
                              .link(userId, driver.id);
                          ref
                              .read(operationsControllerProvider.notifier)
                              .reload();
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                        icon: const Icon(Icons.link),
                        label: Text(context.l10n.linkExistingAccount),
                      ),
                    if (account != null)
                      OutlinedButton.icon(
                        key: const Key('unlink-driver-user'),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: dialogContext,
                            builder: (confirmContext) => AlertDialog(
                              title: Text(context.l10n.unlinkDriverAccount),
                              content: Text(
                                context.l10n.unlinkDriverAccountConfirmation,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, false),
                                  child: Text(context.l10n.cancel),
                                ),
                                FilledButton(
                                  key: const Key('confirm-unlink-driver-user'),
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, true),
                                  child: Text(context.l10n.confirm),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          await ref
                              .read(companyUsersControllerProvider.notifier)
                              .unlink(account.id);
                          ref
                              .read(operationsControllerProvider.notifier)
                              .reload();
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                        icon: const Icon(Icons.link_off),
                        label: Text(context.l10n.unlinkDriverAccount),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  }

  Future<(String, String)?> _accountInput(BuildContext context) async {
    final email = TextEditingController();
    final name = TextEditingController(text: driver.fullName);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (inputContext) => AlertDialog(
        title: Text(context.l10n.createAndLinkAccount),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: context.l10n.displayName),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('driver-account-email'),
              controller: email,
              decoration: InputDecoration(labelText: context.l10n.email),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(inputContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('save-linked-driver-user'),
            onPressed: () => Navigator.pop(inputContext, (
              email.text.trim(),
              name.text.trim(),
            )),
            child: Text(context.l10n.create),
          ),
        ],
      ),
    );
    email.dispose();
    name.dispose();
    return result;
  }
}

class _DriverForm extends StatefulWidget {
  const _DriverForm({this.driver});
  final Driver? driver;
  @override
  State<_DriverForm> createState() => _DriverFormState();
}

class _DriverFormState extends State<_DriverForm> {
  final key = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.driver?.fullName);
  late final phone = TextEditingController(text: widget.driver?.phone);
  late final license = TextEditingController(
    text: widget.driver?.licenseNumber,
  );
  late final expiry = TextEditingController(
    text: widget.driver?.licenseExpiryDate,
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.driver == null
          ? context.l10n.createDriver
          : context.l10n.editDriver,
    ),
    content: SizedBox(
      width: 440,
      child: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('driver-name'),
              controller: name,
              decoration: InputDecoration(labelText: context.l10n.fullName),
              validator: (value) => requiredText(context, value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phone,
              decoration: InputDecoration(labelText: context.l10n.phone),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('driver-license'),
              controller: license,
              decoration: InputDecoration(
                labelText: context.l10n.licenseNumber,
              ),
              validator: (value) => requiredText(context, value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: expiry,
              decoration: InputDecoration(
                labelText: context.l10n.licenseExpiry,
              ),
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
        key: const Key('save-driver'),
        onPressed: () {
          if (key.currentState!.validate()) {
            Navigator.pop(context, {
              'fullName': name.text.trim(),
              'phone': blankToNull(phone.text),
              'licenseNumber': license.text.trim(),
              'licenseExpiryDate': expiry.text.trim().isEmpty
                  ? null
                  : expiry.text.trim(),
              'notes': widget.driver?.notes,
            });
          }
        },
        child: Text(context.l10n.save),
      ),
    ],
  );
}

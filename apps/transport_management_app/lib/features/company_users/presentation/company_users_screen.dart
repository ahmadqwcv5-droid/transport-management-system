import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../memberships/domain/membership_models.dart';
import '../../memberships/presentation/membership_providers.dart';
import '../../operations/presentation/operations_controller.dart';
import '../domain/company_user.dart';
import 'company_users_controller.dart';

class CompanyUsersScreen extends ConsumerWidget {
  const CompanyUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 4,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.companyUsers,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              FilledButton.icon(
                key: const Key('create-driver-user'),
                onPressed: () => _invite(context, ref),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(context.l10n.invitePerson),
              ),
            ],
          ),
        ),
        TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: context.l10n.companyUsers),
            Tab(text: context.l10n.invitations),
            Tab(text: context.l10n.connectionRequests),
            Tab(text: context.l10n.handoverRequests),
          ],
        ),
        const Expanded(
          child: TabBarView(
            children: [
              _MembersTab(),
              _InvitationsTab(),
              _ConnectionsTab(),
              _HandoversTab(),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<_InvitationInput>(
      context: context,
      builder: (_) => const _InvitationDialog(),
    );
    if (input == null) return;
    Invitation? invitation;
    try {
      invitation = await ref
          .read(membershipRepositoryProvider)
          .createInvitation(
            email: input.email,
            displayName: input.displayName,
            roles: input.roles,
            driverId: input.driverId,
          );
      await ref.read(companyUsersControllerProvider.notifier).refresh();
    } on Object {
      invitation = null;
    }
    ref.invalidate(invitationsProvider);
    if (context.mounted && invitation != null) {
      await _showInvitationLink(context, invitation);
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
    }
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(companyUsersControllerProvider);
    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(context.l10n.genericError)),
      data: (items) => RefreshIndicator(
        onRefresh: ref.read(companyUsersControllerProvider.notifier).refresh,
        child: items.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(child: Text(context.l10n.noCompanyUsers)),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (_, index) => _MemberTile(items[index]),
              ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile(this.user);
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
        '${user.email}\n${user.roles.join(', ')} · '
        '${user.driverName ?? context.l10n.noDriverLinked}',
      ),
      isThreeLine: true,
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(
            label: Text(localizedStatus(context.l10n, user.membershipStatus)),
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              final controller = ref.read(
                companyUsersControllerProvider.notifier,
              );
              if (action == 'status' && user.membershipId != null) {
                final status = user.membershipStatus == 'Active'
                    ? 'Suspended'
                    : 'Active';
                await ref
                    .read(membershipRepositoryProvider)
                    .setMembershipStatus(user.membershipId!, status);
                await controller.refresh();
              } else if (action == 'revoke' && user.membershipId != null) {
                final confirmed = await _confirm(
                  context,
                  context.l10n.revoke,
                  context.l10n.confirm,
                );
                if (confirmed) {
                  await ref
                      .read(membershipRepositoryProvider)
                      .setMembershipStatus(user.membershipId!, 'Revoked');
                  await controller.refresh();
                }
              } else if (action == 'unlink') {
                final confirmed = await _confirm(
                  context,
                  context.l10n.unlinkDriverAccount,
                  context.l10n.unlinkDriverAccountConfirmation,
                );
                if (confirmed) {
                  await controller.unlink(user.id);
                  ref.read(operationsControllerProvider.notifier).reload();
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'status',
                child: Text(
                  user.membershipStatus == 'Active'
                      ? context.l10n.suspend
                      : context.l10n.reactivate,
                ),
              ),
              if (user.membershipStatus != 'Revoked')
                PopupMenuItem(
                  value: 'revoke',
                  child: Text(context.l10n.revoke),
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

class _InvitationsTab extends ConsumerWidget {
  const _InvitationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
    onRefresh: () async {
      ref.invalidate(invitationsProvider);
      ref.invalidate(companyCodeProvider);
    },
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CompanyCodeCard(),
        const SizedBox(height: 12),
        Text(
          context.l10n.invitations,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        ref
            .watch(invitationsProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(context.l10n.genericError),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(context.l10n.noData),
                    )
                  : Column(
                      children: items
                          .map(
                            (item) => Card(
                              child: ListTile(
                                key: Key('invitation-${item.id}'),
                                leading: const Icon(Icons.mail_outline),
                                title: Text(item.email),
                                subtitle: Text(
                                  '${item.roles.join(', ')} · '
                                  '${localizedStatus(context.l10n, item.status)}\n'
                                  '${context.l10n.expiresAt}: '
                                  '${MaterialLocalizations.of(context).formatMediumDate(item.expiresAt.toLocal())}',
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    if (action == 'copy' &&
                                        item.acceptancePath != null) {
                                      await Clipboard.setData(
                                        ClipboardData(
                                          text: item.acceptancePath!,
                                        ),
                                      );
                                    } else if (action == 'revoke') {
                                      await ref
                                          .read(membershipRepositoryProvider)
                                          .revokeInvitation(item.id);
                                      ref.invalidate(invitationsProvider);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    if (item.acceptancePath != null)
                                      PopupMenuItem(
                                        value: 'copy',
                                        child: Text(
                                          context.l10n.copyInvitationLink,
                                        ),
                                      ),
                                    if (item.status == 'Pending')
                                      PopupMenuItem(
                                        value: 'revoke',
                                        child: Text(context.l10n.revoke),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
      ],
    ),
  );
}

class _CompanyCodeCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.companyConnectionCode,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(context.l10n.exactCodePrivacy),
          const SizedBox(height: 8),
          ref
              .watch(companyCodeProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text(context.l10n.genericError),
                data: (code) => Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        code.code,
                        key: const Key('company-connection-code'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.copy,
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: code.code)),
                      icon: const Icon(Icons.copy),
                    ),
                    TextButton.icon(
                      key: const Key('rotate-company-code'),
                      onPressed: () async {
                        final confirmed = await _confirm(
                          context,
                          context.l10n.rotateCode,
                          context.l10n.exactCodePrivacy,
                        );
                        if (!confirmed) return;
                        await ref
                            .read(membershipRepositoryProvider)
                            .rotateCompanyCode();
                        ref.invalidate(companyCodeProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.rotateCode),
                    ),
                  ],
                ),
              ),
        ],
      ),
    ),
  );
}

class _ConnectionsTab extends ConsumerWidget {
  const _ConnectionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
    onRefresh: () async => ref.invalidate(pendingConnectionsProvider),
    child: ref
        .watch(pendingConnectionsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(
            children: [Center(child: Text(context.l10n.genericError))],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 100),
                    Center(child: Text(context.l10n.noData)),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: items
                      .map(
                        (item) => Card(
                          child: ListTile(
                            key: Key('connection-${item.id}'),
                            leading: const Icon(Icons.person_search_outlined),
                            title: Text(item.accountName),
                            subtitle: Text(
                              '${item.accountEmail}\n'
                              '${item.requestedRoles.join(', ')}',
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _resolveConnection(
                                    context,
                                    ref,
                                    item,
                                    false,
                                  ),
                                  child: Text(context.l10n.reject),
                                ),
                                FilledButton(
                                  onPressed: () => _resolveConnection(
                                    context,
                                    ref,
                                    item,
                                    true,
                                  ),
                                  child: Text(context.l10n.approve),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
  );

  Future<void> _resolveConnection(
    BuildContext context,
    WidgetRef ref,
    ConnectionRequest request,
    bool approve,
  ) async {
    String? driverId;
    final reason = TextEditingController();
    final drivers =
        ref.read(operationsControllerProvider).value?.drivers ?? const [];
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: Text(approve ? context.l10n.approve : context.l10n.reject),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (approve)
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: context.l10n.selectDriver,
                  ),
                  items: drivers
                      .where((driver) => driver.userId == null)
                      .map(
                        (driver) => DropdownMenuItem(
                          value: driver.id,
                          child: Text(driver.fullName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => driverId = value),
                ),
              TextField(
                controller: reason,
                decoration: InputDecoration(labelText: context.l10n.reason),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed:
                  approve &&
                      request.requestedRoles.contains('Driver') &&
                      driverId == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      await ref
          .read(membershipRepositoryProvider)
          .resolveConnection(
            request.id,
            approve: approve,
            driverId: driverId,
            reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
          );
      ref.invalidate(pendingConnectionsProvider);
      ref.read(companyUsersControllerProvider.notifier).refresh();
      ref.read(operationsControllerProvider.notifier).reload();
    }
    reason.dispose();
  }
}

class _HandoversTab extends ConsumerWidget {
  const _HandoversTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
    onRefresh: () async => ref.invalidate(handoversProvider),
    child: ref
        .watch(handoversProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(
            children: [Center(child: Text(context.l10n.genericError))],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 100),
                    Center(child: Text(context.l10n.noData)),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: items
                      .map(
                        (item) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.tripNumber} · ${item.plateNumber}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  '${context.l10n.currentDriver}: '
                                  '${item.currentDriverName}',
                                ),
                                Text(
                                  '${context.l10n.requestingDriver}: '
                                  '${item.requestingDriverName}',
                                ),
                                Text(
                                  '${context.l10n.status}: '
                                  '${localizedStatus(context.l10n, item.status)}',
                                ),
                                if (item.status == 'Pending')
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton(
                                        key: Key('reject-handover-${item.id}'),
                                        onPressed: () =>
                                            _resolve(context, ref, item, false),
                                        child: Text(
                                          context.l10n.rejectHandover,
                                        ),
                                      ),
                                      FilledButton(
                                        key: Key('approve-handover-${item.id}'),
                                        onPressed: () =>
                                            _resolve(context, ref, item, true),
                                        child: Text(
                                          context.l10n.approveHandover,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
  );

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    Handover handover,
    bool approve,
  ) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          approve ? context.l10n.approveHandover : context.l10n.rejectHandover,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${handover.tripNumber} · ${handover.plateNumber}'),
            Text(
              '${handover.currentDriverName} → '
              '${handover.requestingDriverName}',
            ),
            Text(context.l10n.handoverApprovalRequired),
            TextField(
              controller: reason,
              decoration: InputDecoration(labelText: context.l10n.reason),
            ),
          ],
        ),
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
    if (confirmed == true) {
      await ref
          .read(membershipRepositoryProvider)
          .resolveHandover(
            handover.id,
            approve: approve,
            reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
          );
      ref.invalidate(handoversProvider);
    }
    reason.dispose();
  }
}

final class _InvitationInput {
  const _InvitationInput(
    this.email,
    this.displayName,
    this.roles,
    this.driverId,
  );
  final String email, displayName;
  final List<String> roles;
  final String? driverId;
}

class _InvitationDialog extends ConsumerStatefulWidget {
  const _InvitationDialog();
  @override
  ConsumerState<_InvitationDialog> createState() => _InvitationDialogState();
}

class _InvitationDialogState extends ConsumerState<_InvitationDialog> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final Set<String> _roles = {'Driver'};
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
        ref.watch(operationsControllerProvider).value?.drivers ?? const [];
    return AlertDialog(
      title: Text(context.l10n.invitePerson),
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
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(context.l10n.roles),
              ),
              Wrap(
                spacing: 8,
                children: ['Owner', 'Operations', 'Accountant', 'Driver']
                    .map(
                      (role) => FilterChip(
                        key: Key('invitation-role-$role'),
                        label: Text(role),
                        selected: _roles.contains(role),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _roles.add(role);
                          } else if (_roles.length > 1) {
                            _roles.remove(role);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('driver-user-link'),
                decoration: InputDecoration(labelText: context.l10n.linkDriver),
                items: drivers
                    .where((driver) => driver.userId == null)
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
                _InvitationInput(
                  _email.text.trim(),
                  _name.text.trim(),
                  _roles.toList(),
                  _driverId,
                ),
              );
            }
          },
          child: Text(context.l10n.invitePerson),
        ),
      ],
    );
  }
}

Future<void> _showInvitationLink(BuildContext context, Invitation invitation) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.invitationLink),
        content: SelectableText(
          invitation.acceptancePath ?? '',
          key: const Key('invitation-link-value'),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Clipboard.setData(
              ClipboardData(text: invitation.acceptancePath ?? ''),
            ),
            icon: const Icon(Icons.copy),
            label: Text(context.l10n.copyInvitationLink),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.done),
          ),
        ],
      ),
    );

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
    ) ??
    false;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/membership_models.dart';
import 'membership_providers.dart';

class WorkspaceChooserScreen extends ConsumerStatefulWidget {
  const WorkspaceChooserScreen({super.key});

  @override
  ConsumerState<WorkspaceChooserScreen> createState() =>
      _WorkspaceChooserScreenState();
}

class _WorkspaceChooserScreenState
    extends ConsumerState<WorkspaceChooserScreen> {
  late Future<List<Workspace>> _workspaces;
  final _code = TextEditingController();
  CompanySummary? _summary;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _workspaces = ref.read(authControllerProvider.notifier).workspaces();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.workspaceChooser),
      actions: [
        IconButton(
          tooltip: context.l10n.signOut,
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () async {
        setState(_reload);
        await _workspaces;
        ref.invalidate(ownConnectionsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.l10n.chooseWorkspace,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Workspace>>(
            future: _workspaces,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data ?? const <Workspace>[];
              if (items.isEmpty) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.domain_disabled_outlined),
                    title: Text(context.l10n.noWorkspace),
                  ),
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => Card(
                        child: ListTile(
                          key: Key('workspace-${item.membershipId}'),
                          leading: const CircleAvatar(
                            child: Icon(Icons.business_outlined),
                          ),
                          title: Text(item.companyName),
                          subtitle: Text(
                            '${context.l10n.roles}: ${item.roles.join(', ')} · '
                            '${localizedStatus(context.l10n, item.status)}',
                          ),
                          trailing: FilledButton(
                            onPressed: _busy || item.status != 'Active'
                                ? null
                                : () => _select(item.membershipId),
                            child: Text(context.l10n.chooseWorkspace),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.joinCompany,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(context.l10n.exactCodePrivacy),
          const SizedBox(height: 12),
          TextField(
            key: const Key('company-code-input'),
            controller: _code,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: context.l10n.companyCode,
              prefixIcon: const Icon(Icons.key_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonal(
              key: const Key('resolve-company-code'),
              onPressed: _busy ? null : _resolve,
              child: Text(context.l10n.resolveCompany),
            ),
          ),
          if (_summary != null)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: Text(_summary!.companyName),
                subtitle: Text(_summary!.codeHint),
                trailing: FilledButton(
                  key: const Key('request-company-connection'),
                  onPressed: _busy ? null : _request,
                  child: Text(context.l10n.requestConnection),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            context.l10n.pendingRequests,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ref
              .watch(ownConnectionsProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text(context.l10n.genericError),
                data: (items) => items.isEmpty
                    ? Text(context.l10n.noData)
                    : Column(
                        children: items
                            .map(
                              (item) => ListTile(
                                key: Key('own-connection-${item.id}'),
                                title: Text(item.companyName),
                                subtitle: Text(
                                  localizedStatus(context.l10n, item.status),
                                ),
                                trailing: item.status == 'Pending'
                                    ? TextButton(
                                        onPressed: () => _cancel(item),
                                        child: Text(context.l10n.cancel),
                                      )
                                    : null,
                              ),
                            )
                            .toList(),
                      ),
              ),
        ],
      ),
    ),
  );

  Future<void> _select(String membershipId) async {
    setState(() => _busy = true);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .switchWorkspace(membershipId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      final user = ref.read(authControllerProvider).value?.user;
      context.go(
        user?.hasRole('Driver') == true &&
                user?.hasRole('Owner') != true &&
                user?.hasRole('Operations') != true
            ? '/my-trip'
            : '/dashboard',
      );
    }
  }

  Future<void> _resolve() async {
    setState(() {
      _busy = true;
      _error = null;
      _summary = null;
    });
    try {
      final summary = await ref
          .read(membershipRepositoryProvider)
          .resolveCompany(_code.text);
      if (mounted) setState(() => _summary = summary);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = localizedErrorCode(context.l10n, error.code));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(membershipRepositoryProvider)
          .requestConnection(_code.text);
      ref.invalidate(ownConnectionsProvider);
      if (mounted) {
        setState(() => _summary = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.requestSent)));
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = localizedErrorCode(context.l10n, error.code));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(ConnectionRequest request) async {
    await ref.read(membershipRepositoryProvider).cancelConnection(request.id);
    ref.invalidate(ownConnectionsProvider);
  }
}

class InvitationAcceptanceScreen extends ConsumerStatefulWidget {
  const InvitationAcceptanceScreen({required this.token, super.key});
  final String token;

  @override
  ConsumerState<InvitationAcceptanceScreen> createState() =>
      _InvitationAcceptanceScreenState();
}

class _InvitationAcceptanceScreenState
    extends ConsumerState<InvitationAcceptanceScreen> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  late Future<Invitation> _preview;
  bool _busy = false;
  bool _accepted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _preview = ref
        .read(membershipRepositoryProvider)
        .previewInvitation(widget.token);
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authControllerProvider).value != null;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.invitationAccept)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: FutureBuilder<Invitation>(
              future: _preview,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const CircularProgressIndicator();
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Text(context.l10n.genericError);
                }
                final invitation = snapshot.data!;
                if (_accepted) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(context.l10n.invitationAccepted),
                      trailing: FilledButton(
                        onPressed: () =>
                            context.go(signedIn ? '/workspaces' : '/login'),
                        child: Text(context.l10n.done),
                      ),
                    ),
                  );
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.l10n.invitationFor,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(invitation.email),
                        Text(
                          '${context.l10n.roles}: ${invitation.roles.join(', ')}',
                        ),
                        if (invitation.driverName != null)
                          Text(invitation.driverName!),
                        Text(
                          '${context.l10n.expiresAt}: '
                          '${MaterialLocalizations.of(context).formatMediumDate(invitation.expiresAt.toLocal())}',
                        ),
                        if (!signedIn) ...[
                          const SizedBox(height: 16),
                          Text(context.l10n.loginToAccept),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('invitation-email'),
                            controller: _email,
                            decoration: InputDecoration(
                              labelText: context.l10n.email,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('invitation-name'),
                            controller: _name,
                            decoration: InputDecoration(
                              labelText: context.l10n.displayName,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('invitation-password'),
                            controller: _password,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: context.l10n.password,
                              helperText: context.l10n.passwordMinimumLength,
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          children: [
                            if (signedIn)
                              TextButton(
                                key: const Key('decline-invitation'),
                                onPressed: _busy ? null : _decline,
                                child: Text(context.l10n.declineInvitation),
                              ),
                            FilledButton(
                              key: const Key('accept-invitation'),
                              onPressed: _busy ? null : () => _accept(signedIn),
                              child: Text(context.l10n.acceptInvitation),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accept(bool signedIn) async {
    if (!signedIn &&
        (_email.text.trim().isEmpty ||
            _name.text.trim().isEmpty ||
            _password.text.length < 12)) {
      setState(() => _error = context.l10n.required);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(membershipRepositoryProvider)
          .acceptInvitation(
            token: widget.token,
            email: signedIn ? null : _email.text,
            displayName: signedIn ? null : _name.text,
            password: signedIn ? null : _password.text,
          );
      if (mounted) setState(() => _accepted = true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = localizedErrorCode(context.l10n, error.code));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(membershipRepositoryProvider)
          .declineInvitation(widget.token);
      if (mounted) context.go('/workspaces');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

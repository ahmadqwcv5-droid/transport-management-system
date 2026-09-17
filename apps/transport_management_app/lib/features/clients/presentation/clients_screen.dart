import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../operations/domain/operations_models.dart';
import '../../operations/presentation/operations_controller.dart';
import '../../operations/presentation/operations_view.dart';
import '../../../l10n/l10n_extensions.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});
  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) => OperationsView(
    builder: (context, ref, data) {
      final items = data.clients
          .where(
            (item) => item.name.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
      return Column(
        children: [
          _Header(
            onSearch: (value) => setState(() => query = value),
            onAdd: canManageOperations(ref) ? () => _edit(context) : null,
          ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(context.l10n.noClients)
                : RefreshIndicator(
                    onRefresh: ref
                        .read(operationsControllerProvider.notifier)
                        .reload,
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, index) => _ClientTile(
                        client: items[index],
                        onEdit: canManageOperations(ref)
                            ? () => _edit(context, items[index])
                            : null,
                      ),
                    ),
                  ),
          ),
        ],
      );
    },
  );

  Future<void> _edit(BuildContext context, [Client? client]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ClientForm(client: client),
    );
    if (result == null || !context.mounted) return;
    final ok = await ref
        .read(operationsControllerProvider.notifier)
        .mutate((repo) => repo.saveClient(result, client?.id));
    if (context.mounted) showResult(context, ok);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSearch, this.onAdd});
  final ValueChanged<String> onSearch;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('clients-search'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: context.l10n.searchClients,
            ),
            onChanged: onSearch,
          ),
        ),
        if (onAdd != null) ...[
          const SizedBox(width: 12),
          FilledButton.icon(
            key: const Key('add-client'),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.newClient),
          ),
        ],
      ],
    ),
  );
}

class _ClientTile extends ConsumerWidget {
  const _ClientTile({required this.client, this.onEdit});
  final Client client;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      title: Text(client.name),
      subtitle: Text(
        [
          client.contactPerson,
          client.email,
          client.isActive ? context.l10n.active : context.l10n.inactive,
        ].whereType<String>().join(' • '),
      ),
      trailing: onEdit == null
          ? null
          : PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  onEdit!();
                } else {
                  final ok = await ref
                      .read(operationsControllerProvider.notifier)
                      .mutate((repo) => repo.deactivate('clients', client.id));
                  if (context.mounted) {
                    showResult(
                      context,
                      ok,
                      successMessage: context.l10n.clientDeactivated,
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
                if (client.isActive)
                  PopupMenuItem(
                    value: 'deactivate',
                    child: Text(context.l10n.deactivate),
                  ),
              ],
            ),
    ),
  );
}

class _ClientForm extends StatefulWidget {
  const _ClientForm({this.client});
  final Client? client;
  @override
  State<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<_ClientForm> {
  final key = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.client?.name);
  late final contact = TextEditingController(
    text: widget.client?.contactPerson,
  );
  late final phone = TextEditingController(text: widget.client?.phone);
  late final email = TextEditingController(text: widget.client?.email);
  late final address = TextEditingController(text: widget.client?.address);
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.client == null
          ? context.l10n.createClient
          : context.l10n.editClient,
    ),
    content: SizedBox(
      width: 480,
      child: Form(
        key: key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('client-name'),
                controller: name,
                decoration: InputDecoration(labelText: context.l10n.name),
                validator: (value) => requiredText(context, value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: contact,
                decoration: InputDecoration(
                  labelText: context.l10n.contactPerson,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                decoration: InputDecoration(labelText: context.l10n.phone),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: email,
                decoration: InputDecoration(labelText: context.l10n.email),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: address,
                decoration: InputDecoration(labelText: context.l10n.address),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: const Key('save-client'),
        onPressed: () {
          if (key.currentState!.validate()) {
            Navigator.pop(context, {
              'name': name.text.trim(),
              'contactPerson': blankToNull(contact.text),
              'phone': blankToNull(phone.text),
              'email': blankToNull(email.text),
              'address': blankToNull(address.text),
              'notes': widget.client?.notes,
            });
          }
        },
        child: Text(context.l10n.save),
      ),
    ],
  );
}

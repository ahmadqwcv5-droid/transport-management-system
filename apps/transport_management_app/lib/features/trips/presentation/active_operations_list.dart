import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dashboard/presentation/active_operation_card.dart';
import '../../../l10n/l10n_extensions.dart';
import 'active_operations_controller.dart';

class ActiveOperationsList extends ConsumerWidget {
  const ActiveOperationsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(activeOperationsControllerProvider);
    final controller = ref.read(activeOperationsControllerProvider.notifier);
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: FilledButton.icon(
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.activeOperationsRetry),
        ),
      ),
      data: (page) => RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          key: const Key('active-operations-list'),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 24),
          children: [
            if (controller.isStale)
              MaterialBanner(
                key: Key('active-operations-stale-warning'),
                content: Text(context.l10n.activeOperationsStale),
                actions: const [SizedBox.shrink()],
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 8),
              child: Text(context.l10n.activeOperationsCount(page.totalCount)),
            ),
            if (page.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 80),
                child: Center(child: Text(context.l10n.noActiveOperations)),
              )
            else
              ...page.items.map(
                (operation) => ActiveOperationCard(
                  operation: operation,
                  onTap: () => context.go('/trips/${operation.tripId}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

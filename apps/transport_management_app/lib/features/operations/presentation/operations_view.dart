import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../l10n/l10n_extensions.dart';
import '../domain/operations_models.dart';
import 'operations_controller.dart';

class OperationsView extends ConsumerWidget {
  const OperationsView({required this.builder, super.key});
  final Widget Function(BuildContext, WidgetRef, OperationsData) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(operationsControllerProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error is ApiException
                      ? localizedApiError(context, error)
                      : context.l10n.genericError,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(operationsControllerProvider.notifier).reload(),
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.retry),
                ),
              ],
            ),
          ),
        ),
        data: (data) => builder(context, ref, data),
      );
}

void showResult(BuildContext context, bool success, {String? successMessage}) {
  final state = ProviderScope.containerOf(
    context,
  ).read(operationsControllerProvider);
  final message = success
      ? successMessage ?? context.l10n.savedSuccessfully
      : state.error is ApiException
      ? localizedApiError(context, state.error! as ApiException)
      : context.l10n.genericError;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String? requiredText(BuildContext context, String? value) =>
    value == null || value.trim().isEmpty ? context.l10n.required : null;

String localizedApiError(BuildContext context, ApiException error) =>
    localizedErrorCode(context.l10n, error.code);

String? blankToNull(String value) => value.trim().isEmpty ? null : value.trim();

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: Text(message)),
  );
}

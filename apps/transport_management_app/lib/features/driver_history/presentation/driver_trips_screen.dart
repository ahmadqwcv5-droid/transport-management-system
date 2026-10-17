import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../design_system/app_design_tokens.dart';
import '../../../design_system/components/app_page_header.dart';
import '../../../design_system/components/app_state_panel.dart';
import '../../../design_system/components/app_status_badge.dart';
import '../../../l10n/l10n_extensions.dart';
import '../domain/driver_trip_history_models.dart';
import 'driver_trip_history_controller.dart';

class DriverTripsScreen extends ConsumerWidget {
  const DriverTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverTripHistoryControllerProvider);
    final controller = ref.read(driverTripHistoryControllerProvider.notifier);
    final categories = <String, String>{
      'current': context.l10n.historyCurrent,
      'upcoming': context.l10n.historyUpcoming,
      'completed': context.l10n.tripTabCompleted,
      'cancelled': context.l10n.tripTabCancelled,
    };
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        key: const Key('driver-trip-history'),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(context.tokens.space4),
            sliver: SliverToBoxAdapter(
              child: AppPageHeader(
                title: context.l10n.myTrips,
                subtitle: context.l10n.driverTripHistorySubtitle,
                actions: [
                  OutlinedButton.icon(
                    key: const Key('driver-history-date-filter'),
                    onPressed: () => _pickDates(context, controller),
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(context.l10n.filterByDate),
                  ),
                  if (controller.from != null || controller.to != null)
                    TextButton(
                      onPressed: () => controller.setDateRange(null, null),
                      child: Text(context.l10n.clearDateRange),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: context.tokens.space4,
              ),
              child: SegmentedButton<String>(
                key: const Key('driver-history-categories'),
                segments: categories.entries
                    .map(
                      (item) => ButtonSegment(
                        value: item.key,
                        label: Text(item.value),
                      ),
                    )
                    .toList(),
                selected: {controller.category},
                onSelectionChanged: (value) =>
                    controller.setCategory(value.single),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(context.tokens.space4),
            sliver: state.when(
              loading: () => SliverToBoxAdapter(
                child: AppStatePanel(
                  kind: AppStateKind.loading,
                  title: context.l10n.loading,
                ),
              ),
              error: (_, _) => SliverToBoxAdapter(
                child: AppStatePanel(
                  kind: AppStateKind.error,
                  title: context.l10n.genericError,
                  actionLabel: context.l10n.retry,
                  onAction: controller.refresh,
                ),
              ),
              data: (page) => page.items.isEmpty
                  ? SliverToBoxAdapter(
                      child: AppStatePanel(
                        kind: AppStateKind.empty,
                        title: context.l10n.noTripsInCategory,
                      ),
                    )
                  : SliverList.separated(
                      itemCount: page.items.length + 1,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: context.tokens.space3),
                      itemBuilder: (context, index) {
                        if (index == page.items.length) {
                          return _Pager(page: page, controller: controller);
                        }
                        return _TripCard(item: page.items[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDates(
    BuildContext context,
    DriverTripHistoryController controller,
  ) async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange: controller.from == null || controller.to == null
          ? null
          : DateTimeRange(start: controller.from!, end: controller.to!),
    );
    if (result != null) controller.setDateRange(result.start, result.end);
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.item});
  final DriverTripHistorySummary item;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = item.plannedStartAt ?? item.participationStartedAt;
    return Card(
      child: InkWell(
        key: Key('driver-history-trip-${item.id}'),
        borderRadius: BorderRadius.circular(context.tokens.radiusMedium),
        onTap: () => context.go('/my-trips/${item.id}'),
        child: Padding(
          padding: EdgeInsets.all(context.tokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.tripNumber,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  AppStatusBadge(
                    label: localizedStatus(context.l10n, item.status),
                    tone: _tone(item.status),
                    icon: Icons.route_outlined,
                  ),
                ],
              ),
              SizedBox(height: context.tokens.space3),
              Text(
                '${item.pickup ?? context.l10n.pickup} → '
                '${item.delivery ?? context.l10n.delivery}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: context.tokens.space2),
              Wrap(
                spacing: context.tokens.space4,
                runSpacing: context.tokens.space2,
                children: [
                  _Meta(
                    Icons.calendar_today_outlined,
                    DateFormat.yMMMd(locale).add_jm().format(date.toLocal()),
                  ),
                  if (item.truckPlate != null)
                    _Meta(Icons.local_shipping_outlined, item.truckPlate!),
                  if (item.clientName != null)
                    _Meta(Icons.business_outlined, item.clientName!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: context.tokens.textMuted),
      SizedBox(width: context.tokens.space1),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.controller});
  final DriverTripHistoryPage page;
  final DriverTripHistoryController controller;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        key: const Key('driver-history-previous'),
        onPressed: page.page > 1
            ? () => controller.goToPage(page.page - 1)
            : null,
        icon: const Icon(Icons.chevron_left),
        tooltip: context.l10n.previousPage,
      ),
      Text(context.l10n.pageOf(page.page, page.totalPages, page.totalCount)),
      IconButton(
        key: const Key('driver-history-next'),
        onPressed: page.page < page.totalPages
            ? () => controller.goToPage(page.page + 1)
            : null,
        icon: const Icon(Icons.chevron_right),
        tooltip: context.l10n.nextPage,
      ),
    ],
  );
}

AppStatusTone _tone(String status) => switch (status) {
  'Completed' => AppStatusTone.success,
  'Cancelled' => AppStatusTone.danger,
  'Assigned' => AppStatusTone.information,
  _ => AppStatusTone.warning,
};

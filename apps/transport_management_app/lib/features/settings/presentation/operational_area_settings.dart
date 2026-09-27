import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/maps/locale_aware_map_style.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../dashboard/domain/dashboard_models.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../operations/presentation/operations_controller.dart';
import '../../trips/domain/trip_models.dart';

class OperationalAreaSettings extends ConsumerStatefulWidget {
  const OperationalAreaSettings({super.key});

  @override
  ConsumerState<OperationalAreaSettings> createState() =>
      _OperationalAreaSettingsState();
}

class _OperationalAreaSettingsState
    extends ConsumerState<OperationalAreaSettings> {
  OperationalArea? _area;
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final value = await ref
          .read(dashboardRepositoryProvider)
          .operationalArea();
      if (mounted) setState(() => _area = value);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final value = await showDialog<OperationalArea>(
      context: context,
      builder: (_) => _OperationalAreaEditor(initial: _area),
    );
    if (value == null || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(dashboardRepositoryProvider)
          .saveOperationalArea(value);
      if (!mounted) return;
      setState(() => _area = saved);
      ref.invalidate(dashboardControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.operationalAreaSaved)),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(dashboardRepositoryProvider).clearOperationalArea();
      if (!mounted) return;
      setState(() => _area = null);
      ref.invalidate(dashboardControllerProvider);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('operational-area-settings'),
    child: Padding(
      padding: const EdgeInsetsDirectional.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.operationalArea,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(context.l10n.operationalAreaDescription),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator()
          else
            Text(
              _area == null
                  ? context.l10n.noOperationalArea
                  : '${_area!.label} · ${_area!.countryCode}',
              key: const Key('operational-area-value'),
            ),
          if (_error case final ApiException error) ...[
            const SizedBox(height: 8),
            Text(
              localizedErrorCode(context.l10n, error.code),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: const Key('configure-operational-area'),
                onPressed: _loading || _saving ? null : _edit,
                icon: const Icon(Icons.public),
                label: Text(context.l10n.configureOperationalArea),
              ),
              if (_area != null)
                TextButton.icon(
                  key: const Key('clear-operational-area'),
                  onPressed: _saving ? null : _clear,
                  icon: const Icon(Icons.clear),
                  label: Text(context.l10n.clearOperationalArea),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _OperationalAreaEditor extends ConsumerStatefulWidget {
  const _OperationalAreaEditor({this.initial});
  final OperationalArea? initial;

  @override
  ConsumerState<_OperationalAreaEditor> createState() =>
      _OperationalAreaEditorState();
}

class _OperationalAreaEditorState
    extends ConsumerState<_OperationalAreaEditor> {
  final _query = TextEditingController();
  late final _country = TextEditingController(
    text: widget.initial?.countryCode ?? '',
  );
  OperationalArea? _selected;
  List<LocationResult> _results = const [];
  bool _searching = false;
  String? _validation;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  void dispose() {
    _query.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_query.text.trim().length < 2) return;
    setState(() {
      _searching = true;
      _validation = null;
    });
    try {
      final values = await ref
          .read(operationsRepositoryProvider)
          .searchLocations(_query.text.trim());
      if (mounted) {
        setState(() {
          _results = values
              .where((value) => value.boundingBox?.length == 4)
              .toList();
        });
      }
    } on Object {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _select(LocationResult value) {
    final bounds = value.boundingBox!;
    setState(() {
      _selected = OperationalArea(
        countryCode: _country.text.trim().toUpperCase(),
        label: value.displayName,
        south: bounds[0],
        west: bounds[1],
        north: bounds[2],
        east: bounds[3],
        centerLatitude: value.latitude,
        centerLongitude: value.longitude,
      );
      _results = const [];
    });
  }

  void _submit() {
    final code = _country.text.trim().toUpperCase();
    final selected = _selected;
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code) || selected == null) {
      setState(() => _validation = context.l10n.selectAreaWithBounds);
      return;
    }
    Navigator.pop(
      context,
      OperationalArea(
        countryCode: code,
        label: selected.label,
        south: selected.south,
        west: selected.west,
        north: selected.north,
        east: selected.east,
        centerLatitude: selected.centerLatitude,
        centerLongitude: selected.centerLongitude,
        preferredZoom: selected.preferredZoom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.configureOperationalArea),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('operational-country-code'),
              controller: _country,
              textCapitalization: TextCapitalization.characters,
              maxLength: 2,
              decoration: InputDecoration(
                labelText: context.l10n.countryCode,
                helperText: context.l10n.countryCodeHint,
              ),
            ),
            TextField(
              key: const Key('operational-area-query'),
              controller: _query,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: context.l10n.searchLocation,
                suffixIcon: IconButton(
                  onPressed: _searching ? null : _search,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            if (_searching) const LinearProgressIndicator(),
            ..._results.map(
              (value) => ListTile(
                key: ValueKey('operational-area-result-${value.displayName}'),
                leading: const Icon(Icons.location_on_outlined),
                title: Text(value.displayName),
                onTap: () => _select(value),
              ),
            ),
            if (_selected != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: _OperationalAreaPreview(area: _selected!),
              ),
            ],
            if (_validation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _validation!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
        key: const Key('save-operational-area'),
        onPressed: _submit,
        child: Text(context.l10n.save),
      ),
    ],
  );
}

class _OperationalAreaPreview extends StatefulWidget {
  const _OperationalAreaPreview({required this.area});
  final OperationalArea area;

  @override
  State<_OperationalAreaPreview> createState() =>
      _OperationalAreaPreviewState();
}

class _OperationalAreaPreviewState extends State<_OperationalAreaPreview> {
  static const _styleUrl = String.fromEnvironment('MAP_STYLE_URL');
  String? _style;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_resolveStyle());
  }

  Future<void> _resolveStyle() async {
    if (_styleUrl.isEmpty) return;
    final value = await LocaleAwareMapStyle.resolve(
      _styleUrl,
      Localizations.localeOf(context).languageCode,
    );
    if (mounted) setState(() => _style = value);
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    if (_styleUrl.isEmpty) {
      return Center(child: Text(context.l10n.mapNotConfigured));
    }
    if (style == null) return const Center(child: CircularProgressIndicator());
    final area = widget.area;
    final bounds = LatLngBounds(
      southwest: LatLng(area.south, area.west),
      northeast: LatLng(area.north, area.east),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: MapLibreMap(
        key: ValueKey('operational-area-preview-${area.label}'),
        styleString: style,
        initialCameraPosition: CameraPosition(
          target: LatLng(
            area.centerLatitude ?? (area.south + area.north) / 2,
            area.centerLongitude ?? (area.west + area.east) / 2,
          ),
          zoom: area.preferredZoom ?? 4,
        ),
        onStyleLoadedCallback: () {},
        onMapCreated: (controller) => unawaited(
          controller.animateCamera(
            CameraUpdate.newLatLngBounds(
              bounds,
              left: 32,
              top: 32,
              right: 32,
              bottom: 32,
            ),
          ),
        ),
      ),
    );
  }
}

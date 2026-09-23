part of '../trip_planner_controller.dart';

class _StopFields {
  final name = TextEditingController();
  final address = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  GeoPoint? get point {
    final lat = double.tryParse(latitude.text);
    final lon = double.tryParse(longitude.text);
    return validLocationCoordinate(lat, lon) ? GeoPoint(lat!, lon!) : null;
  }

  void load(TripStop? stop) {
    if (stop == null) return;
    name.text = stop.name;
    address.text = stop.address ?? '';
    latitude.text = stop.latitude?.toString() ?? '';
    longitude.text = stop.longitude?.toString() ?? '';
  }

  void loadResult(LocationResult result) {
    name.text = result.displayName;
    address.text = result.address ?? result.displayName;
    latitude.text = result.latitude.toStringAsFixed(6);
    longitude.text = result.longitude.toStringAsFixed(6);
  }

  TripStop? toStop(int sequence, String type) {
    final lat = double.tryParse(latitude.text);
    final lon = double.tryParse(longitude.text);
    if (lat == null || lon == null) return null;
    return TripStop(
      sequence: sequence,
      type: type,
      name: name.text.trim(),
      address: address.text.trim(),
      latitude: lat,
      longitude: lon,
    );
  }

  void dispose() {
    name.dispose();
    address.dispose();
    latitude.dispose();
    longitude.dispose();
  }
}

class _StopEditor extends StatelessWidget {
  const _StopEditor({
    required this.title,
    required this.fieldKey,
    required this.fields,
    required this.onSearch,
    required this.onSelectMap,
    required this.selectingOnMap,
    required this.onChanged,
    super.key,
  });
  final String title;
  final String fieldKey;
  final _StopFields fields;
  final VoidCallback onSearch, onChanged;
  final VoidCallback onSelectMap;
  final bool selectingOnMap;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: Key('trip-$fieldKey-name'),
                  controller: fields.name,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: context.l10n.locationName,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.l10n.required
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: context.l10n.searchLocation,
                onPressed: onSearch,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: Key('trip-$fieldKey-select-map'),
              onPressed: onSelectMap,
              icon: Icon(
                selectingOnMap ? Icons.touch_app : Icons.add_location_alt,
              ),
              label: Text(
                selectingOnMap
                    ? context.l10n.tapMapToSelect
                    : context.l10n.selectOnMap,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: Key('trip-$fieldKey-address'),
            controller: fields.address,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(labelText: context.l10n.address),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _coordinate(
                  context,
                  fields.latitude,
                  Key('trip-$fieldKey-latitude'),
                  context.l10n.latitude,
                  -90,
                  90,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _coordinate(
                  context,
                  fields.longitude,
                  Key('trip-$fieldKey-longitude'),
                  context.l10n.longitude,
                  -180,
                  180,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _coordinate(
    BuildContext context,
    TextEditingController controller,
    Key fieldKey,
    String label,
    double min,
    double max,
  ) => TextFormField(
    key: fieldKey,
    controller: controller,
    onChanged: (_) => onChanged(),
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final number = double.tryParse(value ?? '');
      return number == null || number < min || number > max
          ? context.l10n.invalidCoordinate
          : null;
    },
  );
}

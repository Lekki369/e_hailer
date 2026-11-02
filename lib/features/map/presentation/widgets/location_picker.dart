import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../infrastructure/osm_routing_service.dart';
import '../../../delivery/domain/entities/location_point.dart';
import '../../../../core/presentation/widgets/adaptive_layout.dart';
import 'osm_map_widget.dart';

/// Search is explicitly submitted; public Nominatim is never used for autocomplete.
class LocationPicker extends StatefulWidget {
  final String title;
  final LocationPoint? initial;
  const LocationPicker({super.key, required this.title, this.initial});
  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _query = TextEditingController();
  final _address = TextEditingController();
  final _routing = OsmRoutingService();
  LocationPoint? _selected;
  List<LocationPoint> _results = [];
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _address.text = _selected?.address ?? '';
  }

  @override
  void dispose() {
    _query.dispose();
    _address.dispose();
    _routing.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_busy || _query.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _routing.searchPlaces(_query.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      result.fold((failure) => _error = failure.message, (items) {
        _results = items;
        if (items.isEmpty) {
          _error =
              'No places found. Try a nearby landmark or choose a pin on the map.';
        }
      });
    });
  }

  void _select(LocationPoint point) => setState(() {
    _selected = point;
    _address.text = point.address;
    _results = [];
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: AdaptiveContent(
      maxWidth: 880,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tap the map to choose a location. Add any directions the courier needs before confirming.',
          ),
          const SizedBox(height: 16),
          if (_routing.supportsGeocoding)
            TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Address or landmark',
                suffixIcon: IconButton(
                  tooltip: 'Search places',
                  onPressed: _busy ? null : _search,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!),
            ),
          for (final result in _results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(result.address),
              onTap: () => _select(result),
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: MediaQuery.sizeOf(context).height < 600 ? 220 : 340,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: OsmMapWidget(
                pickupLocation: _selected == null
                    ? null
                    : LatLng(_selected!.latitude, _selected!.longitude),
                onTap: (_, point) => _select(
                  LocationPoint(
                    latitude: point.latitude,
                    longitude: point.longitude,
                    address: _address.text,
                    contactName: '',
                    contactPhone: '',
                  ),
                ),
                onMyLocationFound: (point) => _select(
                  LocationPoint(
                    latitude: point.latitude,
                    longitude: point.longitude,
                    address: _address.text,
                    contactName: '',
                    contactPhone: '',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _address,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Street address and directions',
              helperText: 'Include building number and a nearby landmark.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _selected == null
                ? null
                : () {
                    if (_address.text.trim().isEmpty) {
                      setState(
                        () => _error = 'Add the street address for this pin.',
                      );
                      return;
                    }
                    Navigator.pop(
                      context,
                      _selected!.copyWith(address: _address.text.trim()),
                    );
                  },
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Confirm location'),
            ),
          ),
        ],
      ),
    ),
  );
}

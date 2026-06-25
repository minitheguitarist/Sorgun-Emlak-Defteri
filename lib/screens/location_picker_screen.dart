import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_links.dart';

const _sorgunCenter = LatLng(39.8104, 35.1850);

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final MapController _mapController;
  late LatLng _selected;
  bool _loadingLocation = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selected =
        widget.initialLatitude != null && widget.initialLongitude != null
            ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
            : _sorgunCenter;

    if (widget.initialLatitude == null || widget.initialLongitude == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _useCurrentLocation(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konum seç'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(_selected),
            icon: const Icon(Icons.check),
            label: const Text('Seç'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: 16,
              minZoom: 6,
              maxZoom: 19,
              onTap: (_, point) => setState(() => _selected = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sorgunemlak.defter',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selected,
                    width: 54,
                    height: 54,
                    alignment: Alignment.topCenter,
                    child: Icon(
                      Icons.location_pin,
                      size: 52,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
              SimpleAttributionWidget(
                source: const Text('OpenStreetMap contributors'),
                backgroundColor:
                    theme.colorScheme.surface.withValues(alpha: 0.88),
              ),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatCoordinates(
                        latitude: _selected.latitude,
                        longitude: _selected.longitude,
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _message!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loadingLocation
                                ? null
                                : () => _useCurrentLocation(),
                            icon: _loadingLocation
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location_outlined),
                            label: const Text('Mevcut konum'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                Navigator.of(context).pop(_selected),
                            icon: const Icon(Icons.check),
                            label: const Text('Konumu seç'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    setState(() {
      _loadingLocation = true;
      if (!silent) {
        _message = null;
      }
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setMessage(
            'Telefon konum servisi kapalı. Haritadan pin seçebilirsiniz.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setMessage('Konum izni verilmedi. Haritadan pin seçebilirsiniz.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) {
        return;
      }
      setState(() {
        _selected = point;
        _message = 'Mevcut konum işaretlendi.';
      });
      _mapController.move(point, 17);
    } catch (_) {
      _setMessage('Konum alınamadı. Haritadan pin seçebilirsiniz.');
    } finally {
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }

  void _setMessage(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _message = message);
  }
}

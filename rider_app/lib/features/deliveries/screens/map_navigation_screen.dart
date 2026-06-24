import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';

class MapNavigationScreen extends StatefulWidget {
  final String title;
  final String address;
  final double destinationLat;
  final double destinationLng;

  const MapNavigationScreen({
    super.key,
    required this.title,
    required this.address,
    required this.destinationLat,
    required this.destinationLng,
  });

  @override
  State<MapNavigationScreen> createState() => _MapNavigationScreenState();
}

class _MapNavigationScreenState extends State<MapNavigationScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _locationSub;

  LatLng? _riderPos;
  bool _followRider = true;
  bool _loadingRoute = false;
  bool _mapReady = false;

  List<LatLng> _routePoints = [];

  String? _duration;
  String? _distance;

  LatLng get _destination => LatLng(widget.destinationLat, widget.destinationLng);

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _startTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      final riderLatLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _riderPos = riderLatLng);
      await _fetchRoute(riderLatLng);

      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((pos) async {
        if (!mounted) return;
        final newPos = LatLng(pos.latitude, pos.longitude);
        setState(() => _riderPos = newPos);
        if (_followRider && _mapReady) {
          _mapController.move(newPos, _mapController.camera.zoom);
        }
        // Update backend
        ApiService.put('/rider/update-location', {
          'lat': pos.latitude,
          'lng': pos.longitude,
          'isOnline': true,
        });
        // Refresh route every ~15m of movement
        await _fetchRoute(newPos);
      });
    } catch (_) {}
  }

  Future<void> _fetchRoute(LatLng origin) async {
    if (mounted) setState(() => _loadingRoute = true);
    try {
      // OSRM public routing service — no API key required.
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${widget.destinationLng},${widget.destinationLat}'
        '?overview=full&geometries=polyline',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        if (mounted) setState(() => _loadingRoute = false);
        return;
      }

      final data = json.decode(response.body);
      if (data['code'] != 'Ok' ||
          (data['routes'] as List?)?.isEmpty != false) {
        if (mounted) setState(() => _loadingRoute = false);
        return;
      }

      final route = data['routes'][0];
      final points = _decodePolyline(route['geometry'] as String);
      final coords = points.map((p) => LatLng(p[0], p[1])).toList();

      final meters = (route['distance'] as num).toDouble();
      final seconds = (route['duration'] as num).toDouble();

      if (!mounted) return;
      setState(() {
        _routePoints = coords;
        _distance = _formatDistance(meters);
        _duration = _formatDuration(seconds);
        _loadingRoute = false;
      });

      if (_mapReady && coords.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: coords,
            padding: const EdgeInsets.all(60),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  void _centerOnRider() {
    if (_riderPos == null || !_mapReady) return;
    setState(() => _followRider = true);
    _mapController.move(_riderPos!, 16);
  }

  void _centerOnDestination() {
    if (!_mapReady) return;
    setState(() => _followRider = false);
    _mapController.move(_destination, 16);
  }

  void _fitRoute() {
    if (!_mapReady || _routePoints.isEmpty) return;
    setState(() => _followRider = false);
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: _routePoints,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  // Google/OSRM encoded polyline decoder
  List<List<double>> _decodePolyline(String encoded) {
    final result = <List<double>>[];
    int index = 0;
    int lat = 0, lng = 0;
    while (index < encoded.length) {
      int shift = 0, result0 = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1);
      lat += dlat;
      shift = 0;
      result0 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1);
      lng += dlng;
      result.add([lat / 1e5, lng / 1e5]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _destination,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () {
                setState(() => _mapReady = true);
                if (_routePoints.isNotEmpty) {
                  _mapController.fitCamera(
                    CameraFit.coordinates(
                      coordinates: _routePoints,
                      padding: const EdgeInsets.all(60),
                    ),
                  );
                }
              },
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _followRider) {
                  setState(() => _followRider = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.ordogo.rider_app',
                maxZoom: 20,
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: AppTheme.primary,
                      strokeWidth: 5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Destination
                  Marker(
                    point: _destination,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.location_on,
                        color: AppTheme.error, size: 44),
                  ),
                  // Rider
                  if (_riderPos != null)
                    Marker(
                      point: _riderPos!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6)
                          ],
                        ),
                        child: const Icon(Icons.directions_bike,
                            color: Colors.white, size: 18),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Loading route indicator
          if (_loadingRoute)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Getting route...', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6)
                          ],
                        ),
                        child: const Icon(Icons.arrow_back, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 6)
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: AppTheme.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.title,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary)),
                                  Text(widget.address,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            if (_distance != null) ...[
                              const SizedBox(width: 8),
                              Text(_distance!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // FAB buttons
          Positioned(
            right: 12,
            bottom: 110,
            child: Column(
              children: [
                _mapFab(
                  icon: Icons.my_location,
                  onTap: _centerOnRider,
                  active: _followRider,
                  tooltip: 'My location',
                ),
                const SizedBox(height: 8),
                _mapFab(
                  icon: Icons.route,
                  onTap: _fitRoute,
                  active: false,
                  tooltip: 'Full route',
                ),
                const SizedBox(height: 8),
                _mapFab(
                  icon: Icons.flag,
                  onTap: _centerOnDestination,
                  active: false,
                  tooltip: 'Destination',
                ),
              ],
            ),
          ),

          // Bottom info card
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10)
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_bike,
                        color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(widget.address,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (_duration != null || _distance != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_duration != null)
                          Text(_duration!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppTheme.primary)),
                        if (_distance != null)
                          Text(_distance!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapFab({
    required IconData icon,
    required VoidCallback onTap,
    required bool active,
    required String tooltip,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)
          ],
        ),
        child: Icon(icon,
            size: 20,
            color: active ? Colors.white : AppTheme.textPrimary),
      ),
    );
  }
}

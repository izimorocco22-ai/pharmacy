import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';

const _googleApiKey = 'AIzaSyDHdBdmN3SL-qm5GSHZ3yLgedq9cBmbpDg';

class MapNavigationScreen extends StatefulWidget {
  final String title;
  final String address;
  final LatLng destination;

  const MapNavigationScreen({
    super.key,
    required this.title,
    required this.address,
    required this.destination,
  });

  @override
  State<MapNavigationScreen> createState() => _MapNavigationScreenState();
}

class _MapNavigationScreenState extends State<MapNavigationScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _locationSub;

  LatLng? _riderPos;
  bool _followRider = true;
  bool _loadingRoute = false;

  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  String? _duration;
  String? _distance;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _mapController?.dispose();
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
      _buildMarkers();
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
        _buildMarkers();
        if (_followRider) {
          _mapController?.animateCamera(CameraUpdate.newLatLng(newPos));
        }
        // Update backend
        ApiService.put('/rider/update-location', {
          'lat': pos.latitude,
          'lng': pos.longitude,
          'isOnline': true,
        });
        // Refresh route every 15m movement
        await _fetchRoute(newPos);
      });
    } catch (_) {}
  }

  Future<void> _fetchRoute(LatLng origin) async {
    setState(() => _loadingRoute = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${widget.destination.latitude},${widget.destination.longitude}'
        '&mode=driving'
        '&key=$_googleApiKey',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      if (data['status'] != 'OK') return;

      final route = data['routes'][0];
      final leg = route['legs'][0];

      // Decode polyline
      final points = _decodePolyline(route['overview_polyline']['points']);
      final polylineCoords = points.map((p) => LatLng(p[0], p[1])).toList();

      if (!mounted) return;
      setState(() {
        _duration = leg['duration']['text'];
        _distance = leg['distance']['text'];
        _polylines
          ..clear()
          ..add(Polyline(
            polylineId: const PolylineId('route'),
            points: polylineCoords,
            color: AppTheme.primary,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ));
        _loadingRoute = false;
      });

      // Fit map to show full route
      if (_mapController != null && polylineCoords.isNotEmpty) {
        final bounds = _boundsFromLatLngList(polylineCoords);
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 80),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _buildMarkers() {
    final markers = <Marker>{};

    // Destination marker
    markers.add(Marker(
      markerId: const MarkerId('destination'),
      position: widget.destination,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: widget.title, snippet: widget.address),
    ));

    // Rider marker
    if (_riderPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: _riderPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }

    setState(() => _markers
      ..clear()
      ..addAll(markers));
  }

  void _centerOnRider() {
    if (_riderPos == null) return;
    setState(() => _followRider = true);
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _riderPos!, zoom: 16),
      ),
    );
  }

  void _centerOnDestination() {
    setState(() => _followRider = false);
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: widget.destination, zoom: 16),
      ),
    );
  }

  void _fitRoute() {
    setState(() => _followRider = false);
    if (_polylines.isEmpty) return;
    final all = _polylines.first.points;
    if (all.isEmpty) return;
    final bounds = _boundsFromLatLngList(all);
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double minLat = list.first.latitude;
    double maxLat = list.first.latitude;
    double minLng = list.first.longitude;
    double maxLng = list.first.longitude;
    for (final p in list) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // Google encoded polyline decoder
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
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.destination,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _buildMarkers();
            },
            onCameraMove: (_) {
              if (_followRider) setState(() => _followRider = false);
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            trafficEnabled: true,
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

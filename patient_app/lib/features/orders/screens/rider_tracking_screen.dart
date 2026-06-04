import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';

class RiderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String deliveryAddress;
  final LatLng? deliveryLocation;

  const RiderTrackingScreen({
    super.key,
    required this.orderId,
    required this.deliveryAddress,
    this.deliveryLocation,
  });

  @override
  State<RiderTrackingScreen> createState() => _RiderTrackingScreenState();
}

class _RiderTrackingScreenState extends State<RiderTrackingScreen> {
  GoogleMapController? _mapController;
  Timer? _pollTimer;

  LatLng? _riderPos;
  String? _orderStatus;
  bool _loading = true;
  bool _riderOffline = false;

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _fetchRiderLocation();
    // Poll every 5 seconds for live updates
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchRiderLocation();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchRiderLocation() async {
    try {
      final res = await ApiService.get('/orders/${widget.orderId}/rider-location');
      if (!mounted) return;

      if (res.success && res.data != null) {
        final lat = (res.data['lat'] as num).toDouble();
        final lng = (res.data['lng'] as num).toDouble();
        final newPos = LatLng(lat, lng);
        final status = res.data['orderStatus']?.toString();

        setState(() {
          _orderStatus = status;
          _riderOffline = res.data['isOnline'] == false;
          _loading = false;
        });

        // Smooth animate marker to new position
        if (_riderPos != null && _mapController != null) {
          _animateMarker(_riderPos!, newPos);
        } else {
          setState(() => _riderPos = newPos);
          _buildMarkers(newPos);
          // First load — fit map to show both rider and destination
          if (widget.deliveryLocation != null) {
            _fitBounds(newPos, widget.deliveryLocation!);
          } else {
            _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: newPos, zoom: 15),
              ),
            );
          }
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Smooth marker animation over 1 second
  void _animateMarker(LatLng from, LatLng to) {
    const steps = 20;
    const stepDuration = Duration(milliseconds: 50);
    int step = 0;

    Timer.periodic(stepDuration, (timer) {
      if (!mounted) { timer.cancel(); return; }
      step++;
      final t = step / steps;
      final lat = from.latitude + (to.latitude - from.latitude) * t;
      final lng = from.longitude + (to.longitude - from.longitude) * t;
      final interpolated = LatLng(lat, lng);

      setState(() => _riderPos = interpolated);
      _buildMarkers(interpolated);

      if (step >= steps) {
        timer.cancel();
        setState(() => _riderPos = to);
        _buildMarkers(to);
      }
    });
  }

  void _buildMarkers(LatLng riderPos) {
    final markers = <Marker>{};

    // Rider marker
    markers.add(Marker(
      markerId: const MarkerId('rider'),
      position: riderPos,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: 'Rider', snippet: 'Your delivery rider'),
    ));

    // Delivery destination marker
    if (widget.deliveryLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: widget.deliveryLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Delivery Location',
          snippet: widget.deliveryAddress,
        ),
      ));
    }

    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

  void _fitBounds(LatLng a, LatLng b) {
    final bounds = LatLngBounds(
      southwest: LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      ),
      northeast: LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      ),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _centerOnRider() {
    if (_riderPos == null) return;
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _riderPos!, zoom: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.deliveryLocation ?? const LatLng(33.5731, -7.5898),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_riderPos != null) {
                _buildMarkers(_riderPos!);
                if (widget.deliveryLocation != null) {
                  _fitBounds(_riderPos!, widget.deliveryLocation!);
                }
              }
            },
            markers: _markers,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            trafficEnabled: false,
            compassEnabled: true,
          ),

          // Loading overlay
          if (_loading)
            Container(
              color: Colors.white,
              child: const Center(child: CircularProgressIndicator()),
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
                            const Icon(Icons.delivery_dining,
                                color: AppTheme.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Rider Location',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary)),
                                  Text(
                                    widget.deliveryAddress,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Live pulse indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _riderOffline
                                    ? Colors.grey.withValues(alpha: 0.1)
                                    : AppTheme.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: _riderOffline
                                          ? Colors.grey
                                          : AppTheme.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _riderOffline ? 'Offline' : 'Live',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _riderOffline
                                          ? Colors.grey
                                          : AppTheme.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Center on rider FAB
          Positioned(
            right: 12,
            bottom: 110,
            child: GestureDetector(
              onTap: _centerOnRider,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6)
                  ],
                ),
                child: const Icon(Icons.my_location,
                    size: 22, color: AppTheme.primary),
              ),
            ),
          ),

          // Bottom status card
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10)
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delivery_dining,
                        color: AppTheme.primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _orderStatus == 'in_transit'
                              ? 'Rider is on the way'
                              : _orderStatus == 'picked_up'
                                  ? 'Order picked up'
                                  : _orderStatus == 'delivered'
                                      ? 'Order delivered!'
                                      : 'Tracking rider...',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.deliveryAddress,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _orderStatus == 'delivered'
                          ? AppTheme.success.withValues(alpha: 0.1)
                          : AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _orderStatus == 'delivered'
                          ? Icons.check_circle
                          : Icons.directions_bike,
                      color: _orderStatus == 'delivered'
                          ? AppTheme.success
                          : AppTheme.primary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

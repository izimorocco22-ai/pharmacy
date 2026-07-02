import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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

class _RiderTrackingScreenState extends State<RiderTrackingScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  Timer? _pollTimer;

  LatLng? _riderPos;
  String? _orderStatus;
  bool _loading = true;
  bool _riderOffline = false;
  bool _mapReady = false;
  bool _didFit = false;

  // Smoothly glide the rider marker between the 5-second location polls.
  late final AnimationController _moveController;
  late final Animation<double> _moveAnimation;
  Tween<double> _latTween = Tween<double>(begin: 0, end: 0);
  Tween<double> _lngTween = Tween<double>(begin: 0, end: 0);

  LatLng? get _destination => widget.deliveryLocation;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _moveAnimation =
        CurvedAnimation(parent: _moveController, curve: Curves.easeInOut)
          ..addListener(_onMoveTick);
    _fetchRiderLocation();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchRiderLocation(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _moveController.dispose();
    super.dispose();
  }

  void _onMoveTick() {
    if (!mounted) return;
    setState(() {
      _riderPos = LatLng(
        _latTween.evaluate(_moveAnimation),
        _lngTween.evaluate(_moveAnimation),
      );
    });
  }

  void _animateRiderTo(LatLng target) {
    final start = _riderPos ?? target;
    _latTween = Tween<double>(begin: start.latitude, end: target.latitude);
    _lngTween = Tween<double>(begin: start.longitude, end: target.longitude);
    _moveController
      ..reset()
      ..forward();
  }

  Future<void> _fetchRiderLocation() async {
    try {
      final res =
          await ApiService.get('/orders/${widget.orderId}/rider-location');
      if (!mounted) return;

      if (res.success && res.data != null && res.data['lat'] != null) {
        final lat = (res.data['lat'] as num).toDouble();
        final lng = (res.data['lng'] as num).toDouble();
        final newPos = LatLng(lat, lng);

        setState(() {
          _orderStatus = res.data['orderStatus']?.toString();
          _riderOffline = res.data['isOnline'] == false;
          _loading = false;
        });

        if (_riderPos == null) {
          setState(() => _riderPos = newPos);
          _fitInitial();
        } else {
          _animateRiderTo(newPos);
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Fit the rider + destination into view once, on first fix.
  void _fitInitial() {
    if (!_mapReady || _riderPos == null || _didFit) return;
    _didFit = true;
    final dest = _destination;
    if (dest != null) {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: [_riderPos!, dest],
          padding: const EdgeInsets.all(80),
        ),
      );
    } else {
      _mapController.move(_riderPos!, 15);
    }
  }

  void _centerOnRider() {
    if (_riderPos == null || !_mapReady) return;
    _mapController.move(_riderPos!, 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _destination ?? const LatLng(33.5731, -7.5898),
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () {
                setState(() => _mapReady = true);
                _fitInitial();
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.ordogo.patient_app',
                maxZoom: 20,
              ),
              MarkerLayer(
                markers: [
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.location_on,
                          color: AppTheme.error, size: 44),
                    ),
                  if (_riderPos != null)
                    Marker(
                      point: _riderPos!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6),
                          ],
                        ),
                        child: const Icon(Icons.delivery_dining,
                            color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Loading overlay
          if (_loading)
            Container(
              color: Colors.white,
              child: const Center(child: CircularProgressIndicator()),
            ),

          // No rider location yet (after loading)
          if (!_loading && _riderPos == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off,
                        size: 64,
                        color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    const Text('Rider location not available yet',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text(
                      "We'll show the rider here once they start moving.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
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
                width: 44,
                height: 44,
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
            bottom: 0,
            left: 0,
            right: 0,
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

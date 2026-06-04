import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../../services/location_service.dart';
import 'map_navigation_screen.dart';

class NavigationScreen extends StatefulWidget {
  final Map<String, dynamic> delivery;

  const NavigationScreen({super.key, required this.delivery});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  String _phase = 'to_pharmacy';
  bool _isUpdating = false;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      LocationService.updateLocation();
    });
    LocationService.updateLocation();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  String get _orderId => widget.delivery['orderId']?.toString() ?? '';
  String get _pickupAddress => widget.delivery['pickupAddress']?.toString() ?? 'Pharmacy';
  String get _deliveryAddress => widget.delivery['deliveryAddress']?.toString() ?? 'Patient';
  String get _orderNumber => widget.delivery['orderNumber']?.toString() ?? '';
  num get _deliveryFee => widget.delivery['deliveryFee'] ?? 0;
  List? get _pharmacyCoords => widget.delivery['pharmacyCoords'] as List?;
  List? get _deliveryCoords => widget.delivery['deliveryCoords'] as List?;
  String get _pharmacyPhone => widget.delivery['pharmacyPhone']?.toString() ?? '';
  String get _patientPhone => widget.delivery['patientPhone']?.toString() ?? '';

  Future<void> _callNumber(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMaps(String address, List? coords) async {
    final l10n = AppLocalizations.of(context)!;
    if (coords == null || coords.length < 2) return;
    final lat = (coords[1] as num).toDouble();
    final lng = (coords[0] as num).toDouble();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapNavigationScreen(
          title: _phase == 'to_pharmacy' ? l10n.translate('pickup_location') : l10n.translate('delivery_location'),
          address: address,
          destination: LatLng(lat, lng),
        ),
      ),
    );
  }

  Future<void> _arrivedAtPharmacy() async {
    setState(() => _isUpdating = true);
    final res = await ApiService.put('/rider/update-status', {
      'orderId': _orderId,
      'status': 'picked_up',
    });
    if (!mounted) return;
    setState(() => _isUpdating = false);
    if (res.success) {
      setState(() => _phase = 'to_patient');
    } else {
      _showError(res.message);
    }
  }

  Future<void> _arrivedAtPatient() async {
    setState(() => _isUpdating = true);
    final res = await ApiService.put('/rider/update-status', {
      'orderId': _orderId,
      'status': 'delivered',
    });
    if (!mounted) return;
    setState(() => _isUpdating = false);
    if (res.success) {
      setState(() => _phase = 'delivered');
    } else {
      _showError(res.message);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: _phase == 'delivered',
      onPopInvoked: (didPop) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('complete_delivery_before_back'))),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(l10n),
              Expanded(child: _buildBody(l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      color: AppTheme.surface,
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: _phase == 'delivered' ? AppTheme.success : AppTheme.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _phase == 'to_pharmacy'
                      ? l10n.translate('head_to_pharmacy')
                      : _phase == 'to_patient'
                          ? l10n.translate('head_to_patient')
                          : l10n.translate('delivery_complete'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(_orderNumber,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              '$_deliveryFee ${l10n.translate('mad')}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.success,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_phase == 'delivered') return _buildDeliveredView(l10n);

    final isToPharmacy = _phase == 'to_pharmacy';

    return Column(
      children: [
        _buildProgressSteps(l10n),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              children: [
                _buildDestinationCard(
                  isActive: true,
                  icon: isToPharmacy ? Icons.store : Icons.location_on,
                  color: isToPharmacy ? AppTheme.primary : AppTheme.error,
                  title: isToPharmacy ? l10n.translate('pickup_location') : l10n.translate('delivery_location'),
                  address: isToPharmacy ? _pickupAddress : _deliveryAddress,
                  coords: isToPharmacy ? _pharmacyCoords : _deliveryCoords,
                  phone: isToPharmacy ? _pharmacyPhone : _patientPhone,
                ),
                const SizedBox(height: AppTheme.spacing12),
                _buildDestinationCard(
                  isActive: false,
                  icon: isToPharmacy ? Icons.location_on : Icons.check_circle,
                  color: AppTheme.textSecondary,
                  title: isToPharmacy ? l10n.translate('then_deliver_to') : l10n.translate('completed'),
                  address: isToPharmacy ? _deliveryAddress : l10n.translate('delivery_done'),
                  coords: isToPharmacy ? _deliveryCoords : null,
                  phone: '',
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          color: AppTheme.surface,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUpdating
                  ? null
                  : (isToPharmacy ? _arrivedAtPharmacy : _arrivedAtPatient),
              style: ElevatedButton.styleFrom(
                backgroundColor: isToPharmacy ? AppTheme.primary : AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
              ),
              child: _isUpdating
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isToPharmacy ? l10n.translate('arrived_at_pharmacy') : l10n.translate('arrived_at_patient'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSteps(AppLocalizations l10n) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing24, vertical: AppTheme.spacing12),
      child: Row(
        children: [
          _stepDot(label: l10n.translate('pickup'), done: _phase != 'to_pharmacy', active: _phase == 'to_pharmacy'),
          Expanded(child: Container(height: 2, color: _phase != 'to_pharmacy' ? AppTheme.primary : AppTheme.divider)),
          _stepDot(label: l10n.translate('delivery'), done: _phase == 'delivered', active: _phase == 'to_patient'),
          Expanded(child: Container(height: 2, color: _phase == 'delivered' ? AppTheme.primary : AppTheme.divider)),
          _stepDot(label: l10n.translate('completed'), done: _phase == 'delivered', active: false),
        ],
      ),
    );
  }

  Widget _stepDot({required String label, required bool done, required bool active}) {
    final color = done || active ? AppTheme.primary : AppTheme.divider;
    return Column(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: done ? AppTheme.primary : active ? AppTheme.primary.withOpacity(0.15) : AppTheme.divider,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : active
                  ? Container(
                      width: 10, height: 10,
                      margin: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                    )
                  : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDestinationCard({
    required bool isActive,
    required IconData icon,
    required Color color,
    required String title,
    required String address,
    required String phone,
    List? coords,
  }) {
    return Opacity(
      opacity: isActive ? 1.0 : 0.45,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          side: BorderSide(
            color: isActive ? color.withOpacity(0.4) : AppTheme.divider,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 12,
                            color: isActive ? color : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(address,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (isActive) ...[
                // Call button
                if (phone.isNotEmpty)
                  Container(
                    width: 38, height: 38,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _callNumber(phone),
                      icon: const Icon(Icons.call, color: AppTheme.success, size: 18),
                      tooltip: 'Call',
                    ),
                  ),
                // Navigate button
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _openMaps(address, coords),
                    icon: const Icon(Icons.navigation, color: AppTheme.primary, size: 18),
                    tooltip: 'Navigate',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveredView(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.success, size: 56),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Text(l10n.translate('delivery_complete'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spacing8),
            Text('${l10n.translate('you_earned')} $_deliveryFee ${l10n.translate('mad')}',
                style: const TextStyle(
                    fontSize: 18, color: AppTheme.success, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppTheme.spacing8),
            Text(_orderNumber,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: AppTheme.spacing48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                ),
                child: Text(l10n.translate('back_to_home'), style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

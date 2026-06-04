import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';

class PharmacyInfoScreen extends StatefulWidget {
  const PharmacyInfoScreen({super.key});

  @override
  State<PharmacyInfoScreen> createState() => _PharmacyInfoScreenState();
}

class _PharmacyInfoScreenState extends State<PharmacyInfoScreen> {
  Map<String, dynamic>? _pharmacy;
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.get('/pharmacy/profile');
      if (res.success && res.data != null) {
        setState(() {
          _user = res.data['user'];
          _pharmacy = res.data['pharmacy'];
        });
      } else {
        setState(() => _error = res.message);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacy Info')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                      const SizedBox(height: AppTheme.spacing12),
                      Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: AppTheme.spacing16),
                      TextButton.icon(
                        onPressed: _fetchProfile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchProfile,
                  color: AppTheme.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: Column(
                      children: [
                        // Header card
                        _buildHeaderCard(),
                        const SizedBox(height: AppTheme.spacing16),
                        // Pharmacy details
                        if (_pharmacy != null) ...[
                          _buildSection('Pharmacy Details', Icons.store, [
                            _buildRow(Icons.badge_outlined, 'Pharmacy Name', _pharmacy!['pharmacyName']),
                            _buildRow(Icons.numbers, 'License Number', _pharmacy!['licenseNumber']),
                            _buildRow(Icons.location_on_outlined, 'Address', _pharmacy!['address']),
                          ]),
                          const SizedBox(height: AppTheme.spacing16),
                          _buildSection('Status & Performance', Icons.bar_chart, [
                            _buildStatusRow(_pharmacy!['isOpen'] == true),
                            _buildRow(Icons.star_outline, 'Rating', '${(_pharmacy!['rating'] ?? 0.0).toStringAsFixed(1)} / 5.0'),
                            _buildRow(Icons.shopping_bag_outlined, 'Total Orders', '${_pharmacy!['totalOrders'] ?? 0}'),
                          ]),
                          const SizedBox(height: AppTheme.spacing16),
                        ],
                        // Account details
                        _buildSection('Account Details', Icons.person_outline, [
                          _buildRow(Icons.person_outline, 'Owner Name', _user?['fullName']),
                          _buildRow(Icons.phone_outlined, 'Phone', _user?['phone']),
                          _buildRow(Icons.verified_outlined, 'Verified', _user?['isVerified'] == true ? 'Yes' : 'No'),
                        ]),
                        const SizedBox(height: AppTheme.spacing24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    final name = _pharmacy?['pharmacyName'] ?? _user?['fullName'] ?? 'Pharmacy';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'P',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),

        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16, AppTheme.spacing16, AppTheme.spacing16, AppTheme.spacing8),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 18),
                const SizedBox(width: AppTheme.spacing8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16, vertical: AppTheme.spacing12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value?.toString().isNotEmpty == true ? value.toString() : '—',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(bool isOpen) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16, vertical: AppTheme.spacing12),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOpen ? const Color(0xFFE8F8F0) : const Color(0xFFFDEDEC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOpen ? 'Open' : 'Closed',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isOpen ? AppTheme.success : AppTheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/input_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/address_service.dart';
import 'map_picker_screen.dart';

class AddAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? address;

  const AddAddressScreen({super.key, this.address});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _labelController;
  late TextEditingController _addressController;
  bool _isDefault = false;
  bool _isLoading = false;
  bool _isFetchingLocation = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.address?['label'] ?? '');
    _addressController = TextEditingController(text: widget.address?['address'] ?? '');
    _isDefault = widget.address?['isDefault'] ?? false;
    _latitude = widget.address?['latitude'];
    _longitude = widget.address?['longitude'];
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        setState(() => _isFetchingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          setState(() => _isFetchingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied')),
          );
        }
        setState(() => _isFetchingLocation = false);
        return;
      }

      // Open map picker centered on current GPS position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() => _isFetchingLocation = false);

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapPickerScreen(
            initialLatitude: position.latitude,
            initialLongitude: position.longitude,
          ),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _latitude = result['latitude'];
          _longitude = result['longitude'];
          _addressController.text = result['address'] ?? '';
        });
      }
    } catch (e) {
      setState(() => _isFetchingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _addressController.text = result['address'] ?? '';
      });
    }
  }

  /// Returns the user-entered label, or generates a friendly one when blank.
  /// Prefers the first part of the resolved address (e.g. "59 Boulevard des
  /// Bourroches"), falling back to a timestamped "Address" name.
  String _resolveLabel() {
    final entered = _labelController.text.trim();
    if (entered.isNotEmpty) return entered;

    final addr = _addressController.text.trim();
    if (addr.isNotEmpty) {
      final firstPart = addr.split(',').first.trim();
      if (firstPart.isNotEmpty) return firstPart;
    }

    final now = DateTime.now();
    return 'Address ${now.day}/${now.month} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick your location on the map first'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isEditing = widget.address != null;
      final AddressResult result;

      // Label is optional — generate a friendly name when left blank
      final label = _resolveLabel();

      if (isEditing) {
        result = await AddressService.updateAddress(
          id: widget.address!['_id'],
          label: label,
          address: _addressController.text.trim(),
          city: '',
          state: '',
          zipCode: '',
          latitude: _latitude!,
          longitude: _longitude!,
          isDefault: _isDefault,
        );
      } else {
        result = await AddressService.addAddress(
          label: label,
          address: _addressController.text.trim(),
          city: '',
          state: '',
          zipCode: '',
          latitude: _latitude!,
          longitude: _longitude!,
          isDefault: _isDefault,
        );
      }

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? '${isEditing ? "Updated" : "Saved"} successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Failed to ${isEditing ? "update" : "save"} address'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${widget.address != null ? "update" : "save"} address'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.address != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Address' : 'Add Address'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location picker card
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _latitude != null ? Icons.check_circle : Icons.location_on,
                          color: _latitude != null ? AppTheme.success : AppTheme.primary,
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _latitude != null ? 'Location Selected' : 'Select Location',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: _latitude != null ? AppTheme.success : AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: AppTheme.spacing4),
                              Text(
                                _latitude != null
                                    ? 'Tap below to adjust on map'
                                    : 'Use GPS or pick on map',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                            icon: _isFetchingLocation
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                            label: Text(_isFetchingLocation ? 'Loading...' : 'Use GPS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openMapPicker,
                            icon: const Icon(Icons.map),
                            label: const Text('Pick on Map'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),
              Text(
                'Address Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              InputField(
                controller: _labelController,
                label: 'Label (optional, e.g., Home, Work)',
                prefixIcon: const Icon(Icons.label),
              ),
              const SizedBox(height: AppTheme.spacing16),
              InputField(
                controller: _addressController,
                label: 'Address',
                prefixIcon: const Icon(Icons.home),
                maxLines: 2,
                enabled: false,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Address is required';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing24),
              CheckboxListTile(
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value ?? false),
                title: const Text('Set as default address'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppTheme.primary,
              ),
              const SizedBox(height: AppTheme.spacing32),
              PrimaryButton(
                text: isEditing ? 'Update Address' : 'Save Address',
                onPressed: _saveAddress,
                isLoading: _isLoading,
              ),
              const SizedBox(height: AppTheme.spacing16),
            ],
          ),
        ),
      ),
    );
  }
}

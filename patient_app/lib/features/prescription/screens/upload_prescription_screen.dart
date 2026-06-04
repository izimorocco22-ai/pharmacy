import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../services/media_service.dart';
import '../../../services/prescription_service.dart';
import '../../../services/ai_service.dart';
import '../../../core/localization/app_localizations.dart';

class UploadPrescriptionScreen extends StatefulWidget {
  const UploadPrescriptionScreen({super.key});

  @override
  State<UploadPrescriptionScreen> createState() => _UploadPrescriptionScreenState();
}

class _UploadPrescriptionScreenState extends State<UploadPrescriptionScreen> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isScanning = false;
  bool? _aiConfirmed;

  // Manual medicine entry
  bool _showMedicineEntry = false;
  final List<_MedicineEntry> _medicines = [_MedicineEntry()];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _showMedicineEntry = false; // hide manual entry if image selected
          _isScanning = true;
          _aiConfirmed = null;
        });

        // Scan image with AI
        final isPrescription = await AiService.isPrescription(_imageFile!);
        
        if (mounted) {
          setState(() {
            _isScanning = false;
            _aiConfirmed = isPrescription;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isScanning = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  void _showImageSourceDialog() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: AppTheme.spacing24),
              Text(l10n.translate('upload_prescription'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppTheme.spacing16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(Icons.camera_alt, color: AppTheme.primary),
                ),
                title: Text(l10n.translate('take_photo')),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(Icons.photo_library, color: AppTheme.primary),
                ),
                title: Text(l10n.translate('choose_gallery')),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addMedicine() {
    setState(() => _medicines.add(_MedicineEntry()));
  }

  void _removeMedicine(int index) {
    if (_medicines.length > 1) setState(() => _medicines.removeAt(index));
  }

  bool get _canContinue {
    if (_imageFile != null) return _aiConfirmed == true;
    if (_showMedicineEntry) {
      return _medicines.any((m) => m.nameController.text.trim().isNotEmpty);
    }
    return false;
  }

  Future<void> _submit() async {
    setState(() => _isUploading = true);

    try {
      String? imageUrl;
      String? imagePublicId;
      List<Map<String, dynamic>>? medicines;

      if (_imageFile != null) {
        final uploadResult = await MediaService.uploadImage(_imageFile!);
        if (!uploadResult.success) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(uploadResult.message ?? 'Failed to upload image')),
          );
          setState(() => _isUploading = false);
          return;
        }
        imageUrl = uploadResult.url;
        imagePublicId = uploadResult.publicId;
      }

      if (_showMedicineEntry) {
        medicines = _medicines
            .where((m) => m.nameController.text.trim().isNotEmpty)
            .map((m) => {
                  'name': m.nameController.text.trim(),
                  'quantity': int.tryParse(m.qtyController.text.trim()) ?? 1,
                })
            .toList();
      }

      final result = await PrescriptionService.uploadPrescription(
        imageUrl: imageUrl,
        imagePublicId: imagePublicId,
        medicines: medicines,
      );

      setState(() => _isUploading = false);
      if (!mounted) return;

      if (result.success) {
        Navigator.pushNamed(context, '/address-selection', arguments: result.prescriptionId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to submit prescription')),
        );
      }
    } catch (_) {
      setState(() => _isUploading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit prescription')),
      );
    }
  }

  @override
  void dispose() {
    for (final m in _medicines) {
      m.nameController.dispose();
      m.qtyController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('upload_prescription'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            AppCard(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              child: Column(
                children: [
                  Icon(Icons.description_outlined, size: 64,
                      color: AppTheme.primary.withOpacity(0.5)),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(l10n.translate('upload_prescription'),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    l10n.translate('prescription_desc'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),

            // Image preview or Take Photo button
            if (_imageFile != null) ...[
              AppCard(
                padding: EdgeInsets.zero,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      child: Image.file(_imageFile!, fit: BoxFit.cover),
                    ),
                    if (_isScanning)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black45,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                'Analyzing prescription...',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
              if (_aiConfirmed == false)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(color: AppTheme.error),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.error_outline, color: AppTheme.error),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'AI could not identify this as a prescription. Please try again with a clearer photo.',
                          style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_aiConfirmed == true)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(color: AppTheme.success),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppTheme.success),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Prescription verified!',
                          style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppTheme.spacing12),
              SecondaryButton(
                text: 'Change Image', // Could add this to l10n
                icon: Icons.refresh,
                onPressed: _isScanning ? null : _showImageSourceDialog,
              ),
            ] else ...[
              PrimaryButton(
                text: l10n.translate('take_photo'),
                icon: Icons.camera_alt,
                onPressed: _showImageSourceDialog,
              ),
            ],

            const SizedBox(height: AppTheme.spacing16),

            // Divider with OR
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR', style: Theme.of(context).textTheme.bodySmall),
                ),
                const Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: AppTheme.spacing16),

            // Enter medicine names button
            if (!_showMedicineEntry)
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _showMedicineEntry = true;
                  _imageFile = null;
                }),
                icon: const Icon(Icons.medication_outlined),
                label: const Text('Enter Medicine Names'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                ),
              ),

            // Manual medicine entry
            if (_showMedicineEntry) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.translate('requested_medicines'),
                      style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _showMedicineEntry = false;
                      for (final m in _medicines) {
                        m.nameController.clear();
                        m.qtyController.clear();
                      }
                    }),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(l10n.translate('cancel')),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing8),
              ...List.generate(_medicines.length, (i) => _buildMedicineRow(i, l10n)),
              const SizedBox(height: AppTheme.spacing8),
              TextButton.icon(
                onPressed: _addMedicine,
                icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                label: Text(l10n.translate('medicine_name'), // or add another medicine
                    style: const TextStyle(color: AppTheme.primary)),
              ),
            ],

            const SizedBox(height: AppTheme.spacing32),

            // Continue button
            if (_imageFile != null || _showMedicineEntry)
              PrimaryButton(
                text: l10n.translate('confirm'),
                onPressed: _canContinue ? _submit : null,
                isLoading: _isUploading,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineRow(int index, AppLocalizations l10n) {
    final entry = _medicines[index];
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            flex: 3,
            child: TextField(
              controller: entry.nameController,
              decoration: InputDecoration(
                hintText: l10n.translate('medicine_name'),
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          SizedBox(
            width: 70,
            child: TextField(
              controller: entry.qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: l10n.translate('quantity'),
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ),
          if (_medicines.length > 1) ...[
            const SizedBox(width: AppTheme.spacing8),
            GestureDetector(
              onTap: () => _removeMedicine(index),
              child: const Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 22),
            ),
          ],
        ],
      ),
    );
  }
}

class _MedicineEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
}

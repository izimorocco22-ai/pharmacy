import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/input_field.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/pharmacy_service.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  List<Map<String, String>> _paymentMethods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final response = await PharmacyService.getPaymentSettings();
    if (response.success && response.data != null) {
      setState(() {
        _paymentMethods = List<Map<String, dynamic>>.from(response.data)
            .map((e) => e.map((key, value) => MapEntry(key, value.toString())))
            .toList();
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    final response = await PharmacyService.updatePaymentSettings(_paymentMethods);
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.success ? 'Settings saved' : response.message),
          backgroundColor: response.success ? AppTheme.success : AppTheme.error,
        ),
      );
    }
  }

  void _showMethodDialog({int? index}) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(
        text: index != null ? _paymentMethods[index]['name'] : '');
    final detailsCtrl = TextEditingController(
        text: index != null ? _paymentMethods[index]['details'] : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index == null
            ? l10n.translate('add_payment_method')
            : l10n.translate('edit_payment_method')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InputField(
              controller: nameCtrl,
              label: l10n.translate('payment_method_name'),
              prefixIcon: Icons.payment,
            ),
            const SizedBox(height: 16),
            InputField(
              controller: detailsCtrl,
              label: l10n.translate('payment_details'),
              prefixIcon: Icons.info_outline,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || detailsCtrl.text.trim().isEmpty) {
                return;
              }
              setState(() {
                if (index == null) {
                  _paymentMethods.add({
                    'name': nameCtrl.text.trim(),
                    'details': detailsCtrl.text.trim(),
                  });
                } else {
                  _paymentMethods[index] = {
                    'name': nameCtrl.text.trim(),
                    'details': detailsCtrl.text.trim(),
                  };
                }
              });
              Navigator.pop(context);
              _saveSettings();
            },
            child: Text(l10n.translate('confirm')),
          ),
        ],
      ),
    );
  }

  void _deleteMethod(int index) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('confirm')),
        content: Text(l10n.translate('delete_payment_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              setState(() {
                _paymentMethods.removeAt(index);
              });
              Navigator.pop(context);
              _saveSettings();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('payment_settings')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _paymentMethods.isEmpty
              ? _buildEmptyState(l10n)
              : _buildList(l10n),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMethodDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment, size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(l10n.translate('no_payment_methods')),
          const SizedBox(height: 24),
          PrimaryButton(
            text: l10n.translate('add_payment_method'),
            onPressed: () => _showMethodDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AppLocalizations l10n) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _paymentMethods.length,
      itemBuilder: (context, index) {
        final method = _paymentMethods[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: ListTile(
              title: Text(method['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(method['details'] ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppTheme.primary),
                    onPressed: () => _showMethodDialog(index: index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppTheme.error),
                    onPressed: () => _deleteMethod(index),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

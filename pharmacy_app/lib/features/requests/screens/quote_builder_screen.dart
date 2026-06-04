import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/input_field.dart';
import '../../../providers/prescription_provider.dart';
import '../../../services/pharmacy_service.dart';
import '../../../core/localization/app_localizations.dart';

class QuoteBuilderScreen extends StatefulWidget {
  final dynamic prescription;

  const QuoteBuilderScreen({super.key, required this.prescription});

  @override
  State<QuoteBuilderScreen> createState() => _QuoteBuilderScreenState();
}

class _QuoteBuilderScreenState extends State<QuoteBuilderScreen> {
  final List<Map<String, dynamic>> _items = [];
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _qtyControllers = [];
  final List<TextEditingController> _priceControllers = [];
  final TextEditingController _directTotalController = TextEditingController();

  bool _isEdit = false;
  bool _isLoading = false;
  bool _isDirectMode = false;

  List<Map<String, String>> _paymentMethods = [];
  Map<String, String>? _selectedPaymentMethod;
  bool _isLoadingPayments = false;

  @override
  void initState() {
    super.initState();
    _loadExistingQuote();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoadingPayments = true);
    final response = await PharmacyService.getPaymentSettings();
    if (response.success && response.data != null) {
      setState(() {
        _paymentMethods = List<Map<String, dynamic>>.from(response.data)
            .map((e) => e.map((key, value) => MapEntry(key, value.toString())))
            .toList();
        
        if (_paymentMethods.isNotEmpty) {
          _selectedPaymentMethod = _paymentMethods.first;
        }
      });
    }
    setState(() => _isLoadingPayments = false);
  }

  @override
  void dispose() {
    for (final c in _nameControllers) c.dispose();
    for (final c in _qtyControllers) c.dispose();
    for (final c in _priceControllers) c.dispose();
    _directTotalController.dispose();
    super.dispose();
  }

  void _loadExistingQuote() {
    final existingQuote = widget.prescription is Map
        ? widget.prescription['existingQuote']
        : null;

    if (existingQuote != null) {
      _isEdit = true;
      final items = existingQuote['items'] as List? ?? [];
      for (final item in items) {
        _addItemWithValues(
          name: item['medicineName']?.toString() ?? '',
          qty: (item['quantity'] ?? 1).toString(),
          price: (item['unitPrice'] ?? 0).toString(),
        );
      }
    }
  }

  void _addItem() => _addItemWithValues(name: '', qty: '1', price: '0');

  void _addItemWithValues({
    required String name,
    required String qty,
    required String price,
  }) {
    final nameCtrl = TextEditingController(text: name);
    final qtyCtrl = TextEditingController(text: qty);
    final priceCtrl = TextEditingController(text: price);

    final q = int.tryParse(qty) ?? 1;
    final p = double.tryParse(price) ?? 0.0;

    setState(() {
      _nameControllers.add(nameCtrl);
      _qtyControllers.add(qtyCtrl);
      _priceControllers.add(priceCtrl);
      _items.add({
        'medicineName': name,
        'quantity': q,
        'unitPrice': p,
        'totalPrice': q * p,
      });
    });
  }

  void _removeItem(int index) {
    _nameControllers[index].dispose();
    _qtyControllers[index].dispose();
    _priceControllers[index].dispose();
    setState(() {
      _nameControllers.removeAt(index);
      _qtyControllers.removeAt(index);
      _priceControllers.removeAt(index);
      _items.removeAt(index);
    });
  }

  void _updateItem(int index) {
    final q = int.tryParse(_qtyControllers[index].text) ?? 1;
    final p = double.tryParse(_priceControllers[index].text) ?? 0.0;
    setState(() {
      _items[index]['medicineName'] = _nameControllers[index].text;
      _items[index]['quantity'] = q;
      _items[index]['unitPrice'] = p;
      _items[index]['totalPrice'] = q * p;
    });
  }

  double get _subtotal =>
      _items.fold(0, (sum, item) => sum + (item['totalPrice'] as num).toDouble());

  double get _total => _subtotal;

  Future<void> _submit() async {
    List<Map<String, dynamic>> itemsToSend;

    if (_isDirectMode) {
      final total = double.tryParse(_directTotalController.text.trim());
      if (total == null || total <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid total amount')),
        );
        return;
      }
      itemsToSend = [
        {
          'medicineName': 'Total',
          'quantity': 1,
          'unitPrice': total,
          'totalPrice': total,
        }
      ];
    } else {
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one item')),
        );
        return;
      }
      for (int i = 0; i < _items.length; i++) {
        if (_items[i]['medicineName'].toString().trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Enter medicine name for item ${i + 1}')),
          );
          return;
        }
      }
      itemsToSend = List<Map<String, dynamic>>.from(_items);
    }

    setState(() => _isLoading = true);

    final prescriptionId = (widget.prescription is Map
            ? widget.prescription['id']
            : widget.prescription.id)
        .toString();

    final success = await context.read<PrescriptionProvider>().sendQuote(
          prescriptionId: prescriptionId,
          items: itemsToSend,
          deliveryFee: 0,
          paymentMethod: _selectedPaymentMethod!,
        );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit
              ? 'Quote updated successfully!'
              : 'Quote sent successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Quote' : 'Send Quote'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isEdit)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_note, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You already sent a quote. Edit and update it below.',
                        style: TextStyle(
                            color: Colors.blue.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Mode toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isDirectMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isDirectMode ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.list_alt,
                                size: 16,
                                color: !_isDirectMode ? Colors.white : AppTheme.textSecondary),
                            const SizedBox(width: 6),
                            Text('Itemized',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: !_isDirectMode ? Colors.white : AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isDirectMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isDirectMode ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.attach_money,
                                size: 16,
                                color: _isDirectMode ? Colors.white : AppTheme.textSecondary),
                            const SizedBox(width: 6),
                            Text('Direct Total',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _isDirectMode ? Colors.white : AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),

            if (_isDirectMode) ..._buildDirectTotalSection()
            else ...[
              Text('Medicines', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppTheme.spacing16),

              ..._items.asMap().entries.map((entry) =>
                  _buildItemCard(entry.key)),

              const SizedBox(height: AppTheme.spacing12),
              OutlinedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Add Medicine'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
              ),

              const SizedBox(height: AppTheme.spacing24),

              _buildSummary(),
            ],
            const SizedBox(height: AppTheme.spacing24),

            _buildPaymentSelection(),

            const SizedBox(height: AppTheme.spacing24),

            PrimaryButton(
              text: _isEdit ? 'Update Quote' : 'Send Quote',
              icon: _isEdit ? Icons.update : Icons.send,
              onPressed: (_isLoading || _selectedPaymentMethod == null) ? null : _submit,
              isLoading: _isLoading,
            ),
            const SizedBox(height: AppTheme.spacing16),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDirectTotalSection() {
    return [
      AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Enter Total Amount',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: AppTheme.spacing12),
              const Text(
                'Enter the total price for all medicines in this order.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppTheme.spacing16),
              InputField(
                controller: _directTotalController,
                label: 'Total Amount (MAD)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              if ((_directTotalController.text.trim().isNotEmpty) &&
                  (double.tryParse(_directTotalController.text.trim()) ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '${double.parse(_directTotalController.text.trim()).toStringAsFixed(2)} MAD',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildItemCard(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Medicine ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                    onPressed: () => _removeItem(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing8),
              InputField(
                controller: _nameControllers[index],
                label: 'Medicine Name',
                onChanged: (_) => _updateItem(index),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Row(
                children: [
                  Expanded(
                    child: InputField(
                      controller: _qtyControllers[index],
                      label: 'Qty',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updateItem(index),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: InputField(
                      controller: _priceControllers[index],
                      label: 'Unit Price',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updateItem(index),
                    ),
                  ),
                ],
              ),
              if ((_items[index]['totalPrice'] as num) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Total: ${(_items[index]['totalPrice'] as num).toStringAsFixed(2)} MAD',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          children: [
            _summaryRow('Total', _total, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: isTotal
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.bodyMedium),
          Text(
            '${amount.toStringAsFixed(2)} MAD',
            style: isTotal
                ? Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.primary)
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSelection() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoadingPayments) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_paymentMethods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
            const SizedBox(height: 8),
            Text(
              l10n.translate('no_payment_methods'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/payment-settings');
                _loadPaymentMethods();
              },
              child: Text(l10n.translate('payment_settings')),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('select_payment_method'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._paymentMethods.map((method) {
          final isSelected = _selectedPaymentMethod == method;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedPaymentMethod = method),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary.withOpacity(0.05) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(method['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(method['details'] ?? '',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

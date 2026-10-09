import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/input_field.dart';
import '../../../providers/prescription_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/pharmacy_service.dart';
import '../../profile/payment_settings_screen.dart';

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
  // Direct Total is the default: the pharmacy just types the total amount.
  // Itemized entry stays available as an optional mode.
  bool _isDirectMode = true;

  // Fee breakdown (commission + delivery) fetched from the backend so the
  // pharmacy can preview what the patient will pay.
  double _commissionRate = 0;
  double _minCommission = 0;
  double _deliveryFee = 0;
  bool _previewLoaded = false;

  // Payment methods saved in Payment Settings; the pharmacy ticks which ones
  // this quote accepts
  List<Map<String, String>> _savedMethods = [];
  final Set<int> _selectedMethods = {};
  bool _methodsLoaded = false;
  // Payment details of the quote being edited, to pre-tick its methods
  String _existingPaymentDetails = '';

  @override
  void initState() {
    super.initState();
    _loadExistingQuote();
    _loadPreview();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    final res = await PharmacyService.getPaymentSettings();
    if (!mounted) return;
    final methods = res.success && res.data is List
        ? (res.data as List)
            .map((m) => {
                  'name': (m['name'] ?? '').toString(),
                  'details': (m['details'] ?? '').toString(),
                })
            .toList()
        : <Map<String, String>>[];
    setState(() {
      _savedMethods = methods;
      _selectedMethods.clear();
      // Editing: tick the methods the quote already had. New quote (or no
      // match): tick them all.
      for (var i = 0; i < methods.length; i++) {
        if (_existingPaymentDetails.contains(_methodLine(methods[i]))) {
          _selectedMethods.add(i);
        }
      }
      if (_selectedMethods.isEmpty) {
        _selectedMethods.addAll(List.generate(methods.length, (i) => i));
      }
      _methodsLoaded = true;
    });
  }

  String _methodLine(Map<String, String> m) => '${m['name']}: ${m['details']}';

  Future<void> _openPaymentSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentSettingsScreen()),
    );
    if (mounted) _loadPaymentMethods();
  }

  Future<void> _loadPreview() async {
    final prescriptionId = (widget.prescription is Map
            ? widget.prescription['id']
            : widget.prescription.id)
        .toString();
    final res = await ApiService.get(
        '/pharmacy/quote-preview?prescriptionId=$prescriptionId');
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() {
        _commissionRate = (res.data['commissionRate'] as num?)?.toDouble() ?? 0;
        _minCommission = (res.data['minCommission'] as num?)?.toDouble() ?? 0;
        _deliveryFee = (res.data['deliveryFee'] as num?)?.toDouble() ?? 0;
        _previewLoaded = true;
      });
    }
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
      final pm = existingQuote['paymentMethod'];
      if (pm is Map) _existingPaymentDetails = pm['details']?.toString() ?? '';
      final items = existingQuote['items'] as List? ?? [];

      // A direct-total quote is stored as a single "Total" item; load it back
      // into Direct Total mode instead of showing it as an itemized row.
      final isDirectQuote = items.length == 1 &&
          (items.first['medicineName']?.toString() ?? '') == 'Total';

      if (isDirectQuote) {
        _isDirectMode = true;
        final total = (items.first['unitPrice'] ?? 0) as num;
        _directTotalController.text =
            total % 1 == 0 ? total.toInt().toString() : total.toString();
      } else if (items.isNotEmpty) {
        _isDirectMode = false;
        for (final item in items) {
          _addItemWithValues(
            name: item['medicineName']?.toString() ?? '',
            qty: (item['quantity'] ?? 1).toString(),
            price: (item['unitPrice'] ?? 0).toString(),
          );
        }
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

  // Medicine subtotal for whichever mode is active.
  double get _currentSubtotal => _isDirectMode
      ? (double.tryParse(_directTotalController.text.trim()) ?? 0)
      : _subtotal;

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
          paymentMethod: _selectedPaymentMethod(),
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

            _buildBreakdown(),

            const SizedBox(height: AppTheme.spacing24),

            PrimaryButton(
              text: _isEdit ? 'Update Quote' : 'Send Quote',
              icon: _isEdit ? Icons.update : Icons.send,
              onPressed: (_isLoading || _selectedMethods.isEmpty) ? null : _submit,
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
                label: 'Total Amount (MRO)',
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
                        '${double.parse(_directTotalController.text.trim()).toStringAsFixed(2)} MRO',
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
                    'Total: ${(_items[index]['totalPrice'] as num).toStringAsFixed(2)} MRO',
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

  // Fee breakdown card: medicine subtotal + service (platform) fee + delivery
  // fee => total the patient will pay.
  Widget _buildBreakdown() {
    final subtotal = _currentSubtotal;
    if (subtotal <= 0) return const SizedBox.shrink();

    // Service fee = max(minimum commission, rate% of medicines).
    final pct = subtotal * _commissionRate / 100;
    final serviceFee = pct > _minCommission ? pct : _minCommission;
    final total = subtotal + serviceFee + _deliveryFee;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('Quote Details',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            _summaryRow('Medicine (Subtotal)', subtotal),
            _summaryRow('Service Fee', serviceFee),
            _summaryRow('Delivery Fee', _deliveryFee),
            const Divider(height: 20),
            _summaryRow('Total', total, isTotal: true),
            if (!_previewLoaded)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Calculating fees…',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
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
            '${amount.toStringAsFixed(2)} MRO',
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

  // The ticked methods as the quote's single payment method: names joined,
  // and one "Name: details" line each, which the patient app shows as is
  Map<String, String> _selectedPaymentMethod() {
    final chosen = (_selectedMethods.toList()..sort())
        .map((i) => _savedMethods[i])
        .toList();
    return {
      'name': chosen.map((m) => m['name']).join(', '),
      'details': chosen.map(_methodLine).join('\n'),
    };
  }

  Widget _buildPaymentSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Payment Methods',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (_savedMethods.isNotEmpty)
              TextButton.icon(
                onPressed: _openPaymentSettings,
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Manage'),
              ),
          ],
        ),
        if (_savedMethods.isNotEmpty)
          Text('Select the methods the patient can pay with',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        if (!_methodsLoaded)
          const Center(child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ))
        else if (_savedMethods.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      size: 36, color: AppTheme.textSecondary),
                  const SizedBox(height: 8),
                  const Text('No payment methods saved yet',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Add one in Payment Settings to send quotes.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openPaymentSettings,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Payment Method'),
                  ),
                ],
              ),
            ),
          )
        else
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < _savedMethods.length; i++)
                  CheckboxListTile(
                    value: _selectedMethods.contains(i),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selectedMethods.add(i);
                      } else {
                        _selectedMethods.remove(i);
                      }
                    }),
                    activeColor: AppTheme.primary,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(_savedMethods[i]['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_savedMethods[i]['details'] ?? ''),
                  ),
              ],
            ),
          ),
        if (_methodsLoaded && _savedMethods.isNotEmpty && _selectedMethods.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Select at least one payment method',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.error)),
          ),
      ],
    );
  }
}

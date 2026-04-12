import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_button.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../sync/presentation/providers/sync_provider.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../providers/expense_provider.dart';
import '../services/expense_category_suggestion_service.dart';
import '../services/receipt_ocr_service.dart';
import '../services/receipt_upload_service.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/recurring_section_widget.dart';

class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage({super.key});

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _picker = ImagePicker();
  ExpenseCategory _category = ExpenseCategory.food;
  DateTime _date = DateTime.now();
  bool _isIncome = false;
  bool _isLoading = false;
  bool _isScanningReceipt = false;
  bool _isRecurring = false;
  int _recurringDueDay = DateTime.now().day;
  bool _categoryLockedByUser = false;
  RecurringFrequency _recurringFrequency = RecurringFrequency.monthly;
  ExpenseCategory? _suggestedCategory;
  String? _receiptImageBase64;
  String? _receiptImageMimeType;
  String? _receiptImageUrl;
  String? _receiptStorageKey;
  String? _receiptOcrText;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        if (_isRecurring && _recurringFrequency == RecurringFrequency.monthly) {
          _recurringDueDay = picked.day.clamp(1, 31);
        }
      });
    }
  }

  void _pickCategory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryPickerSheet(
        selected: _category,
        onSelected: (cat) => setState(() {
          _category = cat;
          _categoryLockedByUser = true;
        }),
      ),
    );
  }

  void _onDescriptionChanged(String value) {
    final suggestion = ExpenseCategorySuggestionService.infer(value);
    setState(() {
      _suggestedCategory = suggestion;
      if (!_categoryLockedByUser && suggestion != null) {
        _category = suggestion;
      }
    });
  }

  void _applySuggestedCategory() {
    final suggestion = _suggestedCategory;
    if (suggestion == null) return;
    setState(() {
      _category = suggestion;
      _categoryLockedByUser = true;
    });
  }

  Future<void> _pickReceiptSource() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scan with Camera'),
              onTap: () {
                Navigator.of(ctx).pop();
                _attachReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(ctx).pop();
                _attachReceipt(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _attachReceipt(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1440,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.length > 1500000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Receipt image is too large. Please choose a smaller image.'),
        ),
      );
      return;
    }

    final mimeType = _guessMimeType(file.name);
    try {
      final uploaded = await ReceiptUploadService.uploadReceipt(
        dio: ref.read(dioProvider),
        bytes: bytes,
        fileName: file.name,
        mimeType: mimeType,
      );
      if (!mounted) return;

      setState(() {
        _receiptImageBase64 = null;
        _receiptImageMimeType = uploaded.receiptImageMimeType ?? mimeType;
        _receiptImageUrl = uploaded.receiptImageUrl;
        _receiptStorageKey = uploaded.receiptStorageKey;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _receiptImageBase64 = base64Encode(bytes);
        _receiptImageMimeType = mimeType;
        _receiptImageUrl = null;
        _receiptStorageKey = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Receipt upload unavailable right now. Using embedded fallback.',
          ),
        ),
      );
    }

    await _runReceiptOcr(file.path);
  }

  Future<void> _runReceiptOcr(String imagePath) async {
    setState(() => _isScanningReceipt = true);
    final result = await ReceiptOcrService.scanFromImagePath(imagePath);
    if (!mounted) return;

    if (result == null) {
      setState(() => _isScanningReceipt = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No readable text found on this receipt.')),
      );
      return;
    }

    setState(() {
      _receiptOcrText = result.rawText;
      if (_amountCtrl.text.trim().isEmpty && result.detectedAmount != null) {
        _amountCtrl.text = result.detectedAmount!.toStringAsFixed(2);
      }
      if (_descCtrl.text.trim().isEmpty && result.detectedMerchant != null) {
        _descCtrl.text = result.detectedMerchant!;
      }
      if (result.detectedDate != null) {
        _date = result.detectedDate!;
      }
      _isScanningReceipt = false;
    });
    _onDescriptionChanged(_descCtrl.text);
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  Future<void> _save() async {
    final amtError = Validators.amount(_amountCtrl.text);
    final descError = Validators.required(_descCtrl.text, 'Description');
    if (amtError != null || descError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(amtError ?? descError!)));
      return;
    }

    // Capture notifiers BEFORE any await — prevents "ref after widget disposed"
    final expenseNotifier = ref.read(expenseProvider.notifier);
    final syncNotifier = ref.read(syncProvider.notifier);

    setState(() => _isLoading = true);
    await expenseNotifier.addExpense(
      amount: double.parse(_amountCtrl.text.replaceAll(',', '')),
      description: _descCtrl.text.trim(),
      category: _category,
      date: _date,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text.trim(),
      recurringDueDay:
          _isRecurring && _recurringFrequency == RecurringFrequency.monthly
              ? _recurringDueDay
              : null,
      receiptImageBase64: _receiptImageBase64,
      receiptImageMimeType: _receiptImageMimeType,
      receiptImageUrl: _receiptImageUrl,
      receiptStorageKey: _receiptStorageKey,
      receiptOcrText: _receiptOcrText,
      isIncome: _isIncome,
      isRecurring: _isRecurring,
      recurringFrequency: _isRecurring ? _recurringFrequency : null,
    );
    // Debounced sync prevents heavy full-sync after every single save.
    syncNotifier.scheduleSync(reason: 'expense-created');
    if (mounted) {
      setState(() => _isLoading = false);
      HapticFeedback.lightImpact();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
        backgroundColor: colorScheme.surfaceContainerLow,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Add Transaction'),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: R.s(12)),
              child: TextButton(
                onPressed: _isLoading ? null : _save,
                child: Text(
                  'Save',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: R.t(16)),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
            padding: EdgeInsets.all(R.s(20)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Expense / Income toggle
                    Container(
                      padding: EdgeInsets.all(R.xs),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(R.s(12)),
                      ),
                      child: Row(
                        children: [
                          _TypeTab(
                            label: '💸  Expense',
                            selected: !_isIncome,
                            onTap: () => setState(() => _isIncome = false),
                          ),
                          _TypeTab(
                            label: '💰  Income',
                            selected: _isIncome,
                            onTap: () => setState(() => _isIncome = true),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                    SizedBox(height: R.s(28)),
                    // Amount input (large)
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'AMOUNT',
                            style: TextStyle(
                              fontSize: R.t(11),
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTertiary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: R.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₹',
                                style: TextStyle(
                                  fontSize: R.t(28),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(width: R.xs),
                              IntrinsicWidth(
                                child: TextField(
                                  controller: _amountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[\d.]')),
                                  ],
                                  autofocus: true,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: R.t(48),
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    height: 1.1,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: TextStyle(
                                      fontSize: R.t(48),
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDisabled,
                                      height: 1.1,
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate(delay: 50.ms).fadeIn(duration: 300.ms),
                    SizedBox(height: R.xl),
                    const Divider(color: AppColors.border),
                    SizedBox(height: R.lg),
                    // Description
                    _fieldLabel('DESCRIPTION'),
                    SizedBox(height: R.sm),
                    TextField(
                      controller: _descCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      onChanged: _onDescriptionChanged,
                      style: TextStyle(
                        fontSize: R.t(16),
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      decoration:
                          _fieldDecoration('e.g. Dinner at Mainland China'),
                    ).animate(delay: 100.ms).fadeIn(duration: 300.ms),
                    if (_suggestedCategory != null) ...[
                      SizedBox(height: R.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: R.s(14),
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: R.xs),
                          Expanded(
                            child: Text(
                              'Suggested category: ${_suggestedCategory!.label}',
                              style: TextStyle(
                                fontSize: R.t(12),
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (_suggestedCategory != _category)
                            TextButton(
                              onPressed: _applySuggestedCategory,
                              child: const Text('Use'),
                            ),
                        ],
                      ),
                    ],
                    SizedBox(height: R.s(20)),
                    // Category
                    _fieldLabel('CATEGORY'),
                    SizedBox(height: R.sm),
                    GestureDetector(
                      onTap: _pickCategory,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: R.md,
                          vertical: R.s(14),
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(R.s(14)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: R.s(36),
                              height: R.s(36),
                              decoration: BoxDecoration(
                                color: _category.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(R.sm),
                              ),
                              child: Center(
                                child: Text(
                                  _category.emoji,
                                  style: TextStyle(fontSize: R.t(18)),
                                ),
                              ),
                            ),
                            SizedBox(width: R.s(12)),
                            Expanded(
                              child: Text(
                                _category.label,
                                style: TextStyle(
                                  fontSize: R.t(15),
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ).animate(delay: 150.ms).fadeIn(duration: 300.ms),
                    SizedBox(height: R.s(20)),
                    // Date
                    _fieldLabel('DATE'),
                    SizedBox(height: R.sm),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: R.md,
                          vertical: R.s(14),
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(R.s(14)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: R.s(20),
                              color: AppColors.textTertiary,
                            ),
                            SizedBox(width: R.s(12)),
                            Expanded(
                              child: Text(
                                _date.relativeLabel == 'Today'
                                    ? 'Today, ${_date.formattedDate}'
                                    : _date.formattedDate,
                                style: TextStyle(
                                  fontSize: R.t(15),
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
                    SizedBox(height: R.s(20)),
                    // Note (optional)
                    _fieldLabel('NOTE (OPTIONAL)'),
                    SizedBox(height: R.sm),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        fontSize: R.t(15),
                        color: AppColors.textPrimary,
                      ),
                      decoration: _fieldDecoration('Add a note...'),
                    ).animate(delay: 250.ms).fadeIn(duration: 300.ms),
                    SizedBox(height: R.s(20)),
                    _fieldLabel('RECEIPT (OPTIONAL)'),
                    SizedBox(height: R.sm),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(R.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(R.s(14)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_receiptImageBase64 != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(R.s(10)),
                              child: Image.memory(
                                base64Decode(_receiptImageBase64!),
                                height: R.s(180),
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          if (_receiptImageBase64 == null &&
                              _receiptImageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(R.s(10)),
                              child: Image.network(
                                _receiptImageUrl!,
                                height: R.s(180),
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: R.s(180),
                                  width: double.infinity,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHigh,
                                  alignment: Alignment.center,
                                  child:
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          if (_receiptImageBase64 != null ||
                              _receiptImageUrl != null)
                            SizedBox(height: R.sm),
                          Wrap(
                            spacing: R.s(10),
                            runSpacing: R.s(10),
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickReceiptSource,
                                icon: Icon(
                                  (_receiptImageBase64 == null &&
                                          _receiptImageUrl == null)
                                      ? Icons.attach_file_rounded
                                      : Icons.refresh_rounded,
                                  size: R.s(16),
                                ),
                                label: Text(
                                  (_receiptImageBase64 == null &&
                                          _receiptImageUrl == null)
                                      ? 'Attach Receipt'
                                      : 'Replace Receipt',
                                ),
                              ),
                              if (_receiptImageBase64 != null ||
                                  _receiptImageUrl != null)
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _receiptImageBase64 = null;
                                      _receiptImageMimeType = null;
                                      _receiptImageUrl = null;
                                      _receiptStorageKey = null;
                                      _receiptOcrText = null;
                                    });
                                  },
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: R.s(16),
                                  ),
                                  label: const Text('Remove'),
                                ),
                            ],
                          ),
                          if (_isScanningReceipt) ...[
                            SizedBox(height: R.sm),
                            const LinearProgressIndicator(minHeight: 3),
                            SizedBox(height: R.xs),
                            Text(
                              'Scanning receipt text...',
                              style: TextStyle(
                                fontSize: R.t(12),
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (_receiptOcrText != null &&
                              _receiptOcrText!.isNotEmpty) ...[
                            SizedBox(height: R.sm),
                            Text(
                              'OCR captured and attached to this expense.',
                              style: TextStyle(
                                fontSize: R.t(12),
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ).animate(delay: 275.ms).fadeIn(duration: 300.ms),
                    if (!_isIncome &&
                        !_isRecurring &&
                        ExpenseCategorySuggestionService.isBillLike(
                          _category,
                        )) ...[
                      SizedBox(height: R.sm),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(R.sm),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(R.s(12)),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_active_outlined,
                              size: R.s(16),
                              color: AppColors.warning,
                            ),
                            SizedBox(width: R.xs),
                            Expanded(
                              child: Text(
                                'Turn on recurring to get bill due reminders.',
                                style: TextStyle(
                                  fontSize: R.t(12),
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _isRecurring = true;
                              }),
                              child: const Text('Enable'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: R.xl),
                    RecurringSectionWidget(
                      isRecurring: _isRecurring,
                      frequency: _recurringFrequency,
                      monthlyDueDay: _recurringDueDay,
                      onToggle: (v) => setState(() {
                        _isRecurring = v;
                        if (v &&
                            _recurringFrequency == RecurringFrequency.monthly) {
                          _recurringDueDay = _date.day.clamp(1, 31);
                        }
                      }),
                      onFrequency: (f) => setState(() {
                        _recurringFrequency = f;
                        if (f == RecurringFrequency.monthly) {
                          _recurringDueDay = _date.day.clamp(1, 31);
                        }
                      }),
                      onMonthlyDueDayChanged: (day) =>
                          setState(() => _recurringDueDay = day),
                      delayMs: 275,
                    ),
                    SizedBox(height: R.xl),
                    DSButton(
                      label: _isLoading
                          ? 'Saving...'
                          : _isIncome
                              ? 'Add Income'
                              : 'Add Expense',
                      onPressed: _isLoading ? null : _save,
                      isLoading: _isLoading,
                    ).animate(delay: 320.ms).fadeIn(duration: 300.ms),
                    SizedBox(height: R.s(20)),
                  ],
                ),
              ),
            )));
  }

  Widget _fieldLabel(String label) => Text(
        label,
        style: TextStyle(
          fontSize: R.t(11),
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
          letterSpacing: 1.2,
        ),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.s(14)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.s(14)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.s(14)),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: R.md, vertical: R.s(14)),
      );
}

class _TypeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: R.s(10)),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(R.s(10)),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: R.xs,
                      offset: Offset(0, R.s(2)),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: R.t(14),
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

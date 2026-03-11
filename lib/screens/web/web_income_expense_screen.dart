import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../models/income_expense_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';

/// Web-optimized Income/Expense screen for the Owner/Manager Dashboard.
class WebIncomeExpenseScreen extends StatefulWidget {
  final String? siteId;
  final VoidCallback? onBack;
  const WebIncomeExpenseScreen({super.key, this.siteId, this.onBack});

  @override
  State<WebIncomeExpenseScreen> createState() => _WebIncomeExpenseScreenState();
}

class _WebIncomeExpenseScreenState extends State<WebIncomeExpenseScreen> {
  List<IncomeExpense> _transactions = [];
  List<Map<String, dynamic>> _mySites = [];
  bool _isLoading = true;
  
  // Filters
  int? _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  String? _selectedSiteId;
  TransactionType? _filterType; // null means "All"
  String _searchQuery = '';

  final List<int> _years = List.generate(5, (index) => DateTime.now().year - index);
  final List<int> _months = List.generate(12, (index) => index + 1);

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.siteId;
    _initScreen();
  }

  Future<void> _initScreen() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser?.role == UserRole.systemOwner) {
      await _fetchMySites();
    }
    await _fetchTransactions();
  }

  Future<void> _fetchMySites() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await SupabaseService.client
          .from('sites')
          .select('id, name')
          .eq('owner_id', authService.currentUser!.id)
          .filter('deleted_at', 'is', null);
      
      if (mounted) {
        setState(() {
          _mySites = List<Map<String, dynamic>>.from(response as List);
        });
      }
    } catch (e) {
      debugPrint('Error fetching sites: $e');
    }
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      var query = SupabaseService.client
          .from('income_expense')
          .select();

      if (_selectedSiteId != null) {
        query = query.eq('site_id', _selectedSiteId as String);
      } else if (user?.role == UserRole.systemOwner) {
        final siteIds = _mySites.map((s) => s['id'] as String).toList();
        if (siteIds.isNotEmpty) {
          query = query.inFilter('site_id', siteIds);
        } else {
          setState(() {
            _transactions = [];
            _isLoading = false;
          });
          return;
        }
      }

      if (_selectedYear != null) {
        final start = DateTime(_selectedYear!, _selectedMonth ?? 1, 1).toUtc().toIso8601String();
        final end = DateTime(_selectedYear!, (_selectedMonth ?? 12) + 1, 0, 23, 59, 59).toUtc().toIso8601String();
        query = query.gte('transaction_date', start).lte('transaction_date', end);
      }

      final response = await query.order('transaction_date', ascending: false);
      
      final List<IncomeExpense> loaded = (response as List)
          .map((json) => IncomeExpense.fromMap(json))
          .toList();

      if (mounted) {
        setState(() {
          _transactions = loaded;
        });
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ──── Calculated Stats ────

  double get _totalIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amount);

  double get _totalExpense => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amount);

  double get _totalBalance => _totalIncome - _totalExpense;

  List<IncomeExpense> get _filteredTransactions {
    var list = _transactions.toList();
    if (_filterType != null) {
      list = list.where((t) => t.type == _filterType).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) => t.title.toLowerCase().contains(q) || (t.description?.toLowerCase() ?? '').contains(q)).toList();
    }
    return list;
  }

  // ──── Transaction Dialog ────

  Future<void> _showTransactionDialog({IncomeExpense? transaction}) async {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final textColor = isModern ? Colors.white : AppColors.mgmtTextHeading;
    final subtextColor = isModern ? Colors.white70 : AppColors.mgmtTextBody;
    final primaryColor = isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary;

    final titleController = TextEditingController(text: transaction?.title);
    final amountController = TextEditingController(text: transaction?.amount.toStringAsFixed(0));
    final descController = TextEditingController(text: transaction?.description);
    TransactionType selectedType = transaction?.type ?? TransactionType.income;
    String? selectedSiteIdForNew = transaction?.siteId ?? _selectedSiteId ?? (widget.siteId);
    DateTime selectedDate = transaction?.date ?? DateTime.now();
    bool isEditing = transaction != null;
    bool isSubmitting = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          return AlertDialog(
            backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(isEditing ? Icons.edit_note_rounded : Icons.add_card_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEditing ? 'İşlemi Düzenle' : l10n.addNewRecord, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18)),
                    Text(
                      isEditing ? 'İşlem detaylarını güncelle' : 'Yeni bir gelir veya gider kaydı oluşturun',
                      style: TextStyle(fontSize: 12, color: subtextColor, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close, color: subtextColor, size: 20)),
            ]),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Type Selector
                    SegmentedButton<TransactionType>(
                      segments: [
                        ButtonSegment(value: TransactionType.income, label: Text(l10n.income), icon: const Icon(Icons.add_circle_outline, size: 18)),
                        ButtonSegment(value: TransactionType.expense, label: Text(l10n.expense), icon: const Icon(Icons.remove_circle_outline, size: 18)),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: isSubmitting ? null : (val) => setDState(() => selectedType = val.first),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(WidgetState.selected)) return selectedType == TransactionType.income ? Colors.teal.withOpacity(0.2) : Colors.red.withOpacity(0.2);
                          return isModern ? Colors.black26 : Colors.grey.withOpacity(0.05);
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(WidgetState.selected)) return selectedType == TransactionType.income ? Colors.tealAccent : Colors.redAccent;
                          return subtextColor;
                        }),
                        side: WidgetStateProperty.all(BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Site Selector
                    if (_mySites.isNotEmpty)
                      _buildDialogDropdown<String?>(
                        value: selectedSiteIdForNew,
                        label: 'Site',
                        icon: Icons.business_outlined,
                        isModern: isModern,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        primaryColor: primaryColor,
                        items: _mySites.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? '', style: TextStyle(fontSize: 14, color: textColor)))).toList(),
                        onChanged: isSubmitting ? null : (val) => setDState(() => selectedSiteIdForNew = val),
                      ),
                    const SizedBox(height: 14),
                    _buildDialogField(
                      controller: titleController,
                      label: l10n.titleLabel,
                      icon: Icons.title_rounded,
                      isModern: isModern,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      primaryColor: primaryColor,
                      enabled: !isSubmitting,
                    ),
                    const SizedBox(height: 14),
                    _buildDialogField(
                      controller: amountController,
                      label: '${l10n.amountLabel} (TL)',
                      icon: Icons.payments_outlined,
                      isModern: isModern,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      primaryColor: primaryColor,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    _buildDialogField(
                      controller: descController,
                      label: l10n.descriptionLabel,
                      icon: Icons.description_outlined,
                      isModern: isModern,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      primaryColor: primaryColor,
                      enabled: !isSubmitting,
                    ),
                    const SizedBox(height: 14),
                    // Date picker
                    InkWell(
                      onTap: isSubmitting ? null : () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDState(() => selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 18, color: primaryColor),
                            const SizedBox(width: 12),
                            Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: TextStyle(color: textColor, fontSize: 14)),
                            const Spacer(),
                            Icon(Icons.edit_calendar_rounded, size: 18, color: subtextColor),
                          ],
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel, style: TextStyle(color: subtextColor))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: isSubmitting ? null : () async {
                  if (titleController.text.trim().isEmpty || amountController.text.trim().isEmpty || selectedSiteIdForNew == null) {
                    setDState(() => errorMessage = 'Lütfen zorunlu alanları doldurun.');
                    return;
                  }
                  setDState(() => isSubmitting = true);
                  try {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final data = {
                      'site_id': selectedSiteIdForNew,
                      'title': titleController.text.trim(),
                      'description': descController.text.trim(),
                      'amount': double.parse(amountController.text.trim().replaceAll(',', '.')),
                      'type': selectedType == TransactionType.expense ? 'expense' : 'income',
                      'transaction_date': selectedDate.toUtc().toIso8601String(),
                      'created_by': authService.currentUser?.id,
                    };

                    if (isEditing) {
                      await SupabaseService.client.from('income_expense').update(data).eq('id', transaction!.id);
                    } else {
                      await SupabaseService.client.from('income_expense').insert(data);
                    }
                    if (mounted) Navigator.pop(ctx);
                    _fetchTransactions();
                  } catch (e) {
                    setDState(() => errorMessage = 'Hata: $e');
                  } finally {
                    setDState(() => isSubmitting = false);
                  }
                },
                child: Text(isSubmitting ? '...' : l10n.save, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ──── Delete Transaction ────

  Future<void> _deleteTransaction(IncomeExpense t) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: const Text('Bu işlemi silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete, style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.client.from('income_expense').delete().eq('id', t.id);
        _fetchTransactions();
      } catch (e) {
        debugPrint('Delete error: $e');
      }
    }
  }

  // ──── Reusable Dialog Widgets ────

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    required bool isModern,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subtextColor, fontSize: 13),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true,
        fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDialogDropdown<T>({
    required T value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required Function(T?)? onChanged,
    required bool isModern,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
      style: TextStyle(color: textColor, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subtextColor, fontSize: 13),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true,
        fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  // ──── Build ────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context).isModern;
    final textColor = isModern ? Colors.white : Colors.black87;
    final subtextColor = isModern ? Colors.white54 : Colors.black54;
    final primaryColor = isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary;
    final cardBg = isModern ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ──── Header ────
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.incomeExpense, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 4),
                      Text('Gelir ve gider işlemlerinizi yönetin ve takip edin.', style: TextStyle(color: subtextColor, fontSize: 16)),
                    ],
                  ),
                ),
                // Filters Row
                if (_mySites.isNotEmpty) ...[
                  SizedBox(
                    width: 180,
                    child: _buildHeaderDropdown<String?>(
                      value: _selectedSiteId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tüm Siteler')),
                        ..._mySites.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? ''))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedSiteId = val);
                        _fetchTransactions();
                      },
                      isModern: isModern,
                      cardBg: cardBg,
                      textColor: textColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                SizedBox(
                  width: 100,
                  child: _buildHeaderDropdown<int?>(
                    value: _selectedYear,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tüm Yıllar')),
                      ..._years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedYear = val);
                      _fetchTransactions();
                    },
                    isModern: isModern,
                    cardBg: cardBg,
                    textColor: textColor,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: _buildHeaderDropdown<int?>(
                    value: _selectedMonth,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tüm Aylar')),
                      ..._months.map((m) {
                        final names = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
                        return DropdownMenuItem(value: m, child: Text(names[m-1]));
                      }),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedMonth = val);
                      _fetchTransactions();
                    },
                    isModern: isModern,
                    cardBg: cardBg,
                    textColor: textColor,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _fetchTransactions,
                  icon: const Icon(Icons.refresh),
                  color: subtextColor,
                  tooltip: 'Yenile',
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showTransactionDialog(),
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  label: Text(l10n.addNewRecord, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ],
            ),
          ),

          // ──── Summary Cards (Clickable Filters) ────
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: Row(
              children: [
                _buildStatCard('Bakiye', '${_totalBalance.toStringAsFixed(0)} TL', Icons.account_balance_wallet_rounded, _totalBalance >= 0 ? Colors.blue : Colors.orangeAccent, isModern, cardBg, textColor, subtextColor, filterKey: null),
                const SizedBox(width: 16),
                _buildStatCard(l10n.totalIncome, '${_totalIncome.toStringAsFixed(0)} TL', Icons.trending_up_rounded, Colors.tealAccent, isModern, cardBg, textColor, subtextColor, filterKey: TransactionType.income),
                const SizedBox(width: 16),
                _buildStatCard('Toplam Gider', '${_totalExpense.toStringAsFixed(0)} TL', Icons.trending_down_rounded, Colors.pinkAccent, isModern, cardBg, textColor, subtextColor, filterKey: TransactionType.expense),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ──── Data Table ────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: subtextColor),
                            const SizedBox(height: 16),
                            Text('İşlem bulunamadı.', style: TextStyle(fontSize: 16, color: subtextColor)),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                          ),
                          child: Column(
                            children: [
                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isModern ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 44), // Icon space
                                    Expanded(flex: 3, child: Text('Başlık / Açıklama', style: _headerStyle(subtextColor))),
                                    Expanded(flex: 2, child: Text('Tarih', style: _headerStyle(subtextColor))),
                                    Expanded(flex: 2, child: Text('Tip', style: _headerStyle(subtextColor))),
                                    Expanded(flex: 2, child: Text('Tutar', style: _headerStyle(subtextColor))),
                                    const SizedBox(width: 100), // Actions
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: isModern ? Colors.white10 : Colors.black.withOpacity(0.06)),
                              // Table Body
                              Expanded(
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: _filteredTransactions.length,
                                  separatorBuilder: (_, __) => Divider(height: 1, color: isModern ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
                                  itemBuilder: (context, index) {
                                    final t = _filteredTransactions[index];
                                    return _buildTransactionRow(t, isModern, textColor, subtextColor, l10n);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(IncomeExpense t, bool isModern, Color textColor, Color subtextColor, AppLocalizations l10n) {
    final isIncome = t.type == TransactionType.income;
    final color = isIncome ? Colors.tealAccent : Colors.pinkAccent;

    return InkWell(
      onTap: () => _showTransactionDialog(transaction: t),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(isIncome ? Icons.add_rounded : Icons.remove_rounded, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                  if (t.description != null && t.description!.isNotEmpty)
                    Text(t.description!, style: TextStyle(fontSize: 12, color: subtextColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(DateFormat('dd MMM yyyy', 'tr_TR').format(t.date), style: TextStyle(fontSize: 13, color: subtextColor)),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
                  child: Text(isIncome ? 'GELİR' : 'GİDER', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${isIncome ? '+' : '-'}${t.amount.toStringAsFixed(0)} TL',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
              ),
            ),
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: subtextColor.withOpacity(0.7), size: 18),
                    onPressed: () => _showTransactionDialog(transaction: t),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: Colors.pinkAccent.withOpacity(0.7), size: 18),
                    onPressed: () => _deleteTransaction(t),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isModern, Color cardBg, Color textColor, Color subtextColor, {TransactionType? filterKey, bool isBalance = false}) {
    // Logic for isSelected: if filterKey is null, it's the balance card which is "selected" when _filterType is null
    final isSelected = (filterKey == null) ? (_filterType == null) : (_filterType == filterKey);

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _filterType = filterKey),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color.withOpacity(0.6) : (isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, spreadRadius: 0)] : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: textColor)),
                    Text(label, style: TextStyle(fontSize: 13, color: subtextColor)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?)? onChanged,
    required bool isModern,
    required Color cardBg,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isModern ? Colors.white10 : AppColors.mgmtBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style: TextStyle(color: textColor, fontSize: 13),
        ),
      ),
    );
  }

  TextStyle _headerStyle(Color color) => TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color, letterSpacing: 0.5);
}

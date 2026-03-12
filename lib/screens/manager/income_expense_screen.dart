import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import 'package:provider/provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import '../../models/income_expense_model.dart';
import '../../models/user_model.dart';
import 'package:intl/intl.dart';

class IncomeExpenseScreen extends StatefulWidget {
  final String? siteId;
  final VoidCallback? onBack;
  const IncomeExpenseScreen({super.key, this.siteId, this.onBack});

  @override
  State<IncomeExpenseScreen> createState() => _IncomeExpenseScreenState();
}

class _IncomeExpenseScreenState extends State<IncomeExpenseScreen> {
  List<IncomeExpense> _transactions = [];
  bool _isLoading = true;
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalBalance = 0;

  int? _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  String? _selectedSiteId;
  List<Map<String, dynamic>> _mySites = [];
  TransactionType? _filterType; // null means "All"

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
      
      setState(() {
        _mySites = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (e) {
      print('Error fetching sites: $e');
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
        // Fetch all transactions for all owner's sites
        final siteIds = _mySites.map((s) => s['id'] as String).toList();
        if (siteIds.isNotEmpty) {
          query = query.inFilter('site_id', siteIds);
        } else {
          // No sites, return empty
          setState(() {
            _transactions = [];
            _totalIncome = 0;
            _totalExpense = 0;
            _totalBalance = 0;
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

      double income = 0;
      double expense = 0;
      for (var t in loaded) {
        if (t.type == TransactionType.income) {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }

      setState(() {
        _transactions = loaded;
        _totalIncome = income;
        _totalExpense = expense;
        _totalBalance = income - expense;
      });
    } catch (e) {
      print('Error fetching transactions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addTransaction() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final descController = TextEditingController();
    TransactionType selectedType = TransactionType.income;
    String? selectedSiteIdForNew;
    DateTime selectedDate = DateTime.now();
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final authService = Provider.of<AuthService>(context, listen: false);
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: isModern ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                // Premium Modal Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isModern ? AppColors.primary : AppColors.mgmtAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.addNewRecord,
                              style: TextStyle(
                                color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Yeni işlem detaylarını girin',
                              style: TextStyle(
                                color: isModern ? Colors.white.withOpacity(0.5) : AppColors.mgmtTextBody,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded, color: isModern ? Colors.white70 : AppColors.mgmtTextBody, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: isModern ? Colors.white10 : Colors.grey.withOpacity(0.2)),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 24,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      children: [
                        SegmentedButton<TransactionType>(
                          segments: [
                            ButtonSegment(value: TransactionType.income, label: Text(l10n.income), icon: const Icon(Icons.add_circle_outline)),
                            ButtonSegment(value: TransactionType.expense, label: Text(l10n.expense), icon: const Icon(Icons.remove_circle_outline)),
                          ],
                          selected: {selectedType},
                          onSelectionChanged: (val) => setModalState(() => selectedType = val.first),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(WidgetState.selected)) {
                                return isModern ? AppColors.primary : AppColors.mgmtAccent;
                              }
                              return isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05);
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(WidgetState.selected)) return Colors.white;
                              return isModern ? Colors.white70 : AppColors.mgmtTextBody;
                            }),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (authService.currentUser?.role == UserRole.systemOwner && _selectedSiteId == null && widget.siteId == null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildGlassDropdown<String?>(
                              value: selectedSiteIdForNew,
                              label: 'Site Seçin *',
                              icon: Icons.business_outlined,
                              isModern: isModern,
                              items: _mySites.map((s) => DropdownMenuItem<String?>(
                                value: s['id'] as String?, 
                                child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)
                              )).toList(),
                              onChanged: (val) => setModalState(() => selectedSiteIdForNew = val),
                            ),
                          ),
                        _buildGlassInput(
                          controller: titleController,
                          label: l10n.titleLabel,
                          icon: Icons.title_rounded,
                          isModern: isModern,
                        ),
                        const SizedBox(height: 16),
                        _buildGlassInput(
                          controller: amountController,
                          label: '${l10n.amountLabel} (TL)',
                          icon: Icons.payments_outlined,
                          isModern: isModern,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _buildGlassInput(
                          controller: descController,
                          label: '${l10n.descriptionLabel} ${l10n.optionalHint}',
                          icon: Icons.description_outlined,
                          isModern: isModern,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: isModern 
                                    ? ColorScheme.dark(
                                        primary: AppColors.primary,
                                        onPrimary: Colors.white,
                                        surface: const Color(0xFF1E1E1E),
                                        onSurface: Colors.white,
                                      )
                                    : ColorScheme.light(
                                        primary: AppColors.mgmtAccent,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: AppColors.mgmtTextHeading,
                                      ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) setModalState(() => selectedDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isModern ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 20, color: isModern ? AppColors.primary : AppColors.mgmtAccent),
                                const SizedBox(width: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('İşlem Tarihi', style: TextStyle(color: isModern ? Colors.white.withOpacity(0.5) : AppColors.mgmtTextBody, fontSize: 12)),
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(selectedDate),
                                      style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 15),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Icon(Icons.edit_calendar_rounded, size: 20, color: isModern ? Colors.white38 : AppColors.mgmtTextBody),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        GlassButton(
                          onPressed: () async {
                            setModalState(() => errorMessage = null);
                            final finalSiteId = selectedSiteIdForNew ?? _selectedSiteId ?? widget.siteId;
                            
                            if (titleController.text.trim().isEmpty) {
                              setModalState(() => errorMessage = 'Lütfen işlem başlığını girin.');
                              return;
                            }
                            if (amountController.text.trim().isEmpty) {
                              setModalState(() => errorMessage = 'Lütfen tutar girin.');
                              return;
                            }
                            if (finalSiteId == null) {
                              setModalState(() => errorMessage = 'Lütfen bir site seçin.');
                              return;
                            }

                            try {
                              await SupabaseService.client.from('income_expense').insert({
                                'site_id': finalSiteId,
                                'title': titleController.text.trim(),
                                'description': descController.text.trim(),
                                'amount': double.parse(amountController.text.trim()),
                                'type': selectedType == TransactionType.expense ? 'expense' : 'income',
                                'is_automatic': false,
                                'transaction_date': selectedDate.toUtc().toIso8601String(),
                                'created_by': authService.currentUser?.id,
                              });
                              Navigator.pop(context);
                              _fetchTransactions();
                            } catch (e) {
                              setModalState(() => errorMessage = 'Kayıt sırasında hata oluştu: $e');
                            }
                          },
                          child: Text(
                            l10n.save,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    required bool isModern,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isModern ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isModern ? Colors.white.withOpacity(0.5) : AppColors.mgmtTextBody, fontSize: 14),
          prefixIcon: Icon(icon, color: isModern ? AppColors.primary : AppColors.mgmtAccent, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildGlassDropdown<T>({
    required T value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required Function(T?)? onChanged,
    required bool isModern,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isModern ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        dropdownColor: isModern ? const Color(0xFF1E1E1E) : Colors.white,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: isModern ? Colors.white54 : AppColors.mgmtTextBody),
        style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isModern ? Colors.white.withOpacity(0.5) : AppColors.mgmtTextBody, fontSize: 14),
          prefixIcon: Icon(icon, color: isModern ? AppColors.primary : AppColors.mgmtAccent, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context).isModern;
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            // Modern header (Mavi-lacivert şerit)
            Container(
              padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isModern 
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [AppColors.mgmtPrimary, const Color(0xFF0D2B4E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () {
                      if (widget.onBack != null) {
                        widget.onBack!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.incomeExpense,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchTransactions, 
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
                  ),
                ],
              ),
            ),

            // Filter row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  if (Provider.of<AuthService>(context, listen: false).currentUser?.role == UserRole.systemOwner)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildGlassDropdown<String?>(
                        value: _selectedSiteId,
                        label: 'Tüm Siteler',
                        icon: Icons.business_outlined,
                        isModern: isModern,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tüm Siteler', style: TextStyle(fontSize: 14))),
                          ..._mySites.map((s) => DropdownMenuItem(value: s['id'], child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 14)))),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedSiteId = val);
                          _fetchTransactions();
                        },
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGlassDropdown<int?>(
                          value: _selectedYear,
                          label: 'Yıl Seçin',
                          icon: Icons.calendar_today_rounded,
                          isModern: isModern,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tüm Yıllar', style: TextStyle(fontSize: 14))),
                            ..._years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString(), style: const TextStyle(fontSize: 14)))),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedYear = val);
                            _fetchTransactions();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGlassDropdown<int?>(
                          value: _selectedMonth,
                          label: 'Ay Seçin',
                          icon: Icons.calendar_month_rounded,
                          isModern: isModern,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tüm Aylar', style: TextStyle(fontSize: 14))),
                            ..._months.map((m) {
                              final monthNames = [
                                'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
                                'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
                              ];
                              return DropdownMenuItem(
                                value: m, 
                                child: Text(monthNames[m - 1], style: const TextStyle(fontSize: 14))
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedMonth = val);
                            _fetchTransactions();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedYear = DateTime.now().year;
                            _selectedMonth = DateTime.now().month;
                          });
                          _fetchTransactions();
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.today_rounded, color: isModern ? AppColors.primary : AppColors.mgmtAccent, size: 20),
                        ),
                        tooltip: 'Bugün',
                      )
                    ],
                  ),
                ],
              ),
            ),

             // Totals Row (Standardized Layout)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildSummaryCard(
                      label: l10n.totalIncome,
                      value: _totalIncome,
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF10B981), // Premium Emerald Green
                      compact: true,
                      onTap: () => setState(() => _filterType = _filterType == TransactionType.income ? null : TransactionType.income),
                      isActive: _filterType == TransactionType.income,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildSummaryCard(
                      label: 'Bakiye',
                      value: _totalBalance,
                      icon: Icons.account_balance_wallet_rounded,
                      color: _totalBalance >= 0 ? Colors.lightBlueAccent : Colors.orangeAccent,
                      isMain: true,
                      onTap: () => setState(() => _filterType = null),
                      isActive: _filterType == null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _buildSummaryCard(
                      label: 'Top. Gider',
                      value: _totalExpense,
                      icon: Icons.trending_down_rounded,
                      color: const Color(0xFFF43F5E), // Premium Rose Red
                      compact: true,
                      onTap: () => setState(() => _filterType = _filterType == TransactionType.expense ? null : TransactionType.expense),
                      isActive: _filterType == TransactionType.expense,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'İşlemler',
                    style: TextStyle(
                      color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  if (_filterType != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _filterType = null),
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: const Text('Filtreyi Kaldır', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: isModern ? Colors.white54 : AppColors.mgmtTextBody,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(builder: (context) {
                      final filteredList = _filterType == null 
                        ? _transactions 
                        : _transactions.where((t) => t.type == _filterType).toList();
                      
                      if (filteredList.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: isModern ? Colors.white10 : Colors.grey.withOpacity(0.2)),
                              const SizedBox(height: 16),
                              Text(
                                'Henüz bir işlem bulunmuyor',
                                style: TextStyle(color: isModern ? Colors.white38 : AppColors.mgmtTextBody),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final t = filteredList[index];
                          final isIncome = t.type == TransactionType.income;
                          final accentColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFF43F5E);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isModern ? Colors.white.withOpacity(0.03) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
                              boxShadow: isModern ? [] : [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {}, // Detail view could be added later
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: accentColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isIncome ? Icons.add_rounded : Icons.remove_rounded,
                                            color: accentColor,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                t.title,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${DateFormat('dd MMM yyyy', 'tr_TR').format(t.date)}${t.description != null && t.description!.isNotEmpty ? ' • ${t.description}' : ''}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isModern ? Colors.white.withOpacity(0.5) : AppColors.mgmtTextBody,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${isIncome ? '+' : '-'}${t.amount.toStringAsFixed(0)} TL',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: accentColor,
                                                fontSize: 16,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            Text(
                                              isIncome ? 'Gelir' : 'Gider',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: accentColor.withOpacity(0.6),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
            ),
          ],
        ),
      ),
      floatingActionButton: Provider.of<AuthService>(context, listen: false).currentUser?.role == UserRole.resident
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isModern ? AppColors.primary : AppColors.mgmtPrimary).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: _addTransaction,
                label: Text(l10n.addNewRecord, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                backgroundColor: isModern ? AppColors.primary : AppColors.mgmtPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSummaryCard({
    required String label, 
    required double value, 
    required IconData icon, 
    required Color color,
    bool isMain = false,
    bool compact = false,
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    
    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(vertical: isMain ? 16 : 10, horizontal: 4),
      border: isActive ? Border.all(color: color.withOpacity(0.8), width: 2) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isMain ? 20 : 14),
          const SizedBox(height: 4),
          Text(
            label, 
            style: TextStyle(fontSize: isMain ? 11 : 9, color: isModern ? Colors.white60 : AppColors.mgmtTextBody),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(
              '${value.toStringAsFixed(0)} TL', 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: isMain ? 18 : 12, 
                color: value < 0 ? (isModern ? Colors.redAccent : Colors.red) : (isModern ? Colors.white : AppColors.mgmtTextHeading)
              )
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';


/// Web-optimized Dues Management screen for the Owner Dashboard.
class WebDuesManagementScreen extends StatefulWidget {
  final String? siteId;
  final VoidCallback? onBack;
  const WebDuesManagementScreen({super.key, this.siteId, this.onBack});

  @override
  State<WebDuesManagementScreen> createState() => _WebDuesManagementScreenState();
}

class _WebDuesManagementScreenState extends State<WebDuesManagementScreen> {
  Map<String, List<dynamic>> _groupedDues = {};
  bool _isLoading = true;
  String? _selectedSiteId;
  List<Map<String, dynamic>> _mySites = [];
  String _statusFilter = 'all'; // all, paid, unpaid, pending

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
    await _fetchDues();
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

  String _formatMonth(String monthStr) {
    try {
      final parts = monthStr.split('-');
      if (parts.length >= 2) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        if (year != null && month != null && month >= 1 && month <= 12) {
          final months = [
            'OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN',
            'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'
          ];
          return '${months[month - 1]} $year';
        }
      }
    } catch (e) {}
    return monthStr.toUpperCase();
  }

  Future<void> _fetchDues() async {
    setState(() => _isLoading = true);
    try {
      dynamic query = SupabaseService.client
          .from('dues')
          .select('*, apartments!inner(number, resident_id, profiles(full_name), blocks!inner(name, site_id, sites!inner(name, owner_id)))')
          .filter('deleted_at', 'is', null);

      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (_selectedSiteId != null) {
        query = query.eq('apartments.blocks.site_id', _selectedSiteId as String);
      } else if (user?.role == UserRole.siteManager && user?.siteId != null) {
        query = query.eq('apartments.blocks.site_id', user!.siteId!);
      } else if (user?.role == UserRole.systemOwner) {
        final siteIds = _mySites.map((s) => s['id'] as String).toList();
        if (siteIds.isNotEmpty) {
          query = query.inFilter('apartments.blocks.site_id', siteIds);
        } else {
          setState(() { _groupedDues = {}; _isLoading = false; });
          return;
        }
      }

      final response = await query.order('month', ascending: false);
      final List<dynamic> data = response as List;

      final Map<String, List<dynamic>> groups = {};
      for (var due in data) {
        final blockName = due['apartments']?['blocks']?['name'] ?? 'Diğer';
        final siteName = due['apartments']?['blocks']?['sites']?['name'] ?? '';
        final key = (_selectedSiteId == null && user?.role == UserRole.systemOwner) ? '$siteName - $blockName' : blockName;
        if (!groups.containsKey(key)) groups[key] = [];
        groups[key]!.add(due);
      }

      final sortedKeys = groups.keys.toList()..sort();
      final Map<String, List<dynamic>> sortedGroups = {};
      for (var key in sortedKeys) {
        final list = groups[key]!;
        list.sort((a, b) {
          final numA = int.tryParse(a['apartments']?['number']?.toString() ?? '0') ?? 0;
          final numB = int.tryParse(b['apartments']?['number']?.toString() ?? '0') ?? 0;
          return numA.compareTo(numB);
        });
        sortedGroups[key] = list;
      }

      setState(() => _groupedDues = sortedGroups);
    } catch (e) {
      print('Error fetching dues: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePaid(String id, bool currentStatus) async {
    try {
      final newStatus = !currentStatus;
      await SupabaseService.client.from('dues').update({
        'status': newStatus ? 'paid' : 'unpaid',
        'is_paid': newStatus,
      }).eq('id', id);

      dynamic targetDue;
      for (var list in _groupedDues.values) {
        targetDue = list.firstWhere((d) => d['id'] == id, orElse: () => null);
        if (targetDue != null) break;
      }

      if (targetDue != null) {
        await _syncIncomeRecord(id, newStatus,
          amount: (targetDue['amount'] as num).toDouble(),
          month: targetDue['month'],
          siteId: targetDue['apartments']?['blocks']?['site_id'],
          blockName: targetDue['apartments']?['blocks']?['name'] ?? '',
          aptNum: targetDue['apartments']?['number'] ?? '',
          residentName: targetDue['apartments']?['profiles']?['full_name'] ?? 'Sakin?',
        );
      }

      setState(() {
        for (var key in _groupedDues.keys) {
          final list = _groupedDues[key]!;
          final index = list.indexWhere((d) => d['id'] == id);
          if (index != -1) {
            list[index]['status'] = newStatus ? 'paid' : 'unpaid';
            list[index]['is_paid'] = newStatus;
            break;
          }
        }
      });
    } catch (e) {
      print('Dues update error: $e');
    }
  }

  Future<void> _approvePayment(String id) async {
    try {
      await SupabaseService.client.from('dues').update({'status': 'paid', 'is_paid': true}).eq('id', id);

      dynamic targetDue;
      for (var list in _groupedDues.values) {
        targetDue = list.firstWhere((d) => d['id'] == id, orElse: () => null);
        if (targetDue != null) break;
      }
      if (targetDue != null) {
        await _syncIncomeRecord(id, true,
          amount: (targetDue['amount'] as num).toDouble(),
          month: targetDue['month'],
          siteId: targetDue['apartments']?['blocks']?['site_id'],
          blockName: targetDue['apartments']?['blocks']?['name'] ?? '',
          aptNum: targetDue['apartments']?['number'] ?? '',
          residentName: targetDue['apartments']?['profiles']?['full_name'] ?? 'Sakin?',
        );
      }
      _fetchDues();
    } catch (e) {
      print('Approve error: $e');
    }
  }

  Future<void> _deleteDue(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 24),
          const SizedBox(width: 8),
          Text('Aidatı Sil', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
        ]),
        content: Text('Bu aidat kaydını silmek istediğinize emin misiniz?', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel, style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(0, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await SupabaseService.client.from('dues').update({'deleted_at': DateTime.now().toIso8601String()}).eq('id', id);
        await _syncIncomeRecord(id, false);
        _fetchDues();
      } catch (e) {
        print('Error deleting due: $e');
      }
    }
  }

  Future<void> _syncIncomeRecord(String dueId, bool isPaid, {double? amount, String? month, String? siteId, String? blockName, String? aptNum, String? residentName}) async {
    try {
      if (isPaid) {
        await SupabaseService.client.from('income_expense').delete().eq('due_id', dueId);
        await SupabaseService.client.from('income_expense').insert({
          'site_id': siteId,
          'due_id': dueId,
          'title': '$month Aidat Ödemesi',
          'description': '$blockName No: $aptNum | $residentName | $month Aidatı (Otomatik)',
          'amount': amount,
          'type': 'income',
          'is_automatic': true,
          'transaction_date': DateTime.now().toUtc().toIso8601String(),
          'created_by': Provider.of<AuthService>(context, listen: false).currentUser?.id,
        });
      } else {
        await SupabaseService.client.from('income_expense').delete().eq('due_id', dueId);
      }
    } catch (e) {
      print('Error syncing income record: $e');
    }
  }

  Future<void> _openCreateDues() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    String? finalSiteId = _selectedSiteId ?? widget.siteId;

    if (auth.currentUser?.role == UserRole.systemOwner && finalSiteId == null) {
      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Site Seçin', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _mySites.map((s) => ListTile(
                leading: Icon(Icons.business_rounded, color: isModern ? Colors.white38 : AppColors.mgmtPrimary),
                title: Text(s['name'] ?? '', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                onTap: () => Navigator.pop(ctx, s['id'] as String),
              )).toList(),
            ),
          ),
        ),
      );
      if (selected != null) finalSiteId = selected;
      else return;
    }

    if (!mounted) return;
    _showCreateDuesDialog(finalSiteId);
  }

  Future<void> _showCreateDuesDialog(String? siteId) async {
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final textColor = isModern ? Colors.white : AppColors.mgmtTextHeading;
    final subtextColor = isModern ? Colors.white70 : AppColors.mgmtTextBody;
    final primaryColor = isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary;
    final amountController = TextEditingController();
    final ibanController = TextEditingController();
    final ibanHolderController = TextEditingController();
    DateTime selectedMonth = DateTime.now();
    DateTime dueDate = DateTime.now().add(const Duration(days: 15));
    List<dynamic> blocks = [];
    List<String> selectedBlockIds = [];
    bool isLoadingBlocks = true;
    bool isSaving = false;
    String? errorMessage;

    // Fetch blocks
    try {
      final resp = await SupabaseService.client.from('blocks').select('id, name').eq('site_id', siteId!).filter('deleted_at', 'is', null);
      blocks = resp as List;
      selectedBlockIds = blocks.map((b) => b['id'] as String).toList();
    } catch (e) {
      print('Error fetching blocks: $e');
    }
    isLoadingBlocks = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          return AlertDialog(
            backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.add_card_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Yeni Aidat Tanımla', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              const Spacer(),
              IconButton(icon: Icon(Icons.close, color: subtextColor, size: 20), onPressed: () => Navigator.pop(ctx)),
            ]),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Aidat Tutarı (TL)',
                        labelStyle: TextStyle(color: subtextColor),
                        prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: primaryColor),
                        filled: true,
                        fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Month picker
                    InkWell(
                      onTap: () async {
                        int selYear = selectedMonth.year;
                        int selMonth = selectedMonth.month;
                        final picked = await showDialog<DateTime>(
                          context: ctx,
                          builder: (mCtx) => StatefulBuilder(
                            builder: (mCtx, setMS) {
                              final monthNames = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
                              return AlertDialog(
                                backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text('Ay Seçin', style: TextStyle(color: textColor)),
                                content: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    IconButton(icon: Icon(Icons.chevron_left, color: subtextColor), onPressed: () => setMS(() => selYear--)),
                                    Text('$selYear', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                                    IconButton(icon: Icon(Icons.chevron_right, color: subtextColor), onPressed: () => setMS(() => selYear++)),
                                  ]),
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: List.generate(12, (i) {
                                    final m = i + 1;
                                    final isSel = selMonth == m;
                                    return InkWell(
                                      onTap: () => setMS(() => selMonth = m),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 70, padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(color: isSel ? primaryColor : (isModern ? Colors.white.withOpacity(0.05) : Colors.grey[100]), borderRadius: BorderRadius.circular(8)),
                                        child: Text(monthNames[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? Colors.white : subtextColor)),
                                      ),
                                    );
                                  })),
                                ]),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(mCtx), child: Text('İptal', style: TextStyle(color: subtextColor))),
                                  TextButton(onPressed: () => Navigator.pop(mCtx, DateTime(selYear, selMonth, 1)), child: Text('Tamam', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))),
                                ],
                              );
                            },
                          ),
                        );
                        if (picked != null) setDState(() => selectedMonth = picked);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_month_rounded, color: primaryColor, size: 20),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Aidat Ayı', style: TextStyle(fontSize: 11, color: subtextColor)),
                            Text(DateFormat('MMMM yyyy').format(selectedMonth), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                          ]),
                          const Spacer(),
                          Icon(Icons.edit_rounded, size: 16, color: subtextColor),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Due date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(context: ctx, initialDate: dueDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime(2030));
                        if (picked != null) setDState(() => dueDate = picked);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.event_busy_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Son Ödeme Tarihi', style: TextStyle(fontSize: 11, color: subtextColor)),
                            Text(DateFormat('dd MMMM yyyy').format(dueDate), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                          ]),
                          const Spacer(),
                          Icon(Icons.edit_rounded, size: 16, color: subtextColor),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // IBAN
                    TextField(
                      controller: ibanController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'IBAN', hintText: 'TR00...',
                        labelStyle: TextStyle(color: subtextColor), hintStyle: TextStyle(color: isModern ? Colors.white24 : Colors.black26),
                        prefixIcon: Icon(Icons.credit_card_rounded, color: primaryColor),
                        filled: true, fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // IBAN Holder
                    TextField(
                      controller: ibanHolderController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'IBAN Sahibi Ad Soyad',
                        labelStyle: TextStyle(color: subtextColor),
                        prefixIcon: Icon(Icons.person_rounded, color: primaryColor),
                        filled: true, fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Blocks selection
                    Text('Blok Seçimi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 8),
                    if (isLoadingBlocks)
                      const Center(child: CircularProgressIndicator())
                    else if (blocks.isEmpty)
                      Text('Bu site için blok bulunamadı.', style: TextStyle(color: subtextColor))
                    else
                      ...blocks.map((block) {
                        final id = block['id'] as String;
                        final isSel = selectedBlockIds.contains(id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isModern ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: CheckboxListTile(
                            title: Text(block['name'] ?? '', style: TextStyle(color: textColor, fontSize: 14)),
                            value: isSel,
                            activeColor: primaryColor,
                            checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            dense: true,
                            onChanged: (val) {
                              setDState(() {
                                if (val == true) selectedBlockIds.add(id);
                                else selectedBlockIds.remove(id);
                              });
                            },
                          ),
                        );
                      }),
                    // Inline error message
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal', style: TextStyle(color: subtextColor, fontWeight: FontWeight.bold))),
              ElevatedButton.icon(
                icon: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                label: Text(isSaving ? 'Oluşturuluyor...' : 'Aidatları Oluştur', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSaving ? null : () async {
                  if (amountController.text.isEmpty || ibanController.text.isEmpty || ibanHolderController.text.isEmpty || selectedBlockIds.isEmpty) {
                    setDState(() => errorMessage = 'Lütfen tüm alanları doldurun ve en az bir blok seçin.');
                    return;
                  }
                  final double? amount = double.tryParse(amountController.text);
                  if (amount == null) {
                    setDState(() => errorMessage = 'Geçerli bir tutar girin.');
                    return;
                  }
                  setDState(() { isSaving = true; errorMessage = null; });
                  try {
                    final monthStr = DateFormat('yyyy-MM-01').format(selectedMonth);
                    final existingCheck = await SupabaseService.client.from('dues').select('id, apartments!inner(blocks!inner(site_id))').eq('month', monthStr).eq('apartments.blocks.site_id', siteId as Object).filter('deleted_at', 'is', null).limit(1);
                    if ((existingCheck as List).isNotEmpty) throw Exception('Bu ay için bu sitede zaten aidat tanımlanmış.');
                    final aptsResp = await SupabaseService.client.from('apartments').select('id').inFilter('block_id', selectedBlockIds);
                    final apartments = aptsResp as List;
                    if (apartments.isEmpty) throw Exception('Seçili bloklarda daire bulunamadı.');
                    final duesData = apartments.map((apt) => {
                      'apartment_id': apt['id'], 'amount': amount,
                      'month': monthStr, 'status': 'unpaid',
                      'iban': ibanController.text, 'iban_holder_name': ibanHolderController.text,
                      'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
                    }).toList();
                    await SupabaseService.client.from('dues').insert(duesData);
                    Navigator.pop(ctx);
                    _fetchDues();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aidatlar başarıyla tanımlandı.'), backgroundColor: Colors.green));
                  } catch (e) {
                    String msg = e.toString();
                    if (msg.startsWith('Exception: ')) msg = msg.replaceFirst('Exception: ', '');
                    setDState(() { isSaving = false; errorMessage = msg; });
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ──── Computed Stats ────
  int get _totalDues {
    int count = 0;
    for (var list in _groupedDues.values) count += list.length;
    return count;
  }
  int get _paidCount {
    int count = 0;
    for (var list in _groupedDues.values) count += list.where((d) => d['is_paid'] == true).length;
    return count;
  }
  int get _unpaidCount => _totalDues - _paidCount - _pendingCount;
  int get _pendingCount {
    int count = 0;
    for (var list in _groupedDues.values) count += list.where((d) => d['status'] == 'pending').length;
    return count;
  }
  double get _totalAmount {
    double total = 0;
    for (var list in _groupedDues.values) {
      for (var d in list) total += (d['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }
  double get _paidAmount {
    double total = 0;
    for (var list in _groupedDues.values) {
      for (var d in list) {
        if (d['is_paid'] == true) total += (d['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context).isModern;
    final textColor = isModern ? Colors.white : Colors.black87;
    final subtextColor = isModern ? Colors.white54 : Colors.black54;
    final primaryColor = isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary;
    final cardBg = isModern ? const Color(0xFF1E293B) : Colors.white;
    final auth = Provider.of<AuthService>(context, listen: false);
    final isManagement = auth.currentUser?.role == UserRole.systemOwner || auth.currentUser?.role == UserRole.siteManager;

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
                      Text(l10n.duesManagement, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 4),
                      Text('Aidat tahsilatlarını takip edin, ödemeleri yönetin.', style: TextStyle(color: subtextColor, fontSize: 16)),
                    ],
                  ),
                ),
                // Site filter
                if (auth.currentUser?.role == UserRole.systemOwner && widget.siteId == null)
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isModern ? Colors.white10 : AppColors.mgmtBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedSiteId,
                        dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: subtextColor, size: 20),
                        hint: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.business_rounded, size: 16, color: subtextColor),
                          const SizedBox(width: 6),
                          Text('Tüm Siteler', style: TextStyle(color: subtextColor, fontSize: 13)),
                        ]),
                        style: TextStyle(color: textColor, fontSize: 13),
                        items: [
                          DropdownMenuItem(value: null, child: Text('Tüm Siteler', style: TextStyle(fontSize: 13, color: textColor))),
                          ..._mySites.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? '', style: TextStyle(fontSize: 13, color: textColor)))),
                        ],
                        onChanged: (val) { setState(() => _selectedSiteId = val); _fetchDues(); },
                      ),
                    ),
                  ),
                IconButton(onPressed: _fetchDues, icon: const Icon(Icons.refresh), color: subtextColor, tooltip: 'Yenile'),
                if (isManagement) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _openCreateDues,
                    icon: const Icon(Icons.add_card_rounded, color: Colors.white, size: 18),
                    label: const Text('Yeni Aidat Tanımla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ──── Summary Cards (clickable for filtering) ────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                _buildStatCard('Toplam Aidat', '$_totalDues', Icons.receipt_long_rounded, primaryColor, isModern, cardBg, textColor, subtextColor, filterKey: 'all'),
                const SizedBox(width: 12),
                _buildStatCard('Ödenen', '$_paidCount', Icons.check_circle_outline, Colors.green, isModern, cardBg, textColor, subtextColor, filterKey: 'paid'),
                const SizedBox(width: 12),
                _buildStatCard('Ödenmemiş', '$_unpaidCount', Icons.cancel_outlined, Colors.redAccent, isModern, cardBg, textColor, subtextColor, filterKey: 'unpaid'),
                const SizedBox(width: 12),
                _buildStatCard('Beklemede', '$_pendingCount', Icons.hourglass_top_rounded, Colors.orange, isModern, cardBg, textColor, subtextColor, filterKey: 'pending'),
                const SizedBox(width: 12),
                _buildStatCard('Tahsilat', '₺${NumberFormat('#,##0', 'tr').format(_paidAmount)}', Icons.trending_up_rounded, Colors.green, isModern, cardBg, textColor, subtextColor,
                  subtitle: '/ ₺${NumberFormat('#,##0', 'tr').format(_totalAmount)}'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ──── Table ────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groupedDues.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: subtextColor),
                          const SizedBox(height: 16),
                          Text(l10n.noDuesFound, style: TextStyle(fontSize: 16, color: subtextColor)),
                          if (isManagement) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _openCreateDues,
                              icon: const Icon(Icons.add, color: Colors.white, size: 18),
                              label: const Text('Aidat Tanımla', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, minimumSize: const Size(0, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            ),
                          ],
                        ]),
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
                              // Table header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isModern ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(width: 60, child: Text('Daire', style: _headerStyle(subtextColor))),
                                    Expanded(child: Text('Sakin', style: _headerStyle(subtextColor))),
                                    SizedBox(width: 120, child: Text('Blok / Site', style: _headerStyle(subtextColor))),
                                    SizedBox(width: 120, child: Text('Dönem', style: _headerStyle(subtextColor))),
                                    SizedBox(width: 100, child: Text('Tutar', style: _headerStyle(subtextColor))),
                                    SizedBox(width: 110, child: Text('Durum', style: _headerStyle(subtextColor))),
                                    if (isManagement) const SizedBox(width: 90),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: isModern ? Colors.white10 : Colors.black.withOpacity(0.06)),
                              // Table body — flatten all dues
                              Expanded(
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: _allDues.length,
                                  separatorBuilder: (_, __) => Divider(height: 1, color: isModern ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
                                  itemBuilder: (context, index) {
                                    final due = _allDues[index];
                                    return _buildDueRow(due, isModern, textColor, subtextColor, primaryColor, isManagement);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<dynamic> get _allDues {
    final List<dynamic> all = [];
    for (var list in _groupedDues.values) all.addAll(list);
    if (_statusFilter == 'all') return all;
    return all.where((d) {
      final status = d['status'] ?? (d['is_paid'] == true ? 'paid' : 'unpaid');
      return status == _statusFilter;
    }).toList();
  }

  TextStyle _headerStyle(Color color) => TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color, letterSpacing: 0.5);

  Widget _buildDueRow(dynamic due, bool isModern, Color textColor, Color subtextColor, Color primaryColor, bool isManagement) {
    final apt = due['apartments'];
    final aptNum = apt?['number'] ?? '';
    final residentName = apt?['profiles']?['full_name'] ?? 'Sakin?';
    final blockName = apt?['blocks']?['name'] ?? '';
    final siteName = apt?['blocks']?['sites']?['name'] ?? '';
    final status = due['status'] ?? (due['is_paid'] == true ? 'paid' : 'unpaid');
    final isPaid = status == 'paid';
    final isPending = status == 'pending';
    final amount = (due['amount'] as num?)?.toDouble() ?? 0;
    final statusColor = isPaid ? Colors.green : (isPending ? Colors.orange : Colors.redAccent);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // Apartment number
          SizedBox(
            width: 60,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: statusColor.withOpacity(0.1),
              child: Text(aptNum.toString(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          // Resident
          Expanded(
            child: Text(residentName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          // Block / Site
          SizedBox(
            width: 120,
            child: Text(_selectedSiteId == null ? '$siteName\n$blockName' : blockName,
              style: TextStyle(fontSize: 12, color: subtextColor), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          // Month
          SizedBox(
            width: 120,
            child: Text(_formatMonth(due['month'] ?? ''), style: TextStyle(fontSize: 12, color: subtextColor)),
          ),
          // Amount
          SizedBox(
            width: 100,
            child: Text('₺${NumberFormat('#,##0', 'tr').format(amount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
          ),
          // Status badge
          SizedBox(
            width: 110,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                  isPaid ? 'ÖDENDİ' : (isPending ? 'BEKLEMEDE' : 'ÖDENMEDİ'),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              ]),
            ),
          ),
          // Actions
          if (isManagement)
            SizedBox(
              width: 90,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (isPending)
                  Tooltip(
                    message: 'Onayla',
                    child: InkWell(
                      onTap: () => _approvePayment(due['id']),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.check_rounded, color: Colors.green, size: 18),
                      ),
                    ),
                  )
                else
                  Checkbox(
                    value: isPaid,
                    activeColor: primaryColor,
                    side: BorderSide(color: isModern ? Colors.white38 : AppColors.mgmtBorder, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => _togglePaid(due['id'], isPaid),
                    visualDensity: VisualDensity.compact,
                  ),
                InkWell(
                  onTap: () => _deleteDue(due['id']),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.6), size: 18),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isModern, Color cardBg, Color textColor, Color subtextColor, {String? subtitle, String? filterKey}) {
    final isActive = filterKey != null && _statusFilter == filterKey;
    return Expanded(
      child: MouseRegion(
        cursor: filterKey != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: filterKey != null ? () => setState(() => _statusFilter = filterKey) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive ? color.withOpacity(0.6) : (isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))] : [],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(isActive ? 0.2 : 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Row(
                        children: [
                          Flexible(child: Text(label, style: TextStyle(fontSize: 11, color: isActive ? color : subtextColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (subtitle != null) Text(' $subtitle', style: TextStyle(fontSize: 11, color: subtextColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import 'create_dues_screen.dart';

class DuesManagementScreen extends StatefulWidget {
  final String? siteId;
  final VoidCallback? onBack;
  const DuesManagementScreen({super.key, this.siteId, this.onBack});

  @override
  State<DuesManagementScreen> createState() => _DuesManagementScreenState();
}

class _DuesManagementScreenState extends State<DuesManagementScreen> {
  Map<String, List<dynamic>> _groupedDues = {};
  bool _isLoading = true;
  String? _selectedSiteId;
  List<Map<String, dynamic>> _mySites = [];

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
          return '${months[month - 1]} - $year';
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
          setState(() {
            _groupedDues = {};
            _isLoading = false;
          });
          return;
        }
      }
      
      final response = await query.order('month', ascending: false);
      
      final List<dynamic> data = response as List;
      
      // Grouping and Sorting
      final Map<String, List<dynamic>> groups = {};
      for (var due in data) {
        final blockName = due['apartments']?['blocks']?['name'] ?? 'Diğer';
        final siteName = due['apartments']?['blocks']?['sites']?['name'] ?? '';
        final key = (_selectedSiteId == null && user?.role == UserRole.systemOwner) ? '$siteName - $blockName' : blockName;
        
        if (!groups.containsKey(key)) {
          groups[key] = [];
        }
        groups[key]!.add(due);
      }

      // Sort blocks alphabetically
      final sortedKeys = groups.keys.toList()..sort();
      final Map<String, List<dynamic>> sortedGroups = {};
      for (var key in sortedKeys) {
        final list = groups[key]!;
        // Sort apartments by number
        list.sort((a, b) {
          final numA = int.tryParse(a['apartments']?['number']?.toString() ?? '0') ?? 0;
          final numB = int.tryParse(b['apartments']?['number']?.toString() ?? '0') ?? 0;
          return numA.compareTo(numB);
        });
        sortedGroups[key] = list;
      }

      setState(() {
        _groupedDues = sortedGroups;
      });
    } catch (e) {
      print('Error fetching dues: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePaid(String id, bool currentStatus) async {
    try {
      final newStatus = !currentStatus;
      await SupabaseService.client
          .from('dues')
          .update({
            'status': newStatus ? 'paid' : 'unpaid',
            'is_paid': newStatus
          })
          .eq('id', id);

      // Find due details for income sync
      dynamic targetDue;
      for (var list in _groupedDues.values) {
        targetDue = list.firstWhere((d) => d['id'] == id, orElse: () => null);
        if (targetDue != null) break;
      }

      if (targetDue != null) {
        final siteId = targetDue['apartments']?['blocks']?['site_id'];
        final blockName = targetDue['apartments']?['blocks']?['name'] ?? '';
        final aptNum = targetDue['apartments']?['number'] ?? '';
        final residentName = targetDue['apartments']?['profiles']?['full_name'] ?? 'Sakin?';
        
        await _syncIncomeRecord(
          id, 
          newStatus, 
          amount: (targetDue['amount'] as num).toDouble(),
          month: targetDue['month'],
          siteId: siteId,
          blockName: blockName,
          aptNum: aptNum,
          residentName: residentName,
        );
      }

      // Local update for better performance/feedback
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _deleteDue(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isModern = themeService.isModern;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isModern ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Aidatı Sil', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
        content: Text('Bu aidat kaydını silmek istediğinize emin misiniz? (Bu işlem geri alınamaz)', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel, style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.client
            .from('dues')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', id);
        
        // Also remove linked income record
        await _syncIncomeRecord(id, false);

        _fetchDues();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aidat silindi.')));
        }
      } catch (e) {
        print('Error deleting due: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    }
  }

  Future<void> _showBulkDeleteDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isModern = themeService.isModern;
    DateTime selectedMonth = DateTime.now();
    String? selectedBlockId;
    List<dynamic> blocks = [];
    // bool loadingBlocks = false; // This variable was declared but not used, removed as per instruction to not make unrelated edits.

    // Fetch blocks for the current site if siteId is present
    if (widget.siteId != null) {
      try {
        final resp = await SupabaseService.client
            .from('blocks')
            .select('id, name')
            .eq('site_id', widget.siteId!)
            .filter('deleted_at', 'is', null);
        blocks = resp as List;
      } catch (e) {
        print('Error fetching blocks for bulk delete: $e');
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isModern ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text('Toplu Aidat Sil', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Seçilen ay ve kriterlere göre tüm aidatlar silinecektir.', 
                style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontSize: 13)),
              const SizedBox(height: 20),
              ListTile(
                title: Text('Silinecek Ay', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 14)),
                subtitle: Text(
                  DateFormat('MMMM yyyy').format(selectedMonth), 
                  style: TextStyle(color: isModern ? AppColors.primary : AppColors.mgmtAccent),
                ),
                trailing: Icon(Icons.calendar_month, color: isModern ? AppColors.primary : AppColors.mgmtAccent),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedMonth,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setModalState(() => selectedMonth = DateTime(picked.year, picked.month, 1));
                  }
                },
              ),
              if (widget.siteId != null && blocks.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedBlockId,
                  dropdownColor: isModern ? const Color(0xFF2C2C2C) : AppColors.mgmtSurface,
                  style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
                  decoration: InputDecoration(
                    labelText: 'Blok (İsteğe Bağlı)',
                    labelStyle: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtSecondary),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text('Tüm Bloklar', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading))),
                    ...blocks.map((b) => DropdownMenuItem(
                      value: b['id'] as String,
                      child: Text(b['name'], style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                    )),
                  ],
                  onChanged: (val) => setModalState(() => selectedBlockId = val),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel, style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: isModern ? const Color(0xFF1E1E1E) : AppColors.mgmtSurface,
                    title: Text('Emin misiniz?', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                    content: Text('Bu işlem seçili kriterdeki TÜM aidatları silecektir.', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false), 
                        child: Text('Hayır', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true), 
                        child: const Text('Evet, Sil', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await _performBulkDelete(
                    DateFormat('yyyy-MM-01').format(selectedMonth),
                    selectedBlockId,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Toplu Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performBulkDelete(String monthStr, String? blockId) async {
    try {
      setState(() => _isLoading = true);
      
      var query = SupabaseService.client
          .from('dues')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('month', monthStr);
      
      if (blockId != null) {
        // If block selected, we need to filter by apartment's block_id
        // Since we can't do direct join in update with filter easily in some versions of postgrest, 
        // we'll fetch IDs first or use a simpler approach if possible.
        // Actually Supabase update supports some filtering via RPC or raw, 
        // but the easiest is to fetch IDs.
        
        final aptsResponse = await SupabaseService.client
            .from('apartments')
            .select('id')
            .eq('block_id', blockId);
        
        final aptIds = (aptsResponse as List).map((a) => a['id']).toList();
        if (aptIds.isNotEmpty) {
          // Find due IDs for these apartments in this month to sync income
          final duesToSync = await SupabaseService.client
              .from('dues')
              .select('id')
              .eq('month', monthStr)
              .inFilter('apartment_id', aptIds);
          
          final dueIds = (duesToSync as List).map((d) => d['id']).toList();
          for (var dId in dueIds) {
            await _syncIncomeRecord(dId as String, false);
          }

          await SupabaseService.client
              .from('dues')
              .update({'deleted_at': DateTime.now().toIso8601String()})
              .eq('month', monthStr)
              .inFilter('apartment_id', aptIds);
        }
      } else if (widget.siteId != null) {
        // Filter by site
        final aptsResponse = await SupabaseService.client
            .from('apartments')
            .select('id, blocks!inner(site_id)')
            .eq('blocks.site_id', widget.siteId!);
        
        final aptIds = (aptsResponse as List).map((a) => a['id']).toList();
        if (aptIds.isNotEmpty) {
          // Find due IDs to sync income
          final duesToSync = await SupabaseService.client
              .from('dues')
              .select('id')
              .eq('month', monthStr)
              .inFilter('apartment_id', aptIds);
          
          final dueIds = (duesToSync as List).map((d) => d['id']).toList();
          for (var dId in dueIds) {
            await _syncIncomeRecord(dId as String, false);
          }

          await SupabaseService.client
              .from('dues')
              .update({'deleted_at': DateTime.now().toIso8601String()})
              .eq('month', monthStr)
              .inFilter('apartment_id', aptIds);
        }
      } else {
        // System owner global delete (could be many, but we'll try to find and sync)
        final duesToSync = await SupabaseService.client
            .from('dues')
            .select('id')
            .eq('month', monthStr);
        
        final dueIds = (duesToSync as List).map((d) => d['id']).toList();
        for (var dId in dueIds) {
          await _syncIncomeRecord(dId as String, false);
        }

        await SupabaseService.client
            .from('dues')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('month', monthStr);
      }
      
      _fetchDues();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toplu silme başarılı.')));
      }
    } catch (e) {
      print('Bulk delete error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approvePayment(String id) async {
    try {
      await SupabaseService.client
          .from('dues')
          .update({'status': 'paid', 'is_paid': true})
          .eq('id', id);

      // Find due details for income sync
      dynamic targetDue;
      for (var list in _groupedDues.values) {
        targetDue = list.firstWhere((d) => d['id'] == id, orElse: () => null);
        if (targetDue != null) break;
      }

      if (targetDue != null) {
        final siteId = targetDue['apartments']?['blocks']?['site_id'];
        final blockName = targetDue['apartments']?['blocks']?['name'] ?? '';
        final aptNum = targetDue['apartments']?['number'] ?? '';
        final residentName = targetDue['apartments']?['profiles']?['full_name'] ?? 'Sakin?';

        await _syncIncomeRecord(
          id, 
          true, 
          amount: (targetDue['amount'] as num).toDouble(),
          month: targetDue['month'],
          siteId: siteId,
          blockName: blockName,
          aptNum: aptNum,
          residentName: residentName,
        );
      }

      _fetchDues();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ödeme onaylandı.')));
      }
    } catch (e) {
      print('Approve error: $e');
    }
  }

  Future<void> _syncIncomeRecord(String dueId, bool isPaid, {double? amount, String? month, String? siteId, String? blockName, String? aptNum, String? residentName}) async {
    try {
      if (isPaid) {
        // First delete existing record using due_id column (more robust)
        await SupabaseService.client
            .from('income_expense')
            .delete()
            .eq('due_id', dueId);

        final String description = '$blockName No: $aptNum | $residentName | $month Aidatı (Otomatik)';

        // Insert new record
        await SupabaseService.client.from('income_expense').insert({
          'site_id': siteId,
          'due_id': dueId,
          'title': '$month Aidat Ödemesi',
          'description': description,
          'amount': amount,
          'type': 'income',
          'is_automatic': true,
          'transaction_date': DateTime.now().toUtc().toIso8601String(),
          'created_by': Provider.of<AuthService>(context, listen: false).currentUser?.id,
        });
      } else {
        // Delete the record using due_id
        await SupabaseService.client
            .from('income_expense')
            .delete()
            .eq('due_id', dueId);
      }
    } catch (e) {
      print('Error syncing income record: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context);
    final isModern = themeService.isModern;

    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            // Modern header
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
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else if (widget.onBack != null) {
                          widget.onBack!();
                        }
                      },
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.siteId == null ? 'Aidat Takibi' : l10n.duesManagement,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (Provider.of<AuthService>(context, listen: false).currentUser?.role == UserRole.systemOwner || 
                      Provider.of<AuthService>(context, listen: false).currentUser?.role == UserRole.siteManager)
                    IconButton(
                      onPressed: _showBulkDeleteDialog,
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
                      tooltip: 'Toplu Sil',
                    ),
                  IconButton(
                    onPressed: _fetchDues, 
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
                  ),
                ],
              ),
            ),
            if (Provider.of<AuthService>(context, listen: false).currentUser?.role == UserRole.systemOwner && widget.siteId == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isModern ? Colors.white.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isModern ? Colors.white10 : AppColors.mgmtBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedSiteId,
                      dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: isModern ? Colors.white54 : AppColors.mgmtPrimary),
                      hint: Row(
                        children: [
                          Icon(Icons.business_rounded, size: 18, color: isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
                          const SizedBox(width: 8),
                          Text('Tüm Siteler', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontSize: 14)),
                        ],
                      ),
                      style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 14, fontWeight: FontWeight.w500),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Tüm Siteler', style: TextStyle(fontSize: 14, color: isModern ? Colors.white : AppColors.mgmtTextHeading))),
                        ..._mySites.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? '', style: TextStyle(fontSize: 14, color: isModern ? Colors.white : AppColors.mgmtTextHeading)))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedSiteId = val);
                        _fetchDues();
                      },
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _groupedDues.isEmpty
                      ? Center(child: Text(l10n.noDuesFound, style: TextStyle(
                          color: isModern ? AppColors.textBody : AppColors.mgmtSecondary,
                        )))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            itemCount: _groupedDues.length,
                            itemBuilder: (context, index) {
                              final blockName = _groupedDues.keys.elementAt(index);
                              final dues = _groupedDues[blockName]!;
                              final paidCount = dues.where((d) => d['is_paid'] == true).length;
                              final accentColor = isModern ? AppColors.secondary : AppColors.mgmtAccent;

                              return TweenAnimationBuilder<double>(
                                duration: Duration(milliseconds: 400 + (index * 100)),
                                tween: Tween(begin: 0.0, end: 1.0),
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: Opacity(
                                      opacity: value,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GlassCard(
                                    padding: EdgeInsets.zero,
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        dividerColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        splashColor: Colors.transparent,
                                      ),
                                      child: ExpansionTile(
                                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        leading: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: (paidCount == dues.length ? Colors.greenAccent : accentColor).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.business_rounded, 
                                            color: paidCount == dues.length ? Colors.greenAccent : accentColor,
                                            size: 24,
                                          ),
                                        ),
                                        title: Text(
                                          blockName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 16,
                                            color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '$paidCount / ${dues.length} Ödendi',
                                          style: TextStyle(
                                            color: isModern ? Colors.white38 : AppColors.mgmtTextBody, 
                                            fontSize: 12
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: isModern ? Colors.white38 : AppColors.mgmtPrimary,
                                        ),
                                        children: [
                                          const Divider(height: 1, color: Colors.white10),
                                          ...dues.map((due) {
                                            final apt = due['apartments'];
                                            final aptNum = apt?['number'] ?? '';
                                            final residentName = apt?['profiles']?['full_name'] ?? 'Sakin?';
                                            final status = due['status'] ?? (due['is_paid'] == true ? 'paid' : 'unpaid');
                                            final isPaid = status == 'paid';
                                            final isPending = status == 'pending';
                                            
                                            final authService = Provider.of<AuthService>(context, listen: false);
                                            final userRole = authService.currentUser?.role;
                                            final isManagement = userRole == UserRole.systemOwner || userRole == UserRole.siteManager;

                                            return Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.02),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: ListTile(
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                leading: CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: (isPaid ? Colors.greenAccent : (isPending ? Colors.orangeAccent : Colors.redAccent)).withOpacity(0.1),
                                                  child: Text(
                                                    aptNum.toString(),
                                                    style: TextStyle(
                                                      color: isPaid ? Colors.greenAccent : (isPending ? Colors.orangeAccent : Colors.redAccent),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  residentName,
                                                  style: TextStyle(
                                                    fontSize: 14, 
                                                    fontWeight: FontWeight.bold,
                                                    color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                                  ),
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '${due['amount']} TL • ${_formatMonth(due['month'])}',
                                                      style: TextStyle(
                                                        color: isModern ? Colors.white38 : AppColors.mgmtTextBody, 
                                                        fontSize: 11
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: (isPaid ? Colors.greenAccent : (isPending ? Colors.orangeAccent : Colors.redAccent)).withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(20),
                                                        border: Border.all(
                                                          color: (isPaid ? Colors.greenAccent : (isPending ? Colors.orangeAccent : Colors.redAccent)).withOpacity(0.3),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        isPaid ? 'ÖDENDİ' : (isPending ? 'BEKLEMEDE' : 'ÖDENMEDİ'),
                                                        style: TextStyle(
                                                          color: isPaid ? Colors.greenAccent : (isPending ? Colors.orangeAccent : Colors.redAccent),
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w800,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                trailing: isManagement 
                                                  ? Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Material(
                                                          color: Colors.transparent,
                                                          child: InkWell(
                                                            onTap: () => _deleteDue(due['id']),
                                                            borderRadius: BorderRadius.circular(20),
                                                            child: Padding(
                                                              padding: const EdgeInsets.all(6),
                                                              child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.7), size: 18),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        isPending 
                                                          ? GlassButton(
                                                              width: 70,
                                                              height: 32,
                                                              padding: EdgeInsets.zero,
                                                              onPressed: () => _approvePayment(due['id']),
                                                              child: const Text('Onayla', style: TextStyle(
                                                                color: Colors.white, 
                                                                fontSize: 10, 
                                                                fontWeight: FontWeight.bold,
                                                              )),
                                                            )
                                                          : Transform.scale(
                                                              scale: 0.9,
                                                              child: Checkbox(
                                                                value: isPaid,
                                                                activeColor: accentColor,
                                                                side: BorderSide(
                                                                    color: isModern ? Colors.white38 : AppColors.mgmtBorder.withOpacity(0.5), 
                                                                    width: 1.5,
                                                                ),
                                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                                onChanged: (val) => _togglePaid(due['id'], isPaid),
                                                              ),
                                                            ),
                                                      ],
                                                    )
                                                  : (isPaid ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20) : null),
                                              ),
                                            );
                                          }).toList(),
                                          const SizedBox(height: 12),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.currentUser?.role != UserRole.systemOwner && 
              auth.currentUser?.role != UserRole.siteManager) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 90),
            child: FloatingActionButton.extended(
              onPressed: () async {
                final auth = Provider.of<AuthService>(context, listen: false);
                String? finalSiteId = _selectedSiteId ?? widget.siteId;
                
                if (auth.currentUser?.role == UserRole.systemOwner && finalSiteId == null) {
                  // Show site selection dialog or inform user
                  final selected = await showDialog<String>(
                    context: context,
                    builder: (context) {
                      final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
                      return AlertDialog(
                        backgroundColor: isModern ? const Color(0xFF1E293B) : AppColors.mgmtSurface,
                        title: Text('Site Seçin', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _mySites.map((s) => ListTile(
                            leading: Icon(Icons.business_rounded, color: isModern ? Colors.white38 : AppColors.mgmtPrimary),
                            title: Text(s['name'] ?? '', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                            onTap: () => Navigator.pop(context, s['id'] as String),
                          )).toList(),
                        ),
                      );
                    },
                  );
                  if (selected != null) finalSiteId = selected;
                  else return;
                }

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateDuesScreen(siteId: finalSiteId)),
                );
                if (result == true) _fetchDues();
              },
              backgroundColor: isModern ? AppColors.primary : AppColors.mgmtPrimary,
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              icon: const Icon(Icons.add_card_rounded, color: Colors.white, size: 24),
              label: const Text('Yeni Aidat Tanımla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          );
        },
      ),
    );
  }
}

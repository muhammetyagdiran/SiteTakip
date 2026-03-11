import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_widgets.dart';
import '../../models/user_model.dart';
import 'package:provider/provider.dart';

class CreateDuesScreen extends StatefulWidget {
  final String? siteId;
  const CreateDuesScreen({super.key, this.siteId});

  @override
  State<CreateDuesScreen> createState() => _CreateDuesScreenState();
}

class _CreateDuesScreenState extends State<CreateDuesScreen> {
  final _amountController = TextEditingController();
  final _ibanController = TextEditingController();
  final _ibanHolderController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 15));
  bool _isSaving = false;
  List<dynamic> _blocks = [];
  List<String> _selectedBlockIds = [];
  bool _isLoadingBlocks = false;
  List<dynamic> _sites = [];
  String? _selectedSiteId;
  bool _isLoadingSites = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndFetchBlocks();
  }

  Future<void> _checkPermissionAndFetchBlocks() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user?.role != UserRole.systemOwner && user?.role != UserRole.siteManager) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sadece Sistem Sahibi ve Site Yöneticileri aidat tanımlayabilir.')),
        );
        Navigator.pop(context);
      });
      return;
    }
    
    if (widget.siteId != null) {
      _selectedSiteId = widget.siteId;
      _fetchBlocks();
    } else if (user?.role == UserRole.siteManager && user?.siteId != null) {
      _selectedSiteId = user!.siteId;
      _fetchBlocks();
    } else if (user?.role == UserRole.systemOwner) {
      _fetchSites();
    }
  }

  Future<void> _fetchSites() async {
    setState(() => _isLoadingSites = true);
    try {
      final response = await SupabaseService.client
          .from('sites')
          .select('id, name')
          .filter('deleted_at', 'is', null) // Soft delete filter
          .order('name');
      setState(() {
        _sites = response as List;
      });
    } catch (e) {
      print('Error fetching sites: $e');
    } finally {
      setState(() => _isLoadingSites = false);
    }
  }

  Future<void> _fetchBlocks() async {
    if (_selectedSiteId == null) return;
    setState(() {
      _isLoadingBlocks = true;
      _blocks = [];
      _selectedBlockIds = [];
    });
    try {
      final response = await SupabaseService.client
          .from('blocks')
          .select('id, name')
          .filter('deleted_at', 'is', null) // Soft delete filter
          .eq('site_id', _selectedSiteId!);
      setState(() {
        _blocks = response as List;
        // Default select all
        _selectedBlockIds = _blocks.map((b) => b['id'] as String).toList();
      });
    } catch (e) {
      print('Error fetching blocks: $e');
    } finally {
      setState(() => _isLoadingBlocks = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    int selectedYear = _selectedDate.year;
    int selectedMonth = _selectedDate.month;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Ay Seçin', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: isModern ? Colors.white54 : AppColors.mgmtPrimary),
                    onPressed: () => setModalState(() => selectedYear--),
                  ),
                  Text(selectedYear.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: isModern ? Colors.white54 : AppColors.mgmtPrimary),
                    onPressed: () => setModalState(() => selectedYear++),
                  ),
                ],
              ),
              const Divider(height: 20, color: Colors.white10),
              SizedBox(
                width: double.maxFinite,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List.generate(12, (index) {
                    final month = index + 1;
                    final isSelected = selectedMonth == month;
                    final monthNames = [
                      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
                      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
                    ];
                    return InkWell(
                      onTap: () => setModalState(() => selectedMonth = month),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 70,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? (isModern ? AppColors.primary : AppColors.mgmtPrimary)
                            : (isModern ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          monthNames[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : (isModern ? Colors.white70 : AppColors.mgmtTextBody),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal', style: TextStyle(color: isModern ? Colors.white54 : Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime(selectedYear, selectedMonth, 1);
                });
                Navigator.pop(context);
              },
              child: Text('Tamam', style: TextStyle(color: isModern ? AppColors.secondary : AppColors.mgmtPrimary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isModern 
              ? const ColorScheme.dark(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: Color(0xFF1E1E1E),
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
        );
      },
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _saveDues() async {
    if (_amountController.text.isEmpty || 
        _selectedBlockIds.isEmpty || 
        _ibanController.text.isEmpty || 
        _ibanHolderController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun ve en az bir blok seçin.')),
      );
      return;
    }

    final double? amount = double.tryParse(_amountController.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir tutar girin.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // 1. Check if dues already exist for this month and site
      final monthStr = DateFormat('yyyy-MM-01').format(_selectedDate);
      
      final existingCheck = await SupabaseService.client
          .from('dues')
          .select('id, apartments!inner(blocks!inner(site_id))')
          .eq('month', monthStr)
          .eq('apartments.blocks.site_id', _selectedSiteId as Object)
          .filter('deleted_at', 'is', null)
          .limit(1);

      if ((existingCheck as List).isNotEmpty) {
        throw Exception('Bu ay için bu sitede zaten aidat tanımlanmış.');
      }

      // 2. Get all apartments in selected blocks
      final response = await SupabaseService.client
          .from('apartments')
          .select('id')
          .inFilter('block_id', _selectedBlockIds);
      
      final apartments = response as List;
      if (apartments.isEmpty) {
        throw Exception('Seçili bloklarda daire bulunamadı.');
      }

      // 2. Insert dues for each apartment
      final duesData = apartments.map((apt) => {
        'apartment_id': apt['id'],
        'amount': amount,
        'month': DateFormat('yyyy-MM-01').format(_selectedDate),
        'status': 'unpaid',
        'iban': _ibanController.text,
        'iban_holder_name': _ibanHolderController.text,
        'due_date': DateFormat('yyyy-MM-dd').format(_dueDate),
      }).toList();

      await SupabaseService.client.from('dues').insert(duesData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aidatlar başarıyla tanımlandı.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error saving dues: $e');
      if (mounted) {
        String message = e.toString();
        if (message.startsWith('Exception: ')) {
          message = message.replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isModern = Provider.of<ThemeService>(context).isModern;
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
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                   Container(
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Aidat Tanımla',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                 child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: isModern ? AppColors.primary : AppColors.mgmtPrimary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Aidat Bilgileri',
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      if (widget.siteId == null) ...[
                        const Text('Site Seçin', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(height: 8),
                        _isLoadingSites 
                          ? const Center(child: CircularProgressIndicator())
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isModern ? Colors.white.withOpacity(0.05) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isModern ? Colors.white10 : AppColors.mgmtBorder),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSiteId,
                                  isExpanded: true,
                                  dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: isModern ? Colors.white54 : AppColors.mgmtPrimary),
                                  hint: Text('Site Seçin', style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtSecondary)),
                                  items: _sites.map((site) {
                                    return DropdownMenuItem<String>(
                                      value: site['id'] as String,
                                      child: Text(site['name'] ?? '', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedSiteId = val);
                                    _fetchBlocks();
                                  },
                                ),
                              ),
                            ),
                        const SizedBox(height: 24),
                      ],
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
                        decoration: InputDecoration(
                          labelText: 'Aidat Tutarı (TL)',
                          labelStyle: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtSecondary),
                          prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: isModern ? AppColors.secondary : AppColors.mgmtPrimary),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isModern ? Colors.white10 : AppColors.mgmtBorder)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Aidat Ayı', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontWeight: FontWeight.w600)),
                        subtitle: Text(DateFormat('MMMM yyyy').format(_selectedDate), style: TextStyle(color: isModern ? AppColors.secondary : AppColors.mgmtAccent)),
                        trailing: Icon(Icons.calendar_month_rounded, color: isModern ? AppColors.secondary : AppColors.mgmtAccent),
                        onTap: () => _selectDate(context),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Son Ödeme Tarihi', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontWeight: FontWeight.w600)),
                        subtitle: Text(DateFormat('dd MMMM yyyy').format(_dueDate), style: TextStyle(color: Colors.redAccent.withOpacity(0.8))),
                        trailing: const Icon(Icons.event_busy_rounded, color: Colors.redAccent),
                        onTap: () => _selectDueDate(context),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ibanController,
                        style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
                        decoration: InputDecoration(
                          labelText: 'IBAN',
                          labelStyle: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtSecondary),
                          prefixIcon: Icon(Icons.credit_card_rounded, color: isModern ? AppColors.secondary : AppColors.mgmtPrimary),
                          hintText: 'TR00...',
                          hintStyle: TextStyle(color: isModern ? Colors.white24 : Colors.black26),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isModern ? Colors.white10 : AppColors.mgmtBorder)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ibanHolderController,
                        style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
                        decoration: InputDecoration(
                          labelText: 'IBAN Sahibi Ad Soyad',
                          labelStyle: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtSecondary),
                          prefixIcon: Icon(Icons.person_rounded, color: isModern ? AppColors.secondary : AppColors.mgmtPrimary),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isModern ? Colors.white10 : AppColors.mgmtBorder)),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Divider(color: Colors.white10, height: 1),
                      ),
                      Row(
                        children: [
                          Icon(Icons.layers_outlined, color: isModern ? AppColors.primary : AppColors.mgmtPrimary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Blok Seçimi',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isModern ? Colors.white : AppColors.mgmtTextHeading),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingBlocks)
                        const Center(child: CircularProgressIndicator())
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _blocks.length,
                          itemBuilder: (context, index) {
                            final block = _blocks[index];
                            final id = block['id'] as String;
                            final isSelected = _selectedBlockIds.contains(id);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isModern ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: CheckboxListTile(
                                title: Text(block['name'] ?? '', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontWeight: FontWeight.w500)),
                                value: isSelected,
                                activeColor: isModern ? AppColors.secondary : AppColors.mgmtAccent,
                                checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedBlockIds.add(id);
                                    } else {
                                      _selectedBlockIds.remove(id);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 32),
                      if (_isSaving)
                        const Center(child: CircularProgressIndicator())
                      else
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: isModern 
                                ? [const Color(0xFF3B82F6), const Color(0xFF8B5CF6)]
                                : [AppColors.mgmtPrimary, const Color(0xFF0D2B4E)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _saveDues,
                              borderRadius: BorderRadius.circular(16),
                              child: const Center(
                                child: Text(
                                  'Aidatları Oluştur',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';

/// A web-optimized dialog for viewing and managing Site Structure (Blocks & Apartments).
/// Replaces the mobile SiteStructureScreen when opened from the web dashboard.
class WebSiteStructureDialog extends StatefulWidget {
  final String siteId;
  const WebSiteStructureDialog({super.key, required this.siteId});

  @override
  State<WebSiteStructureDialog> createState() => _WebSiteStructureDialogState();
}

class _WebSiteStructureDialogState extends State<WebSiteStructureDialog> {
  List<dynamic> _blocks = [];
  bool _isLoading = true;
  String? _siteType;
  String? _siteName;
  
  // Apartment view state
  String? _selectedBlockId;
  String? _selectedBlockName;
  List<dynamic> _apartments = [];
  bool _isLoadingApartments = false;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final siteRes = await SupabaseService.client
          .from('sites')
          .select('type, name')
          .eq('id', widget.siteId)
          .single();
      _siteType = siteRes['type'];
      _siteName = siteRes['name'];

      final response = await SupabaseService.client
          .from('blocks')
          .select('*, apartments(count)')
          .filter('deleted_at', 'is', null)
          .eq('site_id', widget.siteId)
          .order('name');

      final sortedBlocks = List<dynamic>.from(response);
      sortedBlocks.sort((a, b) {
        final aName = a['name'].toString();
        final bName = b['name'].toString();
        final aNumMatch = RegExp(r'\d+').firstMatch(aName);
        final bNumMatch = RegExp(r'\d+').firstMatch(bName);
        if (aNumMatch != null && bNumMatch != null) {
          final aNum = int.parse(aNumMatch.group(0)!);
          final bNum = int.parse(bNumMatch.group(0)!);
          if (aNum != bNum) return aNum.compareTo(bNum);
        }
        return aName.compareTo(bName);
      });
      _blocks = sortedBlocks;

      if (_siteType == 'apartment' && _blocks.isEmpty && mounted) {
        await _createDefaultBlock();
      }
    } catch (e) {
      print('Error fetching details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createDefaultBlock() async {
    try {
      await SupabaseService.client
          .from('blocks')
          .insert({'site_id': widget.siteId, 'name': 'Bina'})
          .select()
          .single();
      final response = await SupabaseService.client
          .from('blocks')
          .select('*, apartments(count)')
          .filter('deleted_at', 'is', null)
          .eq('site_id', widget.siteId)
          .order('name');
      setState(() => _blocks = response);
    } catch (e) {
      print('Error creating default block: $e');
    }
  }

  Future<void> _fetchApartments(String blockId, String blockName) async {
    setState(() {
      _selectedBlockId = blockId;
      _selectedBlockName = blockName;
      _isLoadingApartments = true;
    });
    try {
      final response = await SupabaseService.client
          .from('apartments')
          .select('*, profiles(full_name, phone_number)')
          .filter('deleted_at', 'is', null)
          .eq('block_id', blockId);
      
      final sortedList = List<dynamic>.from(response);
      sortedList.sort((a, b) {
        final aNum = int.tryParse(a['number'].toString()) ?? 0;
        final bNum = int.tryParse(b['number'].toString()) ?? 0;
        if (aNum != bNum) return aNum.compareTo(bNum);
        return a['number'].toString().compareTo(b['number'].toString());
      });
      setState(() => _apartments = sortedList);
    } catch (e) {
      print('Error fetching apartments: $e');
    } finally {
      if (mounted) setState(() => _isLoadingApartments = false);
    }
  }

  void _goBackToBlocks() {
    setState(() {
      _selectedBlockId = null;
      _selectedBlockName = null;
      _apartments = [];
    });
  }

  Future<void> _addBlock() async {
    final nameController = TextEditingController();
    final aptCountController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _siteType == 'apartment' ? l10n.createApartments : l10n.addBlock,
          style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_siteType != 'apartment')
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
                  decoration: InputDecoration(
                    labelText: l10n.blockNameLabel,
                    labelStyle: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody),
                    prefixIcon: Icon(Icons.business_rounded, color: isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
                    filled: true,
                    fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              if (_siteType != 'apartment') const SizedBox(height: 16),
              TextField(
                controller: aptCountController,
                autofocus: _siteType == 'apartment',
                style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
                decoration: InputDecoration(
                  labelText: l10n.apartmentCountLabel,
                  hintText: 'Örn: 10',
                  labelStyle: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody),
                  hintStyle: TextStyle(color: isModern ? Colors.white30 : AppColors.mgmtTextBody.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.format_list_numbered_rounded, color: isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
                  filled: true,
                  fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isModern ? AppColors.primary : AppColors.mgmtPrimary,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final count = int.tryParse(aptCountController.text) ?? 0;
              if (count <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lütfen geçerli bir daire sayısı girin.'), backgroundColor: Colors.orange),
                );
                return;
              }
              if (_siteType != 'apartment' && nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lütfen bir blok adı girin.'), backgroundColor: Colors.orange),
                );
                return;
              }
              try {
                String blockId;
                if (_siteType == 'apartment' && _blocks.isNotEmpty) {
                  blockId = _blocks.first['id'];
                } else {
                  final blockResponse = await SupabaseService.client
                      .from('blocks')
                      .insert({
                        'site_id': widget.siteId,
                        'name': _siteType == 'apartment' ? 'Bina' : nameController.text.trim(),
                      })
                      .select()
                      .single();
                  blockId = blockResponse['id'];
                }
                final apartments = List.generate(count, (index) => {
                  'block_id': blockId,
                  'number': (index + 1).toString(),
                });
                await SupabaseService.client.from('apartments').insert(apartments);
                Navigator.pop(ctx);
                _fetchDetails();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _editBlock(dynamic block) async {
    final nameController = TextEditingController(text: block['name']);
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Bloğu Düzenle', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: nameController,
            autofocus: true,
            style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
            decoration: InputDecoration(
              labelText: l10n.blockNameLabel,
              labelStyle: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody),
              prefixIcon: Icon(Icons.business_rounded, color: isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
              filled: true,
              fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isModern ? AppColors.primary : AppColors.mgmtPrimary,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              try {
                await SupabaseService.client.from('blocks').update({'name': nameController.text}).eq('id', block['id']);
                Navigator.pop(ctx);
                _fetchDetails();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: Text(l10n.save, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBlock(dynamic block) async {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Bloğu Sil', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 18)),
            ),
          ],
        ),
        content: Text(
          '${block['name']} bloğunu ve dairelerini siliyorsunuz. Emin misiniz?',
          style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final now = DateTime.now().toIso8601String();
        await SupabaseService.client.from('blocks').update({'deleted_at': now}).eq('id', block['id']);
        await SupabaseService.client.from('apartments').update({'deleted_at': now}).eq('block_id', block['id']);
        _fetchDetails();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _manageResident(dynamic apartment) async {
    final l10n = AppLocalizations.of(context)!;
    final searchController = TextEditingController();
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    List<dynamic> searchResults = [];
    bool isSearching = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '${l10n.assignResident} (Daire ${apartment['number']})',
            style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (apartment['profiles'] != null) ...[
                  ListTile(
                    leading: const Icon(Icons.person, color: AppColors.primary),
                    title: Text(apartment['profiles']['full_name'] ?? 'İsimsiz',
                        style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                    subtitle: Text(apartment['profiles']['phone_number'] ?? 'Telefon yok',
                        style: TextStyle(color: isModern ? Colors.white60 : AppColors.mgmtTextBody)),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                      onPressed: () async {
                        await SupabaseService.client
                            .from('apartments')
                            .update({'resident_id': null})
                            .eq('id', apartment['id']);
                        Navigator.pop(ctx);
                        if (_selectedBlockId != null) {
                          _fetchApartments(_selectedBlockId!, _selectedBlockName!);
                        }
                      },
                    ),
                  ),
                  Divider(color: isModern ? Colors.white24 : Colors.grey.shade300),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: searchController,
                  style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
                  decoration: InputDecoration(
                    labelText: l10n.searchResidentLabel,
                    labelStyle: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody),
                    prefixIcon: Icon(Icons.search_rounded, color: isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
                    filled: true,
                    fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: isSearching
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton(
                            icon: Icon(Icons.arrow_forward_rounded, color: isModern ? AppColors.primary : AppColors.mgmtPrimary),
                            onPressed: () async {
                              if (searchController.text.isEmpty) return;
                              setDialogState(() => isSearching = true);
                              try {
                                final results = await SupabaseService.client
                                    .from('profiles')
                                    .select()
                                    .eq('role', 'resident')
                                    .filter('deleted_at', 'is', null)
                                    .or('full_name.ilike.%${searchController.text}%,phone_number.ilike.%${searchController.text}%')
                                    .limit(5);
                                setDialogState(() => searchResults = results);
                              } finally {
                                setDialogState(() => isSearching = false);
                              }
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (searchResults.isNotEmpty)
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final person = searchResults[index];
                        return ListTile(
                          title: Text(person['full_name'] ?? 'İsimsiz',
                              style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                          subtitle: Text(person['phone_number'] ?? 'Telefon yok',
                              style: TextStyle(color: isModern ? Colors.white60 : AppColors.mgmtTextBody)),
                          onTap: () async {
                            await SupabaseService.client
                                .from('apartments')
                                .update({'resident_id': person['id']})
                                .eq('id', apartment['id']);
                            Navigator.pop(ctx);
                            if (_selectedBlockId != null) {
                              _fetchApartments(_selectedBlockId!, _selectedBlockName!);
                            }
                          },
                        );
                      },
                    ),
                  ),
                if (searchResults.isEmpty && searchController.text.isNotEmpty && !isSearching)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(l10n.noResultsFoundRedirect, style: const TextStyle(fontSize: 12, color: Colors.orangeAccent)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isModern = Provider.of<ThemeService>(context).isModern;
    final l10n = AppLocalizations.of(context)!;
    final bgColor = isModern ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isModern ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isModern ? Colors.white : Colors.black87;
    final subtextColor = isModern ? Colors.white54 : Colors.black54;
    final primaryColor = isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 800,
          height: MediaQuery.of(context).size.height * 0.85,
          color: bgColor,
          child: Column(
            children: [
              // ──── Header ────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(bottom: BorderSide(color: isModern ? Colors.white10 : Colors.black.withOpacity(0.06))),
                ),
                child: Row(
                  children: [
                    // Back button when viewing apartments
                    if (_selectedBlockId != null)
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: textColor, size: 22),
                        onPressed: _goBackToBlocks,
                        tooltip: 'Geri',
                      ),
                    if (_selectedBlockId != null) const SizedBox(width: 8),
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _selectedBlockId != null ? Icons.home_rounded : Icons.account_tree_rounded,
                        color: primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedBlockId != null
                                ? '$_selectedBlockName Daireleri'
                                : (_siteName ?? (_siteType == 'apartment' ? l10n.binaYapisi : l10n.siteYapisi)),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          if (_selectedBlockId == null)
                            Text(
                              _siteType == 'apartment' ? 'Bina yapısını yönetin' : 'Blok ve daire yapısını yönetin',
                              style: TextStyle(fontSize: 13, color: subtextColor),
                            ),
                        ],
                      ),
                    ),
                    // Add Block / Refresh buttons
                    if (_selectedBlockId == null) ...[
                      IconButton(
                        icon: Icon(Icons.refresh_rounded, color: subtextColor, size: 20),
                        onPressed: _fetchDetails,
                        tooltip: 'Yenile',
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _addBlock,
                        icon: Icon(
                          _siteType == 'apartment' ? Icons.home_work_rounded : Icons.add_business_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          _siteType == 'apartment' ? l10n.createApartments : l10n.addBlock,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    // Close button
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: subtextColor, size: 22),
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                      tooltip: 'Kapat',
                    ),
                  ],
                ),
              ),

              // ──── Summary Row ────
              if (_selectedBlockId == null && !_isLoading && _blocks.isNotEmpty)
                _buildBlocksSummary(isModern, primaryColor, textColor, subtextColor),

              if (_selectedBlockId != null && !_isLoadingApartments && _apartments.isNotEmpty)
                _buildAptSummary(isModern, primaryColor, textColor, subtextColor, l10n),

              // ──── Body ────
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _selectedBlockId != null
                        ? _buildApartmentView(isModern, cardBg, textColor, subtextColor, primaryColor, l10n)
                        : _buildBlocksView(isModern, cardBg, textColor, subtextColor, primaryColor, l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──── Blocks Summary ────
  Widget _buildBlocksSummary(bool isModern, Color primaryColor, Color textColor, Color subtextColor) {
    int totalApts = 0;
    for (var b in _blocks) {
      totalApts += (b['apartments'] as List).isNotEmpty ? (b['apartments'][0]['count'] ?? 0) as int : 0;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _buildMiniStat(Icons.layers_rounded, '${_blocks.length}', 'Blok', Colors.blueAccent, isModern),
          const SizedBox(width: 16),
          _buildMiniStat(Icons.home_rounded, '$totalApts', 'Daire', Colors.orangeAccent, isModern),
        ],
      ),
    );
  }

  // ──── Apartment Summary ────
  Widget _buildAptSummary(bool isModern, Color primaryColor, Color textColor, Color subtextColor, AppLocalizations l10n) {
    final full = _apartments.where((a) => a['resident_id'] != null).length;
    final empty = _apartments.length - full;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _buildMiniStat(Icons.analytics_rounded, '${_apartments.length}', 'Toplam', Colors.blueAccent, isModern),
          const SizedBox(width: 16),
          _buildMiniStat(Icons.person_pin_circle_rounded, '$full', 'Dolu', Colors.greenAccent, isModern),
          const SizedBox(width: 16),
          _buildMiniStat(Icons.person_off_rounded, '$empty', 'Boş', Colors.redAccent, isModern),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color, bool isModern) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isModern ? Colors.white : Colors.black87, fontSize: 15)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: isModern ? Colors.white54 : Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }

  // ──── Blocks Grid View ────
  Widget _buildBlocksView(bool isModern, Color cardBg, Color textColor, Color subtextColor, Color primaryColor, AppLocalizations l10n) {
    if (_blocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree_outlined, size: 64, color: subtextColor),
            const SizedBox(height: 16),
            Text('Henüz blok eklenmemiş', style: TextStyle(fontSize: 16, color: subtextColor)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addBlock,
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: Text(l10n.addBlock, style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        mainAxisExtent: 130,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _blocks.length,
      itemBuilder: (context, index) {
        final block = _blocks[index];
        final aptCount = (block['apartments'] as List).isNotEmpty
            ? block['apartments'][0]['count'] ?? 0
            : 0;
        final blockColors = [
          const Color(0xFF6366F1),
          const Color(0xFF06B6D4),
          const Color(0xFF8B5CF6),
          const Color(0xFF10B981),
          const Color(0xFFF59E0B),
          const Color(0xFFEF4444),
        ];
        final accentColor = blockColors[index % blockColors.length];

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _fetchApartments(
              block['id'],
              _siteType == 'apartment' ? l10n.apartmentList : block['name'],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                boxShadow: isModern ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.business_rounded, color: accentColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _siteType == 'apartment' ? l10n.apartmentList : block['name'],
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_siteType != 'apartment')
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_horiz_rounded, size: 20, color: subtextColor),
                            onSelected: (val) {
                              if (val == 'edit') _editBlock(block);
                              if (val == 'delete') _deleteBlock(block);
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit, size: 20), title: Text(l10n.edit))),
                              PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete, color: Colors.redAccent, size: 20), title: Text(l10n.delete))),
                            ],
                          ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.home_outlined, size: 16, color: subtextColor),
                        const SizedBox(width: 6),
                        Text('$aptCount Daire', style: TextStyle(fontSize: 13, color: subtextColor)),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded, size: 20, color: subtextColor),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ──── Apartments Grid View ────
  Widget _buildApartmentView(bool isModern, Color cardBg, Color textColor, Color subtextColor, Color primaryColor, AppLocalizations l10n) {
    if (_isLoadingApartments) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_apartments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, size: 64, color: subtextColor),
            const SizedBox(height: 16),
            Text(l10n.noApartmentsFound, style: TextStyle(fontSize: 16, color: subtextColor)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 110,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _apartments.length,
      itemBuilder: (context, index) {
        final apt = _apartments[index];
        final resident = apt['profiles'];
        final isFull = resident != null;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _manageResident(apt),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFull
                      ? Colors.green.withOpacity(0.3)
                      : (isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                ),
                boxShadow: isModern
                    ? []
                    : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isFull ? Icons.person_rounded : Icons.person_outline_rounded,
                        color: isFull ? Colors.green : subtextColor,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'No: ${apt['number']}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                      ),
                      const Spacer(),
                      Icon(Icons.edit_outlined, size: 14, color: subtextColor),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    isFull ? (resident['full_name'] ?? 'İsimsiz') : l10n.emptyApartment,
                    style: TextStyle(
                      fontSize: 12,
                      color: isFull ? textColor : subtextColor,
                      fontWeight: isFull ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isFull && resident['phone_number'] != null)
                    Text(
                      resident['phone_number'],
                      style: TextStyle(fontSize: 11, color: subtextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

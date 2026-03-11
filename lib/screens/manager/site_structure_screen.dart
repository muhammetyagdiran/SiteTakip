import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import 'package:flutter/services.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import '../../services/theme_service.dart';
import 'package:provider/provider.dart';

class SiteStructureScreen extends StatefulWidget {
  final String? siteId;
  final VoidCallback? onBack;
  const SiteStructureScreen({super.key, this.siteId, this.onBack});

  @override
  State<SiteStructureScreen> createState() => _SiteStructureScreenState();
}

class _SiteStructureScreenState extends State<SiteStructureScreen> {
  List<dynamic> _blocks = [];
  bool _isLoading = true;
  String? _siteType;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    if (widget.siteId == null) return;
    setState(() => _isLoading = true);
    try {
      // Fetch site type
      final siteRes = await SupabaseService.client
          .from('sites')
          .select('type')
          .eq('id', widget.siteId as String)
          .single();
      _siteType = siteRes['type'];

      // Fetch blocks
      final response = await SupabaseService.client
          .from('blocks')
          .select('*, apartments(count)')
          .filter('deleted_at', 'is', null)
          .eq('site_id', widget.siteId as String)
          .order('name');
      
      // Explicitly sort blocks naturally by name (A, B, C... or 1, 2, 10...)
      final sortedBlocks = List<dynamic>.from(response);
      sortedBlocks.sort((a, b) {
        // Handle natural sort for something like "Blok 1, Blok 2, Blok 10"
        final aName = a['name'].toString();
        final bName = b['name'].toString();
        
        // Try to find numbers in the string for natural sort
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

      // Logic for Apartment: If no block exists, create one automatically
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
      final blockResponse = await SupabaseService.client
          .from('blocks')
          .insert({
            'site_id': widget.siteId,
            'name': 'Bina', // Default name for apartment
          })
          .select()
          .single();
      
      // Refresh to show the new default block
      final response = await SupabaseService.client
          .from('blocks')
          .select('*, apartments(count)')
          .filter('deleted_at', 'is', null)
          .eq('site_id', widget.siteId as String)
          .order('name');
      
      setState(() => _blocks = response);
    } catch (e) {
      print('Error creating default block: $e');
    }
  }

  Future<void> _fetchBlocks() async {
    _fetchDetails();
  }

  Future<void> _addBlock() async {
    final nameController = TextEditingController();
    final aptCountController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_siteType == 'apartment' ? l10n.createApartments : l10n.addBlock, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white : AppColors.mgmtTextHeading)),
                const SizedBox(height: 24),
                if (_siteType != 'apartment')
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white : AppColors.mgmtTextHeading),
                    decoration: InputDecoration(
                      labelText: l10n.blockNameLabel,
                      labelStyle: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white70 : AppColors.mgmtTextBody),
                      prefixIcon: Icon(Icons.business_rounded, color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
                      filled: true,
                      fillColor: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    autofocus: true,
                  ),
                if (_siteType != 'apartment') const SizedBox(height: 16),
                TextField(
                  controller: aptCountController,
                  style: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white : AppColors.mgmtTextHeading),
                  decoration: InputDecoration(
                    labelText: l10n.apartmentCountLabel,
                    hintText: 'Örn: 10',
                    labelStyle: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white70 : AppColors.mgmtTextBody),
                    hintStyle: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white30 : AppColors.mgmtTextBody.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.format_list_numbered_rounded, color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
                    filled: true,
                    fillColor: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: _siteType == 'apartment',
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                    if (widget.siteId == null) return;
                    
                    final count = int.tryParse(aptCountController.text) ?? 0;
                    if (count <= 0) {
                      if (mounted) {
                        final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Text(l10n.errorLabel, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                            content: Text('Lütfen geçerli bir daire sayısı girin.', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                child: Text('Tamam', style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }
                      return;
                    }

                    if (_siteType != 'apartment' && nameController.text.trim().isEmpty) {
                      if (mounted) {
                        final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Text(l10n.errorLabel, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                            content: Text('Lütfen bir blok adı girin.', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                child: Text('Tamam', style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }
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

                      Navigator.pop(context);
                      _fetchBlocks();
                    } catch (e) {
                      if (mounted) {
                        final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
                        final l10n = AppLocalizations.of(context)!;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: isModern ? const Color(0xFF1E1E1E) : Colors.white,
                            title: Text(l10n.errorLabel, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                            content: Text('Hata: $e', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Tamam', style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody)),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Provider.of<ThemeService>(context, listen: false).isModern ? AppColors.primary : AppColors.mgmtPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  child: Text(l10n.save, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Future<void> _editBlock(dynamic block) async {
    final nameController = TextEditingController(text: block['name']);
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Düzenle', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white : AppColors.mgmtTextHeading)), 
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white : AppColors.mgmtTextHeading),
                  decoration: InputDecoration(
                    labelText: l10n.blockNameLabel,
                    labelStyle: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white70 : AppColors.mgmtTextBody),
                    prefixIcon: Icon(Icons.business_rounded, color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
                    filled: true,
                    fillColor: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                    try {
                      await SupabaseService.client
                          .from('blocks')
                          .update({'name': nameController.text})
                          .eq('id', block['id']);
                      Navigator.pop(context);
                      _fetchBlocks();
                    } catch (e) {
                      if (mounted) {
                        final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
                        final l10n = AppLocalizations.of(context)!;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: isModern ? const Color(0xFF1E1E1E) : Colors.white,
                            title: Text(l10n.errorLabel, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                            content: Text('Hata: $e', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Tamam', style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody)),
                              ),
                            ],
                          ),
                        );
                      }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Provider.of<ThemeService>(context, listen: false).isModern ? AppColors.primary : AppColors.mgmtPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: Text(l10n.save, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBlock(dynamic block) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
        return AlertDialog(
          backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Bloğu Sil', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 18)),
              ),
            ],
          ),
          content: Text('${block['name']} bloğunu ve dairelerini siliyorsunuz. Emin misiniz?', 
            style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontSize: 14)),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.cancel, style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.delete, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final now = DateTime.now().toIso8601String();
        // Soft delete block
        await SupabaseService.client
            .from('blocks')
            .update({'deleted_at': now})
            .eq('id', block['id']);
        
        // Soft delete all apartments in this block
        await SupabaseService.client
            .from('apartments')
            .update({'deleted_at': now})
            .eq('block_id', block['id']);

        _fetchBlocks();
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) {
              final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
              return AlertDialog(
                backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(l10n.errorLabel, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                content: Text('Hata: $e', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Tamam', style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            // Modern header
            Container(
              padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Provider.of<ThemeService>(context, listen: false).isModern 
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
                      _siteType == 'apartment' ? l10n.binaYapisi : l10n.siteYapisi,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchBlocks, 
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _blocks.isEmpty
                        ? Center(child: Text(l10n.notConfigured))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _blocks.length + 1, // Header + list
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // Summary Info
                                int totalApts = 0;
                                for (var b in _blocks) {
                                  totalApts += (b['apartments'] as List).isNotEmpty 
                                      ? (b['apartments'][0]['count'] ?? 0) as int
                                      : 0;
                                }
                                return _buildSummaryRow(l10n, _blocks.length, totalApts);
                              }
                              
                              final blockIndex = index - 1;
                              final block = _blocks[blockIndex];
                              final aptCount = (block['apartments'] as List).isNotEmpty 
                                  ? block['apartments'][0]['count'] ?? 0 
                                  : 0;
                                  
                              return TweenAnimationBuilder<double>(
                                duration: Duration(milliseconds: 300 + (blockIndex * 100)),
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
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ApartmentListScreen(
                                            siteId: widget.siteId ?? '',
                                            blockId: block['id'],
                                            blockName: _siteType == 'apartment' ? l10n.apartmentList : block['name'],
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 24),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _siteType == 'apartment' ? l10n.apartmentList : block['name'],
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white : AppColors.mgmtTextHeading,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '$aptCount ${l10n.apartment}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white70 : AppColors.mgmtTextBody,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_siteType != 'apartment')
                                            PopupMenuButton<String>(
                                              icon: Icon(Icons.more_horiz_rounded, size: 22, color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white54 : AppColors.mgmtTextBody.withOpacity(0.5)),
                                              onSelected: (val) {
                                                if (val == 'edit') _editBlock(block);
                                                if (val == 'delete') _deleteBlock(block);
                                              },
                                              itemBuilder: (context) => [
                                                PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit, size: 20), title: Text(l10n.edit))),
                                                PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete, color: Colors.redAccent, size: 20), title: Text(l10n.delete))),
                                              ],
                                            ),
                                          Icon(Icons.chevron_right_rounded, color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white24 : AppColors.mgmtTextBody.withOpacity(0.2)),
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
          onPressed: _addBlock,
          label: Text(_siteType == 'apartment' ? l10n.createApartments : l10n.addBlock, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          icon: Icon(_siteType == 'apartment' ? Icons.home_work_rounded : Icons.add_business_rounded, color: Colors.white, size: 24),
          backgroundColor: Provider.of<ThemeService>(context, listen: false).isModern ? AppColors.primary : AppColors.mgmtPrimary,
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSummaryRow(AppLocalizations l10n, int blockCount, int apartmentCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Expanded(child: _buildSummaryCard('Bloklar', blockCount.toString(), Icons.layers_rounded, Colors.blueAccent)),
          const SizedBox(width: 12),
          Expanded(child: _buildSummaryCard('Daireler', apartmentCount.toString(), Icons.home_rounded, Colors.orangeAccent)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold,
            color: isModern ? Colors.white : AppColors.mgmtTextHeading,
          )),
          Text(label, style: TextStyle(
            fontSize: 10, 
            color: isModern ? Colors.white54 : AppColors.mgmtTextBody,
          )),
        ],
      ),
    );
  }
}

class ApartmentListScreen extends StatefulWidget {
  final String siteId;
  final String blockId;
  final String blockName;
  final VoidCallback? onBack;
  const ApartmentListScreen({
    super.key, 
    required this.siteId, 
    required this.blockId, 
    required this.blockName,
    this.onBack,
  });

  @override
  State<ApartmentListScreen> createState() => _ApartmentListScreenState();
}

class _ApartmentListScreenState extends State<ApartmentListScreen> {
  List<dynamic> _apartments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApartments();
  }

  Future<void> _fetchApartments() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client
          .from('apartments')
          .select('*, profiles(full_name, phone_number)')
          .filter('deleted_at', 'is', null) // Soft delete filter
          .eq('block_id', widget.blockId);
      
      // Natural sort for apartment numbers (1, 2, 10 instead of 1, 10, 2)
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  colors: Provider.of<ThemeService>(context, listen: false).isModern 
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
                      '${widget.blockName} Daireleri',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _apartments.isEmpty
                      ? Center(child: Text(l10n.noApartmentsFound))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: _apartments.length + 1, // Summary + list
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              int fullApts = _apartments.where((a) => a['resident_id'] != null).length;
                              return _buildAptSummaryRow(l10n, _apartments.length, fullApts);
                            }

                            final aptIndex = index - 1;
                            final apt = _apartments[aptIndex];
                            final resident = apt['profiles'];
                            final isFull = resident != null;

                            return TweenAnimationBuilder<double>(
                              duration: Duration(milliseconds: 300 + (aptIndex * 50)),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 15 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: child,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  onTap: () => _manageResident(apt),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isFull 
                                                ? (isModern ? Colors.greenAccent : AppColors.primary).withOpacity(0.15)
                                                : (isModern ? Colors.white : Colors.grey).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            isFull ? Icons.person_rounded : Icons.person_outline_rounded, 
                                            color: isFull 
                                                ? (isModern ? Colors.greenAccent : AppColors.primary)
                                                : (isModern ? Colors.white.withOpacity(0.6) : Colors.grey),
                                            size: 24
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'No: ${apt['number']}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                isFull 
                                                    ? (resident['full_name'] ?? 'İsimsiz Sakin')
                                                    : l10n.emptyApartment,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isModern 
                                                      ? (isFull ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.7))
                                                      : AppColors.mgmtTextBody,
                                                  fontWeight: isFull ? FontWeight.w500 : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.edit_outlined, 
                                          size: 18, 
                                          color: isModern ? Colors.white38 : AppColors.mgmtTextBody.withOpacity(0.3)
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _manageResident(dynamic apartment) async {
    final l10n = AppLocalizations.of(context)!;
    final searchController = TextEditingController();
    List<dynamic> _searchResults = [];
    bool _isSearching = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${l10n.assignResident} (${l10n.apartmentCountLabel.split(' ')[0]} ${apartment['number']})', 
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                      )),
                  const SizedBox(height: 20),
                  if (apartment['profiles'] != null) ...[
                    ListTile(
                      leading: const Icon(Icons.person, color: AppColors.primary),
                      title: Text(apartment['profiles']['full_name']),
                      subtitle: Text(apartment['profiles']['phone_number'] ?? 'No Phone'),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                        onPressed: () async {
                          await SupabaseService.client
                              .from('apartments')
                              .update({'resident_id': null})
                              .eq('id', apartment['id']);
                          Navigator.pop(context);
                          _fetchApartments();
                        },
                      ),
                    ),
                    const Divider(color: Colors.white24),
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
                      suffixIcon: _isSearching 
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton(
                            icon: Icon(Icons.arrow_forward_rounded, color: isModern ? AppColors.primary : AppColors.mgmtPrimary),
                            onPressed: () async {
                              if (searchController.text.isEmpty) return;
                              setModalState(() => _isSearching = true);
                              try {
                                final results = await SupabaseService.client
                                    .from('profiles')
                                    .select()
                                    .eq('role', 'resident')
                                    .eq('site_id', widget.siteId as String)
                                    .filter('deleted_at', 'is', null) // Soft delete filter
                                    .or('full_name.ilike.%${searchController.text}%,phone_number.ilike.%${searchController.text}%')
                                    .limit(5);
                                setModalState(() => _searchResults = results);
                              } finally {
                                setModalState(() => _isSearching = false);
                              }
                            },
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_searchResults.isNotEmpty)
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final person = _searchResults[index];
                          return ListTile(
                            title: Text(person['full_name'] ?? 'İsimsiz', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                            subtitle: Text(person['phone_number'] ?? 'Telefon yok', style: TextStyle(color: isModern ? Colors.white60 : AppColors.mgmtTextBody)),
                            onTap: () async {
                              await SupabaseService.client
                                  .from('apartments')
                                  .update({'resident_id': person['id']})
                                  .eq('id', apartment['id']);
                              Navigator.pop(context);
                              _fetchApartments();
                            },
                          );
                        },
                      ),
                    ),
                  if (_searchResults.isEmpty && searchController.text.isNotEmpty && !_isSearching)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(l10n.noResultsFoundRedirect, 
                        style: const TextStyle(fontSize: 12, color: Colors.orangeAccent)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildAptSummaryRow(AppLocalizations l10n, int total, int full) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Expanded(child: _buildSummaryCard('Toplam', total.toString(), Icons.analytics_rounded, Colors.blueAccent)),
          const SizedBox(width: 12),
          Expanded(child: _buildSummaryCard('Dolu', full.toString(), Icons.person_pin_circle_rounded, Colors.greenAccent)),
          const SizedBox(width: 12),
          Expanded(child: _buildSummaryCard('Boş', (total - full).toString(), Icons.person_off_rounded, Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold,
            color: isModern ? Colors.white : AppColors.mgmtTextHeading,
          )),
          Text(label, style: TextStyle(
            fontSize: 10, 
            color: isModern ? Colors.white54 : AppColors.mgmtTextBody,
          )),
        ],
      ),
    );
  }
}

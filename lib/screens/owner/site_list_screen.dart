import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import 'create_site_screen.dart';
import '../manager/site_structure_screen.dart';

class SiteListScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const SiteListScreen({super.key, this.onBack});

  @override
  State<SiteListScreen> createState() => _SiteListScreenState();
}

class _SiteListScreenState extends State<SiteListScreen> {
  final List<dynamic> _sites = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSites();
  }

  Future<void> _fetchSites() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final ownerId = authService.currentUser?.id;
      if (ownerId == null) return;

      final response = await SupabaseService.client
          .from('sites')
          .select()
          .eq('owner_id', ownerId)
          .filter('deleted_at', 'is', null) // Soft delete filter
          .order('name');
      if (mounted) {
        setState(() {
          _sites.clear();
          _sites.addAll(response);
        });
      }
    } catch (e) {
      print('Error fetching sites: $e');
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSite(String id) async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isModern = themeService.isModern;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Siteyi Sil', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 18)),
            ),
          ],
        ),
        content: Text('Bu siteyi siliyorsunuz. Bu işlem geri alınamaz.', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontSize: 14)),
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
            child: Text('Vazgeç', style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.client
            .from('sites')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', id);
        _fetchSites();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Site silindi.')));
        }
      } catch (e) {
        print('Error deleting site: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    }
  }

  void _addOrEditSite([Map<String, dynamic>? site]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateSiteScreen(
          site: site,
          onSaved: () {
            Navigator.pop(context);
            _fetchSites();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context);
    final isModern = themeService.isModern;

    return Scaffold(
      extendBody: true,
      body: GradientBackground(
        child: Column(
          children: [
            // Modern header
            Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 12, 16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.mySites,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_sites.length} site kayıtlı',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchSites,
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 24),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Site list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                              const SizedBox(height: 12),
                              Text(
                                'VERİTABANI HATASI (Lütfen Asistana Söyleyin):',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, color: isModern ? Colors.white70 : AppColors.mgmtTextBody),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _sites.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.business_outlined, size: 48, color: isModern ? Colors.white24 : AppColors.mgmtSecondary.withOpacity(0.3)),
                                  const SizedBox(height: 12),
                                  Text(l10n.noSitesYet, style: TextStyle(
                                    color: isModern ? AppColors.textBody : AppColors.mgmtTextBody,
                                    fontSize: 14,
                                  )),
                                ],
                              ),
                            )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _sites.length,
                          itemBuilder: (context, index) {
                            final site = _sites[index];
                            // Rotate colors for visual variety
                            final cardColors = [
                              const Color(0xFF6366F1), // Indigo
                              const Color(0xFF06B6D4), // Cyan
                              const Color(0xFF8B5CF6), // Violet
                              const Color(0xFF10B981), // Emerald
                              const Color(0xFFF59E0B), // Amber
                              const Color(0xFFEF4444), // Red
                            ];
                            final accentColor = cardColors[index % cardColors.length];
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isModern ? Colors.white.withOpacity(0.05) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isModern ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.12),
                                  ),
                                  boxShadow: isModern ? null : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      // Color accent strip
                                      Container(
                                        width: 4,
                                        decoration: BoxDecoration(
                                          color: accentColor,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            bottomLeft: Radius.circular(16),
                                          ),
                                        ),
                                      ),
                                      // Content
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          child: Row(
                                            children: [
                                              // Icon
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: accentColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(Icons.business_rounded, color: accentColor, size: 26),
                                              ),
                                              const SizedBox(width: 14),
                                              // Text
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      site['name'] ?? l10n.unknownSite,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                        color: isModern ? Colors.white : AppColors.mgmtTextHeading,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      site['address'] ?? l10n.noAddressProvided,
                                                      style: TextStyle(
                                                        color: isModern ? Colors.white54 : AppColors.mgmtTextBody,
                                                        fontSize: 12,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Actions
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildActionIcon(
                                                    Icons.account_tree_outlined,
                                                    accentColor,
                                                    isModern,
                                                    () => Navigator.push(context, MaterialPageRoute(
                                                      builder: (context) => SiteStructureScreen(siteId: site['id']),
                                                    )),
                                                  ),
                                                  _buildActionIcon(
                                                    Icons.edit_outlined,
                                                    isModern ? Colors.white54 : AppColors.mgmtTextBody,
                                                    isModern,
                                                    () => _addOrEditSite(site),
                                                  ),
                                                  _buildActionIcon(
                                                    Icons.delete_outline,
                                                    Colors.redAccent.withOpacity(0.7),
                                                    isModern,
                                                    () => _deleteSite(site['id']),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 95),
        child: FloatingActionButton.extended(
          onPressed: () => _addOrEditSite(),
          label: const Text('Yeni Site Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          icon: const Icon(Icons.add_business_rounded, color: Colors.white, size: 24),
          backgroundColor: isModern ? AppColors.primary : AppColors.mgmtPrimary,
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, bool isModern, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

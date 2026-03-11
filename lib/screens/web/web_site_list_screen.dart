import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import '../owner/create_site_screen.dart';
import 'web_site_structure_dialog.dart';

class WebSiteListScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const WebSiteListScreen({super.key, this.onBack});

  @override
  State<WebSiteListScreen> createState() => _WebSiteListScreenState();
}

class _WebSiteListScreenState extends State<WebSiteListScreen> {
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
          .filter('deleted_at', 'is', null)
          .order('name');
          
      if (mounted) {
        setState(() {
          _sites.clear();
          _sites.addAll(response);
        });
      }
    } catch (e) {
      print('Error fetching web sites: $e');
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSite(String id, String siteName) async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isModern = themeService.isModern;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Siteyi Sil', 
                style: TextStyle(color: isModern ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          '"$siteName" isimli siteyi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(color: isModern ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Vazgeç', style: TextStyle(color: isModern ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: const Size(0, 48),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: 600,
            height: 800,
            child: CreateSiteScreen(
              site: site,
              onSaved: () {
                Navigator.pop(context);
                _fetchSites();
              },
            ),
          ),
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
      backgroundColor: Colors.transparent, // Background handled by parent
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.mySites,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isModern ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sisteminize kayıtlı olan tüm siteleri yönetin.',
                        style: TextStyle(
                          color: isModern ? Colors.white54 : Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _fetchSites,
                      icon: const Icon(Icons.refresh),
                      color: isModern ? Colors.white70 : Colors.black54,
                      tooltip: 'Yenile',
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _addOrEditSite(),
                      icon: const Icon(Icons.add_business, color: Colors.white),
                      label: const Text('Yeni Site Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
                            const SizedBox(height: 24),
                            Text(
                              'VERİTABANI HATASI (Lütfen Asistana Söyleyin):',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: isModern ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      )
                : _sites.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.business_outlined, size: 80, color: isModern ? Colors.white24 : Colors.black12),
                            const SizedBox(height: 24),
                            Text(l10n.noSitesYet, style: TextStyle(fontSize: 18, color: isModern ? Colors.white54 : Colors.black54)),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                              onPressed: () => _addOrEditSite(),
                              child: const Text('İlk Sitenizi Ekleyin'),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: GridView.builder(
                          padding: const EdgeInsets.only(bottom: 32),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            mainAxisExtent: 200,
                            crossAxisSpacing: 24,
                            mainAxisSpacing: 24,
                          ),
                          itemCount: _sites.length,
                          itemBuilder: (context, index) {
                            final site = _sites[index];
                            return _buildSiteCard(site, index, isModern, l10n);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(Map<String, dynamic> site, int index, bool isModern, AppLocalizations l10n) {
    // Dynamic colors for cards
    final cardColors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
    ];
    final accentColor = cardColors[index % cardColors.length];
    final bgColor = isModern ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: isModern ? Border.all(color: Colors.white.withOpacity(0.05)) : Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: isModern ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top section
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.business_rounded, color: accentColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          site['name'] ?? l10n.unknownSite,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: isModern ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          site['address'] ?? l10n.noAddressProvided,
                          style: TextStyle(
                            color: isModern ? Colors.white54 : Colors.black54,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Divider
          Divider(height: 1, color: isModern ? Colors.white10 : Colors.black.withOpacity(0.05)),
          
          // Action buttons row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isModern ? Colors.black.withOpacity(0.1) : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.account_tree_outlined,
                  label: 'Yapı',
                  color: accentColor,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => WebSiteStructureDialog(siteId: site['id']),
                    );
                  },
                ),
                Container(width: 1, height: 24, color: isModern ? Colors.white12 : Colors.black12),
                _buildActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Düzenle',
                  color: isModern ? Colors.white70 : Colors.black54,
                  onTap: () => _addOrEditSite(site),
                ),
                Container(width: 1, height: 24, color: isModern ? Colors.white12 : Colors.black12),
                _buildActionButton(
                  icon: Icons.delete_outline,
                  label: 'Sil',
                  color: Colors.redAccent,
                  onTap: () => _deleteSite(site['id'], site['name'] ?? 'Bilinmeyen Site'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

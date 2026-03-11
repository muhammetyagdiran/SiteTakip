import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import 'create_announcement_screen.dart';

class ManagerAnnouncementListScreen extends StatefulWidget {
  final String? siteId;
  final VoidCallback? onBack;
  const ManagerAnnouncementListScreen({super.key, this.siteId, this.onBack});

  @override
  State<ManagerAnnouncementListScreen> createState() => _ManagerAnnouncementListScreenState();
}

class _ManagerAnnouncementListScreenState extends State<ManagerAnnouncementListScreen> {
  final List<dynamic> _announcements = [];
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
    await _fetchAnnouncements();
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

  Future<void> _fetchAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      dynamic query = SupabaseService.client
          .from('announcements')
          .select('*, sites!inner(name, owner_id)')
          .filter('deleted_at', 'is', null); // Soft delete filter
      
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (_selectedSiteId != null) {
        query = query.eq('site_id', _selectedSiteId as String);
      } else if (user?.role == UserRole.systemOwner) {
        final siteIds = _mySites.map((s) => s['id'] as String).toList();
        if (siteIds.isNotEmpty) {
          query = query.inFilter('site_id', siteIds);
        } else {
          setState(() {
            _announcements.clear();
            _isLoading = false;
          });
          return;
        }
      }

      query = query.order('created_at', ascending: false);

      final response = await query;
      setState(() {
        _announcements.clear();
        _announcements.addAll(response as List);
      });
    } catch (e) {
      print('Error fetching announcements: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
        return AlertDialog(
          backgroundColor: isModern ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text('Duyuruyu Sil', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
          content: Text('Bu duyuruyu silmek istediğinize emin misiniz?', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Vazgeç', style: TextStyle(color: isModern ? Colors.white54 : AppColors.mgmtTextBody)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );

    if (confirmed == true) {
      try {
        await SupabaseService.client
            .from('announcements')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', id);
        _fetchAnnouncements();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Duyuru başarıyla silindi')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
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
                      l10n.announcements,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchAnnouncements, 
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22)
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            if (Provider.of<AuthService>(context, listen: false).currentUser?.role == UserRole.systemOwner && widget.siteId == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedSiteId,
                      dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                      isExpanded: true,
                      hint: Text('Tüm Siteler', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontSize: 13)),
                      style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 13),
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: isModern ? Colors.white38 : AppColors.mgmtPrimary),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Tüm Siteler', style: TextStyle(fontSize: 13, color: isModern ? Colors.white : AppColors.mgmtTextHeading))),
                        ..._mySites.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? '', style: TextStyle(fontSize: 13, color: isModern ? Colors.white : AppColors.mgmtTextHeading)))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedSiteId = val);
                        _fetchAnnouncements();
                      },
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _announcements.isEmpty
                      ? Center(child: Text(l10n.noAnnouncements, style: TextStyle(color: isModern ? Colors.white38 : AppColors.mgmtTextBody)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          itemCount: _announcements.length,
                          itemBuilder: (context, index) {
                            final ann = _announcements[index];
                            final siteName = ann['sites']?['name'] ?? l10n.unknownSite;
                            
                            return TweenAnimationBuilder<double>(
                              duration: Duration(milliseconds: 300 + (index * 100)),
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
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (isModern ? AppColors.secondary : AppColors.mgmtAccent).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              siteName,
                                              style: TextStyle(
                                                color: isModern ? AppColors.secondary : AppColors.mgmtAccent, 
                                                fontSize: 10, 
                                                fontWeight: FontWeight.bold
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                ann['created_at'].toString().split('T')[0],
                                                style: TextStyle(color: isModern ? Colors.white38 : AppColors.mgmtTextBody, fontSize: 11),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                                onPressed: () => _deleteAnnouncement(ann['id']),
                                                constraints: const BoxConstraints(),
                                                padding: EdgeInsets.zero,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        ann['title'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 17, 
                                          color: isModern ? Colors.white : AppColors.mgmtTextHeading
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        ann['content'],
                                        style: TextStyle(
                                          color: isModern ? Colors.white.withOpacity(0.7) : AppColors.mgmtTextBody,
                                          height: 1.4,
                                          fontSize: 14,
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
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final auth = Provider.of<AuthService>(context, listen: false);
            String? finalSiteId = _selectedSiteId ?? widget.siteId;

            if (auth.currentUser?.role == UserRole.systemOwner && finalSiteId == null) {
              final selected = await showDialog<String>(
                context: context,
                builder: (context) {
                  final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
                  return AlertDialog(
                    backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateAnnouncementScreen(
                  siteId: finalSiteId,
                  onSaved: () {
                    _fetchAnnouncements();
                  },
                ),
              ),
            );
          },
          label: Text(l10n.newAnnouncement, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          icon: const Icon(Icons.campaign_rounded, color: Colors.white, size: 24),
          backgroundColor: isModern ? AppColors.primary : AppColors.mgmtPrimary,
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

/// Web-optimized Announcements screen for the Owner Dashboard.
class WebAnnouncementListScreen extends StatefulWidget {
  final String? siteId;
  final VoidCallback? onBack;
  const WebAnnouncementListScreen({super.key, this.siteId, this.onBack});

  @override
  State<WebAnnouncementListScreen> createState() => _WebAnnouncementListScreenState();
}

class _WebAnnouncementListScreenState extends State<WebAnnouncementListScreen> {
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
          .filter('deleted_at', 'is', null);

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
            Expanded(child: Text('Duyuruyu Sil', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 18))),
          ],
        ),
        content: Text(
          'Bu duyuruyu silmek istediğinize emin misiniz?',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.client
            .from('announcements')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', id);
        _fetchAnnouncements();
      } catch (e) {
        print('Error deleting announcement: $e');
      }
    }
  }

  Future<void> _createAnnouncement() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    final l10n = AppLocalizations.of(context)!;
    String? finalSiteId = _selectedSiteId ?? widget.siteId;

    // If system owner and no site selected, ask to pick one
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
              children: _mySites
                  .map((s) => ListTile(
                        leading: Icon(Icons.business_rounded, color: isModern ? Colors.white38 : AppColors.mgmtPrimary),
                        title: Text(s['name'] ?? '', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading)),
                        onTap: () => Navigator.pop(ctx, s['id'] as String),
                      ))
                  .toList(),
            ),
          ),
        ),
      );
      if (selected != null) {
        finalSiteId = selected;
      } else {
        return;
      }
    }

    // Show create announcement dialog
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    bool isSaving = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final textColor = isModern ? Colors.white : AppColors.mgmtTextHeading;
          final subtextColor = isModern ? Colors.white70 : AppColors.mgmtTextBody;
          final primaryColor = isModern ? const Color(0xFF3B82F6) : AppColors.mgmtPrimary;

          return AlertDialog(
            backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.campaign_rounded, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(l10n.newAnnouncement, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                const Spacer(),
                IconButton(icon: Icon(Icons.close, color: subtextColor, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: l10n.announcementPrompt,
                      labelStyle: TextStyle(color: subtextColor),
                      prefixIcon: Icon(Icons.title_rounded, color: subtextColor),
                      filled: true,
                      fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: l10n.announcementContentLabel,
                      labelStyle: TextStyle(color: subtextColor),
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 80),
                        child: Icon(Icons.description_rounded, color: subtextColor),
                      ),
                      filled: true,
                      fillColor: isModern ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel, style: TextStyle(color: subtextColor, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                icon: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                label: Text(isSaving ? 'Yayınlanıyor...' : 'Yayınla', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
                          setDialogState(() => errorMessage = 'Lütfen başlık ve içerik alanlarını doldurun.');
                          return;
                        }
                        setDialogState(() { isSaving = true; errorMessage = null; });
                        try {
                          await SupabaseService.client.from('announcements').insert({
                            'site_id': finalSiteId,
                            'title': titleController.text.trim(),
                            'content': contentController.text.trim(),
                            'created_by': auth.currentUser!.id,
                          });
                          Navigator.pop(ctx);
                          _fetchAnnouncements();
                        } catch (e) {
                          setDialogState(() { isSaving = false; errorMessage = 'Hata: $e'; });
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

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
                      Text(l10n.announcements, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 4),
                      Text('Site sakinlerine duyurularınızı yayınlayın ve yönetin.', style: TextStyle(color: subtextColor, fontSize: 16)),
                    ],
                  ),
                ),
                // Site filter dropdown
                if (Provider.of<AuthService>(context, listen: false).currentUser?.role == UserRole.systemOwner && widget.siteId == null)
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
                        hint: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_rounded, size: 16, color: subtextColor),
                            const SizedBox(width: 6),
                            Text('Tüm Siteler', style: TextStyle(color: subtextColor, fontSize: 13)),
                          ],
                        ),
                        style: TextStyle(color: textColor, fontSize: 13),
                        items: [
                          DropdownMenuItem(value: null, child: Text('Tüm Siteler', style: TextStyle(fontSize: 13, color: textColor))),
                          ..._mySites.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? '', style: TextStyle(fontSize: 13, color: textColor)))),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedSiteId = val);
                          _fetchAnnouncements();
                        },
                      ),
                    ),
                  ),
                IconButton(onPressed: _fetchAnnouncements, icon: const Icon(Icons.refresh), color: subtextColor, tooltip: 'Yenile'),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _createAnnouncement,
                  icon: const Icon(Icons.campaign_rounded, color: Colors.white, size: 18),
                  label: Text(l10n.newAnnouncement, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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

          const SizedBox(height: 16),

          // ──── Summary ────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                _buildSummaryCard('Toplam', '${_announcements.length}', Icons.campaign_rounded, primaryColor, isModern, cardBg, textColor, subtextColor),
                const SizedBox(width: 12),
                _buildSummaryCard('Bu Ay', '${_announcements.where((a) {
                  final date = DateTime.tryParse(a['created_at'] ?? '');
                  if (date == null) return false;
                  final now = DateTime.now();
                  return date.month == now.month && date.year == now.year;
                }).length}', Icons.calendar_month_rounded, Colors.cyan, isModern, cardBg, textColor, subtextColor),
                const SizedBox(width: 12),
                _buildSummaryCard('Site Sayısı', '${_mySites.length}', Icons.business_rounded, Colors.orange, isModern, cardBg, textColor, subtextColor),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ──── Announcements Grid ────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _announcements.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.campaign_outlined, size: 64, color: subtextColor),
                            const SizedBox(height: 16),
                            Text(l10n.noAnnouncements, style: TextStyle(fontSize: 16, color: subtextColor)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _createAnnouncement,
                              icon: const Icon(Icons.add, color: Colors.white, size: 18),
                              label: Text(l10n.newAnnouncement, style: const TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 450,
                          mainAxisExtent: 210,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: _announcements.length,
                        itemBuilder: (context, index) {
                          final ann = _announcements[index];
                          return _buildAnnouncementCard(ann, index, isModern, cardBg, textColor, subtextColor, primaryColor, l10n);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(dynamic ann, int index, bool isModern, Color cardBg, Color textColor, Color subtextColor, Color primaryColor, AppLocalizations l10n) {
    final siteName = ann['sites']?['name'] ?? l10n.unknownSite;
    final date = ann['created_at'].toString().split('T')[0];
    final accentColors = [
      const Color(0xFF6366F1),
      const Color(0xFF06B6D4),
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];
    final accent = accentColors[index % accentColors.length];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showAnnouncementDetail(ann, isModern, textColor, subtextColor, primaryColor, l10n),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
            boxShadow: isModern ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top accent bar
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row: site badge + date + delete
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(siteName, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(),
                          Text(date, style: TextStyle(color: subtextColor, fontSize: 12)),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _deleteAnnouncement(ann['id']),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.7), size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Title
                      Text(
                        ann['title'] ?? '',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Content preview
                      Expanded(
                        child: Text(
                          ann['content'] ?? '',
                          style: TextStyle(color: subtextColor, fontSize: 13, height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
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
  }

  void _showAnnouncementDetail(dynamic ann, bool isModern, Color textColor, Color subtextColor, Color primaryColor, AppLocalizations l10n) {
    final siteName = ann['sites']?['name'] ?? l10n.unknownSite;
    final date = ann['created_at'].toString().split('T')[0];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isModern ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.campaign_rounded, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(ann['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18))),
            IconButton(icon: Icon(Icons.close, color: subtextColor, size: 20), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meta row
              Row(
                children: [
                  Icon(Icons.business_rounded, size: 14, color: subtextColor),
                  const SizedBox(width: 6),
                  Text(siteName, style: TextStyle(fontSize: 13, color: subtextColor)),
                  const Spacer(),
                  Icon(Icons.calendar_today_rounded, size: 14, color: subtextColor),
                  const SizedBox(width: 6),
                  Text(date, style: TextStyle(fontSize: 13, color: subtextColor)),
                ],
              ),
              const SizedBox(height: 16),
              // Content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isModern ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                ),
                child: Text(ann['content'] ?? '', style: TextStyle(color: textColor, fontSize: 14, height: 1.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color, bool isModern, Color cardBg, Color textColor, Color subtextColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isModern ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: textColor)),
                Text(label, style: TextStyle(fontSize: 12, color: subtextColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:site_takip/services/theme_service.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'package:animations/animations.dart';
import '../../widgets/glass_widgets.dart';
import 'package:site_takip/l10n/app_localizations.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  final String? siteId;
  const CreateAnnouncementScreen({super.key, this.onSaved, this.siteId});

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _selectedSiteId;
  List<dynamic> _sites = [];
  bool _isSaving = false;
  bool _isLoadingSites = false;

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.siteId;
    if (_selectedSiteId == null) {
      _fetchSites();
    }
  }

  Future<void> _fetchSites() async {
    setState(() => _isLoadingSites = true);
    try {
      final response = await SupabaseService.client
          .from('sites')
          .select('id, name')
          .filter('deleted_at', 'is', null); // Soft delete filter
      setState(() {
        _sites = response as List;
      });
    } catch (e) {
      print('Error fetching sites: $e');
    } finally {
      setState(() => _isLoadingSites = false);
    }
  }

  Future<void> _saveAnnouncement() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty || _selectedSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun ve site seçin.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) throw Exception('Kullanıcı oturumu bulunamadı.');
      
      await SupabaseService.client.from('announcements').insert({
        'title': title,
        'content': content,
        'site_id': _selectedSiteId,
        'author_id': userId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duyuru başarıyla paylaşıldı.')),
        );
        if (widget.onSaved != null) {
          widget.onSaved!();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error saving announcement: $e');
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('403') || errorMessage.contains('row-level security')) {
          errorMessage = 'Yetki hatası: Bu siteye duyuru paylaşma yetkiniz bulunmuyor (403).';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.newAnnouncement,
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 500),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (isModern ? AppColors.secondary : AppColors.mgmtAccent).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.campaign_rounded, size: 32, color: isModern ? AppColors.secondary : AppColors.mgmtAccent),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.newAnnouncement,
                                    style: TextStyle(
                                      fontSize: 20, 
                                      fontWeight: FontWeight.bold,
                                      color: isModern ? Colors.white : AppColors.mgmtTextHeading
                                    ),
                                  ),
                                  Text(
                                    'Site sakinlerine mesaj gönder',
                                    style: TextStyle(
                                      color: isModern ? Colors.white38 : AppColors.mgmtTextBody,
                                      fontSize: 12
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        if (widget.siteId == null) ...[
                          if (_isLoadingSites)
                            const LinearProgressIndicator()
                          else
                            DropdownButtonFormField<String>(
                              value: _selectedSiteId,
                              dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
                              decoration: InputDecoration(
                                labelText: 'Duyuru Yapılacak Site',
                                labelStyle: TextStyle(color: isModern ? Colors.white38 : AppColors.mgmtTextBody),
                                prefixIcon: Icon(Icons.business_rounded, color: isModern ? Colors.white38 : AppColors.mgmtPrimary),
                              ),
                              items: _sites.map((site) => DropdownMenuItem(
                                value: site['id'].toString(),
                                child: Text(site['name'].toString()),
                              )).toList(),
                              onChanged: (val) => setState(() => _selectedSiteId = val),
                            ),
                          const SizedBox(height: 20),
                        ],

                        TextField(
                          controller: _titleController,
                          style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading),
                          decoration: InputDecoration(
                            labelText: l10n.titleLabel,
                            labelStyle: TextStyle(color: isModern ? Colors.white38 : AppColors.mgmtTextBody),
                            prefixIcon: Icon(Icons.title_rounded, color: isModern ? Colors.white38 : AppColors.mgmtPrimary),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _contentController,
                          maxLines: 8,
                          style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, height: 1.4),
                          decoration: InputDecoration(
                            labelText: l10n.announcementContentLabel,
                            labelStyle: TextStyle(color: isModern ? Colors.white38 : AppColors.mgmtTextBody),
                            alignLabelWithHint: true,
                            hintText: l10n.announcementPrompt,
                            hintStyle: TextStyle(color: isModern ? Colors.white10 : Colors.black12, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 40),
                        if (_isSaving)
                          const Center(child: CircularProgressIndicator())
                        else
                          GlassButton(
                            onPressed: _saveAnnouncement,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(l10n.shareNow, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
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

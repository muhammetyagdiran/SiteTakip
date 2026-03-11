import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:site_takip/services/theme_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import 'package:animations/animations.dart';
import 'package:site_takip/l10n/app_localizations.dart';

class AnnouncementListScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const AnnouncementListScreen({super.key, this.onBack});

  @override
  State<AnnouncementListScreen> createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  final List<dynamic> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client
          .from('announcements')
          .select()
          .filter('deleted_at', 'is', null) // Soft delete filter
          .order('created_at', ascending: false);
      setState(() {
        _announcements.clear();
        _announcements.addAll(response);
      });
    } catch (e) {
      print('Error fetching announcements: $e');
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
                ],
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
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (isModern ? AppColors.secondary : AppColors.primary).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              l10n.newBadge, 
                                              style: TextStyle(
                                                color: isModern ? AppColors.secondary : AppColors.primary, 
                                                fontSize: 10, 
                                                fontWeight: FontWeight.bold
                                              )
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            ann['created_at'].toString().split('T')[0],
                                            style: TextStyle(color: isModern ? Colors.white38 : AppColors.textBody, fontSize: 11),
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
                                          color: isModern ? Colors.white70 : AppColors.textBody, 
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
    );
  }
}

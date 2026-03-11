import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import 'package:provider/provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import 'create_request_screen.dart';

class ResidentRequestListScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ResidentRequestListScreen({super.key, this.onBack});

  @override
  State<ResidentRequestListScreen> createState() => _ResidentRequestListScreenState();
}

class _ResidentRequestListScreenState extends State<ResidentRequestListScreen> {
  final List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyRequests();
  }

  Future<void> _fetchMyRequests() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      
      if (userId == null) return;

      final response = await SupabaseService.client
          .from('requests')
          .select('*')
          .filter('deleted_at', 'is', null) // Soft delete filter
          .eq('resident_id', userId)
          .order('created_at', ascending: false);
      
      setState(() {
        _requests.clear();
        _requests.addAll(response);
      });
    } catch (e) {
      print('Error fetching my requests: $e');
    } finally {
      setState(() => _isLoading = false);
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
                      'Taleplerim',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchMyRequests, 
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _requests.isEmpty
                      ? Center(child: Text(l10n.noActiveRequestsFound))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            final req = _requests[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8), // Reduced bottom margin
                              child: GlassCard(
                                padding: const EdgeInsets.all(12), // Reduced card padding
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            req['title'],
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white : AppColors.mgmtTextHeading), // Reduced font size
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusBadge(req['status']),
                                      ],
                                    ),
                                    const SizedBox(height: 10), // Reduced gap
                                    Container(
                                      padding: const EdgeInsets.all(10), // Reduced container padding
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white.withOpacity(0.04) : Colors.grey[50],
                                        borderRadius: BorderRadius.circular(10), // Reduced border radius
                                        border: Border.all(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.2)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            req['description'] ?? '',
                                            style: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white70 : AppColors.mgmtTextBody, fontSize: 12), // Reduced font size
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8), // Reduced gap
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              req['created_at'] != null ? DateFormat('dd.MM.yyyy').format(DateTime.parse(req['created_at'])) : '',
                                              style: TextStyle(color: Provider.of<ThemeService>(context, listen: false).isModern ? Colors.white30 : AppColors.mgmtTextBody.withOpacity(0.5), fontSize: 11), // Reduced font size
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateRequestScreen(
                  onSaved: () {
                    _fetchMyRequests();
                  },
                ),
              ),
            );
          },
          label: const Text('Yeni Talep Oluştur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          icon: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 24),
          backgroundColor: Provider.of<ThemeService>(context, listen: false).isModern ? AppColors.primary : AppColors.mgmtPrimary,
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'open':
        color = Colors.blue;
        text = 'AÇIK';
        break;
      case 'in_progress':
        color = Colors.orange;
        text = 'İŞLEMDE';
        break;
      case 'completed':
        color = Colors.green;
        text = 'TAMAMLANDI';
        break;
      default:
        color = Colors.grey;
        text = status.toUpperCase();
    }

    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isModern ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(isModern ? 0.4 : 0.6), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

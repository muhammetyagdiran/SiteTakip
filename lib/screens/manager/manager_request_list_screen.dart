import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../services/theme_service.dart';
import 'package:provider/provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../theme/app_theme.dart';
import 'package:site_takip/l10n/app_localizations.dart';

class ManagerRequestListScreen extends StatefulWidget {
  final String? siteId;
  final VoidCallback? onBack;
  const ManagerRequestListScreen({super.key, this.siteId, this.onBack});

  @override
  State<ManagerRequestListScreen> createState() => _ManagerRequestListScreenState();
}

class _ManagerRequestListScreenState extends State<ManagerRequestListScreen> {
  final List<dynamic> _requests = [];
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
    await _fetchRequests();
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

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      dynamic query = SupabaseService.client
          .from('requests')
          .select('*, profiles(full_name), apartments!inner(number, blocks!inner(name, sites!inner(name, owner_id)))')
          .filter('deleted_at', 'is', null); // Soft delete filter
      
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (_selectedSiteId != null) {
        query = query.eq('apartments.blocks.site_id', _selectedSiteId as String);
      } else if (user?.role == UserRole.systemOwner) {
        final siteIds = _mySites.map((s) => s['id'] as String).toList();
        if (siteIds.isNotEmpty) {
          query = query.inFilter('apartments.blocks.site_id', siteIds);
        } else {
          setState(() {
            _requests.clear();
            _isLoading = false;
          });
          return;
        }
      }
      
      query = query.order('created_at', ascending: false);

      final response = await query;
      setState(() {
        _requests.clear();
        _requests.addAll(response as List);
      });
    } catch (e) {
      print('Error fetching requests: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await SupabaseService.client
          .from('requests')
          .update({'status': newStatus})
          .eq('id', id);
      _fetchRequests();
    } catch (e) {
      print('Status update error: $e');
    }
  }

  Future<void> _deleteRequest(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
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
                child: Text('Talebi Sil', style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 18)),
              ),
            ],
          ),
          content: Text('Bu talebi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontSize: 14)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        await SupabaseService.client
            .from('requests')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', id);
        _fetchRequests();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Talep silindi.')));
        }
      } catch (e) {
        print('Error deleting request: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
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
                      l10n.incomingRequests,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchRequests, 
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (Provider.of<AuthService>(context, listen: false).currentUser?.role == UserRole.systemOwner && widget.siteId == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isModern ? Colors.white.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isModern ? Colors.white10 : AppColors.mgmtBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedSiteId,
                      dropdownColor: isModern ? const Color(0xFF1E293B) : Colors.white,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: isModern ? Colors.white54 : AppColors.mgmtPrimary),
                      hint: Row(
                        children: [
                          Icon(Icons.business_rounded, size: 18, color: isModern ? Colors.white54 : AppColors.mgmtPrimary.withOpacity(0.7)),
                          const SizedBox(width: 8),
                          Text('Tüm Siteler', style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontSize: 14)),
                        ],
                      ),
                      style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading, fontSize: 14, fontWeight: FontWeight.w500),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Tüm Siteler', style: TextStyle(fontSize: 14, color: isModern ? Colors.white : AppColors.mgmtTextHeading))),
                        ..._mySites.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? '', style: TextStyle(fontSize: 14, color: isModern ? Colors.white : AppColors.mgmtTextHeading)))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedSiteId = val);
                        _fetchRequests();
                      },
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _requests.isEmpty
                      ? Center(child: Text(l10n.noActiveRequestsFound))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            final req = _requests[index];
                            final status = req['status'];
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8), // Reuced bottom padding
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
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isModern ? Colors.white : AppColors.mgmtTextHeading), // Reduced font size
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildActionableStatusBadge(req['id'], status),
                                        if (Provider.of<AuthService>(context, listen: false).currentUser?.role == UserRole.systemOwner)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 6),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(10),
                                                onTap: () => _deleteRequest(req['id']),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(4),
                                                  child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.8), size: 20), // Smaller icon
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10), // Reduced gap
                                    Container(
                                      padding: const EdgeInsets.all(10), // Reduced container padding
                                      decoration: BoxDecoration(
                                        color: isModern ? Colors.white.withOpacity(0.04) : Colors.grey[50],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: isModern ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.2)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.location_city_rounded, size: 14, color: AppColors.secondary.withOpacity(0.8)), // Smaller icon
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  '${req['apartments']?['blocks']?['sites']?['name'] ?? l10n.unknownSite} / '
                                                  '${req['apartments']?['blocks']?['name'] ?? '-'} / '
                                                  'No: ${req['apartments']?['number'] ?? '-'}',
                                                  style: TextStyle(fontSize: 12, color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontWeight: FontWeight.w500), // Reduced font size
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6), // Reduced gap
                                          Row(
                                            children: [
                                              Icon(Icons.person_rounded, size: 14, color: AppColors.primary.withOpacity(0.8)), // Smaller icon
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  '${req['profiles']?['full_name'] ?? l10n.unknown}',
                                                  style: TextStyle(color: isModern ? Colors.white70 : AppColors.mgmtTextBody, fontSize: 12, fontWeight: FontWeight.w500), // Reduced font size
                                                ),
                                              ),
                                              Text(
                                                req['created_at'].toString().split('T')[0],
                                                style: TextStyle(color: isModern ? Colors.white30 : AppColors.mgmtTextBody.withOpacity(0.5), fontSize: 11), // Reduced font size
                                              ),
                                            ],
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
    );
  }

  Widget _buildActionableStatusBadge(String reqId, String status) {
    final isModern = Provider.of<ThemeService>(context, listen: false).isModern;
    Color color;
    String text;
    switch (status) {
      case 'open':
        color = Colors.blue;
        text = AppLocalizations.of(context)!.open.toUpperCase();
        break;
      case 'in_progress':
        color = Colors.orange;
        text = AppLocalizations.of(context)!.inProgress.toUpperCase();
        break;
      case 'completed':
        color = Colors.green;
        text = AppLocalizations.of(context)!.completed.toUpperCase();
        break;
      default:
        color = Colors.grey;
        text = status.toUpperCase();
    }

    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<String>(
      onSelected: (val) => _updateStatus(reqId, val),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isModern ? const Color(0xFF1E293B) : Colors.white,
      position: PopupMenuPosition.under,
      child: Container(
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
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'open', child: Text(l10n.open, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading))),
        PopupMenuItem(value: 'in_progress', child: Text(l10n.inProgress, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading))),
        PopupMenuItem(value: 'completed', child: Text(l10n.completed, style: TextStyle(color: isModern ? Colors.white : AppColors.mgmtTextHeading))),
      ],
    );
  }
}
